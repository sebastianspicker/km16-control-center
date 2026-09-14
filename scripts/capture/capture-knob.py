#!/usr/bin/env python3
"""Record one labelled knob action; SIGINT ends acquisition and saves evidence."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


MAX_CAPTURE_BYTES = 8 * 1024 * 1024
MAX_CAPTURE_REPORTS = 20_000
MAX_REPORT_BYTES = 65_536
MAX_REPORT_LINE_BYTES = MAX_REPORT_BYTES * 2 + 192
MAX_CAPTURE_JSONL_BYTES = MAX_CAPTURE_BYTES * 2 + MAX_CAPTURE_REPORTS * 192
LOG_EXCERPT_BYTES = 16 * 1024
HEX_DIGITS = frozenset("0123456789abcdefABCDEF")
INTERFACES = (
    ("keyboard", "0001", "0006"),
    ("composite", "0001", "0002"),
    ("vendor-via", "ff60", "61"),
    ("vendor-input", "ff31", "74"),
)


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=[
        f"{knob}-{action}"
        for knob in ("upper-left", "upper-right", "bottom")
        for action in ("cw", "ccw", "click")
    ])
    parser.add_argument("--seconds", type=int, default=120)
    args = parser.parse_args(argv)
    if not 1 <= args.seconds <= 3600:
        parser.error("seconds must be 1..3600")
    return args


def read_log_excerpt(path):
    try:
        with path.open("rb") as stream:
            content = stream.read(LOG_EXCERPT_BYTES + 1)
    except OSError as error:
        return f"log unavailable: {error}"
    clipped = len(content) > LOG_EXCERPT_BYTES
    text = content[:LOG_EXCERPT_BYTES].decode("utf-8", errors="replace").strip()
    return text + ("\n[log excerpt truncated]" if clipped else "")


def read_capture_rows(path, interface):
    """Return a bounded valid prefix, accounting, and any evidence error."""
    rows = []
    jsonl_bytes = 0
    payload_bytes = 0
    line_number = 0
    error = None
    try:
        with path.open("rb") as stream:
            while True:
                line = stream.readline(MAX_REPORT_LINE_BYTES + 1)
                if not line:
                    break
                line_number += 1
                if len(line) > MAX_REPORT_LINE_BYTES:
                    error = f"line {line_number} exceeds the report record limit"
                    break
                jsonl_bytes += len(line)
                if jsonl_bytes > MAX_CAPTURE_JSONL_BYTES:
                    error = "JSONL byte quota exceeded"
                    break
                if len(rows) >= MAX_CAPTURE_REPORTS:
                    error = "report quota exceeded"
                    break
                if not line.endswith(b"\n"):
                    error = f"line {line_number} is unterminated"
                    break
                try:
                    row = json.loads(line)
                except (UnicodeDecodeError, ValueError, RecursionError) as decode_error:
                    error = f"line {line_number} is invalid JSON: {decode_error}"
                    break
                if not isinstance(row, dict):
                    error = f"line {line_number} is not a JSON object"
                    break
                try:
                    timestamp = int(row["unix_ns"])
                except (KeyError, TypeError, ValueError, OverflowError):
                    error = f"line {line_number} has an invalid unix_ns"
                    break
                if timestamp < 0:
                    error = f"line {line_number} has an invalid unix_ns"
                    break
                report_type = row.get("type")
                report_id = row.get("report_id")
                if (not isinstance(report_type, int) or isinstance(report_type, bool) or
                        not 0 <= report_type <= 2):
                    error = f"line {line_number} has an invalid report type"
                    break
                if (not isinstance(report_id, int) or isinstance(report_id, bool) or
                        not 0 <= report_id <= 0xffffffff):
                    error = f"line {line_number} has an invalid report ID"
                    break
                report_hex = row.get("hex")
                if (not isinstance(report_hex, str) or len(report_hex) % 2 or
                        any(character not in HEX_DIGITS for character in report_hex)):
                    error = f"line {line_number} has invalid report hex"
                    break
                report_bytes = len(report_hex) // 2
                if report_bytes > MAX_REPORT_BYTES:
                    error = f"line {line_number} exceeds the report payload limit"
                    break
                if payload_bytes + report_bytes > MAX_CAPTURE_BYTES:
                    error = "payload byte quota exceeded"
                    break
                payload_bytes += report_bytes
                rows.append({
                    "unix_ns": row["unix_ns"],
                    "type": report_type,
                    "report_id": report_id,
                    "hex": report_hex,
                    "interface": interface,
                })
    except OSError as read_error:
        error = f"could not read evidence: {read_error}"
    accounting = {
        "reports": len(rows),
        "payload_bytes": payload_bytes,
        "jsonl_bytes_read": jsonl_bytes,
    }
    return rows, accounting, error


def merge_capture_rows(rows_by_interface):
    """Globally sort bounded rows, including per-interface clock regressions."""
    merged = []
    for rows in rows_by_interface:
        merged.extend(rows)
    merged.sort(key=lambda row: int(row["unix_ns"]))
    return merged


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main(argv=None):
    args = parse_args(argv)
    root = Path(__file__).resolve().parents[2]
    start = datetime.datetime.now(datetime.timezone.utc)
    out = root / "evidence/captures" / (
        "knob-" + args.action + "-" + start.strftime("%Y%m%dT%H%M%S.%fZ")
    )
    out.mkdir()
    processes = []
    stopped = False
    runner_error = None

    def stop(signum, frame):
        del signum, frame
        nonlocal stopped
        stopped = True
        for _, process, _, _ in processes:
            if process.poll() is None:
                process.send_signal(signal.SIGINT)

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    meta = {
        "requested_action": args.action,
        "started_at_utc": start.isoformat(),
        "maximum_seconds": args.seconds,
        "vid": "28e9",
        "pid": "3145",
        "physical_action_verification": "Awaiting user confirmation",
        "limits": {
            "per_interface_payload_bytes": MAX_CAPTURE_BYTES,
            "per_interface_reports": MAX_CAPTURE_REPORTS,
            "per_interface_jsonl_bytes": MAX_CAPTURE_JSONL_BYTES,
        },
        "interfaces": {},
    }
    (out / "capture.json").write_text(json.dumps(meta, indent=2) + "\n")
    try:
        for name, page, usage in INTERFACES:
            meta["interfaces"][name] = {"usage_page": page, "usage": usage}
            data = (out / (name + ".jsonl")).open("x")
            try:
                log = (out / (name + ".log")).open("x")
            except Exception:
                data.close()
                raise
            try:
                process = subprocess.Popen([
                    str(root / "bin/hid-capture"), "28e9", "3145", page, usage,
                    str(args.seconds),
                ], stdout=data, stderr=log)
            except Exception:
                data.close()
                log.close()
                raise
            processes.append((name, process, data, log))
        time.sleep(0.3)
        print("RUNNER PID:", os.getpid(), "DIRECTORY:", out, flush=True)
        for name, _, _, _ in processes:
            print(name + ": " + read_log_excerpt(out / (name + ".log")), flush=True)
        if any(process.poll() is not None for _, process, _, _ in processes):
            stop(None, None)
        for name, process, _, _ in processes:
            meta["interfaces"][name]["exit_code"] = process.wait()
    except Exception as error:
        runner_error = f"{type(error).__name__}: {error}"
        meta["runner_error"] = runner_error
        stop(None, None)
    finally:
        for name, process, data, log in processes:
            if process.poll() is None:
                process.send_signal(signal.SIGINT)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            meta["interfaces"][name].setdefault("exit_code", process.returncode)
            data.close()
            log.close()

    rows_by_interface = []
    evidence_errors = []
    for name, _, _ in INTERFACES:
        interface_meta = meta["interfaces"].get(name)
        if interface_meta is None:
            continue
        path = out / (name + ".jsonl")
        rows, accounting, error = read_capture_rows(path, name)
        interface_meta.update(accounting)
        if interface_meta.get("exit_code") != 0:
            interface_meta["capture_error"] = (
                f"hid-capture exited with code {interface_meta.get('exit_code')}; "
                f"see {name}.log"
            )
            evidence_errors.append(f"{name}: {interface_meta['capture_error']}")
        if error is not None:
            interface_meta["evidence_error"] = error
            evidence_errors.append(f"{name}: {error}")
        rows_by_interface.append(rows)

    merged = merge_capture_rows(rows_by_interface)
    with (out / "timeline.jsonl").open("x") as timeline:
        for row in merged:
            timeline.write(json.dumps(row) + "\n")
    partial = runner_error is not None or bool(evidence_errors)
    meta.update(
        finished_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        stopped_by_signal=stopped,
        capture_status="partial" if partial else "complete",
        partial_evidence=partial,
    )
    if evidence_errors:
        meta["errors"] = evidence_errors
    (out / "capture.json").write_text(json.dumps(meta, indent=2) + "\n")
    hashes = {
        path.name: sha256_file(path)
        for path in sorted(out.iterdir())
        if path.is_file() and path.name != "sha256.json"
    }
    (out / "sha256.json").write_text(json.dumps(hashes, indent=2) + "\n")
    print("FINISHED", args.action, "reports:", len(merged), flush=True)
    return 1 if partial else 0


if __name__ == "__main__":
    sys.exit(main())
