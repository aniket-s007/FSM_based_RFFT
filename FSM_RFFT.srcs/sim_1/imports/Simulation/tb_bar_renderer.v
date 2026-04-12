`timescale 1ns / 1ps

module tb_bar_renderer;

    reg  [9:0]  h_count, v_count;
    reg         video_active;
    reg  [15:0] bh [0:8];
    wire [3:0]  vga_r, vga_g, vga_b;

    bar_renderer uut (
        .h_count(h_count), .v_count(v_count),
        .video_active(video_active),
        .bar_height_0(bh[0]), .bar_height_1(bh[1]),
        .bar_height_2(bh[2]), .bar_height_3(bh[3]),
        .bar_height_4(bh[4]), .bar_height_5(bh[5]),
        .bar_height_6(bh[6]), .bar_height_7(bh[7]),
        .bar_height_8(bh[8]),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b)
    );

    integer i, errors;

    task check_pixel;
        input [9:0] h, v;
        input [3:0] exp_r, exp_g, exp_b;
        input [80*8-1:0] label;
        begin
            h_count = h; v_count = v; video_active = 1;
            #10;
            if (vga_r !== exp_r || vga_g !== exp_g || vga_b !== exp_b) begin
                $display("  FAIL at h=%0d v=%0d (%0s): got R=%h G=%h B=%h, expected R=%h G=%h B=%h",
                         h, v, label, vga_r, vga_g, vga_b, exp_r, exp_g, exp_b);
                errors = errors + 1;
            end else begin
                $display("  OK   at h=%0d v=%0d (%0s): R=%h G=%h B=%h",
                         h, v, label, vga_r, vga_g, vga_b);
            end
        end
    endtask

    initial begin
        $display("=== Bar Renderer Testbench ===");
        errors = 0;

        // Set bar heights: bar 0 = DC (small), bar 2 = tall, rest medium/small
        bh[0] = 16'd3200;   // 3200 >> 6 = 50 pixels
        bh[1] = 16'd6400;   // 100 pixels
        bh[2] = 16'd12800;  // 200 pixels
        bh[3] = 16'd0;      // 0 pixels (empty)
        bh[4] = 16'd9600;   // 150 pixels
        bh[5] = 16'd1600;   // 25 pixels
        bh[6] = 16'd3200;   // 50 pixels
        bh[7] = 16'd800;    // 12 pixels
        bh[8] = 16'd400;    // 6 pixels

        $display("\n--- Bar height pixel mapping ---");
        for (i = 0; i < 9; i = i + 1)
            $display("  Bar %0d: raw=%0d, pixel_height=%0d", i, bh[i], bh[i] >> 6);

        // Bar layout: LEFT_MARGIN=20, BAR_WIDTH=56, GAP=12, STRIDE=68
        // Bar 0: x = 20..75
        // Bar 1: x = 88..143
        // Bar 2: x = 156..211
        // ...

        $display("\n--- Test 1: Blanking region (must be black) ---");
        h_count = 10'd300; v_count = 10'd200; video_active = 0; #10;
        if (vga_r != 0 || vga_g != 0 || vga_b != 0) begin
            $display("  FAIL: non-black during blanking!");
            errors = errors + 1;
        end else
            $display("  OK: black during blanking");

        $display("\n--- Test 2: Background (black) ---");
        // Left margin area
        check_pixel(10'd5, 10'd200, 4'h0, 4'h0, 4'h0, "left margin");
        // Gap between bar 0 and bar 1 (x=76..87)
        check_pixel(10'd80, 10'd200, 4'h0, 4'h0, 4'h0, "gap between bars");

        $display("\n--- Test 3: Baseline strip (dark gray) ---");
        check_pixel(10'd300, 10'd465, 4'h2, 4'h2, 4'h2, "baseline strip");

        $display("\n--- Test 4: Bar 0 (DC bin = blue) ---");
        // Bar 0: x=20..75, height=50px, top_y = 459-50+1 = 410
        // Inside bar at bottom
        check_pixel(10'd40, 10'd450, 4'h2, 4'h4, 4'hF, "bar 0 inside (blue)");
        // Above bar 0 (y < 410)
        check_pixel(10'd40, 10'd400, 4'h0, 4'h0, 4'h0, "above bar 0");

        $display("\n--- Test 5: Bar 2 (frequency bin = green) ---");
        // Bar 2: x=156..211, height=200px, top_y = 459-200+1 = 260
        check_pixel(10'd180, 10'd300, 4'h1, 4'hE, 4'h3, "bar 2 inside (green)");
        // Above bar 2
        check_pixel(10'd180, 10'd250, 4'h0, 4'h0, 4'h0, "above bar 2");

        $display("\n--- Test 6: Bar 3 (empty, height=0) ---");
        // Bar 3: x=224..279, height=0px
        // Even at the very bottom, should be black (no bar to draw)
        check_pixel(10'd250, 10'd459, 4'h0, 4'h0, 4'h0, "bar 3 (empty)");

        $display("\n--- Test 7: Edge cases ---");
        // Very top of display
        check_pixel(10'd300, 10'd0, 4'h0, 4'h0, 4'h0, "top of screen");
        // Bar area just above BAR_TOP (should be black, no bar reaches there)
        check_pixel(10'd40, 10'd39, 4'h0, 4'h0, 4'h0, "above bar area");

        $display("\n--- Test 8: Large bar height (clamping) ---");
        // Test with max bar height to verify clamping
        bh[1] = 16'd65535;  // 65535 >> 6 = 1023, clamped to 420
        #10;
        // Bar 1: x=88..143, should be clamped to 420px
        // top_y = 459 - 420 + 1 = 40 = BAR_TOP
        check_pixel(10'd100, 10'd40, 4'h1, 4'hE, 4'h3, "bar 1 max (at BAR_TOP)");
        check_pixel(10'd100, 10'd39, 4'h0, 4'h0, 4'h0, "bar 1 above BAR_TOP (black)");

        $display("\n=== SUMMARY ===");
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d ERROR(S) FOUND", errors);

        $finish;
    end

endmodule
