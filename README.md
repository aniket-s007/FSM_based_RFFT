# FSM-RFFT Spectrum Analyzer

<div align="center">

![FPGA](https://img.shields.io/badge/FPGA-Artix--7%20XC7A100T-blue?style=for-the-badge&logo=xilinx&logoColor=white)
![Language](https://img.shields.io/badge/HDL-Verilog-orange?style=for-the-badge)
![Tool](https://img.shields.io/badge/Vivado-2020.x%2B-red?style=for-the-badge)
![Board](https://img.shields.io/badge/Board-Nexys%204%20Rev%20B-green?style=for-the-badge)
![VGA](https://img.shields.io/badge/VGA-640×480%20%4060Hz-purple?style=for-the-badge)

**Real-time N=16 FFT spectrum analyzer on an Artix-7 FPGA — live bar-graph display over VGA, Q1.15 fixed-point arithmetic, fully FSM-driven.**

[Features](#-features) · [Architecture](#-architecture) · [Source Files](#-source-files) · [Quick Start](#-quick-start) · [Usage](#-usage) · [Pinout](#-board-pinout) · [Fixed-Point Math](#-fixed-point-arithmetic)

</div>

---

## 👥 Team

| Name | GitHub |
|------|--------|
| Aniket Singh | [Github](https://github.com/aniket-s007) |
| Aryan Rastogi | [Github](https://github.com/AryanRastogi72) |
| Rhythm Jain | [Github](https://github.com) |
| Yashika Jain | [Github](https://github.com) |

---

## ✨ Features

- **Radix-2 DIF FFT** — N=16, 4 butterfly stages, ~60 clock cycles per frame
- **FSM-controlled datapath** — clean IDLE → LOADING → COMPUTING → DONE pipeline
- **Q1.15 fixed-point** — scaled per-stage to prevent overflow, no floating-point needed
- **α|Re| + β|Im| magnitude approximation** — 9 bins computed combinationally
- **Live VGA output** — 640×480 @ 60 Hz vertical bar-graph, updates on every capture
- **Dual signal sources** — 4 preset ROM waveforms or live LFSR pseudo-random noise
- **LED indicators** — LD0–LD8 light for any bin with magnitude > 512; LD10/LD11 show FSM status
- **Pre-built bitstream** — program the board instantly, no rebuild required

---

## 🏗 Architecture

```
100 MHz clk
    │
    ▼
┌───────────────────────────────────────────────────────┐
│                    rfft_demo_top                      │
│                                                       │
│  ┌──────────────┐   ┌────────────────┐                │
│  │ test_signal  │   │    lfsr16      │  SW2 selects   │
│  │    _rom      │   │  (LFSR noise)  │  ROM or LFSR   │
│  └──────┬───────┘   └──────┬─────────┘                │
│         └─────────┬────────┘                          │
│                   ▼                                   │
│          ┌─────────────────┐                          │
│          │ rfft_n16_simple │  N=16 radix-2 DIF FFT    │
│          │  (FSM + regs)   │  Q1.15 fixed-point       │
│          └────────┬────────┘                          │
│                   ▼                                   │
│          ┌──────────────────┐                         │
│          │ magnitude_approx │  × 9 instances          │
│          │  (α|re| + β|im|) │  one per output bin     │
│          └────────┬─────────┘                         │
│           bar_height[0..8]                            │
└───────────────┬───────────────────────────────────────┘
                │
    ┌───────────┼────────────┐
    ▼           ▼            ▼
┌────────┐ ┌──────────┐ ┌──────────┐
│vga_sync│ │   bar_   │ │LED bins  │
│640×480 │ │ renderer │ │ LD0–LD8  │
│ @60 Hz │ │          │ │          │
└────────┘ └────┬─────┘ └──────────┘
                │
           VGA output
```

---

## 📁 Source Files

| File | Module | Description |
|------|--------|-------------|
| `fpga_top.v` | `fpga_top` | Board-level top — wires all submodules, maps Nexys 4 pins |
| `rfft_demo_top.v` | `rfft_demo_top` | FSM controller: IDLE → LOADING → COMPUTING → DONE |
| `rfft_n16_simple.v` | `rfft_n16_simple` | N=16 radix-2 DIF FFT, register-based, Q1.15 fixed-point |
| `magnitude_approx.v` | `magnitude_approx` | Magnitude approximation: α\|Re\| + β\|Im\| |
| `bar_renderer.v` | `bar_renderer` | VGA bar-graph pixel generator |
| `vga_sync.v` | `vga_sync` | VGA timing (640×480 @ 60 Hz) from 100 MHz clock |
| `lfsr16.v` | `lfsr16` | 16-bit LFSR pseudo-random signal generator |
| `test_signal_rom.v` | `test_signal_rom` | 4 preset waveforms (ROM), selectable via switches |

---

## 🚀 Quick Start

### Requirements

- Vivado **2020.x or later** (tested on 2020.2)
- Digilent **Nexys 4 Rev B** (XC7A100T-1CSG324C)

### Option A — Flash the pre-built bitstream

No rebuild needed. Open **Hardware Manager** in Vivado, connect to the board, and program:

```
bitstream/fpga_top.bit
```

### Option B — Build from source

```
File → Open Project → FSM_RFFT.xpr
```

Then run the standard flow:

```
Flow Navigator → Generate Bitstream
```

---

## 🎛 Usage

| Step | Action |
|------|--------|
| 1 | Select signal source: **SW2 = 0** (ROM preset) or **SW2 = 1** (LFSR noise) |
| 2 | If using ROM, choose waveform with **SW1:SW0** (00 / 01 / 10 / 11) |
| 3 | Press **BTNC** to trigger a capture |
| 4 | Watch the VGA bar graph and LEDs update with the new spectrum |
| 5 | Press **BTNC** again to retrigger — LFSR source advances the window each time |

**LED status:**

| LED | Meaning |
|-----|---------|
| LD0–LD8 | Frequency bin magnitude > 512 (real signal energy above noise floor) |
| LD10 | FFT is computing |
| LD11 | Results valid and latched |

---

## 📌 Board Pinout

| Signal | Pin | Description |
|--------|-----|-------------|
| `clk` | E3 | 100 MHz onboard oscillator |
| `cpu_resetn` | C12 | CPU RESET (active low) |
| `sig_sel[1:0]` | U9, U8 | SW1, SW0 — ROM waveform selector |
| `sig_source` | R7 | SW2 — 0: ROM preset · 1: LFSR noise |
| `btnc` | E16 | Centre button — trigger FFT capture |
| `led_bins[8:0]` | LD0–LD8 | One LED per frequency bin |
| `led_computing` | LD10 | High while FFT is running |
| `led_valid` | LD11 | High when results are ready |
| VGA | A3–D8, B11, B12 | 4-bit R/G/B + HSync/VSync |

---

## 🔢 Fixed-Point Arithmetic

| Parameter | Value |
|-----------|-------|
| Format | Q1.15 (1 sign bit, 15 fractional bits) |
| Per-stage scaling | ÷2 (right shift) to prevent butterfly overflow |
| Total scaling after 4 stages | 1/16 |
| Twiddle multiply | `(Q1.15 × Q1.15) >> 15` |
| Magnitude approximation | `max(|re|, |im|) + 0.375 × min(|re|, |im|)` (α=1, β≈3/8) |

The per-stage divide-by-2 ensures no intermediate value overflows the Q1.15 range throughout all four butterfly stages.

---

## 🗂 Project Structure

```
FSM_RFFT/
├── FSM_RFFT.xpr                           # Vivado project file
├── FSM_RFFT.srcs/
│   ├── sources_1/imports/Code/            # Verilog source files
│   └── constrs_1/imports/Constraints/    # XDC pin constraints
├── bitstream/
│   └── fpga_top.bit                       # Pre-built bitstream
├── .gitignore
└── README.md
```

---

## 🎯 Target Device

| Field | Value |
|-------|-------|
| Board | Digilent Nexys 4 Rev B |
| FPGA | Xilinx Artix-7 XC7A100T-1CSG324C |
| Toolchain | Vivado (Xilinx/AMD) 2020.x+ |
| Clock | 100 MHz oscillator · constrained to 80 MHz |
| VGA output | 640×480 @ 60 Hz |

---

## 🤝 Contributing

Pull requests are welcome. For significant changes, open an issue first to discuss what you'd like to change. Please ensure any modified RTL is simulated and timing constraints remain met at 80 MHz.
