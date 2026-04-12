`timescale 1ns / 1ps

//=============================================================================
// Module: horizontal_counter
//
// Counts horizontal pixel positions 0 to 799 (800 total = one VGA line).
// Based on SimplyEmbedded horizontal_counter approach.
//
// When H_Count_Value reaches 799:
//   - Resets to 0 (next line starts)
//   - Pulses enable_V_Counter HIGH for one pixel-tick (triggers vertical count)
//
// Clocked at 100 MHz but gated by pixel_tick (25 MHz enable) so it only
// advances once per pixel-clock — single clock domain maintained.
//
// Interface matches the original vga_sync h_count output (10-bit, 0–799).
//=============================================================================

module horizontal_counter (
    input  wire        clk,             // 100 MHz system clock
    input  wire        rst_n,           // Active-low reset
    input  wire        pixel_tick,      // 25 MHz enable from clock_divider
    output reg  [9:0]  H_Count_Value,   // 0 to 799
    output reg         enable_V_Counter // Pulses high at end of each line
);

    always @(posedge clk) begin
        if (!rst_n) begin
            H_Count_Value   <= 10'd0;
            enable_V_Counter <= 1'b0;
        end
        else if (pixel_tick) begin
            if (H_Count_Value < 10'd799) begin
                H_Count_Value    <= H_Count_Value + 10'd1;
                enable_V_Counter <= 1'b0;   // keep V counter disabled
            end
            else begin
                H_Count_Value    <= 10'd0;  // reset horizontal counter
                enable_V_Counter <= 1'b1;   // trigger vertical counter
            end
        end
        else begin
            // Between pixel_ticks: hold value, clear enable so it's a 1-tick pulse
            enable_V_Counter <= 1'b0;
        end
    end

endmodule
