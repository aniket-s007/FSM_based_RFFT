`timescale 1ns / 1ps

//=============================================================================
// Module: text_overlay
//
// Renders hardcoded text labels on top of the bar_renderer output:
//
//  - Title "RFFT SPECTRUM"  at top center      (y=4..11)
//  - Y-axis label "MAG"     at top-left        (y=4..11, x=2)
//  - Y-axis tick values     in left margin     (5 ticks)
//  - Y-axis tick dashes     at left of bars    (4px wide)
//  - Bin numbers "0".."8"   below baseline     (y=452..459)
//  - X-axis label "FREQ BIN" at bottom center  (y=466..473)
//
// Font: 8x8 bitmap via font_rom instance.
// Purely combinational — no clock.
//
// Text color: white {F,F,F} for bin numbers and title,
//             gray  {6,6,6} for magnitude tick labels,
//             dim   {3,3,3} for tick dashes.
// All other pixels pass bg_r/bg_g/bg_b through unchanged.
//=============================================================================

module text_overlay (
    input  wire [9:0] h_count,
    input  wire [9:0] v_count,
    input  wire       video_active,

    // Passthrough from bar_renderer
    input  wire [3:0] bg_r,
    input  wire [3:0] bg_g,
    input  wire [3:0] bg_b,

    output reg  [3:0] vga_r,
    output reg  [3:0] vga_g,
    output reg  [3:0] vga_b
);

    //=========================================================================
    // Layout parameters (must match bar_renderer.v)
    //=========================================================================
    localparam LEFT_MARGIN  = 10'd44;
    localparam BAR_WIDTH    = 10'd52;
    localparam BAR_STRIDE   = 10'd62;
    localparam BAR_BOTTOM   = 10'd447;
    localparam BAR_TOP      = 10'd16;

    //=========================================================================
    // Font ROM instance
    //=========================================================================
    reg  [6:0] font_char;
    reg  [2:0] font_row;
    wire [7:0] font_bits;

    font_rom fnt (
        .char_code(font_char),
        .row(font_row),
        .bitmap(font_bits)
    );

    //=========================================================================
    // Text region helpers
    // Returns: pixel_on=1 if current pixel is a lit font pixel in that region
    //          Drives font_char and font_row for the last active region.
    //=========================================================================

    // --- Helper function: given string base x, return char index ---
    // We use inline wire logic below per region.

    //=========================================================================
    // Region A: Title "RFFT SPECTRUM" — 13 chars, y=4..11, centered
    //   Width = 13*8 = 104px, x_start = (640-104)/2 = 268
    //=========================================================================
    localparam TITLE_X     = 10'd268;
    localparam TITLE_Y     = 10'd4;
    localparam TITLE_LEN   = 4'd13;

    wire in_title = (h_count >= TITLE_X) && (h_count < TITLE_X + TITLE_LEN*8)
                 && (v_count >= TITLE_Y) && (v_count < TITLE_Y + 10'd8);

    wire [3:0] title_idx = (h_count - TITLE_X) >> 3;  // 0..12
    wire [2:0] title_col = (h_count - TITLE_X) & 3'b111;
    wire [2:0] title_row = (v_count - TITLE_Y) & 3'b111;

    // "RFFT SPECTRUM" = 52 46 46 54 20 53 50 45 43 54 52 55 4D
    reg [7:0] title_char;
    always @(*) begin
        case (title_idx)
            4'd0:  title_char = 7'h52; // R
            4'd1:  title_char = 7'h46; // F
            4'd2:  title_char = 7'h46; // F
            4'd3:  title_char = 7'h54; // T
            4'd4:  title_char = 7'h20; // space
            4'd5:  title_char = 7'h53; // S
            4'd6:  title_char = 7'h50; // P
            4'd7:  title_char = 7'h45; // E
            4'd8:  title_char = 7'h43; // C
            4'd9:  title_char = 7'h54; // T
            4'd10: title_char = 7'h52; // R
            4'd11: title_char = 7'h55; // U
            4'd12: title_char = 7'h4D; // M
            default: title_char = 7'h20;
        endcase
    end

    //=========================================================================
    // Region B: Y-axis label "MAG" — 3 chars, y=4..11, x=2
    //=========================================================================
    localparam MAG_X   = 10'd2;
    localparam MAG_Y   = 10'd4;

    wire in_mag = (h_count >= MAG_X) && (h_count < MAG_X + 10'd24)
               && (v_count >= MAG_Y) && (v_count < MAG_Y + 10'd8);

    wire [1:0] mag_idx = (h_count - MAG_X) >> 3;
    wire [2:0] mag_col = (h_count - MAG_X) & 3'b111;
    wire [2:0] mag_row = (v_count - MAG_Y) & 3'b111;

    reg [7:0] mag_char;
    always @(*) begin
        case (mag_idx)
            2'd0: mag_char = 7'h4D; // M
            2'd1: mag_char = 7'h41; // A
            2'd2: mag_char = 7'h47; // G
            default: mag_char = 7'h20;
        endcase
    end

    //=========================================================================
    // Region C: Y-axis tick labels in left margin
    // Tick positions (v_count of bar bottom reference):
    //   pixels_from_bottom = 0   → v=447 → label "0"       1 char, x=36..43
    //   pixels_from_bottom = 80  → v=367 → label "5120"    4 chars, x=12..43
    //   pixels_from_bottom = 160 → v=287 → label "10240"   5 chars, x=4..43
    //   pixels_from_bottom = 240 → v=207 → label "15360"   5 chars, x=4..43
    //   pixels_from_bottom = 320 → v=127 → label "20480"   5 chars, x=4..43
    //   pixels_from_bottom = 400 → v=47  → label "25600"   5 chars, x=4..43
    //
    // Each label rendered at y = tick_v - 3 (vertically centered, 8px tall)
    // so y_start = tick_v - 3, y_end = tick_v + 4
    //
    // Colors: gray {6,6,6}
    //=========================================================================

    // Tick 0: "0" at v=447, y_start=444, x=36..43
    localparam T0_V = 10'd447; localparam T0_Y = 10'd444;
    localparam T0_X = 10'd36;  localparam T0_W = 10'd1;

    // Tick 1: "5120" at v=367, y_start=364, x=12..43
    localparam T1_V = 10'd367; localparam T1_Y = 10'd364;
    localparam T1_X = 10'd12;  localparam T1_W = 10'd4;

    // Tick 2: "10240" at v=287, y_start=284, x=4..43
    localparam T2_V = 10'd287; localparam T2_Y = 10'd284;
    localparam T2_X = 10'd4;   localparam T2_W = 10'd5;

    // Tick 3: "15360" at v=207, y_start=204, x=4..43
    localparam T3_V = 10'd207; localparam T3_Y = 10'd204;
    localparam T3_X = 10'd4;   localparam T3_W = 10'd5;

    // Tick 4: "20480" at v=127, y_start=124, x=4..43
    localparam T4_V = 10'd127; localparam T4_Y = 10'd124;
    localparam T4_X = 10'd4;   localparam T4_W = 10'd5;

    // Tick 5: "25600" at v=47, y_start=44, x=4..43
    localparam T5_V = 10'd47;  localparam T5_Y = 10'd44;
    localparam T5_X = 10'd4;   localparam T5_W = 10'd5;

    wire in_tick0 = (h_count >= T0_X) && (h_count < T0_X + T0_W*8)
                 && (v_count >= T0_Y) && (v_count < T0_Y + 10'd8);
    wire in_tick1 = (h_count >= T1_X) && (h_count < T1_X + T1_W*8)
                 && (v_count >= T1_Y) && (v_count < T1_Y + 10'd8);
    wire in_tick2 = (h_count >= T2_X) && (h_count < T2_X + T2_W*8)
                 && (v_count >= T2_Y) && (v_count < T2_Y + 10'd8);
    wire in_tick3 = (h_count >= T3_X) && (h_count < T3_X + T3_W*8)
                 && (v_count >= T3_Y) && (v_count < T3_Y + 10'd8);
    wire in_tick4 = (h_count >= T4_X) && (h_count < T4_X + T4_W*8)
                 && (v_count >= T4_Y) && (v_count < T4_Y + 10'd8);
    wire in_tick5 = (h_count >= T5_X) && (h_count < T5_X + T5_W*8)
                 && (v_count >= T5_Y) && (v_count < T5_Y + 10'd8);

    wire in_any_tick = in_tick0 | in_tick1 | in_tick2 | in_tick3 | in_tick4 | in_tick5;

    // Character lookup per tick label
    wire [2:0] t0_col = (h_count - T0_X) & 3'b111;
    wire [2:0] t0_row = (v_count - T0_Y) & 3'b111;
    wire [2:0] t1_col = (h_count - T1_X) & 3'b111;
    wire [2:0] t1_row = (v_count - T1_Y) & 3'b111;
    wire [2:0] t2_col = (h_count - T2_X) & 3'b111;
    wire [2:0] t2_row = (v_count - T2_Y) & 3'b111;
    wire [1:0] t1_idx = (h_count - T1_X) >> 3;
    wire [2:0] t_idx5 = (h_count - T2_X) >> 3; // same X for t2..t5

    // Tick chars
    reg [7:0] tick_char;
    always @(*) begin
        tick_char = 7'h20; // default space
        if (in_tick0) tick_char = 7'h30; // "0"
        else if (in_tick1) begin
            // "5120"
            case (t1_idx)
                2'd0: tick_char = 7'h35; // 5
                2'd1: tick_char = 7'h31; // 1
                2'd2: tick_char = 7'h32; // 2
                2'd3: tick_char = 7'h30; // 0
                default: tick_char = 7'h20;
            endcase
        end
        else if (in_tick2) begin
            // "10240"
            case (t_idx5)
                3'd0: tick_char = 7'h31; // 1
                3'd1: tick_char = 7'h30; // 0
                3'd2: tick_char = 7'h32; // 2
                3'd3: tick_char = 7'h34; // 4
                3'd4: tick_char = 7'h30; // 0
                default: tick_char = 7'h20;
            endcase
        end
        else if (in_tick3) begin
            // "15360"
            case (t_idx5)
                3'd0: tick_char = 7'h31; // 1
                3'd1: tick_char = 7'h35; // 5
                3'd2: tick_char = 7'h33; // 3
                3'd3: tick_char = 7'h36; // 6
                3'd4: tick_char = 7'h30; // 0
                default: tick_char = 7'h20;
            endcase
        end
        else if (in_tick4) begin
            // "20480"
            case (t_idx5)
                3'd0: tick_char = 7'h32; // 2
                3'd1: tick_char = 7'h30; // 0
                3'd2: tick_char = 7'h34; // 4
                3'd3: tick_char = 7'h38; // 8
                3'd4: tick_char = 7'h30; // 0
                default: tick_char = 7'h20;
            endcase
        end
        else if (in_tick5) begin
            // "25600"
            case (t_idx5)
                3'd0: tick_char = 7'h32; // 2
                3'd1: tick_char = 7'h35; // 5
                3'd2: tick_char = 7'h36; // 6
                3'd3: tick_char = 7'h30; // 0
                3'd4: tick_char = 7'h30; // 0
                default: tick_char = 7'h20;
            endcase
        end
    end

    // Row for whichever tick is active
    // T2_Y=284, T3_Y=204, T4_Y=124, T5_Y=44 all ≡ 4 (mod 8), so t2_row works for all
    wire [2:0] tick_row = in_tick0 ? t0_row :
                          in_tick1 ? t1_row :
                          t2_row;

    // Column for tick — use the low 3 bits of (h_count - tick_x)
    wire [2:0] tick_col = in_tick0 ? t0_col :
                          in_tick1 ? t1_col :
                          t2_col; // t2..t5 share same x=4

    //=========================================================================
    // Region D: Y-axis tick dashes
    // 4px wide horizontal line at each tick v_count, from x=40..43
    //=========================================================================
    wire is_tick_dash = (h_count >= 10'd40) && (h_count <= 10'd43)
                     && (v_count == T0_V || v_count == T1_V || v_count == T2_V
                      || v_count == T3_V || v_count == T4_V || v_count == T5_V);

    //=========================================================================
    // Region E: Bin numbers "0".."8" — y=452..459
    // Bar k center x = LEFT_MARGIN + k*BAR_STRIDE + BAR_WIDTH/2
    //                = 44 + k*62 + 26 = 70 + k*62
    // Each digit is 8px wide, placed at x = 70 + k*62 - 4 = 66 + k*62
    // k=0: x=66  k=1: x=128  k=2: x=190  k=3: x=252  k=4: x=314
    // k=5: x=376 k=6: x=438  k=7: x=500  k=8: x=562
    //=========================================================================
    localparam BIN_Y = 10'd452;

    wire in_bin_row = (v_count >= BIN_Y) && (v_count < BIN_Y + 10'd8);

    // Determine if h_count is in any bin label and which one
    wire in_bin0 = in_bin_row && (h_count >= 10'd66)  && (h_count < 10'd74);
    wire in_bin1 = in_bin_row && (h_count >= 10'd128) && (h_count < 10'd136);
    wire in_bin2 = in_bin_row && (h_count >= 10'd190) && (h_count < 10'd198);
    wire in_bin3 = in_bin_row && (h_count >= 10'd252) && (h_count < 10'd260);
    wire in_bin4 = in_bin_row && (h_count >= 10'd314) && (h_count < 10'd322);
    wire in_bin5 = in_bin_row && (h_count >= 10'd376) && (h_count < 10'd384);
    wire in_bin6 = in_bin_row && (h_count >= 10'd438) && (h_count < 10'd446);
    wire in_bin7 = in_bin_row && (h_count >= 10'd500) && (h_count < 10'd508);
    wire in_bin8 = in_bin_row && (h_count >= 10'd562) && (h_count < 10'd570);

    wire in_any_bin = in_bin0|in_bin1|in_bin2|in_bin3|in_bin4|
                      in_bin5|in_bin6|in_bin7|in_bin8;

    reg [7:0] bin_char;
    always @(*) begin
        if      (in_bin0) bin_char = 7'h30;
        else if (in_bin1) bin_char = 7'h31;
        else if (in_bin2) bin_char = 7'h32;
        else if (in_bin3) bin_char = 7'h33;
        else if (in_bin4) bin_char = 7'h34;
        else if (in_bin5) bin_char = 7'h35;
        else if (in_bin6) bin_char = 7'h36;
        else if (in_bin7) bin_char = 7'h37;
        else              bin_char = 7'h38;
    end

    // Column within the active bin digit
    // Use low 3 bits of (h_count - base): equivalent to h_count[2:0] - base[2:0]
    // base mod 8: 66→2, 128→0, 190→6, 252→4, 314→2, 376→0, 438→6, 500→4, 562→2
    wire [2:0] bin_col = in_bin0 ? (h_count[2:0] - 3'd2) :
                         in_bin1 ? (h_count[2:0] - 3'd0) :
                         in_bin2 ? (h_count[2:0] - 3'd6) :
                         in_bin3 ? (h_count[2:0] - 3'd4) :
                         in_bin4 ? (h_count[2:0] - 3'd2) :
                         in_bin5 ? (h_count[2:0] - 3'd0) :
                         in_bin6 ? (h_count[2:0] - 3'd6) :
                         in_bin7 ? (h_count[2:0] - 3'd4) :
                                   (h_count[2:0] - 3'd2);

    wire [2:0] bin_row_sel = v_count - BIN_Y;

    //=========================================================================
    // Region F: X-axis label "FREQ BIN" — 8 chars, y=466..473, centered
    //   Width = 8*8 = 64px, x_start = (640-64)/2 = 288
    //=========================================================================
    localparam XLAB_X   = 10'd288;
    localparam XLAB_Y   = 10'd466;

    wire in_xlab = (h_count >= XLAB_X) && (h_count < XLAB_X + 10'd64)
                && (v_count >= XLAB_Y) && (v_count < XLAB_Y + 10'd8);

    wire [2:0] xlab_idx = (h_count - XLAB_X) >> 3;
    wire [2:0] xlab_col = (h_count - XLAB_X) & 3'b111;
    wire [2:0] xlab_row = (v_count - XLAB_Y) & 3'b111;

    // "FREQ BIN" = 46 52 45 51 20 42 49 4E
    reg [7:0] xlab_char;
    always @(*) begin
        case (xlab_idx)
            3'd0: xlab_char = 7'h46; // F
            3'd1: xlab_char = 7'h52; // R
            3'd2: xlab_char = 7'h45; // E
            3'd3: xlab_char = 7'h51; // Q
            3'd4: xlab_char = 7'h20; // space
            3'd5: xlab_char = 7'h42; // B
            3'd6: xlab_char = 7'h49; // I
            3'd7: xlab_char = 7'h4E; // N
            default: xlab_char = 7'h20;
        endcase
    end

    //=========================================================================
    // Font ROM mux: drive font_char and font_row based on active region
    //=========================================================================
    always @(*) begin
        font_char = 7'h20;
        font_row  = 3'd0;

        if (in_title) begin
            font_char = title_char;
            font_row  = title_row;
        end else if (in_mag) begin
            font_char = mag_char;
            font_row  = mag_row;
        end else if (in_any_tick) begin
            font_char = tick_char;
            font_row  = tick_row;
        end else if (in_any_bin) begin
            font_char = bin_char;
            font_row  = bin_row_sel;
        end else if (in_xlab) begin
            font_char = xlab_char;
            font_row  = xlab_row;
        end
    end

    //=========================================================================
    // Pixel bit extraction
    //=========================================================================
    // For each region, extract the relevant column bit from font_bits
    reg [2:0] active_col;
    always @(*) begin
        if      (in_title)    active_col = title_col;
        else if (in_mag)      active_col = mag_col;
        else if (in_any_tick) active_col = tick_col;
        else if (in_any_bin)  active_col = bin_col;
        else if (in_xlab)     active_col = xlab_col;
        else                  active_col = 3'd0;
    end

    wire pixel_on = font_bits[3'd7 - active_col];

    wire in_any_text = in_title | in_mag | in_any_tick | in_any_bin | in_xlab;

    //=========================================================================
    // Output mux
    //=========================================================================
    always @(*) begin
        if (!video_active) begin
            vga_r = 4'h0; vga_g = 4'h0; vga_b = 4'h0;
        end
        else if (is_tick_dash) begin
            vga_r = 4'h3; vga_g = 4'h3; vga_b = 4'h3;
        end
        else if (in_any_text && pixel_on) begin
            if (in_title || in_any_bin) begin
                // White for title and bin numbers
                vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'hF;
            end else begin
                // Gray for axis labels and magnitude ticks
                vga_r = 4'h6; vga_g = 4'h6; vga_b = 4'h6;
            end
        end
        else begin
            // Passthrough
            vga_r = bg_r; vga_g = bg_g; vga_b = bg_b;
        end
    end

endmodule
