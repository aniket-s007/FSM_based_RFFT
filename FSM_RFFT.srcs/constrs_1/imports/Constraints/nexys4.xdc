## =============================================================================
## Nexys 4 (Rev B) XDC Constraints — RFFT Spectrum Analyzer
## Board: Digilent Nexys 4 (XC7A100T-1CSG324C)
##
## Pin assignments verified against:
##   - Nexys 4 FPGA Board Reference Manual (Rev April 11, 2016)
##   - Board photo with silkscreen pin labels
##   - Figure 11 (VGA), Figure 16 (GPIO), Section 9 (Basic I/O)
## =============================================================================

## Clock (100 MHz onboard oscillator, pin E3)
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 12.5 -waveform {0 6.25} [get_ports { clk }];

## CPU Reset Button (active low, top-right red button, pin C12)
set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports { cpu_resetn }];

## Switches — signal selector (SW0, SW1) and source select (SW2)
## Pins verified against Digilent Nexys-4-Master.xdc (non-DDR rev B).
##   SW0 = U9, SW1 = U8, SW2 = R7
set_property -dict { PACKAGE_PIN U9  IOSTANDARD LVCMOS33 } [get_ports { sig_sel[0] }];
set_property -dict { PACKAGE_PIN U8  IOSTANDARD LVCMOS33 } [get_ports { sig_sel[1] }];
set_property -dict { PACKAGE_PIN R7  IOSTANDARD LVCMOS33 } [get_ports { sig_source }];

## Center Button — trigger (BTNC, pin E16)
## From manual Figure 16 and board silkscreen: BTNC = E16
set_property -dict { PACKAGE_PIN E16 IOSTANDARD LVCMOS33 } [get_ports { btnc }];

## LEDs — 9 frequency bin indicators (LD0 through LD8)
## From manual Figure 16:
##   LD0=T8, LD1=V9, LD2=R8, LD3=T6, LD4=T5,
##   LD5=T4, LD6=U7, LD7=U6, LD8=V4
set_property -dict { PACKAGE_PIN T8  IOSTANDARD LVCMOS33 } [get_ports { led_bins[0] }];
set_property -dict { PACKAGE_PIN V9  IOSTANDARD LVCMOS33 } [get_ports { led_bins[1] }];
set_property -dict { PACKAGE_PIN R8  IOSTANDARD LVCMOS33 } [get_ports { led_bins[2] }];
set_property -dict { PACKAGE_PIN T6  IOSTANDARD LVCMOS33 } [get_ports { led_bins[3] }];
set_property -dict { PACKAGE_PIN T5  IOSTANDARD LVCMOS33 } [get_ports { led_bins[4] }];
set_property -dict { PACKAGE_PIN T4  IOSTANDARD LVCMOS33 } [get_ports { led_bins[5] }];
set_property -dict { PACKAGE_PIN U7  IOSTANDARD LVCMOS33 } [get_ports { led_bins[6] }];
set_property -dict { PACKAGE_PIN U6  IOSTANDARD LVCMOS33 } [get_ports { led_bins[7] }];
set_property -dict { PACKAGE_PIN V4  IOSTANDARD LVCMOS33 } [get_ports { led_bins[8] }];

## LEDs — status indicators
## LD10=V1 (computing), LD11=R1 (valid)
set_property -dict { PACKAGE_PIN V1  IOSTANDARD LVCMOS33 } [get_ports { led_computing }];
set_property -dict { PACKAGE_PIN R1  IOSTANDARD LVCMOS33 } [get_ports { led_valid }];

## VGA Connector (identical between Nexys 4 and Nexys A7)
## From manual Figure 11:
# Red channel
set_property -dict { PACKAGE_PIN A3  IOSTANDARD LVCMOS33 } [get_ports { vga_r[0] }];
set_property -dict { PACKAGE_PIN B4  IOSTANDARD LVCMOS33 } [get_ports { vga_r[1] }];
set_property -dict { PACKAGE_PIN C5  IOSTANDARD LVCMOS33 } [get_ports { vga_r[2] }];
set_property -dict { PACKAGE_PIN A4  IOSTANDARD LVCMOS33 } [get_ports { vga_r[3] }];

# Green channel
set_property -dict { PACKAGE_PIN C6  IOSTANDARD LVCMOS33 } [get_ports { vga_g[0] }];
set_property -dict { PACKAGE_PIN A5  IOSTANDARD LVCMOS33 } [get_ports { vga_g[1] }];
set_property -dict { PACKAGE_PIN B6  IOSTANDARD LVCMOS33 } [get_ports { vga_g[2] }];
set_property -dict { PACKAGE_PIN A6  IOSTANDARD LVCMOS33 } [get_ports { vga_g[3] }];

# Blue channel
set_property -dict { PACKAGE_PIN B7  IOSTANDARD LVCMOS33 } [get_ports { vga_b[0] }];
set_property -dict { PACKAGE_PIN C7  IOSTANDARD LVCMOS33 } [get_ports { vga_b[1] }];
set_property -dict { PACKAGE_PIN D7  IOSTANDARD LVCMOS33 } [get_ports { vga_b[2] }];
set_property -dict { PACKAGE_PIN D8  IOSTANDARD LVCMOS33 } [get_ports { vga_b[3] }];

# Sync signals
set_property -dict { PACKAGE_PIN B11 IOSTANDARD LVCMOS33 } [get_ports { vga_hs }];
set_property -dict { PACKAGE_PIN B12 IOSTANDARD LVCMOS33 } [get_ports { vga_vs }];

## =============================================================================
## Configuration
## =============================================================================
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
