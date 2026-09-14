#!/usr/bin/env python3
"""Render recovered firmware indices; no device access or assumed case geometry."""
import json
from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "evidence/analysis/live-20260912"
data = json.loads((OUT / "led-layout.json").read_text())
parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1180" height="1000" viewBox="0 0 1180 1000" role="img" aria-labelledby="title desc">',
         '<title id="title">KM16 Pro recovered input and LED map</title>',
         '<desc id="desc">Sixteen key LEDs in a four by four grid. Three encoder pin pairs. Five status and six underglow slots shown separately because their physical locations are unknown.</desc>',
         '<rect width="1180" height="1000" fill="#f4f6fa"/>',
         '<style>text{font-family:Arial,sans-serif;fill:#182636}.title{font-size:30px;font-weight:bold}.head{font-size:21px;font-weight:bold}.body{font-size:17px}.small{font-size:15px}.num{font-size:25px;font-weight:bold;fill:#07576a}</style>']


def text(x, y, value, cls="body"):
    parts.append(f'<text x="{x}" y="{y}" class="{cls}">{escape(str(value))}</text>')


def box(x, y, w, h, fill="#ffffff", stroke="#cbd5e1"):
    parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="{fill}" stroke="{stroke}"/>')


text(40, 48, "KM16 Pro • recovered input and LED map", "title")
text(40, 79, "Source: this board’s acquired firmware • 2026-09-12 • GPIO names use the STM32F1-compatible map")
text(40, 125, "Key grid: user-confirmed orientation", "head")
text(680, 125, "Rotary controls", "head")
for row, indices in enumerate(data["matrix_led_index_by_row_col"]):
    for col, index in enumerate(indices[:4]):
        x, y = 40 + col * 145, 145 + row * 95
        box(x, y, 130, 80)
        text(x + 14, y + 33, f"LED {index}", "num")
        text(x + 14, y + 61, f"matrix {row},{col}", "small")
for y, title, phase, press in [
    (145, "Upper-left • encoder 0", "PB5 / PB4", "Press: PA0 / PB11 • matrix 0,4"),
    (270, "Upper-right • encoder 1", "PA6 / PA7", "Press: PA0 / PB12 • matrix 0,5"),
    (395, "Large lower • encoder 2", "PC14 / PC15", "Press: PA2 / PB12 • matrix 2,5"),
]:
    box(680, y, 455, 108)
    text(698, y + 29, title, "head")
    text(698, y + 57, f"Quadrature phases: {phase}")
    text(698, y + 85, press)
text(40, 555, "Rows: PA0, PA1, PA2, PA3")
text(40, 584, "Columns: PB0, PC13, PB2, PB10, PB11, PB12")
text(40, 613, "One column driven low; pulled-up rows read active-low. Diodes and PCB continuity unverified.")
text(40, 660, "Additional LED groups • physical positions unknown", "head")
text(40, 693, "Slots below are grouped logically; this is not their placement around the case.")
for start, count, x, label, fill in [(16, 5, 40, "Layer / status", "#e8ddfa"), (21, 6, 590, "Underglow", "#d6eee5")]:
    text(x, 729, label, "head")
    for i in range(count):
        box(x + i * 83, 748, 70, 50, fill)
        text(x + i * 83 + 20, 781, start + i, "num")
text(40, 842, "27 RGB slots total: PB8 → TIM4 CH3 + DMA1 CH7 → addressable LED chain", "head")
text(40, 876, "800 kbit/s configured • GRB-compatible channel order • PB7 firmware LED-enable control")
text(40, 909, "Key coordinates are normalized animation units. Non-key coordinates are (0,0) placeholders.")
text(40, 956, "Exact MCU, radio, LED IC, switching circuit and physical supply voltages remain unverified.", "small")
parts.append("</svg>")
(OUT / "board-map.svg").write_text("\n".join(parts) + "\n")
print(OUT / "board-map.svg")
