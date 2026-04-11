`timescale 1ns / 1ps

//=============================================================================
// Module: vga_sync
//
// VGA timing generator for 640×480 @ 60 Hz.
//
// Input: 100 MHz physical oscillator (timing constraint set to 80 MHz).
// Internally generates 25 MHz pixel clock using a clock-enable toggle.
//
// NOTE: The pixel clock divider (clk_div, divide-by-4) uses the physical
// 100 MHz oscillator frequency, giving 100/4 = 25 MHz as intended.
// The 80 MHz timing constraint only affects Vivado's slack analysis,
// not the actual clock frequency seen by this module at runtime.
//
// Timing (industry standard VESA 640×480 @ 60 Hz):
//   Horizontal: 640 visible + 16 FP + 96 sync + 48 BP = 800 total
//   Vertical:   480 visible + 10 FP +  2 sync + 33 BP = 525 total
//   Pixel clock: 25.175 MHz (we use 25 MHz = 100/4, well within tolerance)
//
// Outputs:
//   h_count    - horizontal pixel position (0-799)
//   v_count    - vertical line position (0-524)
//   hsync      - horizontal sync pulse (active low)
//   vsync      - vertical sync pulse (active low)
//   video_active - high when in visible area (h < 640 AND v < 480)
//   pixel_tick - one-cycle pulse at 25 MHz rate (use to gate rendering)
//
// All outputs are registered (no glitches on sync lines).
//=============================================================================

module vga_sync (
    input  wire        clk,       // 100 MHz physical clock (constrained to 80 MHz)
    input  wire        rst_n,     // Active-low reset
    output reg  [9:0]  h_count,   // 0-799
    output reg  [9:0]  v_count,   // 0-524
    output reg         hsync,
    output reg         vsync,
    output reg         video_active,
    output wire        pixel_tick // 25 MHz enable pulse
);

    //=========================================================================
    // Timing parameters
    //=========================================================================
    // Horizontal
    localparam H_VISIBLE  = 10'd640;
    localparam H_FP       = 10'd16;
    localparam H_SYNC     = 10'd96;
    localparam H_BP       = 10'd48;
    localparam H_TOTAL    = 10'd800;  // 640+16+96+48

    // Vertical
    localparam V_VISIBLE  = 10'd480;
    localparam V_FP       = 10'd10;
    localparam V_SYNC     = 10'd2;
    localparam V_BP       = 10'd33;
    localparam V_TOTAL    = 10'd525;  // 480+10+2+33

    // Sync pulse boundaries (inclusive start, exclusive end)
    localparam H_SYNC_START = H_VISIBLE + H_FP;        // 656
    localparam H_SYNC_END   = H_SYNC_START + H_SYNC;   // 752
    localparam V_SYNC_START = V_VISIBLE + V_FP;         // 490
    localparam V_SYNC_END   = V_SYNC_START + V_SYNC;    // 492

    //=========================================================================
    // 25 MHz pixel clock generation from 100 MHz physical oscillator
    //
    // We use a 2-bit counter dividing by 4:
    //   100 MHz / 4 = 25 MHz.
    // pixel_tick is high for one 100 MHz cycle every 4 cycles.
    // All pixel logic is gated on pixel_tick.
    //=========================================================================
    reg [1:0] clk_div;

    always @(posedge clk) begin
        if (!rst_n)
            clk_div <= 2'd0;
        else
            clk_div <= clk_div + 2'd1;
    end

    assign pixel_tick = (clk_div == 2'd3);

    //=========================================================================
    // Horizontal and vertical counters
    //=========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
        end else if (pixel_tick) begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 10'd0;
                if (v_count == V_TOTAL - 1)
                    v_count <= 10'd0;
                else
                    v_count <= v_count + 10'd1;
            end else begin
                h_count <= h_count + 10'd1;
            end
        end
    end

    //=========================================================================
    // Sync signals and video_active (all registered)
    //
    // Registered one pixel_tick after the counter updates.
    // This adds one pixel of latency but guarantees clean sync edges.
    //=========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            hsync        <= 1'b1;  // Inactive (active low)
            vsync        <= 1'b1;
            video_active <= 1'b0;
        end else if (pixel_tick) begin
            // Hsync: active low during sync pulse region
            hsync <= ~(h_count >= H_SYNC_START && h_count < H_SYNC_END);

            // Vsync: active low during sync pulse region
            vsync <= ~(v_count >= V_SYNC_START && v_count < V_SYNC_END);

            // Video active: high only in visible area
            video_active <= (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
        end
    end

endmodule
