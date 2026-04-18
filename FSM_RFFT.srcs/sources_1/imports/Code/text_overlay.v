`timescale 1ns / 1ps

//=============================================================================
// Module: text_overlay
//
// Renders hardcoded text labels on top of bar_renderer output.
// Updated for 16-bin display (BAR_STRIDE=36, BAR_WIDTH=30).
//
// Regions:
//  A. Title        "RFFT SPECTRUM"   y=4..11,   centered
//  B. Y-axis label "MAG"             y=4..11,   x=2
//  C. Y-axis tick values             left margin, 6 ticks
//  D. Y-axis tick dashes             x=40..43, at each tick v_count
//  E. Bin numbers  "0".."9","A".."F" y=452..459, centered under each bar
//  F. X-axis label "FREQ BIN"        y=466..473, centered
//
// Bar x positions: LEFT_MARGIN + k*BAR_STRIDE = 44 + k*36
// Digit center:    44 + k*36 + 15 = 59 + k*36
// Digit x_start:   59 + k*36 - 4  = 55 + k*36
//=============================================================================

module text_overlay (
    input  wire [9:0] h_count,
    input  wire [9:0] v_count,
    input  wire       video_active,
    input  wire [3:0] bg_r,
    input  wire [3:0] bg_g,
    input  wire [3:0] bg_b,
    output reg  [3:0] vga_r,
    output reg  [3:0] vga_g,
    output reg  [3:0] vga_b
);

    //=========================================================================
    // Font ROM instance
    //=========================================================================
    reg  [6:0] font_char;
    reg  [2:0] font_row;
    wire [7:0] font_bits;

    font_rom fnt (.char_code(font_char), .row(font_row), .bitmap(font_bits));

    //=========================================================================
    // Region A: Title "RFFT SPECTRUM" — 13 chars, y=4..11, x_start=268
    //=========================================================================
    localparam TITLE_X = 10'd268;
    localparam TITLE_Y = 10'd4;

    wire in_title = (h_count >= TITLE_X) && (h_count < TITLE_X + 10'd104)
                 && (v_count >= TITLE_Y) && (v_count < TITLE_Y + 10'd8);

    wire [3:0] title_idx = (h_count - TITLE_X) >> 3;
    wire [2:0] title_col = (h_count - TITLE_X) & 3'b111;
    wire [2:0] title_row = (v_count - TITLE_Y) & 3'b111;

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
    // Region B: "MAG" — 3 chars, y=4..11, x=2
    //=========================================================================
    localparam MAG_X = 10'd2;
    localparam MAG_Y = 10'd4;

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
    // Region C: Y-axis tick labels (same tick positions as before)
    // T0: "0"     v=447, y_start=444, x=36 (1 char)
    // T1: "5120"  v=367, y_start=364, x=12 (4 chars)
    // T2: "10240" v=287, y_start=284, x=4  (5 chars)
    // T3: "15360" v=207, y_start=204, x=4  (5 chars)
    // T4: "20480" v=127, y_start=124, x=4  (5 chars)
    // T5: "25600" v=47,  y_start=44,  x=4  (5 chars)
    //=========================================================================
    localparam T0_V=10'd447; localparam T0_Y=10'd444; localparam T0_X=10'd36;
    localparam T1_V=10'd367; localparam T1_Y=10'd364; localparam T1_X=10'd12;
    localparam T2_V=10'd287; localparam T2_Y=10'd284; localparam T2_X=10'd4;
    localparam T3_V=10'd207; localparam T3_Y=10'd204; localparam T3_X=10'd4;
    localparam T4_V=10'd127; localparam T4_Y=10'd124; localparam T4_X=10'd4;
    localparam T5_V=10'd47;  localparam T5_Y=10'd44;  localparam T5_X=10'd4;

    wire in_tick0 = (h_count >= T0_X) && (h_count < T0_X + 10'd8)
                 && (v_count >= T0_Y) && (v_count < T0_Y + 10'd8);
    wire in_tick1 = (h_count >= T1_X) && (h_count < T1_X + 10'd32)
                 && (v_count >= T1_Y) && (v_count < T1_Y + 10'd8);
    wire in_tick2 = (h_count >= T2_X) && (h_count < T2_X + 10'd40)
                 && (v_count >= T2_Y) && (v_count < T2_Y + 10'd8);
    wire in_tick3 = (h_count >= T3_X) && (h_count < T3_X + 10'd40)
                 && (v_count >= T3_Y) && (v_count < T3_Y + 10'd8);
    wire in_tick4 = (h_count >= T4_X) && (h_count < T4_X + 10'd40)
                 && (v_count >= T4_Y) && (v_count < T4_Y + 10'd8);
    wire in_tick5 = (h_count >= T5_X) && (h_count < T5_X + 10'd40)
                 && (v_count >= T5_Y) && (v_count < T5_Y + 10'd8);

    wire in_any_tick = in_tick0|in_tick1|in_tick2|in_tick3|in_tick4|in_tick5;

    wire [2:0] t0_col = (h_count - T0_X) & 3'b111;
    wire [2:0] t0_row = (v_count - T0_Y) & 3'b111;
    wire [2:0] t1_col = (h_count - T1_X) & 3'b111;
    wire [2:0] t1_row = (v_count - T1_Y) & 3'b111;
    wire [2:0] t2_col = (h_count - T2_X) & 3'b111;
    wire [2:0] t2_row = (v_count - T2_Y) & 3'b111;
    wire [1:0] t1_idx = (h_count - T1_X) >> 3;
    wire [2:0] t_idx5 = (h_count - T2_X) >> 3;

    reg [7:0] tick_char;
    always @(*) begin
        tick_char = 7'h20;
        if (in_tick0) tick_char = 7'h30;
        else if (in_tick1) begin
            case (t1_idx)
                2'd0: tick_char = 7'h35;
                2'd1: tick_char = 7'h31;
                2'd2: tick_char = 7'h32;
                2'd3: tick_char = 7'h30;
                default: tick_char = 7'h20;
            endcase
        end else if (in_tick2) begin
            case (t_idx5)
                3'd0: tick_char = 7'h31; 3'd1: tick_char = 7'h30;
                3'd2: tick_char = 7'h32; 3'd3: tick_char = 7'h34;
                3'd4: tick_char = 7'h30; default: tick_char = 7'h20;
            endcase
        end else if (in_tick3) begin
            case (t_idx5)
                3'd0: tick_char = 7'h31; 3'd1: tick_char = 7'h35;
                3'd2: tick_char = 7'h33; 3'd3: tick_char = 7'h36;
                3'd4: tick_char = 7'h30; default: tick_char = 7'h20;
            endcase
        end else if (in_tick4) begin
            case (t_idx5)
                3'd0: tick_char = 7'h32; 3'd1: tick_char = 7'h30;
                3'd2: tick_char = 7'h34; 3'd3: tick_char = 7'h38;
                3'd4: tick_char = 7'h30; default: tick_char = 7'h20;
            endcase
        end else if (in_tick5) begin
            case (t_idx5)
                3'd0: tick_char = 7'h32; 3'd1: tick_char = 7'h35;
                3'd2: tick_char = 7'h36; 3'd3: tick_char = 7'h30;
                3'd4: tick_char = 7'h30; default: tick_char = 7'h20;
            endcase
        end
    end

    // T2..T5 share same x=4, same mod-8 alignment (284%8=204%8=124%8=44%8=4)
    wire [2:0] tick_row = in_tick0 ? t0_row : in_tick1 ? t1_row : t2_row;
    wire [2:0] tick_col = in_tick0 ? t0_col : in_tick1 ? t1_col : t2_col;

    //=========================================================================
    // Region D: Tick dashes — x=40..43 at each tick v_count
    //=========================================================================
    wire is_tick_dash = (h_count >= 10'd40) && (h_count <= 10'd43)
                     && (v_count == T0_V || v_count == T1_V || v_count == T2_V
                      || v_count == T3_V || v_count == T4_V || v_count == T5_V);

    //=========================================================================
    // Region E: Bin numbers — y=452..459
    // Digit x_start = 55 + k*36 (8px wide, centered in 30px bar)
    // k:  0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15
    // x: 55  91 127 163 199 235 271 307 343 379 415 451 487 523 559 595
    // mod8: even k → 7, odd k → 3
    //=========================================================================
    localparam BIN_Y = 10'd452;

    wire in_bin_row = (v_count >= BIN_Y) && (v_count < BIN_Y + 10'd8);

    wire in_bin0  = in_bin_row && (h_count >= 10'd55)  && (h_count < 10'd63);
    wire in_bin1  = in_bin_row && (h_count >= 10'd91)  && (h_count < 10'd99);
    wire in_bin2  = in_bin_row && (h_count >= 10'd127) && (h_count < 10'd135);
    wire in_bin3  = in_bin_row && (h_count >= 10'd163) && (h_count < 10'd171);
    wire in_bin4  = in_bin_row && (h_count >= 10'd199) && (h_count < 10'd207);
    wire in_bin5  = in_bin_row && (h_count >= 10'd235) && (h_count < 10'd243);
    wire in_bin6  = in_bin_row && (h_count >= 10'd271) && (h_count < 10'd279);
    wire in_bin7  = in_bin_row && (h_count >= 10'd307) && (h_count < 10'd315);
    wire in_bin8  = in_bin_row && (h_count >= 10'd343) && (h_count < 10'd351);
    wire in_bin9  = in_bin_row && (h_count >= 10'd379) && (h_count < 10'd387);
    wire in_bin10 = in_bin_row && (h_count >= 10'd415) && (h_count < 10'd423);
    wire in_bin11 = in_bin_row && (h_count >= 10'd451) && (h_count < 10'd459);
    wire in_bin12 = in_bin_row && (h_count >= 10'd487) && (h_count < 10'd495);
    wire in_bin13 = in_bin_row && (h_count >= 10'd523) && (h_count < 10'd531);
    wire in_bin14 = in_bin_row && (h_count >= 10'd559) && (h_count < 10'd567);
    wire in_bin15 = in_bin_row && (h_count >= 10'd595) && (h_count < 10'd603);

    wire in_any_bin = in_bin0|in_bin1|in_bin2|in_bin3|in_bin4|in_bin5|in_bin6|in_bin7|
                      in_bin8|in_bin9|in_bin10|in_bin11|in_bin12|in_bin13|in_bin14|in_bin15;

    // ASCII for hex digits: 0-9 = 0x30-0x39, A-F = 0x41-0x46
    reg [7:0] bin_char;
    always @(*) begin
        if      (in_bin0)  bin_char = 7'h30; // '0'
        else if (in_bin1)  bin_char = 7'h31; // '1'
        else if (in_bin2)  bin_char = 7'h32; // '2'
        else if (in_bin3)  bin_char = 7'h33; // '3'
        else if (in_bin4)  bin_char = 7'h34; // '4'
        else if (in_bin5)  bin_char = 7'h35; // '5'
        else if (in_bin6)  bin_char = 7'h36; // '6'
        else if (in_bin7)  bin_char = 7'h37; // '7'
        else if (in_bin8)  bin_char = 7'h38; // '8'
        else if (in_bin9)  bin_char = 7'h39; // '9'
        else if (in_bin10) bin_char = 7'h41; // 'A'
        else if (in_bin11) bin_char = 7'h42; // 'B'
        else if (in_bin12) bin_char = 7'h43; // 'C'
        else if (in_bin13) bin_char = 7'h44; // 'D'
        else if (in_bin14) bin_char = 7'h45; // 'E'
        else               bin_char = 7'h46; // 'F'
    end

    // Column: even k → base mod8 = 7, odd k → base mod8 = 3
    wire bin_is_even = in_bin0|in_bin2|in_bin4|in_bin6|in_bin8|in_bin10|in_bin12|in_bin14;
    wire [2:0] bin_col = bin_is_even ? (h_count[2:0] - 3'd7) : (h_count[2:0] - 3'd3);
    wire [2:0] bin_row_sel = v_count - BIN_Y;

    //=========================================================================
    // Region F: "FREQ BIN" — 8 chars, y=466..473
    // Bar area center: 44 + 576/2 = 332 → x_start = 332 - 32 = 300
    //=========================================================================
    localparam XLAB_X = 10'd300;
    localparam XLAB_Y = 10'd466;

    wire in_xlab = (h_count >= XLAB_X) && (h_count < XLAB_X + 10'd64)
                && (v_count >= XLAB_Y) && (v_count < XLAB_Y + 10'd8);

    wire [2:0] xlab_idx = (h_count - XLAB_X) >> 3;
    wire [2:0] xlab_col = (h_count - XLAB_X) & 3'b111;
    wire [2:0] xlab_row = (v_count - XLAB_Y) & 3'b111;

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
    // Font ROM mux
    //=========================================================================
    always @(*) begin
        font_char = 7'h20;
        font_row  = 3'd0;
        if      (in_title)    begin font_char = title_char; font_row = title_row; end
        else if (in_mag)      begin font_char = mag_char;   font_row = mag_row;   end
        else if (in_any_tick) begin font_char = tick_char;  font_row = tick_row;  end
        else if (in_any_bin)  begin font_char = bin_char;   font_row = bin_row_sel; end
        else if (in_xlab)     begin font_char = xlab_char;  font_row = xlab_row;  end
    end

    //=========================================================================
    // Active column mux
    //=========================================================================
    reg [2:0] active_col;
    always @(*) begin
        if      (in_title)    active_col = title_col;
        else if (in_mag)      active_col = mag_col;
        else if (in_any_tick) active_col = tick_col;
        else if (in_any_bin)  active_col = bin_col;
        else if (in_xlab)     active_col = xlab_col;
        else                  active_col = 3'd0;
    end

    wire pixel_on    = font_bits[3'd7 - active_col];
    wire in_any_text = in_title | in_mag | in_any_tick | in_any_bin | in_xlab;

    //=========================================================================
    // Output mux
    //=========================================================================
    always @(*) begin
        if (!video_active) begin
            vga_r = 4'h0; vga_g = 4'h0; vga_b = 4'h0;
        end else if (is_tick_dash) begin
            vga_r = 4'h3; vga_g = 4'h3; vga_b = 4'h3;
        end else if (in_any_text && pixel_on) begin
            if (in_title || in_any_bin) begin
                vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'hF; // white
            end else begin
                vga_r = 4'h6; vga_g = 4'h6; vga_b = 4'h6; // gray
            end
        end else begin
            vga_r = bg_r; vga_g = bg_g; vga_b = bg_b;
        end
    end

endmodule
