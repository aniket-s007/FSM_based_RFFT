`timescale 1ns / 1ps

//=============================================================================
// Module: bar_renderer
//
// Draws 9 vertical bars on a 640×480 VGA display.
// Each bar represents the magnitude of one RFFT frequency bin (X[0]..X[8]).
//
// Layout (all values in pixels):
//   - Display area: 640 wide × 480 tall
//   - Left margin:  20 px (to center the bar group)
//   - Each bar:     56 px wide
//   - Gap between:  12 px
//   - 9 bars + 8 gaps: 9×56 + 8×12 = 504 + 96 = 600 px
//   - Right margin: 640 - 20 - 600 = 20 px
//   - Bars grow upward from bottom (y=479) to top (y=0)
//   - Bar area: y = 40 to y = 459 (420 px tall max)
//   - Bottom label area: y = 460 to 479
//
// Height mapping:
//   bar_height is 16-bit unsigned. We scale to 0–420 pixels:
//   pixel_height = bar_height[15:6]  (top 10 bits = divide by 64)
//   Then clamp to 420 max.
//   With 1/16 RFFT scaling, max realistic bar_height ≈ 11469,
//   so pixel_height ≈ 179 pixels. Good visible range.
//
// Color scheme:
//   - Bar fill: bright green (bin 0 = DC gets distinct blue)
//   - Background: black (all zeros when video_active=0)
//   - Bottom strip: dark gray baseline
//
// Output: 12-bit RGB (4 bits each), matching Nexys A7 VGA resistor DAC.
//
// Latency: combinational (registered externally by VGA top if needed).
//=============================================================================

module bar_renderer (
    input  wire [9:0]  h_count,
    input  wire [9:0]  v_count,
    input  wire        video_active,

    // 9 bar heights (unsigned 16-bit magnitudes)
    input  wire [15:0] bar_height_0,
    input  wire [15:0] bar_height_1,
    input  wire [15:0] bar_height_2,
    input  wire [15:0] bar_height_3,
    input  wire [15:0] bar_height_4,
    input  wire [15:0] bar_height_5,
    input  wire [15:0] bar_height_6,
    input  wire [15:0] bar_height_7,
    input  wire [15:0] bar_height_8,

    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b
);

    //=========================================================================
    // Layout parameters
    //=========================================================================
    localparam LEFT_MARGIN  = 10'd20;
    localparam BAR_WIDTH    = 10'd56;
    localparam GAP_WIDTH    = 10'd12;
    localparam BAR_STRIDE   = 10'd68;   // BAR_WIDTH + GAP_WIDTH
    localparam NUM_BARS     = 4'd9;

    // Vertical bar area
    localparam BAR_TOP      = 10'd40;   // Topmost pixel a bar can reach
    localparam BAR_BOTTOM   = 10'd459;  // Bottom of bar area
    localparam BAR_MAX_PX   = 10'd420;  // BAR_BOTTOM - BAR_TOP + 1

    // Baseline strip
    localparam BASELINE_TOP = 10'd460;

    //=========================================================================
    // Determine which bar (if any) the current pixel is inside
    //=========================================================================
    // Horizontal position relative to left margin
    wire [9:0] h_rel = h_count - LEFT_MARGIN;

    // Bar index and position within bar stride
    // bar_idx = h_rel / BAR_STRIDE, pos_in_stride = h_rel % BAR_STRIDE
    // For 9 bars, bar_idx valid range is 0-8
    //
    // Division by 68 is expensive. Instead, use a cascaded compare:
    reg [3:0] bar_idx;
    reg       in_bar;   // Whether current pixel is within a bar column

    always @(*) begin
        bar_idx = 4'd0;
        in_bar  = 1'b0;

        if (h_count >= LEFT_MARGIN && h_count < LEFT_MARGIN + NUM_BARS * BAR_STRIDE) begin
            // Determine bar index by comparing h_rel against bar boundaries
            // Bar k occupies: LEFT_MARGIN + k*68 to LEFT_MARGIN + k*68 + 55
            if      (h_rel < 1*BAR_STRIDE) begin bar_idx = 4'd0; in_bar = (h_rel < BAR_WIDTH); end
            else if (h_rel < 2*BAR_STRIDE) begin bar_idx = 4'd1; in_bar = (h_rel - 1*BAR_STRIDE < BAR_WIDTH); end
            else if (h_rel < 3*BAR_STRIDE) begin bar_idx = 4'd2; in_bar = (h_rel - 2*BAR_STRIDE < BAR_WIDTH); end
            else if (h_rel < 4*BAR_STRIDE) begin bar_idx = 4'd3; in_bar = (h_rel - 3*BAR_STRIDE < BAR_WIDTH); end
            else if (h_rel < 5*BAR_STRIDE) begin bar_idx = 4'd4; in_bar = (h_rel - 4*BAR_STRIDE < BAR_WIDTH); end
            else if (h_rel < 6*BAR_STRIDE) begin bar_idx = 4'd5; in_bar = (h_rel - 5*BAR_STRIDE < BAR_WIDTH); end
            else if (h_rel < 7*BAR_STRIDE) begin bar_idx = 4'd6; in_bar = (h_rel - 6*BAR_STRIDE < BAR_WIDTH); end
            else if (h_rel < 8*BAR_STRIDE) begin bar_idx = 4'd7; in_bar = (h_rel - 7*BAR_STRIDE < BAR_WIDTH); end
            else                           begin bar_idx = 4'd8; in_bar = (h_rel - 8*BAR_STRIDE < BAR_WIDTH); end
        end
    end

    //=========================================================================
    // Select the bar_height for the current bar_idx
    //=========================================================================
    reg [15:0] current_bar_height;

    always @(*) begin
        case (bar_idx)
            4'd0: current_bar_height = bar_height_0;
            4'd1: current_bar_height = bar_height_1;
            4'd2: current_bar_height = bar_height_2;
            4'd3: current_bar_height = bar_height_3;
            4'd4: current_bar_height = bar_height_4;
            4'd5: current_bar_height = bar_height_5;
            4'd6: current_bar_height = bar_height_6;
            4'd7: current_bar_height = bar_height_7;
            4'd8: current_bar_height = bar_height_8;
            default: current_bar_height = 16'd0;
        endcase
    end

    //=========================================================================
    // Scale bar_height to pixel height (0 to BAR_MAX_PX)
    //
    // bar_height >> 6 gives a range of 0-1023 for 16-bit input.
    // Clamp to BAR_MAX_PX (420).
    //=========================================================================
    wire [9:0] scaled_height_raw = current_bar_height[15:6]; // 0-1023
    wire [9:0] scaled_height = (scaled_height_raw > BAR_MAX_PX) ? BAR_MAX_PX : scaled_height_raw;

    // Bar top pixel position (bar grows upward from BAR_BOTTOM)
    wire [9:0] bar_top_y = BAR_BOTTOM - scaled_height + 10'd1;

    //=========================================================================
    // Pixel color assignment
    //=========================================================================
    always @(*) begin
        if (!video_active) begin
            // Blanking: must output black (VGA standard)
            vga_r = 4'h0;
            vga_g = 4'h0;
            vga_b = 4'h0;
        end
        else if (v_count >= BASELINE_TOP) begin
            // Bottom baseline strip: dark gray
            vga_r = 4'h2;
            vga_g = 4'h2;
            vga_b = 4'h2;
        end
        else if (in_bar && v_count >= bar_top_y && v_count <= BAR_BOTTOM) begin
            // Inside a bar: use color based on bar index
            case (bar_idx)
                4'd0: begin  // DC bin: blue
                    vga_r = 4'h2;
                    vga_g = 4'h4;
                    vga_b = 4'hF;
                end
                default: begin  // Frequency bins: green
                    vga_r = 4'h1;
                    vga_g = 4'hE;
                    vga_b = 4'h3;
                end
            endcase
        end
        else begin
            // Background: black
            vga_r = 4'h0;
            vga_g = 4'h0;
            vga_b = 4'h0;
        end
    end

endmodule
