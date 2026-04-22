`timescale 1ns / 1ps

//=============================================================================
// Module: lfsr16
//
// 16-bit Fibonacci Linear Feedback Shift Register used as a pseudo-random
// test-signal generator for the RFFT demo. Taps are {16, 14, 13, 11} which
// gives a maximal-length sequence of period 2^16 - 1 = 65535.
//
// Usage:
//   - Hold `rst_n` low to (re-)seed the state to SEED (non-zero).
//   - Pulse `advance` high for one clock to shift the LFSR one step.
//   - `data_out` is the current 16-bit state, re-interpreted as a signed
//     Q1.15 sample. Because the state is uniformly distributed over the
//     non-zero 16-bit space, this looks like broadband noise to the FFT.
//
// Notes:
//   - The LFSR never holds the all-zero state once seeded, so there is no
//     stuck-at-zero failure mode.
//   - Seed is deterministic, so repeated triggers with the same reset
//     history yield the same sequence. This makes regressions easier.
//=============================================================================

module lfsr16 (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               advance,
    output wire signed [15:0] data_out
);

    localparam [15:0] SEED = 16'hACE1;  // Non-zero value (can be any 16-bit value except 0)

    reg [15:0] state;
    
    //  XOR of state[15], state[13], state[12], state[10]
    wire feedback = state[15] ^ state[13] ^ state[12] ^ state[10];  // XOR of bits

    always @(posedge clk) begin
        if (!rst_n)
            state <= SEED;
        else if (advance)   //advances exactly 16 times per capture, stays high until (state == S_LOADING)
            state <= {state[14:0], feedback};   //shift left by 1 pos and insert feedback at LSB
    end

    assign data_out = $signed(state);   // Reinterpret the 16-bit state as a signed Q1.15 value
                                        // as demo top expects a signed value for the signal source
endmodule
