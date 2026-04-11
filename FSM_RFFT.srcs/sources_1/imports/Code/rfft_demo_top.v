`timescale 1ns / 1ps

//=============================================================================
// Module: rfft_demo_top
//
// Top-level module for the RFFT course project demo.
//
// Architecture:
//   [Test Signal ROM] → [N=16 RFFT] → [Magnitude] → [9 Bar Heights]
//                ↑                                          ↓
//          sig_sel (switches)                         [VGA Display]
//
// Operation:
//   1. On trigger (button press or auto), loads 16 samples from ROM
//   2. Computes N=16 FFT (~60 clock cycles)
//   3. Computes magnitude of each of the 9 frequency bins
//   4. Stores magnitudes in output registers
//   5. VGA module reads bar heights continuously
//   6. Can re-trigger to update (or auto-repeat for continuous display)
//
// Inputs:
//   clk        - System clock (100 MHz on Nexys 4)
//   rst_n      - Active-low reset (active-low pushbutton)
//   sig_sel    - 2-bit ROM preset selector (connect to SW[1:0])
//   sig_source - 0 = ROM preset (existing behaviour),
//                1 = live LFSR noise
//   trigger    - Start computation (connect to BTNC or auto-pulse)
//
// Outputs:
//   bar_height[0..8] - 16-bit magnitude for each frequency bin
//                      Your teammate's VGA module reads these
//   computing  - High while FFT is in progress
//   valid      - High when bar heights are ready to display
//
// For FPGA:
//   - Uses ~16 registers + a few DSP48 slices for multiplication
//   - Fits trivially on Artix-7 (xc7a100t has 240 DSP slices)
//   - Runs at 100 MHz easily
//=============================================================================

module rfft_demo_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [1:0]  sig_sel,     // Connect to SW[1:0]
    input  wire        sig_source,  // 0=ROM, 1=LFSR (connect to SW2)
    input  wire        trigger,     // Connect to BTNC (active high)
    output wire        computing,   // LED indicator
    output wire        valid,       // LED indicator
    // 9 bar heights for VGA (unsigned, higher = taller bar)
    output reg  [15:0] bar_height_0,
    output reg  [15:0] bar_height_1,
    output reg  [15:0] bar_height_2,
    output reg  [15:0] bar_height_3,
    output reg  [15:0] bar_height_4,
    output reg  [15:0] bar_height_5,
    output reg  [15:0] bar_height_6,
    output reg  [15:0] bar_height_7,
    output reg  [15:0] bar_height_8
);

    //=========================================================================
    // State machine for loading and computing
    //=========================================================================
    localparam S_IDLE    = 2'd0;
    localparam S_LOADING = 2'd1;
    localparam S_COMPUTING = 2'd2;
    localparam S_DONE    = 2'd3;

    reg [1:0] state;
    reg [3:0] load_counter;

    // Edge detection for trigger button
    reg trigger_prev;
    wire trigger_rising = trigger & ~trigger_prev;
    always @(posedge clk) begin
        if (!rst_n) trigger_prev <= 0;
        else        trigger_prev <= trigger;
    end

    //=========================================================================
    // Test signal ROM
    //=========================================================================
    wire signed [15:0] rom_data;
    test_signal_rom rom (
        .sig_sel (sig_sel),
        .addr    (load_counter),
        .data    (rom_data)
    );

    //=========================================================================
    // LFSR pseudo-random source
    //
    // The LFSR advances once per clock cycle while we are loading samples,
    // i.e. exactly 16 steps per capture. It is seeded only on reset, so
    // successive triggers walk further along the LFSR sequence and produce
    // different (but deterministic) windows — useful for visually
    // confirming "this is random" on the board LEDs.
    //=========================================================================
    wire signed [15:0] lfsr_data;
    wire               lfsr_advance = (state == S_LOADING);

    lfsr16 lfsr_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .advance  (lfsr_advance),
        .data_out (lfsr_data)
    );

    // Mux between ROM and LFSR for the FFT input stream.
    wire signed [15:0] source_data = sig_source ? lfsr_data : rom_data;

    //=========================================================================
    // RFFT core
    //=========================================================================
    reg  signed [15:0] rfft_data_in;
    reg                rfft_sample_valid;
    reg                rfft_start;
    wire               rfft_done;
    wire               rfft_busy;

    wire signed [15:0] X0_re, X0_im, X1_re, X1_im, X2_re, X2_im;
    wire signed [15:0] X3_re, X3_im, X4_re, X4_im, X5_re, X5_im;
    wire signed [15:0] X6_re, X6_im, X7_re, X7_im, X8_re, X8_im;

    rfft_n16_simple rfft_core (
        .clk(clk), .rst_n(rst_n),
        .data_in(rfft_data_in),
        .sample_valid(rfft_sample_valid),
        .start(rfft_start),
        .done(rfft_done), .busy(rfft_busy),
        .X0_re(X0_re), .X0_im(X0_im), .X1_re(X1_re), .X1_im(X1_im),
        .X2_re(X2_re), .X2_im(X2_im), .X3_re(X3_re), .X3_im(X3_im),
        .X4_re(X4_re), .X4_im(X4_im), .X5_re(X5_re), .X5_im(X5_im),
        .X6_re(X6_re), .X6_im(X6_im), .X7_re(X7_re), .X7_im(X7_im),
        .X8_re(X8_re), .X8_im(X8_im)
    );

    //=========================================================================
    // Magnitude computation (9 instances, one per bin)
    //=========================================================================
    wire [15:0] mag0, mag1, mag2, mag3, mag4, mag5, mag6, mag7, mag8;

    magnitude_approx mag_inst0 (.re(X0_re), .im(X0_im), .mag(mag0));
    magnitude_approx mag_inst1 (.re(X1_re), .im(X1_im), .mag(mag1));
    magnitude_approx mag_inst2 (.re(X2_re), .im(X2_im), .mag(mag2));
    magnitude_approx mag_inst3 (.re(X3_re), .im(X3_im), .mag(mag3));
    magnitude_approx mag_inst4 (.re(X4_re), .im(X4_im), .mag(mag4));
    magnitude_approx mag_inst5 (.re(X5_re), .im(X5_im), .mag(mag5));
    magnitude_approx mag_inst6 (.re(X6_re), .im(X6_im), .mag(mag6));
    magnitude_approx mag_inst7 (.re(X7_re), .im(X7_im), .mag(mag7));
    magnitude_approx mag_inst8 (.re(X8_re), .im(X8_im), .mag(mag8));

    //=========================================================================
    // Control FSM
    //=========================================================================
    assign computing = (state == S_LOADING || state == S_COMPUTING);
    assign valid     = (state == S_DONE);

    always @(posedge clk) begin
        if (!rst_n) begin
            state             <= S_IDLE;
            load_counter      <= 0;
            rfft_data_in      <= 0;
            rfft_sample_valid <= 0;
            rfft_start        <= 0;
            bar_height_0      <= 0;
            bar_height_1      <= 0;
            bar_height_2      <= 0;
            bar_height_3      <= 0;
            bar_height_4      <= 0;
            bar_height_5      <= 0;
            bar_height_6      <= 0;
            bar_height_7      <= 0;
            bar_height_8      <= 0;
        end else begin
            rfft_sample_valid <= 0;
            rfft_start        <= 0;

            case (state)
                S_IDLE: begin
                    if (trigger_rising) begin
                        state        <= S_LOADING;
                        load_counter <= 0;
                    end
                end

                S_LOADING: begin
                    rfft_data_in      <= source_data;
                    rfft_sample_valid <= 1;
                    load_counter      <= load_counter + 1;
                    if (load_counter == 4'd15) begin
                        state <= S_COMPUTING;
                    end
                end

                S_COMPUTING: begin
                    if (rfft_done) begin
                        // Latch magnitudes
                        bar_height_0 <= mag0;
                        bar_height_1 <= mag1;
                        bar_height_2 <= mag2;
                        bar_height_3 <= mag3;
                        bar_height_4 <= mag4;
                        bar_height_5 <= mag5;
                        bar_height_6 <= mag6;
                        bar_height_7 <= mag7;
                        bar_height_8 <= mag8;
                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    // Stay here showing results until user triggers again
                    if (trigger_rising) begin
                        rfft_start   <= 1;  // Reset RFFT core (it goes S_DONE→S_IDLE)
                        state        <= S_LOADING;  // Go directly to loading new data
                        load_counter <= 0;
                    end
                end
            endcase
        end
    end

endmodule
