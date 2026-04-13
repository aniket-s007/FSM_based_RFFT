`timescale 1ns / 1ps

//=============================================================================
// Module: vga_sync
//
// VGA timing generator for 640×480 @ 60 Hz.
//
// INTERNAL ARCHITECTURE (refactored into 3 submodules):
//   [clock_divider]     → pixel_tick (25 MHz enable)
//   [horizontal_counter]→ H_Count_Value (0-799), enable_V_Counter
//   [vertical_counter]  → V_Count_Value (0-524)
//
// Based on SimplyEmbedded (youtube) VGA approach
//
// Timing (VESA 640×480 @ 60 Hz):
//   Horizontal: 640 visible + 16 FP + 96 sync + 48 BP = 800 total
//   Vertical:   480 visible + 10 FP +  2 sync + 33 BP = 525 total
//   Pixel clock: 25 MHz (100 MHz / 4)
//
// PORT INTERFACE — UNCHANGED FROM ORIGINAL:
//   clk          → 100 MHz system clock
//   rst_n        → Active-low reset
//   h_count[9:0] → Horizontal pixel position (0-799)
//   v_count[9:0] → Vertical line position (0-524)
//   hsync        → Active-low horizontal sync pulse
//   vsync        → Active-low vertical sync pulse
//   video_active → High when pixel is in visible area
//   pixel_tick   → 25 MHz enable pulse
//=============================================================================

module vga_sync (
    input  wire        clk,          // 100 MHz system clock
    input  wire        rst_n,        // Active-low reset
    output wire [9:0]  h_count,      // 0-799  (driven from horizontal_counter)
    output wire [9:0]  v_count,      // 0-524  (driven from vertical_counter)
    output reg         hsync,        // Active-low hsync
    output reg         vsync,        // Active-low vsync
    output reg         video_active, // High in visible region
    output wire        pixel_tick    // 25 MHz enable pulse
);

    //=========================================================================
    // VGA timing parameters
    //=========================================================================
    localparam H_VISIBLE    = 10'd640;
    localparam H_SYNC_START = 10'd656;   // 640 + 16 (FP)
    localparam H_SYNC_END   = 10'd752;   // 656 + 96 (SYNC)

    localparam V_VISIBLE    = 10'd480;
    localparam V_SYNC_START = 10'd490;   // 480 + 10 (FP)
    localparam V_SYNC_END   = 10'd492;   // 490 + 2  (SYNC)

    //=========================================================================
    // Internal wires between submodules
    //=========================================================================
    wire enable_V_Counter;

    //=========================================================================
    // Submodule 1: Clock divider → pixel_tick (25 MHz enable)
    //=========================================================================
    clock_divider clk_div_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .pixel_tick (pixel_tick)
    );

    //=========================================================================
    // Submodule 2: Horizontal counter → h_count, enable_V_Counter
    //=========================================================================
    horizontal_counter h_counter_inst (
        .clk             (clk),
        .rst_n           (rst_n),
        .pixel_tick      (pixel_tick),
        .H_Count_Value   (h_count),
        .enable_V_Counter(enable_V_Counter)
    );

    //=========================================================================
    // Submodule 3: Vertical counter → v_count
    //=========================================================================
    vertical_counter v_counter_inst (
        .clk             (clk),
        .rst_n           (rst_n),
        .enable_V_Counter(enable_V_Counter),
        .V_Count_Value   (v_count)
    );

    //=========================================================================
    // Sync and video_active generation
    // Registered on pixel_tick — glitch-free edges, same as original
    //=========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            hsync        <= 1'b1;
            vsync        <= 1'b1;
            video_active <= 1'b0;
        end
        else if (pixel_tick) begin
            hsync        <= ~(h_count >= H_SYNC_START && h_count < H_SYNC_END);
            vsync        <= ~(v_count >= V_SYNC_START && v_count < V_SYNC_END);
            video_active <= (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
        end
    end

endmodule
