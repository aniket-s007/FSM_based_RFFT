# FSM-Controlled RFFT Spectrum Analyzer — Nexys 4

A real-time **N=16 FFT spectrum analyzer** implemented on a Digilent Nexys 4 FPGA board (Artix-7 XC7A100T). The design computes a radix-2 DIF RFFT using a finite-state-machine-controlled datapath and displays the 9 frequency-bin magnitudes as a live bar graph over VGA.

---

## Block Diagram

```
100 MHz clk
    │
    ▼
┌───────────────────────────────────────────────────────┐
│                    rfft_demo_top                       │
│                                                        │
│  ┌──────────────┐   ┌────────────────┐                │
│  │ test_signal  │   │   lfsr16       │  SW2 selects   │
│  │    _rom      │   │ (LFSR noise)   │  ROM or LFSR   │
│  └──────┬───────┘   └──────┬─────────┘                │
│         └─────────┬────────┘                           │
│                   ▼                                    │
│          ┌─────────────────┐                           │
│          │  rfft_n16_simple │  N=16 radix-2 DIF FFT   │
│          │   (FSM + regs)  │  Q1.15 fixed-point       │
│          └────────┬────────┘                           │
│                   ▼                                    │
│          ┌──────────────────┐                          │
│          │ magnitude_approx │  × 9 instances          │
│          │  (α|re|+β|im|)  │  (one per bin)          │
│          └────────┬─────────┘                          │
│           bar_height[0..8]                             │
└───────────────┬───────────────────────────────────────┘
                │
    ┌───────────┼────────────┐
    ▼           ▼            ▼
┌────────┐ ┌─────────┐  ┌───────────┐
│vga_sync│ │  bar_   │  │ LED bins  │
│640×480 │ │renderer │  │  LD0-LD8  │
│ @60 Hz │ │         │  │           │
└────────┘ └────┬────┘  └───────────┘
                │
           VGA output
```

---

## Source Files

| File | Module | Description |
|------|--------|-------------|
| `fpga_top.v` | `fpga_top` | Board-level top: wires all submodules together, maps Nexys 4 pins |
| `rfft_demo_top.v` | `rfft_demo_top` | FSM controller: IDLE → LOADING → COMPUTING → DONE |
| `rfft_n16_simple.v` | `rfft_n16_simple` | N=16 radix-2 DIF FFT, register-based, Q1.15 fixed-point |
| `magnitude_approx.v` | `magnitude_approx` | Magnitude approximation: α\|Re\| + β\|Im\| |
| `bar_renderer.v` | `bar_renderer` | VGA bar-graph pixel generator |
| `vga_sync.v` | `vga_sync` | VGA timing (640×480 @ 60 Hz) from 100 MHz clock |
| `lfsr16.v` | `lfsr16` | 16-bit LFSR for pseudo-random test signal |
| `test_signal_rom.v` | `test_signal_rom` | 4 preset test waveforms (ROM) selectable via switches |

---

## Board Pinout (Nexys 4 Rev B)

| Signal | Pin | Description |
|--------|-----|-------------|
| `clk` | E3 | 100 MHz onboard oscillator |
| `cpu_resetn` | C12 | CPU RESET button (active low) |
| `sig_sel[1:0]` | U9, U8 | SW1, SW0 — ROM waveform selector |
| `sig_source` | R7 | SW2 — 0: ROM preset, 1: LFSR noise |
| `btnc` | E16 | Centre button — trigger FFT capture |
| `led_bins[8:0]` | LD0–LD8 | One LED per frequency bin (lights if magnitude > 512) |
| `led_computing` | LD10 | High while FFT is computing |
| `led_valid` | LD11 | High when results are ready |
| VGA | A3–D8, B11, B12 | 4-bit R/G/B + HSync/VSync |

---

## How It Works

1. Press **BTNC** to trigger a capture.
2. The FSM loads 16 samples (from ROM or LFSR) into the RFFT core.
3. The radix-2 DIF FFT computes 4 butterfly stages (~60 clock cycles at 80 MHz).
4. Nine magnitude approximations run combinationally on the output bins.
5. Results are latched and displayed as vertical bars on VGA (640×480 @ 60 Hz).
6. LEDs LD0–LD8 light up for any bin whose magnitude exceeds 512 (threshold for real signal energy vs. rounding noise).
7. Press **BTNC** again to retrigger with a new capture.

**SW2 = 0** → select one of 4 preset waveforms (SW1:SW0 = 00/01/10/11)  
**SW2 = 1** → capture live LFSR pseudo-random noise (each trigger advances the LFSR window)

---

## Fixed-Point Arithmetic

- Format: **Q1.15** (1 sign bit, 15 fractional bits)
- Each butterfly stage scales by **1/2** to prevent overflow → total scale of **1/16** after 4 stages
- Twiddle multiplication: `(Q1.15 × Q1.15) >> 15`
- Magnitude approximation: `max(|re|, |im|) + 0.375 × min(|re|, |im|)` (α=1, β≈3/8)

---

## Build & Program

### Requirements
- Vivado 2020.x or later (tested on 2020.2)
- Digilent Nexys 4 board (XC7A100T-1CSG324C)

### Open the project
```
File → Open Project → FSM_RFFT.xpr
```

### Synthesize, implement, generate bitstream
Run the standard Vivado flow (Flow Navigator → Generate Bitstream).

### Program the board (pre-built bitstream)
A pre-built bitstream is provided in `bitstream/fpga_top.bit`.  
Open **Hardware Manager**, connect to the board, and program with this file — no rebuild needed.

---

## Project Structure

```
FSM_RFFT/
├── FSM_RFFT.xpr                          # Vivado project file
├── FSM_RFFT.srcs/
│   ├── sources_1/imports/Code/           # All Verilog source files
│   └── constrs_1/imports/Constraints/   # XDC pin constraints
├── bitstream/
│   └── fpga_top.bit                      # Pre-built bitstream
├── .gitignore
└── README.md
```

---

## Target Device

| Field | Value |
|-------|-------|
| Board | Digilent Nexys 4 Rev B |
| FPGA | Xilinx Artix-7 XC7A100T-1CSG324C |
| Tool | Vivado (Xilinx/AMD) |
| Clock | 100 MHz oscillator (timing constrained to 80 MHz) |
| VGA | 640×480 @ 60 Hz |
