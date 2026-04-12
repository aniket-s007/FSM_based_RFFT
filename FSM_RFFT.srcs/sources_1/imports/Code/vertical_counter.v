`timescale 1ns / 1ps

//=============================================================================
// Module: vertical_counter
//
// Counts vertical line positions 0 to 524 (525 total = one VGA frame).
// Based on SimplyEmbedded vertical_counter approach.
//
// Only advances when enable_V_Counter is HIGH (pulsed by horizontal_counter
// at the end of each horizontal line). This ensures V_Count_Value increments
// exactly once per complete horizontal line — 525 times per frame.
//
// Clocked at 100 MHz; enable_V_Counter acts as the gate (set by h counter
// which is itself gated by pixel_tick), so single clock domain is preserved.
//
// Interface matches the original vga_sync v_count output (10-bit, 0–524).
//=============================================================================

module vertical_counter (
    input  wire        clk,            // 100 MHz system clock
    input  wire        rst_n,          // Active-low reset
    input  wire        enable_V_Counter, // Pulse from horizontal_counter (end of line)
    output reg  [9:0]  V_Count_Value   // 0 to 524
);

    always @(posedge clk) begin
        if (!rst_n) begin
            V_Count_Value <= 10'd0;
        end
        else if (enable_V_Counter == 1'b1) begin
            // keep counting until 525 lines
            if (V_Count_Value < 10'd524)
                V_Count_Value <= V_Count_Value + 10'd1;
            else
                V_Count_Value <= 10'd0;  // reset vertical counter (new frame)
        end
    end

endmodule
