`timescale 1ns/1ps

module axi_clock_converter_multi_rid_tb;
    reg sclk = 0, mclk = 0, sresetn = 0, mresetn = 0;
    reg [3:0] s_arid = 0;
    reg [31:0] s_araddr = 0;
    reg s_arvalid = 0;
    wire s_arready;
    wire [3:0] s_rid;
    wire [31:0] s_rdata;
    wire [1:0] s_rresp;
    wire s_rlast, s_rvalid;
    reg s_rready = 0;
    wire [3:0] m_arid;
    wire [31:0] m_araddr;
    wire [3:0] m_arlen;
    wire m_arvalid;
    reg m_arready = 1;
    reg [3:0] m_rid = 0;
    reg [31:0] m_rdata = 0;
    reg [1:0] m_rresp = 0;
    reg m_rlast = 0, m_rvalid = 0;
    wire m_rready;
    integer s_ar_count = 0, m_ar_count = 0, r_count = 0, cycles = 0;
    reg [3:0] expected_rid [0:15];
    reg expected_last [0:15];

    always #7.5 sclk = ~sclk;
    always #4 mclk = ~mclk;

    axi_clock_converter_0 dut (
        .s_axi_aclk(sclk), .s_axi_aresetn(sresetn),
        .s_axi_awid(0), .s_axi_awaddr(0), .s_axi_awlen(0), .s_axi_awsize(0),
        .s_axi_awburst(0), .s_axi_awlock(0), .s_axi_awcache(0), .s_axi_awprot(0),
        .s_axi_awqos(0), .s_axi_awvalid(0), .s_axi_wid(0), .s_axi_wdata(0),
        .s_axi_wstrb(0), .s_axi_wlast(0), .s_axi_wvalid(0), .s_axi_bready(1),
        .s_axi_arid(s_arid), .s_axi_araddr(s_araddr), .s_axi_arlen(4'd3),
        .s_axi_arsize(3'd2), .s_axi_arburst(2'b01), .s_axi_arlock(0),
        .s_axi_arcache(0), .s_axi_arprot(0), .s_axi_arqos(0),
        .s_axi_arvalid(s_arvalid), .s_axi_arready(s_arready),
        .s_axi_rid(s_rid), .s_axi_rdata(s_rdata), .s_axi_rresp(s_rresp),
        .s_axi_rlast(s_rlast), .s_axi_rvalid(s_rvalid), .s_axi_rready(s_rready),
        .m_axi_aclk(mclk), .m_axi_aresetn(mresetn),
        .m_axi_awready(0), .m_axi_wready(0), .m_axi_bid(0), .m_axi_bresp(0),
        .m_axi_bvalid(0), .m_axi_arid(m_arid), .m_axi_araddr(m_araddr),
        .m_axi_arlen(m_arlen), .m_axi_arvalid(m_arvalid), .m_axi_arready(m_arready),
        .m_axi_rid(m_rid), .m_axi_rdata(m_rdata), .m_axi_rresp(m_rresp),
        .m_axi_rlast(m_rlast), .m_axi_rvalid(m_rvalid), .m_axi_rready(m_rready)
    );

    task automatic send_ar(input [3:0] id, input [31:0] addr);
        begin
            @(negedge sclk); s_arid = id; s_araddr = addr; s_arvalid = 1;
            @(posedge sclk); while (!s_arready) @(posedge sclk);
            @(negedge sclk); s_arvalid = 0;
        end
    endtask

    task automatic send_r(input [3:0] id, input [31:0] data, input last);
        begin
            @(negedge mclk); m_rid = id; m_rdata = data; m_rlast = last; m_rvalid = 1;
            @(posedge mclk); while (!m_rready) @(posedge mclk);
            @(negedge mclk); m_rvalid = 0;
        end
    endtask

    always @(posedge sclk) begin
        cycles <= cycles + 1;
        s_rready <= cycles % 5 != 2;
        if (sresetn && s_arvalid && s_arready) s_ar_count <= s_ar_count + 1;
        if (sresetn && s_rvalid && s_rready) begin
            if (s_rid !== expected_rid[r_count] || s_rlast !== expected_last[r_count])
                $fatal(1, "S R mismatch beat=%0d id=%0d last=%0d", r_count, s_rid, s_rlast);
            r_count <= r_count + 1;
        end
        if (cycles > 3000) $fatal(1, "timeout sar=%0d mar=%0d r=%0d", s_ar_count, m_ar_count, r_count);
    end

    always @(posedge mclk)
        if (mresetn && m_arvalid && m_arready) m_ar_count <= m_ar_count + 1;

    integer beat, id;
    initial begin
        for (beat = 0; beat < 4; beat = beat + 1)
            for (id = 4; id >= 1; id = id - 1) begin
                expected_rid[beat * 4 + 4-id] = id[3:0];
                expected_last[beat * 4 + 4-id] = beat == 3;
            end
        repeat (8) @(negedge mclk); mresetn = 1;
        repeat (4) @(negedge sclk); sresetn = 1;
        repeat (8) @(negedge sclk);
        send_ar(1, 32'h1000); send_ar(2, 32'h2000);
        send_ar(3, 32'h3000); send_ar(4, 32'h4000);
        wait (m_ar_count == 4);
        for (beat = 0; beat < 4; beat = beat + 1)
            for (id = 4; id >= 1; id = id - 1)
                send_r(id[3:0], {24'b0, beat[3:0], id[3:0]}, beat == 3);
        wait (r_count == 16);
        $display("PASS: axi_clock_converter_0 preserved four interleaved RIDs across async clocks");
        $finish;
    end
endmodule
