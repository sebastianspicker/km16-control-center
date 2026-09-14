#!/usr/bin/env python3
"""Save only this pad's registry evidence and HID report descriptors. No HID writes."""
import datetime
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess

ROOT = Path(__file__).resolve().parents[2]
VID, PID = 0x28E9, 0x3145

def walk(nodes):
    for node in nodes:
        yield node
        yield from walk(node.get("IORegistryEntryChildren", []))

def registry(kind):
    return plistlib.loads(subprocess.check_output(["ioreg", "-a", "-r", "-c", kind]))

def main():
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    out = ROOT / "evidence/device-snapshots" / stamp
    out.mkdir(parents=True)
    hid = [n for n in walk(registry("IOHIDDevice"))
           if n.get("VendorID") == VID and n.get("ProductID") == PID]
    usb = [n for n in walk(registry("IOUSBHostDevice"))
           if n.get("idVendor") == VID and n.get("idProduct") == PID]
    # Preserve the selected nodes; child nodes describe this same physical device.
    for name, data in [("hid.plist", hid), ("usb.plist", usb)]:
        (out / name).write_bytes(plistlib.dumps(data))
    fields = ("Product", "Manufacturer", "VendorID", "ProductID", "PrimaryUsagePage",
              "PrimaryUsage", "MaxInputReportSize", "MaxOutputReportSize",
              "MaxFeatureReportSize", "Transport", "LocationID", "IORegistryEntryID")
    interfaces = []
    for n in hid:
        row = {k: n.get(k) for k in fields}
        descriptor = n.get("ReportDescriptor", b"")
        name = f"report-{n['IORegistryEntryID']:x}-{n.get('PrimaryUsagePage', 0):04x}.bin"
        (out / name).write_bytes(descriptor)
        row.update(descriptor_file=name, descriptor_hex=descriptor.hex(),
                   descriptor_sha256=hashlib.sha256(descriptor).hexdigest())
        interfaces.append(row)
    manifest = {"captured_at_utc": stamp, "vid": "28e9", "pid": "3145",
                "interfaces": interfaces,
                "usb": [{k: n.get(k) for k in ("USB Product Name", "USB Vendor Name",
                         "bcdDevice", "bcdUSB", "UsbLinkSpeed", "locationID")} for n in usb]}
    (out / "device.json").write_text(json.dumps(manifest, indent=2) + "\n")
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
              for p in sorted(out.iterdir()) if p.is_file()}
    (out / "sha256.json").write_text(json.dumps(hashes, indent=2) + "\n")
    print(f"{out}: {len(hid)} HID interface(s), {len(usb)} USB device(s)")
    return 0 if hid else 3

if __name__ == "__main__":
    raise SystemExit(main())
