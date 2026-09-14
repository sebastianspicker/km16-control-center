#!/usr/bin/env python3
"""Extract fixed-offset hardware facts from the acquired image, without device I/O."""
import argparse
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[2]
EXPECTED = "5ff18a34b99de0e6ebb657f9f79df8e35a8b8e21459997096c24209bc493262e"
BASE = 0x08002000


def battery_percent(value, wired_input, previous):
    """Independent integer model of 0x08002fe0, including its 3200 hold case."""
    if value >= 4151 or (value <= 899 and wired_input):
        return 100
    for low, high, numerator, denominator, offset in (
        (3200, 3300, 1, 20, 0), (3300, 3470, 1, 34, 5),
        (3470, 3630, 30, 160, 10), (3630, 3760, 20, 130, 40),
        (3760, 3930, 20, 170, 60), (3930, 3980, 1, 10, 80),
        (3980, 4150, 14, 170, 85),
    ):
        if low < value <= high:
            return (value - low) * numerator // denominator + offset
    return 0 if value < 3200 else previous


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dump", type=Path, default=ROOT / "evidence/backups/dfu-backup-20260912T103449Z/km16pro-live-alt2-0x08002000.bin")
    parser.add_argument("--output", type=Path, default=ROOT / "build/analysis/hardware-contract.json")
    args = parser.parse_args()
    raw = args.dump.read_bytes()
    if hashlib.sha256(raw).hexdigest() != EXPECTED:
        parser.error("Image hash differs: recovered offsets require fresh analysis")

    def words(address, count=1):
        return list(struct.unpack_from(f"<{count}I", raw, address - BASE))

    def pin(word):
        port = {0x40010800: "A", 0x40010c00: "B", 0x40011000: "C", 0x40011400: "D"}[word & ~15]
        return f"P{port}{word & 15}"

    matrix = words(0x0800ed10, 10)
    assert matrix == words(0x0800e994, 6) + words(0x0800e9ac, 4)
    descriptor_address = words(0x0800d7e4)[0]
    flash = words(descriptor_address, 7)
    assert flash == [3, 2, 256, 0, 2048, 0x08000000, 524288]
    console = raw[0xd750:0xd765]
    assert console.hex() == "0631ff0974a1010975150026ff00952075088102c0"
    assert words(0x08006218)[0] == 0x0800b811
    assert words(0x0800ded0)[0] == 72000000
    assert words(0x0800f48c, 2) == [36000000, 45]
    led_map = [list(raw[0xdb91 + row * 6:0xdb97 + row * 6]) for row in range(4)]
    boundary_inputs = [0, 899, 900, 3199, 3200, 3201, 3300, 3470, 3630,
                       3760, 3930, 3980, 4150, 4151, 65535]
    battery = [{"input": n, "pb9_low": battery_percent(n, False, 42),
                "pb9_high": battery_percent(n, True, 42)} for n in boundary_inputs]
    assert [battery_percent(n, False, 42) for n in (3200, 3300, 3470, 3630, 3760, 3930, 3980, 4150, 4151)] == [42, 5, 10, 40, 60, 80, 85, 99, 100]
    assert all(0 <= battery_percent(n, w, 42) <= 100 for n in range(65536) for w in (False, True))
    result = {
        "source": {"sha256": EXPECTED, "load_address": hex(BASE), "bytes": len(raw),
                   "authority": "acquired device application; software configuration, not measured circuit"},
        "mcu": {"exact_part": None, "compatible_register_family": "STM32F1", "physical_ram_bytes": None},
        "matrix": {"columns": list(map(pin, matrix[:6])), "rows": list(map(pin, matrix[6:])),
                   "table_address": "0x0800ed10", "sleep_tables_match": True},
        "encoders": {"phase0": list(map(pin, words(0x0800f474, 3))),
                     "phase1": list(map(pin, words(0x0800f480, 3))),
                     "transition_table": list(struct.unpack_from("16b", raw, 0xd464)),
                     "emission": "abs(accumulator)>=4 OR new state3 with nonzero accumulator; reset after attempt",
                     "queue_storage_entries": 4, "queue_usable_entries": 3,
                     "source_functions": ["0x0800954c", "0x08009444"]},
        "leds": {"count": 27, "matrix_index": led_map, "key_range": [0, 15],
                 "status_range": [16, 20], "underglow_range": [21, 26],
                 "signal_pin": "PB8", "enable_pin": "PB7", "enable_initial_level": 0,
                 "timer_input_hz": 72000000, "prescaler": 1, "autoreload": 44,
                 "counter_hz": 36000000, "bit_rate_hz": 800000,
                 "compare_zero": 9, "compare_one": 30, "tail_samples": 170},
        "flash_driver": {"descriptor_address": hex(descriptor_address), "raw_words": flash,
                         "program_unit_bytes": flash[1], "sector_count_in_model": flash[2],
                         "sector_bytes_in_model": flash[4], "model_bytes": flash[6],
                         "physical_capacity_bytes": None,
                         "runtime_capacity_input": "low16 bits at 0x1ffff7e0, KiB; value not captured",
                         "settings_bytes_reserved": 8192,
                         "warning": "512KiB is the compiled driver model, not fitted chip capacity; 2KiB is software erase geometry"},
        "debug": {"source_function": "0x0800448c", "afio_mapr_address": "0x40010004",
                  "stock_swj_cfg": 4, "compatible_map_effect": "disable both JTAG and SWD",
                  "future_port_policy": "do not reproduce debug disable without a demonstrated need"},
        "console": {"usage_page": "0xff31", "usage": "0x74", "interface": 3,
                    "endpoint_in": "0x85", "report_bytes": 32, "descriptor_hex": console.hex(),
                    "enqueue_function": "0x0800b810", "flush_function": "0x0800b844",
                    "ring_storage_bytes": 256, "ring_usable_bytes": 255},
        "wake": {"gpio_both_edges": ["PA0", "PA1", "PA2", "PA3", "PB4", "PB5", "PA6", "PC14"],
                 "sleep_matrix_columns": "all six output-low; all four rows input-pull-up",
                 "usb_exti18": "configured by 0x08003d18; no GPIO identity",
                 "sources": ["0x0800375c", "0x0800394c", "0x08003b2c", "0x08003d18", "0x0800dcb0"]},
        "battery_model": {"source_function": "0x08002fe0", "previous_for_boundary_check": 42,
                          "physical_units_verified": False, "boundaries": battery,
                          "domain_range_check": "all 65536 input values, both PB9 states: output0..100 for previous42"},
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(f"Verified raw tables, console descriptor, flash geometry model and battery boundaries: {args.output}")


if __name__ == "__main__":
    main()
