"""Synthetic, device-free checks for bounded capture evidence handling."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


MODULE_PATH = Path(__file__).resolve().parents[2] / "scripts/capture/capture-knob.py"
REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("capture_knob", MODULE_PATH)
capture_knob = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(capture_knob)


def record(timestamp, report_hex="00", **extra):
    row = {
        "unix_ns": str(timestamp),
        "type": 0,
        "report_id": 1,
        "hex": report_hex,
    }
    row.update(extra)
    return json.dumps(row).encode() + b"\n"


class CaptureEvidenceLimitTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)

    def tearDown(self):
        self.temporary.cleanup()

    def write(self, name, content):
        path = self.root / name
        path.write_bytes(content)
        return path

    def test_native_callback_and_quota_helpers(self):
        binary = self.root / "hid-capture-quota-test"
        compile_result = subprocess.run([
            "xcrun", "clang", "-std=c11", "-Wall", "-Wextra", "-Werror", "-O2",
            str(REPOSITORY_ROOT / "scripts/tests/hid-capture-quota.c"),
            "-framework", "IOKit", "-framework", "CoreFoundation", "-o", str(binary),
        ], capture_output=True, text=True)
        self.assertEqual(compile_result.returncode, 0, compile_result.stderr)
        run_result = subprocess.run([str(binary)], capture_output=True, text=True)
        self.assertEqual(run_result.returncode, 0, run_result.stderr)

    def test_report_quota_retains_only_bounded_prefix(self):
        path = self.write("reports.jsonl", record(1) + record(2) + record(3))
        with mock.patch.object(capture_knob, "MAX_CAPTURE_REPORTS", 2):
            rows, accounting, error = capture_knob.read_capture_rows(path, "keyboard")
        self.assertEqual([row["unix_ns"] for row in rows], ["1", "2"])
        self.assertEqual(accounting["reports"], 2)
        self.assertEqual(error, "report quota exceeded")

    def test_payload_quota_retains_only_bounded_prefix(self):
        path = self.write("payload.jsonl", record(1, "0001") + record(2, "02"))
        with mock.patch.object(capture_knob, "MAX_CAPTURE_BYTES", 2):
            rows, accounting, error = capture_knob.read_capture_rows(path, "keyboard")
        self.assertEqual(len(rows), 1)
        self.assertEqual(accounting["payload_bytes"], 2)
        self.assertEqual(error, "payload byte quota exceeded")

    def test_overlong_record_is_rejected_by_bounded_read(self):
        path = self.write("overlong.jsonl", b"x" * 33 + b"\n")
        with mock.patch.object(capture_knob, "MAX_REPORT_LINE_BYTES", 32):
            rows, accounting, error = capture_knob.read_capture_rows(path, "keyboard")
        self.assertEqual(rows, [])
        self.assertEqual(accounting["reports"], 0)
        self.assertEqual(error, "line 1 exceeds the report record limit")

    def test_invalid_tail_retains_partial_evidence(self):
        path = self.write("partial.jsonl", record(1) + b"not-json\n")
        rows, accounting, error = capture_knob.read_capture_rows(path, "vendor-via")
        self.assertEqual(accounting["reports"], 1)
        self.assertEqual(rows[0]["interface"], "vendor-via")
        self.assertRegex(error, r"line 2 is invalid JSON")

    def test_non_finite_timestamp_retains_partial_evidence(self):
        path = self.write("timestamp.jsonl", record(1) + record(2).replace(b'"2"', b"1e999", 1))
        rows, accounting, error = capture_knob.read_capture_rows(path, "vendor-via")
        self.assertEqual(accounting["reports"], 1)
        self.assertEqual(rows[0]["unix_ns"], "1")
        self.assertEqual(error, "line 2 has an invalid unix_ns")

    @unittest.skipUnless(hasattr(sys, "set_int_max_str_digits"), "Interpreter has no integer digit limit")
    def test_oversized_integer_retains_partial_evidence(self):
        oversized = b'{"unix_ns":' + b"9" * 5000 + b',"type":0,"report_id":1,"hex":"00"}\n'
        path = self.write("oversized-integer.jsonl", record(1) + oversized)
        previous_limit = sys.get_int_max_str_digits()
        try:
            sys.set_int_max_str_digits(4300)
            rows, accounting, error = capture_knob.read_capture_rows(path, "vendor-via")
        finally:
            sys.set_int_max_str_digits(previous_limit)
        self.assertEqual(accounting["reports"], 1)
        self.assertEqual(rows[0]["unix_ns"], "1")
        self.assertRegex(error, r"line 2 is invalid JSON")

    def test_unexpected_fields_are_not_retained_in_memory(self):
        path = self.write("extra.jsonl", record(1, ignored=[1, 2, 3]))
        rows, _, error = capture_knob.read_capture_rows(path, "keyboard")
        self.assertIsNone(error)
        self.assertNotIn("ignored", rows[0])

    def test_global_sort_handles_clock_reorder(self):
        first = self.write("first.jsonl", record(30) + record(10))
        second = self.write("second.jsonl", record(20))
        first_rows, _, first_error = capture_knob.read_capture_rows(first, "keyboard")
        second_rows, _, second_error = capture_knob.read_capture_rows(second, "vendor-input")
        merged = capture_knob.merge_capture_rows([first_rows, second_rows])
        self.assertIsNone(first_error)
        self.assertIsNone(second_error)
        self.assertEqual([int(row["unix_ns"]) for row in merged], [10, 20, 30])

    def test_log_excerpt_is_bounded(self):
        path = self.write("capture.log", b"x" * (capture_knob.LOG_EXCERPT_BYTES + 100))
        excerpt = capture_knob.read_log_excerpt(path)
        self.assertTrue(excerpt.startswith("x" * capture_knob.LOG_EXCERPT_BYTES))
        self.assertIn("[log excerpt truncated]", excerpt)


if __name__ == "__main__":
    unittest.main()
