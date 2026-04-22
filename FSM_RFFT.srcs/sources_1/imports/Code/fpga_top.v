`timescale 1ns / 1ps

//=============================================================================
// Module: fpga_top
//
// Board-level top module for the RFFT Spectrum Analyzer on Nexys 4.
//
// Architecture:
//   100 MHz osc (constrained to 80 MHz) → [rfft_demo_top] → bar_heights
//                  [vga_sync]      → timing signals
//                  [bar_renderer]  → RGB out
//
// Nexys 4 (Rev B) pin mapping:
//   E3        → clk (100 MHz onboard oscillator)
//   C12       → cpu_resetn (CPU RESET button, active low)
//   U9, U8    → sig_sel[1:0] (SW0, SW1)
//   R7        → sig_source (SW2) — 0: ROM preset, 1: LFSR noise
//   E16       → btnc (center button, active high)
//   LD0..LD8  → led_bins[8:0]: one LED per frequency bin
//   LD10      → led_computing
//   LD11      → led_valid
//   VGA       → A3..D8, B11, B12
//=============================================================================

module fpga_top (
    input  wire        clk,
    input  wire        cpu_resetn,
    input  wire [1:0]  sig_sel,
    input  wire        sig_source,
    input  wire        btnc,

    output wire [8:0]  led_bins,
    output wire        led_computing,
    output wire        led_valid,

    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b,
    output wire        vga_hs,
    output wire        vga_vs
);

    wire rst_n = cpu_resetn;

    //=========================================================================
    // RFFT demo core
    //=========================================================================
    wire [15:0] bar_height_0,  bar_height_1,  bar_height_2,  bar_height_3;
    wire [15:0] bar_height_4,  bar_height_5,  bar_height_6,  bar_height_7;
    wire [15:0] bar_height_8,  bar_height_9,  bar_height_10, bar_height_11;
    wire [15:0] bar_height_12, bar_height_13, bar_height_14, bar_height_15;
    wire        computing, valid;

    rfft_demo_top rfft_demo (
        .clk(clk), .rst_n(rst_n),
        .sig_sel(sig_sel), .sig_source(sig_source), .trigger(btnc),
        .computing(computing), .valid(valid),
        .bar_height_0(bar_height_0),   .bar_height_1(bar_height_1),
        .bar_height_2(bar_height_2),   .bar_height_3(bar_height_3),
        .bar_height_4(bar_height_4),   .bar_height_5(bar_height_5),
        .bar_height_6(bar_height_6),   .bar_height_7(bar_height_7),
        .bar_height_8(bar_height_8),   .bar_height_9(bar_height_9),
        .bar_height_10(bar_height_10), .bar_height_11(bar_height_11),
        .bar_height_12(bar_height_12), .bar_height_13(bar_height_13),
        .bar_height_14(bar_height_14), .bar_height_15(bar_height_15)
    );

    assign led_computing = computing;
    assign led_valid     = valid;

    //=========================================================================
    // LED bin indicators
    // Each LED lights up if the bin magnitude exceeds threshold.
    //=========================================================================
    localparam LED_THRESH = 16'd512;

    assign led_bins[0] = valid & (bar_height_0 > LED_THRESH);   //for debugging
    assign led_bins[1] = valid & (bar_height_1 > LED_THRESH);
    assign led_bins[2] = valid & (bar_height_2 > LED_THRESH);
    assign led_bins[3] = valid & (bar_height_3 > LED_THRESH);
    assign led_bins[4] = valid & (bar_height_4 > LED_THRESH);
    assign led_bins[5] = valid & (bar_height_5 > LED_THRESH);
    assign led_bins[6] = valid & (bar_height_6 > LED_THRESH);
    assign led_bins[7] = valid & (bar_height_7 > LED_THRESH);
    assign led_bins[8] = valid & (bar_height_8 > LED_THRESH);

    //=========================================================================
    // VGA timing generator
    //=========================================================================
    wire [9:0] h_count, v_count;
    wire       hsync, vsync, video_active, pixel_tick;

    vga_sync vga_timing (
        .clk(clk), .rst_n(rst_n),
        .h_count(h_count), .v_count(v_count),
        .hsync(hsync), .vsync(vsync),
        .video_active(video_active), .pixel_tick(pixel_tick)
    );

    //=========================================================================
    // Bar renderer
    //=========================================================================
    wire [3:0] render_r, render_g, render_b;

    bar_renderer renderer (
        .h_count(h_count), .v_count(v_count),
        .video_active(video_active),
        .bar_height_0(bar_height_0),   .bar_height_1(bar_height_1),
        .bar_height_2(bar_height_2),   .bar_height_3(bar_height_3),
        .bar_height_4(bar_height_4),   .bar_height_5(bar_height_5),
        .bar_height_6(bar_height_6),   .bar_height_7(bar_height_7),
        .bar_height_8(bar_height_8),   .bar_height_9(bar_height_9),
        .bar_height_10(bar_height_10), .bar_height_11(bar_height_11),
        .bar_height_12(bar_height_12), .bar_height_13(bar_height_13),
        .bar_height_14(bar_height_14), .bar_height_15(bar_height_15),
        .vga_r(render_r), .vga_g(render_g), .vga_b(render_b)
    );

    //=========================================================================
    // Text overlay (labels, bin numbers, magnitude ticks, axis titles)
    //=========================================================================
    wire [3:0] final_r, final_g, final_b;

    text_overlay text_ovl (
        .h_count(h_count), .v_count(v_count),
        .video_active(video_active),
        .bg_r(render_r), .bg_g(render_g), .bg_b(render_b),
        .vga_r(final_r), .vga_g(final_g), .vga_b(final_b)
    );

    //=========================================================================
    // VGA output registration
    //=========================================================================
    reg [3:0] vga_r_reg, vga_g_reg, vga_b_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            vga_r_reg <= 4'h0;
            vga_g_reg <= 4'h0;
            vga_b_reg <= 4'h0;
        end else if (pixel_tick) begin
            vga_r_reg <= final_r;
            vga_g_reg <= final_g;
            vga_b_reg <= final_b;
        end
    end

    assign vga_r  = vga_r_reg;
    assign vga_g  = vga_g_reg;
    assign vga_b  = vga_b_reg;
    assign vga_hs = hsync;
    assign vga_vs = vsync;

endmodule
