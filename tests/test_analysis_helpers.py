"""Unit checks for the offline firmware-analysis helpers."""
import importlib.util
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


MODULE_PATH = (
    Path(__file__).resolve().parents[1] / "scripts/analysis/analyze-firmware.py"
)
SPEC = importlib.util.spec_from_file_location("analyze_firmware", MODULE_PATH)
analyze_firmware = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(analyze_firmware)


class PublicCheckoutCLITest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.script = self.root / "scripts/analysis/analyze-firmware.py"
        self.script.parent.mkdir(parents=True)
        shutil.copyfile(MODULE_PATH, self.script)
        self.firmware = self.root / "input.bin"
        self.definition = self.root / "definition.json"
        self.snapshot = self.root / "snapshot.json"
        self.firmware.write_bytes(b"synthetic unsupported firmware")
        self.definition.write_text("{}")
        self.snapshot.write_text("{}")
        self.required = ["--snapshot", str(self.snapshot),
                         "--output", str(self.root / "output")]

    def run_cli(self, *arguments):
        return subprocess.run([sys.executable, str(self.script), *arguments],
                              capture_output=True, text=True, timeout=10)

    def test_help_needs_no_private_artifacts(self):
        result = self.run_cli("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--firmware", result.stdout)

    def test_explicit_inputs_work_without_vendor_directory(self):
        result = self.run_cli("--firmware", str(self.firmware),
                              "--definition", str(self.definition), *self.required)
        self.assertEqual(result.returncode, 2)
        self.assertIn("Unsupported image hash", result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        self.assertFalse((self.root / "output").exists())

    def test_missing_default_reports_required_option(self):
        result = self.run_cli(*self.required)
        self.assertEqual(result.returncode, 2)
        self.assertIn("--firmware is required", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_single_defaults_resolve_but_ambiguous_defaults_are_rejected(self):
        vendor = self.root / "firmware/vendor"
        vendor.mkdir(parents=True)
        shutil.copyfile(self.firmware, vendor / "first.bin")
        shutil.copyfile(self.definition, vendor / "definition.json")
        result = self.run_cli(*self.required)
        self.assertEqual(result.returncode, 2)
        self.assertIn("Unsupported image hash", result.stderr)
        shutil.copyfile(self.firmware, vendor / "second.bin")
        result = self.run_cli(*self.required)
        self.assertEqual(result.returncode, 2)
        self.assertIn("has 2 matches", result.stderr)
        self.assertNotIn("Traceback", result.stderr)


class DescriptorSearchTest(unittest.TestCase):
    def test_find_all_preserves_overlapping_matches(self):
        self.assertEqual(analyze_firmware.find_all(b"aaaa", b"aa"), [0, 1, 2])

    def test_find_all_rejects_empty_needle(self):
        with self.assertRaisesRegex(ValueError, "must not be empty"):
            analyze_firmware.find_all(b"abc", b"")


class ReportSizeTest(unittest.TestCase):
    def test_decodes_known_input_report(self):
        descriptor = bytes.fromhex("750895048101")
        self.assertEqual(
            analyze_firmware.report_sizes(descriptor),
            [{"type": "input", "id": 0, "payload_bits": 32,
              "bytes_including_id": 4}],
        )

    def test_rejects_truncated_items(self):
        for descriptor in (b"\xfe", b"\xfe\x04\x00\x01", b"\x76\x01"):
            with self.subTest(descriptor=descriptor):
                with self.assertRaisesRegex(ValueError, "truncated HID"):
                    analyze_firmware.report_sizes(descriptor)

    def test_rejects_unmatched_global_pop(self):
        with self.assertRaisesRegex(ValueError, "pop without matching push"):
            analyze_firmware.report_sizes(b"\xb4")


if __name__ == "__main__":
    unittest.main()
