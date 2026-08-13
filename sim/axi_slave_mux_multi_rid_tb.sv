`timescale 1ns/1ps

module axi_slave_mux_multi_rid_tb;
    reg         clk = 1'b0;
    reg         resetn = 1'b0;
    reg  [3:0]  axi_arid = 0;
    reg  [31:0] axi_araddr = 0;
    reg  [3:0]  axi_arlen = 0;
    reg  [2:0]  axi_arsize = 3'd2;
    reg  [1:0]  axi_arburst = 2'b01;
    reg  [1:0]  axi_arlock = 0;
    reg  [3:0]  axi_arcache = 0;
    reg  [2:0]  axi_arprot = 0;
    reg         axi_arvalid = 0;
    wire        axi_arready;

    wire [3:0]  axi_rid;
    wire [31:0] axi_rdata;
    wire [1:0]  axi_rresp;
    wire        axi_rlast;
    wire        axi_rvalid;
    reg         axi_rready = 0;

    wire [3:0]  s0_arid;
    wire [31:0] s0_araddr;
    wire [3:0]  s0_arlen;
    wire        s0_arvalid;
    reg         s0_arready = 1'b1;
    reg  [3:0]  s0_rid = 0;
    reg  [31:0] s0_rdata = 0;
    reg  [1:0]  s0_rresp = 0;
    reg         s0_rlast = 0;
    reg         s0_rvalid = 0;
    wire        s0_rready;

    integer accepted_ar = 0;
    integer accepted_r = 0;
    integer cycles = 0;
    reg [3:0] expected_rid [0:15];
    reg       expected_last [0:15];

    always #5 clk = ~clk;

    axi_slave_mux dut (
        .spi_boot(1'b0),
        .axi_s_aclk(clk),
        .axi_s_aresetn(resetn),

        .axi_s_awid(4'b0), .axi_s_awaddr(32'b0), .axi_s_awlen(4'b0),
        .axi_s_awsize(3'b0), .axi_s_awburst(2'b0), .axi_s_awlock(2'b0),
        .axi_s_awcache(4'b0), .axi_s_awprot(3'b0), .axi_s_awvalid(1'b0),
        .axi_s_wid(4'b0), .axi_s_wdata(32'b0), .axi_s_wstrb(4'b0),
        .axi_s_wlast(1'b0), .axi_s_wvalid(1'b0), .axi_s_bready(1'b1),

        .axi_s_arid(axi_arid), .axi_s_araddr(axi_araddr),
        .axi_s_arlen(axi_arlen), .axi_s_arsize(axi_arsize),
        .axi_s_arburst(axi_arburst), .axi_s_arlock(axi_arlock),
        .axi_s_arcache(axi_arcache), .axi_s_arprot(axi_arprot),
        .axi_s_arvalid(axi_arvalid), .axi_s_arready(axi_arready),
        .axi_s_rid(axi_rid), .axi_s_rdata(axi_rdata),
        .axi_s_rresp(axi_rresp), .axi_s_rlast(axi_rlast),
        .axi_s_rvalid(axi_rvalid), .axi_s_rready(axi_rready),

        .s0_awready(1'b0), .s0_wready(1'b0), .s0_bid(4'b0),
        .s0_bresp(2'b0), .s0_bvalid(1'b0),
        .s0_arid(s0_arid), .s0_araddr(s0_araddr), .s0_arlen(s0_arlen),
        .s0_arvalid(s0_arvalid), .s0_arready(s0_arready),
        .s0_rid(s0_rid), .s0_rdata(s0_rdata), .s0_rresp(s0_rresp),
        .s0_rlast(s0_rlast), .s0_rvalid(s0_rvalid), .s0_rready(s0_rready),

        .s1_awready(1'b0), .s1_wready(1'b0), .s1_bid(4'b0), .s1_bresp(2'b0),
        .s1_bvalid(1'b0), .s1_arready(1'b0), .s1_rid(4'b0),
        .s1_rdata(32'b0), .s1_rresp(2'b0), .s1_rlast(1'b0), .s1_rvalid(1'b0),
        .s2_awready(1'b0), .s2_wready(1'b0), .s2_bid(4'b0), .s2_bresp(2'b0),
        .s2_bvalid(1'b0), .s2_arready(1'b0), .s2_rid(4'b0),
        .s2_rdata(32'b0), .s2_rresp(2'b0), .s2_rlast(1'b0), .s2_rvalid(1'b0),
        .s3_awready(1'b0), .s3_wready(1'b0), .s3_bid(4'b0), .s3_bresp(2'b0),
        .s3_bvalid(1'b0), .s3_arready(1'b0), .s3_rid(4'b0),
        .s3_rdata(32'b0), .s3_rresp(2'b0), .s3_rlast(1'b0), .s3_rvalid(1'b0),
        .s4_awready(1'b0), .s4_wready(1'b0), .s4_bid(4'b0), .s4_bresp(2'b0),
        .s4_bvalid(1'b0), .s4_arready(1'b0), .s4_rid(4'b0),
        .s4_rdata(32'b0), .s4_rresp(2'b0), .s4_rlast(1'b0), .s4_rvalid(1'b0),
        .s5_awready(1'b0), .s5_wready(1'b0), .s5_bid(4'b0), .s5_bresp(2'b0),
        .s5_bvalid(1'b0), .s5_arready(1'b0), .s5_rid(4'b0),
        .s5_rdata(32'b0), .s5_rresp(2'b0), .s5_rlast(1'b0), .s5_rvalid(1'b0),
        .s6_awready(1'b0), .s6_wready(1'b0), .s6_bid(4'b0), .s6_bresp(2'b0),
        .s6_bvalid(1'b0), .s6_arready(1'b0), .s6_rid(4'b0),
        .s6_rdata(32'b0), .s6_rresp(2'b0), .s6_rlast(1'b0), .s6_rvalid(1'b0)
    );

    task automatic send_ar(input [3:0] id, input [31:0] addr);
        begin
            @(negedge clk);
            axi_arid = id;
            axi_araddr = addr;
            axi_arlen = 4'd3;
            axi_arvalid = 1'b1;
            @(posedge clk);
            while (!axi_arready) @(posedge clk);
            @(negedge clk);
            axi_arvalid = 1'b0;
        end
    endtask

    task automatic send_r(input [3:0] id, input [31:0] data, input last);
        begin
            @(negedge clk);
            s0_rid = id;
            s0_rdata = data;
            s0_rlast = last;
            s0_rvalid = 1'b1;
            @(posedge clk);
            while (!s0_rready) @(posedge clk);
            @(negedge clk);
            s0_rvalid = 1'b0;
        end
    endtask

    always @(posedge clk) begin
        cycles <= cycles + 1;
        axi_rready <= (cycles % 4 != 1);
        if (resetn && axi_arvalid && axi_arready) begin
            if (!s0_arvalid || s0_arid != axi_arid || s0_araddr != axi_araddr)
                $fatal(1, "AR payload/routing mismatch");
            accepted_ar <= accepted_ar + 1;
        end
        if (resetn && axi_rvalid && axi_rready) begin
            if (axi_rid !== expected_rid[accepted_r] ||
                axi_rlast !== expected_last[accepted_r])
                $fatal(1, "R mismatch beat=%0d rid=%0d last=%0d", accepted_r,
                       axi_rid, axi_rlast);
            accepted_r <= accepted_r + 1;
        end
        if (cycles > 1000)
            $fatal(1, "timeout accepted_ar=%0d accepted_r=%0d arid=%0d araddr=%08x hit=%02x arvalid=%0d arready=%0d s0_arready=%0d rvalid=%0d rready=%0d s0_rvalid=%0d s0_rready=%0d active=%04x",
                   accepted_ar, accepted_r, axi_arid, axi_araddr, dut.rd_addr_hit,
                   axi_arvalid, axi_arready, s0_arready, axi_rvalid,
                   axi_rready, s0_rvalid, s0_rready, dut.rd_id_active);
    end

    integer round;
    integer id;
    initial begin
        // Four bursts are deliberately interleaved beat-by-beat in reverse RID order.
        for (round = 0; round < 4; round = round + 1)
            for (id = 4; id >= 1; id = id - 1) begin
                expected_rid[round * 4 + (4-id)] = id[3:0];
                expected_last[round * 4 + (4-id)] = (round == 3);
            end

        repeat (4) @(negedge clk);
        resetn = 1'b1;
        send_ar(4'd1, 32'h0000_1000);
        send_ar(4'd2, 32'h0000_2000);
        send_ar(4'd3, 32'h0000_3000);
        send_ar(4'd4, 32'h0000_4000);

        for (round = 0; round < 4; round = round + 1)
            for (id = 4; id >= 1; id = id - 1)
                send_r(id[3:0], {24'h0, round[3:0], id[3:0]}, round == 3);

        wait (accepted_r == 16);
        if (accepted_ar != 4) $fatal(1, "expected four accepted AR, got %0d", accepted_ar);
        $display("PASS: axi_slave_mux preserved interleaved RIDs and RLAST under backpressure");
        $finish;
    end
endmodule
