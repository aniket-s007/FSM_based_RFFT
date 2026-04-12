module clock_divider (
    input  wire clk,
    input  wire rst_n,
    output wire pixel_tick
);
    reg [1:0] counter_value;

    always @(posedge clk) begin
        if (!rst_n) counter_value <= 2'd0;
        else        counter_value <= counter_value + 2'd1;
        // 2-bit counter naturally wraps: 0→1→2→3→0 = 4 states ✅
    end

    assign pixel_tick = (counter_value == 2'd3); // one pulse every 4 clocks
endmodule