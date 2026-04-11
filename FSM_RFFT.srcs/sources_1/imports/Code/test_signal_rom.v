`timescale 1ns / 1ps

//=============================================================================
// Module: test_signal_rom
//
// Provides precomputed test signals for the RFFT demo.
// Select between different signals using sig_sel input.
// Connect sig_sel to switches on the Nexys A7 for live switching!
//
// Signal 0: Two-tone (bins 2 and 5) — two bars visible
// Signal 1: Single tone (bin 3) — one bar visible
// Signal 2: DC + tone (bins 0 and 4) — DC bar + one frequency bar
// Signal 3: x[n] = n^2 — broad spectrum (all bars different heights)
//
// Each signal has 16 samples in Q1.15 format.
// Read one sample per clock using the addr input (0 to 15).
//=============================================================================

module test_signal_rom (
    input  wire [1:0]  sig_sel,    // Signal selector (connect to switches)
    input  wire [3:0]  addr,       // Sample index (0 to 15)
    output reg  signed [15:0] data // Q1.15 sample value
);

    always @(*) begin
        case (sig_sel)

            // ============================================================
            // Signal 0: Two-tone
            // 0.4*sin(2pi*2*n/16) + 0.4*sin(2pi*5*n/16)
            // Expected peaks at bins 2 and 5
            // ============================================================
            2'd0: begin
                case (addr)
                    4'd0:  data = 16'sd0;
                    4'd1:  data = 16'sd21378;
                    4'd2:  data = 16'sd3839;
                    4'd3:  data = 16'sd4252;
                    4'd4:  data = 16'sd13107;
                    4'd5:  data = -16'sd14284;
                    4'd6:  data = -16'sd22375;
                    4'd7:  data = 16'sd2841;
                    4'd8:  data = 16'sd0;
                    4'd9:  data = -16'sd2841;
                    4'd10: data = 16'sd22375;
                    4'd11: data = 16'sd14284;
                    4'd12: data = -16'sd13107;
                    4'd13: data = -16'sd4252;
                    4'd14: data = -16'sd3839;
                    4'd15: data = -16'sd21378;
                endcase
            end

            // ============================================================
            // Signal 1: Single tone at bin 3
            // 0.7*sin(2pi*3*n/16)
            // Expected peak at bin 3 only
            // ============================================================
            2'd1: begin
                case (addr)
                    4'd0:  data =  16'sd0;
                    4'd1:  data =  16'sd21192;
                    4'd2:  data =  16'sd16219;
                    4'd3:  data = -16'sd8778;
                    4'd4:  data = -16'sd22938;
                    4'd5:  data = -16'sd8778;
                    4'd6:  data =  16'sd16219;
                    4'd7:  data =  16'sd21192;
                    4'd8:  data =  16'sd0;
                    4'd9:  data = -16'sd21192;
                    4'd10: data = -16'sd16219;
                    4'd11: data =  16'sd8778;
                    4'd12: data =  16'sd22938;
                    4'd13: data =  16'sd8778;
                    4'd14: data = -16'sd16219;
                    4'd15: data = -16'sd21192;
                endcase
            end

            // ============================================================
            // Signal 2: DC offset + tone at bin 4
            // 0.3 + 0.5*sin(2pi*4*n/16)
            // Expected: DC bar + bin 4 bar
            // ============================================================
            2'd2: begin
                case (addr)
                    4'd0:  data = 16'sd9830;      // 0.3
                    4'd1:  data = 16'sd26214;     // 0.3 + 0.5*sin(pi/2)
                    4'd2:  data = 16'sd9830;      // 0.3 + 0.5*sin(pi) = 0.3
                    4'd3:  data = -16'sd6554;     // 0.3 + 0.5*sin(3pi/2) = -0.2
                    4'd4:  data = 16'sd9830;
                    4'd5:  data = 16'sd26214;
                    4'd6:  data = 16'sd9830;
                    4'd7:  data = -16'sd6554;
                    4'd8:  data = 16'sd9830;
                    4'd9:  data = 16'sd26214;
                    4'd10: data = 16'sd9830;
                    4'd11: data = -16'sd6554;
                    4'd12: data = 16'sd9830;
                    4'd13: data = 16'sd26214;
                    4'd14: data = 16'sd9830;
                    4'd15: data = -16'sd6554;
                endcase
            end

            // ============================================================
            // Signal 3: x[n] = n^2 / 225 (normalized)
            // Broad spectrum — all bars have different heights
            // (Divided by 225 to keep within Q1.15 range)
            // ============================================================
            2'd3: begin
                case (addr)
                    4'd0:  data = 16'sd0;
                    4'd1:  data = 16'sd146;       // 1/225 * 32768
                    4'd2:  data = 16'sd582;       // 4/225 * 32768
                    4'd3:  data = 16'sd1311;
                    4'd4:  data = 16'sd2330;
                    4'd5:  data = 16'sd3641;
                    4'd6:  data = 16'sd5243;
                    4'd7:  data = 16'sd7136;
                    4'd8:  data = 16'sd9320;
                    4'd9:  data = 16'sd11796;
                    4'd10: data = 16'sd14564;
                    4'd11: data = 16'sd17622;
                    4'd12: data = 16'sd20972;
                    4'd13: data = 16'sd24614;
                    4'd14: data = 16'sd28546;
                    4'd15: data = 16'sd32767;     // 225/225 clamped
                endcase
            end

        endcase
    end

endmodule
