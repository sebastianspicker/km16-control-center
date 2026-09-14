"""Check journal record boundaries and failure cases against recovered flash format."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("decoder", Path(__file__).resolve().parents[1] / "scripts/analysis/decode-live-eeprom.py")
decoder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(decoder)


def image_with(words):
    image = bytearray(b"\xff" * decoder.JOURNAL_END)
    pos = decoder.JOURNAL_FILE_OFFSET
    for word in words:
        image[pos:pos + 2] = (word ^ 0xffff).to_bytes(2, "little")
        pos += 2
    return image


class JournalTest(unittest.TestCase):
    def test_boolean_record_does_not_skip_following_byte_record(self):
        # Boolean1 at0x80 followed immediately by byte4 at3.
        logical, records, end = decoder.replay_journal(image_with([0x40a0, 0x0443]))
        self.assertEqual(logical[0x80:0x82], b"\x01\x00")
        self.assertEqual(logical[3], 4)
        self.assertEqual(len(records), 2)
        self.assertEqual(end, decoder.JOURNAL_FILE_OFFSET + 4)

    def test_five_byte_record_then_overwrite(self):
        # Address0x196, payload11,22,33,44,55, then single-byte record overwrites0x197.
        logical, records, end = decoder.replay_journal(image_with([0x0128, 0x1196, 0x3322, 0x5544, 0x0108, 0xaa97]))
        self.assertEqual(logical[0x196:0x19b], bytes.fromhex("11aa334455"))
        self.assertEqual(len(records), 2)
        self.assertEqual(end, decoder.JOURNAL_FILE_OFFSET + 12)

    def test_non_erased_base_requires_other_decoder(self):
        image = image_with([])
        image[decoder.STORAGE_FILE_OFFSET] = 0
        with self.assertRaises(decoder.DecodeError):
            decoder.replay_journal(image)

    def test_reserved_record_rejected(self):
        with self.assertRaises(decoder.DecodeError):
            decoder.replay_journal(image_with([0x00c0]))

    def test_out_of_range_write_rejected(self):
        with self.assertRaises(decoder.DecodeError):
            decoder.replay_journal(image_with([0x1008, 0xaa00]))


if __name__ == "__main__":
    unittest.main()
