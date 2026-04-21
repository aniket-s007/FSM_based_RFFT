`timescale 1ns / 1ps

//=============================================================================
// Module: rfft_n16_simple
//
// SIMPLE N=16 DIF RFFT — register-based, FSM-controlled.
//
// This is the PRAGMATIC implementation for the course project demo.
// It stores all 16 input samples in registers, then computes the
// standard radix-2 DIF FFT butterfly stages one at a time.
//
// Strategy:
//   1. LOAD state: Accept 16 samples (one per clock)
//   2. COMPUTE state: Process 4 butterfly stages + twiddle
//   3. OUTPUT state: Output 9 frequency bins (X[0]..X[8])
//
// For N=16 on Artix-7, the 16 registers + arithmetic is tiny.
// No complex control signal alignment issues.
// The serial pipeline optimization is for the IEEE paper.
//
// Interface:
//   - Feed 16 samples via data_in (one per clock, natural order x[0]..x[15])
//   - Assert start pulse to begin
//   - Wait for done signal
//   - Read 9 frequency bins from output ports
//
// Fixed-point: Q1.15 throughout.
// Scaling: 1/2 at each butterfly stage = total 1/16 after 4 stages.
// Twiddle multiplication: Q1.15 * Q1.15 >> 15 (no extra scaling).
//=============================================================================

module rfft_n16_simple (
    input  wire        clk,
    input  wire        rst_n,
    input  wire signed [15:0] data_in,
    input  wire        sample_valid,   // High when data_in has a valid sample
    input  wire        start,          // Pulse to begin computation after loading
    output reg         done,           // High when results are ready
    output reg         busy,           // High during computation
    // Output: all 16 frequency bins (X[0] to X[15])
    // Each has real and imaginary parts
    output wire signed [15:0] X0_re,  X0_im,
    output wire signed [15:0] X1_re,  X1_im,
    output wire signed [15:0] X2_re,  X2_im,
    output wire signed [15:0] X3_re,  X3_im,
    output wire signed [15:0] X4_re,  X4_im,
    output wire signed [15:0] X5_re,  X5_im,
    output wire signed [15:0] X6_re,  X6_im,
    output wire signed [15:0] X7_re,  X7_im,
    output wire signed [15:0] X8_re,  X8_im,
    output wire signed [15:0] X9_re,  X9_im,
    output wire signed [15:0] X10_re, X10_im,
    output wire signed [15:0] X11_re, X11_im,
    output wire signed [15:0] X12_re, X12_im,
    output wire signed [15:0] X13_re, X13_im,
    output wire signed [15:0] X14_re, X14_im,
    output wire signed [15:0] X15_re, X15_im
);

    //=========================================================================
    // Data registers: 16 real + 16 imaginary
    //=========================================================================
    reg signed [15:0] re [0:15];
    reg signed [15:0] im [0:15];

    //=========================================================================
    // Sample loading counter
    //=========================================================================
    reg [3:0] load_idx;

    //=========================================================================
    // FSM
    //=========================================================================
    localparam S_IDLE    = 3'd0;
    localparam S_LOAD    = 3'd1;
    localparam S_STAGE1  = 3'd2;
    localparam S_STAGE2  = 3'd3;
    localparam S_STAGE3  = 3'd4;
    localparam S_STAGE4  = 3'd5;
    localparam S_DONE    = 3'd6;

    reg [2:0] state;
    reg [3:0] sub_step;  // Sub-step within each stage (up to 15)

    //=========================================================================
    // Twiddle factor ROM (combinational)
    // W_16^k = cos(2*pi*k/16) - j*sin(2*pi*k/16)
    //=========================================================================
    function signed [15:0] tw_cos;
        input [3:0] k;
        case (k)
            4'd0: tw_cos =  16'sd32767;  // cos(0)
            4'd1: tw_cos =  16'sd30274;  // cos(pi/8)
            4'd2: tw_cos =  16'sd23170;  // cos(pi/4)
            4'd3: tw_cos =  16'sd12540;  // cos(3pi/8)
            4'd4: tw_cos =  16'sd0;      // cos(pi/2)
            4'd5: tw_cos = -16'sd12540;  // cos(5pi/8)
            4'd6: tw_cos = -16'sd23170;  // cos(3pi/4)
            4'd7: tw_cos = -16'sd30274;  // cos(7pi/8)
            default: tw_cos = 16'sd32767;
        endcase
    endfunction

    function signed [15:0] tw_sin;
        input [3:0] k;
        case (k)
            4'd0: tw_sin =  16'sd0;      // sin(0)
            4'd1: tw_sin =  16'sd12540;  // sin(pi/8)
            4'd2: tw_sin =  16'sd23170;  // sin(pi/4)
            4'd3: tw_sin =  16'sd30274;  // sin(3pi/8)
            4'd4: tw_sin =  16'sd32767;  // sin(pi/2) (clamped from 32768)
            4'd5: tw_sin =  16'sd30274;  // sin(5pi/8)
            4'd6: tw_sin =  16'sd23170;  // sin(3pi/4)
            4'd7: tw_sin =  16'sd12540;  // sin(7pi/8)
            default: tw_sin = 16'sd0;
        endcase
    endfunction

    //=========================================================================
    // Butterfly computation wires
    // We compute one butterfly pair per clock cycle.
    //=========================================================================
    reg [3:0] bf_i1, bf_i2;  // Indices of butterfly pair
    reg [3:0] tw_idx;        // Twiddle factor index

    // Scaled butterfly: (a+b)/2, (a-b)/2 using 17-bit intermediate
    wire signed [16:0] sum_re  = {re[bf_i1][15], re[bf_i1]} + {re[bf_i2][15], re[bf_i2]};
    wire signed [16:0] diff_re = {re[bf_i1][15], re[bf_i1]} - {re[bf_i2][15], re[bf_i2]};
    wire signed [16:0] sum_im  = {im[bf_i1][15], im[bf_i1]} + {im[bf_i2][15], im[bf_i2]};
    wire signed [16:0] diff_im = {im[bf_i1][15], im[bf_i1]} - {im[bf_i2][15], im[bf_i2]};

    wire signed [15:0] bf_sum_re  = sum_re[16:1];
    wire signed [15:0] bf_diff_re = diff_re[16:1];
    wire signed [15:0] bf_sum_im  = sum_im[16:1];
    wire signed [15:0] bf_diff_im = diff_im[16:1];

    // Twiddle multiplication: (a+jb) * (cos-jsin)
    // real = a*cos + b*sin, imag = b*cos - a*sin
    wire signed [15:0] cos_val = tw_cos(tw_idx);
    wire signed [15:0] sin_val = tw_sin(tw_idx);

    wire signed [31:0] tw_prod_ac = re[bf_i2] * cos_val;
    wire signed [31:0] tw_prod_bs = im[bf_i2] * sin_val;
    wire signed [31:0] tw_prod_bc = im[bf_i2] * cos_val;
    wire signed [31:0] tw_prod_as = re[bf_i2] * sin_val;

    wire signed [15:0] tw_re = tw_prod_ac[30:15] + tw_prod_bs[30:15];
    wire signed [15:0] tw_im = tw_prod_bc[30:15] - tw_prod_as[30:15];

    //=========================================================================
    // Main FSM
    //=========================================================================
    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            sub_step <= 0;
            load_idx <= 0;
            done     <= 0;
            busy     <= 0;
            bf_i1    <= 0;
            bf_i2    <= 0;
            tw_idx   <= 0;
            for (i = 0; i < 16; i = i + 1) begin
                re[i] <= 16'sd0;
                im[i] <= 16'sd0;
            end
        end else begin
            case (state)

                S_IDLE: begin
                    done <= 0;
                    busy <= 0;
                    if (sample_valid) begin
                        re[0]    <= data_in;
                        im[0]    <= 16'sd0;
                        load_idx <= 4'd1;
                        state    <= S_LOAD;
                        busy     <= 1;
                    end
                end

                S_LOAD: begin
                    if (sample_valid) begin
                        re[load_idx] <= data_in;
                        im[load_idx] <= 16'sd0;
                        if (load_idx == 4'd15) begin
                            state    <= S_STAGE1;
                            sub_step <= 0;
                        end else begin
                            load_idx <= load_idx + 4'd1;
                        end
                    end
                end

                // ===========================================================
                // STAGE 1: Butterfly distance=8, NO twiddle
                // Pairs: (0,8),(1,9),(2,10),(3,11),(4,12),(5,13),(6,14),(7,15)
                // 8 pairs, one per clock cycle
                // ===========================================================
                S_STAGE1: begin
                    if (sub_step <= 4'd8) begin
                        // Butterfly phase: 8 pairs (0..7 with 8..15)
                        bf_i1 <= sub_step[3:0];
                        bf_i2 <= sub_step[3:0] + 4'd8;
                        if (sub_step > 0) begin
                            re[bf_i1] <= bf_sum_re;
                            re[bf_i2] <= bf_diff_re;
                        end
                        if (sub_step == 4'd8) begin
                            // Start twiddle phase
                            // idx 8: W^0 is trivial, skip. Start with idx 9: W^1
                            bf_i2 <= 4'd9; tw_idx <= 4'd1;
                        end
                        sub_step <= sub_step + 1;
                    end else begin
                        // Twiddle phase: W^k on indices 9..15
                        // sub_step 9: apply W^1 to idx 9 (read from prev cycle)
                        // sub_step 10: apply W^2 to idx 10, write W^1 result
                        // etc.
                        case (sub_step)
                            9: begin
                                re[4'd9] <= tw_re; im[4'd9] <= tw_im;
                                bf_i2 <= 4'd10; tw_idx <= 4'd2;
                                sub_step <= 10;
                            end
                            10: begin
                                re[4'd10] <= tw_re; im[4'd10] <= tw_im;
                                bf_i2 <= 4'd11; tw_idx <= 4'd3;
                                sub_step <= 11;
                            end
                            11: begin
                                re[4'd11] <= tw_re; im[4'd11] <= tw_im;
                                bf_i2 <= 4'd12; tw_idx <= 4'd4;
                                sub_step <= 12;
                            end
                            12: begin
                                re[4'd12] <= tw_re; im[4'd12] <= tw_im;
                                bf_i2 <= 4'd13; tw_idx <= 4'd5;
                                sub_step <= 13;
                            end
                            13: begin
                                re[4'd13] <= tw_re; im[4'd13] <= tw_im;
                                bf_i2 <= 4'd14; tw_idx <= 4'd6;
                                sub_step <= 14;
                            end
                            14: begin
                                re[4'd14] <= tw_re; im[4'd14] <= tw_im;
                                bf_i2 <= 4'd15; tw_idx <= 4'd7;
                                sub_step <= 15;
                            end
                            15: begin
                                re[4'd15] <= tw_re; im[4'd15] <= tw_im;
                                state <= S_STAGE2;
                                sub_step <= 0;
                            end
                            default: sub_step <= 0;
                        endcase
                    end
                end

                // ===========================================================
                // STAGE 2: BF distance=4, twiddle W^(2k) on lower outputs
                // Groups: [0-7] BF(k,k+4) for k=0..3
                //         [8-15] BF(k,k+4) for k=8..11
                // Then twiddle indices 5,6,7 and 13,14,15
                // ===========================================================
                S_STAGE2: begin
                    case (sub_step)
                        // Butterfly phase: 8 pairs (now handling both re and im)
                        0: begin bf_i1<=4'd0;  bf_i2<=4'd4;  sub_step<=1; end
                        1: begin bf_i1<=4'd1;  bf_i2<=4'd5;
                           re[4'd0]<=bf_sum_re; re[4'd4]<=bf_diff_re;
                           im[4'd0]<=bf_sum_im; im[4'd4]<=bf_diff_im; sub_step<=2; end
                        2: begin bf_i1<=4'd2;  bf_i2<=4'd6;
                           re[4'd1]<=bf_sum_re; re[4'd5]<=bf_diff_re;
                           im[4'd1]<=bf_sum_im; im[4'd5]<=bf_diff_im; sub_step<=3; end
                        3: begin bf_i1<=4'd3;  bf_i2<=4'd7;
                           re[4'd2]<=bf_sum_re; re[4'd6]<=bf_diff_re;
                           im[4'd2]<=bf_sum_im; im[4'd6]<=bf_diff_im; sub_step<=4; end
                        4: begin bf_i1<=4'd8;  bf_i2<=4'd12;
                           re[4'd3]<=bf_sum_re; re[4'd7]<=bf_diff_re;
                           im[4'd3]<=bf_sum_im; im[4'd7]<=bf_diff_im; sub_step<=5; end
                        5: begin bf_i1<=4'd9;  bf_i2<=4'd13;
                           re[4'd8]<=bf_sum_re; re[4'd12]<=bf_diff_re;
                           im[4'd8]<=bf_sum_im; im[4'd12]<=bf_diff_im; sub_step<=6; end
                        6: begin bf_i1<=4'd10; bf_i2<=4'd14;
                           re[4'd9]<=bf_sum_re; re[4'd13]<=bf_diff_re;
                           im[4'd9]<=bf_sum_im; im[4'd13]<=bf_diff_im; sub_step<=7; end
                        7: begin bf_i1<=4'd11; bf_i2<=4'd15;
                           re[4'd10]<=bf_sum_re; re[4'd14]<=bf_diff_re;
                           im[4'd10]<=bf_sum_im; im[4'd14]<=bf_diff_im; sub_step<=8; end
                        8: begin
                            re[4'd11]<=bf_sum_re; re[4'd15]<=bf_diff_re;
                            im[4'd11]<=bf_sum_im; im[4'd15]<=bf_diff_im;
                            bf_i2 <= 4'd5; tw_idx <= 4'd2;
                            sub_step<=9;
                        end
                        9: begin
                            re[4'd5] <= tw_re; im[4'd5] <= tw_im;
                            bf_i2 <= 4'd6; tw_idx <= 4'd4;
                            sub_step<=10;
                        end
                        10: begin
                            re[4'd6] <= tw_re; im[4'd6] <= tw_im;
                            bf_i2 <= 4'd7; tw_idx <= 4'd6;
                            sub_step<=11;
                        end
                        11: begin
                            re[4'd7] <= tw_re; im[4'd7] <= tw_im;
                            bf_i2 <= 4'd13; tw_idx <= 4'd2;
                            sub_step<=12;
                        end
                        12: begin
                            re[4'd13] <= tw_re; im[4'd13] <= tw_im;
                            bf_i2 <= 4'd14; tw_idx <= 4'd4;
                            sub_step<=13;
                        end
                        13: begin
                            re[4'd14] <= tw_re; im[4'd14] <= tw_im;
                            bf_i2 <= 4'd15; tw_idx <= 4'd6;
                            sub_step<=14;
                        end
                        14: begin
                            re[4'd15] <= tw_re; im[4'd15] <= tw_im;
                            state <= S_STAGE3;
                            sub_step <= 0;
                        end
                        default: sub_step <= 0;
                    endcase
                end

                // ===========================================================
                // STAGE 3: BF distance=2, twiddle W^(4k)
                // Groups of 4: BF(k,k+2) for k in each group
                // Twiddle: W^0 (skip), W^4 on odd lower outputs
                // ===========================================================
                S_STAGE3: begin
                    case (sub_step)
                        0:  begin bf_i1<=4'd0;  bf_i2<=4'd2;  sub_step<=1; end
                        1:  begin bf_i1<=4'd1;  bf_i2<=4'd3;
                            re[4'd0]<=bf_sum_re; re[4'd2]<=bf_diff_re;
                            im[4'd0]<=bf_sum_im; im[4'd2]<=bf_diff_im; sub_step<=2; end
                        2:  begin bf_i1<=4'd4;  bf_i2<=4'd6;
                            re[4'd1]<=bf_sum_re; re[4'd3]<=bf_diff_re;
                            im[4'd1]<=bf_sum_im; im[4'd3]<=bf_diff_im; sub_step<=3; end
                        3:  begin bf_i1<=4'd5;  bf_i2<=4'd7;
                            re[4'd4]<=bf_sum_re; re[4'd6]<=bf_diff_re;
                            im[4'd4]<=bf_sum_im; im[4'd6]<=bf_diff_im; sub_step<=4; end
                        4:  begin bf_i1<=4'd8;  bf_i2<=4'd10;
                            re[4'd5]<=bf_sum_re; re[4'd7]<=bf_diff_re;
                            im[4'd5]<=bf_sum_im; im[4'd7]<=bf_diff_im; sub_step<=5; end
                        5:  begin bf_i1<=4'd9;  bf_i2<=4'd11;
                            re[4'd8]<=bf_sum_re; re[4'd10]<=bf_diff_re;
                            im[4'd8]<=bf_sum_im; im[4'd10]<=bf_diff_im; sub_step<=6; end
                        6:  begin bf_i1<=4'd12; bf_i2<=4'd14;
                            re[4'd9]<=bf_sum_re; re[4'd11]<=bf_diff_re;
                            im[4'd9]<=bf_sum_im; im[4'd11]<=bf_diff_im; sub_step<=7; end
                        7:  begin bf_i1<=4'd13; bf_i2<=4'd15;
                            re[4'd12]<=bf_sum_re; re[4'd14]<=bf_diff_re;
                            im[4'd12]<=bf_sum_im; im[4'd14]<=bf_diff_im; sub_step<=8; end
                        8:  begin
                            re[4'd13]<=bf_sum_re; re[4'd15]<=bf_diff_re;
                            im[4'd13]<=bf_sum_im; im[4'd15]<=bf_diff_im;
                            bf_i2 <= 4'd3; tw_idx <= 4'd4;
                            sub_step<=9;
                        end
                        9:  begin
                            re[4'd3] <= tw_re; im[4'd3] <= tw_im;
                            bf_i2 <= 4'd7; tw_idx <= 4'd4;
                            sub_step<=10;
                        end
                        10: begin
                            re[4'd7] <= tw_re; im[4'd7] <= tw_im;
                            bf_i2 <= 4'd11; tw_idx <= 4'd4;
                            sub_step<=11;
                        end
                        11: begin
                            re[4'd11] <= tw_re; im[4'd11] <= tw_im;
                            bf_i2 <= 4'd15; tw_idx <= 4'd4;
                            sub_step<=12;
                        end
                        12: begin
                            re[4'd15] <= tw_re; im[4'd15] <= tw_im;
                            state <= S_STAGE4;
                            sub_step <= 0;
                        end
                        default: sub_step <= 0;
                    endcase
                end

                // ===========================================================
                // STAGE 4: BF distance=1, NO twiddle
                // 8 pairs: (0,1),(2,3),(4,5),(6,7),(8,9),(10,11),(12,13),(14,15)
                // ===========================================================
                S_STAGE4: begin
                    case (sub_step)
                        0: begin bf_i1<=4'd0;  bf_i2<=4'd1;  sub_step<=1; end
                        1: begin bf_i1<=4'd2;  bf_i2<=4'd3;
                           re[4'd0]<=bf_sum_re; re[4'd1]<=bf_diff_re;
                           im[4'd0]<=bf_sum_im; im[4'd1]<=bf_diff_im; sub_step<=2; end
                        2: begin bf_i1<=4'd4;  bf_i2<=4'd5;
                           re[4'd2]<=bf_sum_re; re[4'd3]<=bf_diff_re;
                           im[4'd2]<=bf_sum_im; im[4'd3]<=bf_diff_im; sub_step<=3; end
                        3: begin bf_i1<=4'd6;  bf_i2<=4'd7;
                           re[4'd4]<=bf_sum_re; re[4'd5]<=bf_diff_re;
                           im[4'd4]<=bf_sum_im; im[4'd5]<=bf_diff_im; sub_step<=4; end
                        4: begin bf_i1<=4'd8;  bf_i2<=4'd9;
                           re[4'd6]<=bf_sum_re; re[4'd7]<=bf_diff_re;
                           im[4'd6]<=bf_sum_im; im[4'd7]<=bf_diff_im; sub_step<=5; end
                        5: begin bf_i1<=4'd10; bf_i2<=4'd11;
                           re[4'd8]<=bf_sum_re; re[4'd9]<=bf_diff_re;
                           im[4'd8]<=bf_sum_im; im[4'd9]<=bf_diff_im; sub_step<=6; end
                        6: begin bf_i1<=4'd12; bf_i2<=4'd13;
                           re[4'd10]<=bf_sum_re; re[4'd11]<=bf_diff_re;
                           im[4'd10]<=bf_sum_im; im[4'd11]<=bf_diff_im; sub_step<=7; end
                        7: begin bf_i1<=4'd14; bf_i2<=4'd15;
                           re[4'd12]<=bf_sum_re; re[4'd13]<=bf_diff_re;
                           im[4'd12]<=bf_sum_im; im[4'd13]<=bf_diff_im; sub_step<=8; end
                        8: begin
                           re[4'd14]<=bf_sum_re; re[4'd15]<=bf_diff_re;
                           im[4'd14]<=bf_sum_im; im[4'd15]<=bf_diff_im;
                           state <= S_DONE;
                        end
                        default: sub_step <= 0;
                    endcase
                end

                S_DONE: begin
                    done <= 1;
                    busy <= 0;
                    // Stay here until reset or new start
                    if (start) begin
                        done  <= 0;
                        state <= S_IDLE;
                    end
                end

            endcase
        end
    end

    //=========================================================================
    // Output mapping: bit-reversed order → natural order
    // DIF FFT outputs are in bit-reversed order.
    // Bit-reversal of 4-bit index:
    //   0(0000)→0, 1(0001)→8, 2(0010)→4, 3(0011)→12,
    //   4(0100)→2, 5(0101)→10, 6(0110)→6, 7(0111)→14,
    //   8(1000)→1, ...
    //
    // X[k] = data at bit_reversed(k):
    //   X[0] = re[0],im[0]    (0→0)
    //   X[1] = re[8],im[8]    (1→8)
    //   X[2] = re[4],im[4]    (2→4)
    //   X[3] = re[12],im[12]  (3→12)
    //   X[4] = re[2],im[2]    (4→2)
    //   X[5] = re[10],im[10]  (5→10)
    //   X[6] = re[6],im[6]    (6→6)
    //   X[7] = re[14],im[14]  (7→14)
    //   X[8] = re[1],im[1]    (8→1)
    //=========================================================================
    // Bit-reversal: k → bit_reverse_4bit(k)
    //   0→0, 1→8, 2→4, 3→12, 4→2, 5→10, 6→6,  7→14
    //   8→1, 9→9, 10→5, 11→13, 12→3, 13→11, 14→7, 15→15
    assign X0_re  = re[0];   assign X0_im  = im[0];
    assign X1_re  = re[8];   assign X1_im  = im[8];
    assign X2_re  = re[4];   assign X2_im  = im[4];
    assign X3_re  = re[12];  assign X3_im  = im[12];
    assign X4_re  = re[2];   assign X4_im  = im[2];
    assign X5_re  = re[10];  assign X5_im  = im[10];
    assign X6_re  = re[6];   assign X6_im  = im[6];
    assign X7_re  = re[14];  assign X7_im  = im[14];
    assign X8_re  = re[1];   assign X8_im  = im[1];
    assign X9_re  = re[9];   assign X9_im  = im[9];
    assign X10_re = re[5];   assign X10_im = im[5];
    assign X11_re = re[13];  assign X11_im = im[13];
    assign X12_re = re[3];   assign X12_im = im[3];
    assign X13_re = re[11];  assign X13_im = im[11];
    assign X14_re = re[7];   assign X14_im = im[7];
    assign X15_re = re[15];  assign X15_im = im[15];

endmodule
