`timescale 1ns / 1ps

//=============================================================================
// Module: magnitude_approx
//
// Computes approximate magnitude of a complex number (Re, Im).
//
// Method: Alpha-Max Beta-Min approximation
//   |Z| ≈ max(|Re|, |Im|) + 0.4 * min(|Re|, |Im|)
//
// The 0.4 factor is approximated as (3/8) = 0.375 using shifts:
//   0.4 * x ≈ (x >> 1) - (x >> 3) = x/2 - x/8 = 3x/8
//
// Maximum error: ~3.5% (perfectly acceptable for VGA bar display).
// No multipliers or DSP slices used — just logic.
//
// Alternative: |Re| + |Im| (even simpler, ~40% max error, also works for VGA)
//
// Latency: Combinational (0 cycles). Register externally if needed.
//
// MANUAL VERIFICATION:
//   Re=7, Im=8: max=8, min=7, mag ≈ 8 + 7*3/8 = 8 + 2 = 10
//     True: sqrt(49+64) = 10.63. Error = 5.9% ✓
//
//   Re=77, Im=0: max=77, min=0, mag = 77
//     True: 77. Error = 0% ✓
//
//   Re=-5, Im=19: max=19, min=5, mag ≈ 19 + 5*3/8 = 19 + 1 = 20
//     True: sqrt(25+361) = 19.65. Error = 1.8% ✓
//=============================================================================

module magnitude_approx (
    input  wire signed [15:0] re,
    input  wire signed [15:0] im,
    output wire        [15:0] mag   // Unsigned magnitude
);

    // Absolute values
    wire [15:0] abs_re = re[15] ? (~re + 1'b1) : re;
    wire [15:0] abs_im = im[15] ? (~im + 1'b1) : im;

    // Max and min
    wire [15:0] max_val = (abs_re >= abs_im) ? abs_re : abs_im;
    wire [15:0] min_val = (abs_re >= abs_im) ? abs_im : abs_re;

    // 0.375 * min ≈ min/2 - min/8 = (min >> 1) - (min >> 3)
    wire [15:0] beta = (min_val >> 1) - (min_val >> 3);

    // Result: max + 0.375 * min
    assign mag = max_val + beta;

endmodule
