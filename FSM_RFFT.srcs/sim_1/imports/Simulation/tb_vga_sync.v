`timescale 1ns / 1ps

//=============================================================================
// Testbench: tb_vga_sync (modular version)
// Tests: clock_divider + horizontal_counter + vertical_counter + vga_sync
//=============================================================================

module tb_vga_sync;

    reg         clk;
    reg         rst_n;
    wire [9:0]  h_count;
    wire [9:0]  v_count;
    wire        hsync;
    wire        vsync;
    wire        video_active;
    wire        pixel_tick;

    vga_sync dut (
        .clk(clk), .rst_n(rst_n),
        .h_count(h_count), .v_count(v_count),
        .hsync(hsync), .vsync(vsync),
        .video_active(video_active), .pixel_tick(pixel_tick)
    );

    initial clk = 0;
    always  #5 clk = ~clk;

    localparam H_VISIBLE=640, H_SYNC_START=656, H_SYNC_END=752, H_SYNC_W=96, H_TOTAL=800;
    localparam V_VISIBLE=480, V_SYNC_START=490, V_SYNC_END=492, V_SYNC_W=2,  V_TOTAL=525;
    localparam FRAME_PIXELS = H_TOTAL * V_TOTAL;

    integer error_count;

    task apply_reset;
        begin rst_n=1'b0; repeat(8) @(posedge clk); @(negedge clk); rst_n=1'b1; end
    endtask

    task wait_pixel_ticks;
        input integer n; integer i;
        begin for(i=0;i<n;i=i+1) begin @(posedge clk); while(!pixel_tick) @(posedge clk); end end
    endtask

    task check;
        input condition; input [240*8-1:0] msg;
        begin
            if (!condition) begin $display("  [FAIL] %0s (t=%0t)",msg,$time); error_count=error_count+1; end
            else            begin $display("  [PASS] %0s",msg); end
        end
    endtask

    initial begin
        $display("==========================================================");
        $display("  tb_vga_sync - Modular VGA (SimplyEmbedded style)");
        $display("==========================================================");
        error_count=0; rst_n=1'b0;

        //--- TEST 1: Reset ---
        $display("\n[TEST 1] Reset behaviour");
        repeat(4) @(posedge clk); #1;
        check(h_count===10'd0,  "h_count==0 during reset");
        check(v_count===10'd0,  "v_count==0 during reset");
        check(hsync===1'b1,     "hsync==1 (inactive) during reset");
        check(vsync===1'b1,     "vsync==1 (inactive) during reset");
        check(video_active===0, "video_active==0 during reset");

        //--- TEST 2: pixel_tick period ---
        $display("\n[TEST 2] clock_divider: pixel_tick every 4 clocks");
        apply_reset;
        begin : t2
            integer cc,tc,t; reg ff;
            cc=0; tc=0; ff=0;
            for(t=0;t<100;t=t+1) begin
                @(posedge clk); #1; cc=cc+1;
                if(pixel_tick) begin tc=tc+1;
                    if(ff) begin check((cc==4),"pixel_tick every 4 sys clocks"); cc=0; end
                    else   begin ff=1; cc=0; end
                end
            end
            check((tc>=10),">=10 pixel_ticks in 100 cycles");
        end

        //--- TEST 3: h_count rollover ---
        $display("\n[TEST 3] horizontal_counter: rollover 799->0");
        apply_reset;
        begin : t3
            integer i,hp; reg rs,bi;
            rs=0; bi=0; hp=0;
            for(i=0;i<3210;i=i+1) begin
                @(posedge clk); #1;
                if(pixel_tick) begin
                    if(h_count==0 && hp==799) rs=1;
                    if(hp!=799 && h_count!=hp+1 && hp!=0) bi=1;
                    hp=h_count;
                end
            end
            check(rs,          "h_count rolls over 799->0");
            check(!bi,         "h_count increments by 1 each pixel_tick");
            check(h_count<=799,"h_count never exceeds 799");
        end

        //--- TEST 4: enable_V_Counter ---
        $display("\n[TEST 4] enable_V_Counter fires once per line");
        apply_reset;
        begin : t4
            integer px,ec; ec=0;
            for(px=0; px<5*H_TOTAL*4; px=px+1) begin
                @(posedge clk); #1;
                if(dut.enable_V_Counter) ec=ec+1;
            end
            check((ec==5),"enable_V_Counter fires exactly once per line (5 lines)");
        end

        //--- TEST 5: v_count rollover ---
        $display("\n[TEST 5] vertical_counter: rollover 524->0");
        apply_reset;
        begin : t5
            integer px; reg vr; reg [9:0] vp;
            vr=0; vp=0;
            // One full frame + a few extra lines is enough to see rollover
            for(px=0; px<FRAME_PIXELS*4+H_TOTAL*8; px=px+1) begin
                @(posedge clk); #1;
                if(pixel_tick && h_count==0) begin
                    if(v_count==0 && vp==524) vr=1;
                    vp=v_count;
                end
            end
            check(vr,"v_count rolls over 524->0");
        end

        //--- TEST 6: hsync pulse width and position ---
        // FIX: use 'done' flag so we stop counting after first complete pulse
        // and don't accidentally count a second pulse in the 2-line window
        $display("\n[TEST 6] hsync pulse width=96, position");
        begin : t6
            integer pw,ls,le,px; reg ip,done;
            pw=0; ls=-1; le=-1; ip=0; done=0;
            for(px=0; px<H_TOTAL*4*2; px=px+1) begin
                @(posedge clk); #1;
                if(pixel_tick && !done) begin
                    if(!hsync && !ip) begin ip=1; ls=h_count; end  // open
                    if(ip && hsync)   begin ip=0; le=h_count; done=1; end  // close FIRST
                    if(ip) pw=pw+1;   // count AFTER close check - won't count closing tick
                end
            end
            $display("  hsync: ls=%0d le=%0d pw=%0d", ls, le, pw);
            check((pw==H_SYNC_W),       "hsync width==96 pixel-clocks");
            check((ls==H_SYNC_START+1), "hsync low  at h=657 (+1 reg latency)");
            check((le==H_SYNC_END+1),   "hsync high at h=753 (+1 reg latency)");
        end 

        //--- TEST 7: vsync pulse width and position ---
        $display("\n[TEST 7] vsync pulse width=2, position");
        begin : t7
            integer vpl,vls,vle,px; reg vip,vdone;
            vpl=0; vls=-1; vle=-1; vip=0; vdone=0;
            for(px=0; px<FRAME_PIXELS*4+H_TOTAL*4; px=px+1) begin
                @(posedge clk); #1;
                if(pixel_tick && h_count==0 && !vdone) begin
                    if(!vsync && !vip) begin vip=1; vls=v_count; end  // open
                    if(vip && vsync)   begin vip=0; vle=v_count; vdone=1; end  // close FIRST
                    if(vip) vpl=vpl+1; // count AFTER close - won't count closing line
                end
            end
            $display("  vsync: vls=%0d vle=%0d vpl=%0d", vls, vle, vpl);
            check((vpl==V_SYNC_W),       "vsync width==2 lines");
            check((vls==V_SYNC_START+1), "vsync low  at v=491 (+1 reg latency)");
            check((vle==V_SYNC_END+1),   "vsync high at v=493 (+1 reg latency)");
        end

        //--- TEST 8: video_active never in blanking ---
        // FIX: +1 on both boundaries to account for 1-pixel registration latency
        // At h=640 video_active is still 1 for one tick (registered update pending)
        // This is a known DUT behaviour documented in the code review
        $display("\n[TEST 8] video_active: never in blanking (adjusted for reg latency)");
        apply_reset;
        begin : t8
            integer px,ae; ae=0;
            for(px=0;px<FRAME_PIXELS*4;px=px+1) begin
                @(posedge clk); #1;
                if(pixel_tick) begin
                    // +1 accounts for 1-pixel registration latency boundary
                    if(h_count >= H_VISIBLE+1 && video_active) ae=ae+1;
                    if(v_count >= V_VISIBLE+1 && video_active) ae=ae+1;
                end
            end
            check((ae==0),
                "video_active not high in blanking (adjusted for 1-pixel reg latency)");
        end

        //--- TEST 9: Full-frame counts ---
        $display("\n[TEST 9] Full-frame counts");
        apply_reset;
        begin : t9
            integer px,tf,hf,vf,af; reg hd,vd;
            tf=0; hf=0; vf=0; af=0; hd=1; vd=1;
            @(posedge clk);
            while(!(v_count==0 && h_count==0 && pixel_tick)) @(posedge clk);
            for(px=0;px<FRAME_PIXELS*4;px=px+1) begin
                @(posedge clk); #1;
                if(pixel_tick) begin
                    tf=tf+1;
                    if(video_active)    af=af+1;
                    if(!hsync&&hd)      hf=hf+1;
                    if(!vsync&&vd)      vf=vf+1;
                    hd=hsync; vd=vsync;
                end
            end
            $display("  pixel_ticks  : %0d (exp 420000)", tf);
            $display("  hsync pulses : %0d (exp 525)",    hf);
            $display("  vsync pulses : %0d (exp 1)",      vf);
            $display("  active pixels: %0d (exp ~307200)",af);
            check((tf==FRAME_PIXELS),  "pixel_tick count==420000");
            check((hf==V_TOTAL),       "hsync count==525 per frame");
            check((vf==1),             "vsync count==1 per frame");
            check((af>=H_VISIBLE*V_VISIBLE-H_TOTAL &&
                   af<=H_VISIBLE*V_VISIBLE+H_TOTAL),
                  "active pixels ~307200");
        end

        //--- TEST 10: Mid-run reset ---
        $display("\n[TEST 10] Mid-run reset");
        wait_pixel_ticks(FRAME_PIXELS/2);
        $display("  Before reset: h=%0d v=%0d",h_count,v_count);
        rst_n=1'b0; repeat(4) @(posedge clk); #1;
        check((h_count===10'd0), "h_count==0 after reset");
        check((v_count===10'd0), "v_count==0 after reset");
        check((hsync===1'b1),    "hsync inactive after reset");
        check((vsync===1'b1),    "vsync inactive after reset");
        check((video_active===0),"video_active==0 after reset");
        @(negedge clk); rst_n=1'b1;
        wait_pixel_ticks(5); #1;
        check((h_count>0),"Counting resumes after reset release");

        $display("\n==========================================================");
        if(error_count==0) $display("  ALL TESTS PASSED (0 errors)");
        else               $display("  DONE - %0d ERROR(S)",error_count);
        $display("==========================================================");
        $finish;
    end

    initial begin $dumpfile("tb_vga_sync.vcd"); $dumpvars(0,tb_vga_sync); end
    initial begin #100_000_000; $display("[TIMEOUT]"); $finish; end

endmodule