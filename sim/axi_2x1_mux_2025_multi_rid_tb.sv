`timescale 1ns/1ps

module axi_2x1_mux_2025_multi_rid_tb;
    reg clk = 0, resetn = 0;
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

    integer ar_count = 0, r_count = 0, cycles = 0;
    reg [3:0] expected_rid [0:15];
    reg expected_last [0:15];

    always #5 clk = ~clk;

    axi_2x1_mux_2025_wrapper dut (
        .aclk(clk), .aresetn(resetn),
        .s0_arid(s_arid), .s0_araddr(s_araddr), .s0_arlen(4'd3),
        .s0_arsize(3'd2), .s0_arburst(2'b01), .s0_arlock(2'b0),
        .s0_arcache(4'b0), .s0_arprot(3'b0), .s0_arvalid(s_arvalid),
        .s0_arready(s_arready), .s0_rid(s_rid), .s0_rdata(s_rdata),
        .s0_rresp(s_rresp), .s0_rlast(s_rlast), .s0_rvalid(s_rvalid),
        .s0_rready(s_rready),
        .s1_arid(4'b0), .s1_araddr(32'b0), .s1_arlen(4'b0),
        .s1_arsize(3'b0), .s1_arburst(2'b0), .s1_arlock(2'b0),
        .s1_arcache(4'b0), .s1_arprot(3'b0), .s1_arvalid(1'b0),
        .s1_rready(1'b1),
        .m_arid(m_arid), .m_araddr(m_araddr), .m_arlen(m_arlen),
        .m_arvalid(m_arvalid), .m_arready(m_arready),
        .m_rid(m_rid), .m_rdata(m_rdata), .m_rresp(m_rresp),
        .m_rlast(m_rlast), .m_rvalid(m_rvalid), .m_rready(m_rready)
    );

    task automatic send_ar(input [3:0] id, input [31:0] addr);
        begin
            @(negedge clk);
            s_arid = id; s_araddr = addr; s_arvalid = 1;
            @(posedge clk);
            while (!s_arready) @(posedge clk);
            @(negedge clk); s_arvalid = 0;
        end
    endtask

    task automatic send_r(input [3:0] id, input [31:0] data, input last);
        begin
            @(negedge clk);
            m_rid = id; m_rdata = data; m_rlast = last; m_rvalid = 1;
            @(posedge clk);
            while (!m_rready) @(posedge clk);
            @(negedge clk); m_rvalid = 0;
        end
    endtask

    always @(posedge clk) begin
        cycles <= cycles + 1;
        s_rready <= cycles % 4 != 1;
        if (resetn && m_arvalid && m_arready) begin
            if (m_arid !== s_arid || m_araddr !== s_araddr || m_arlen !== 4'd3)
                $fatal(1, "downstream AR mismatch id=%0d/%0d", m_arid, s_arid);
            ar_count <= ar_count + 1;
        end
        if (resetn && s_rvalid && s_rready) begin
            if (s_rid !== expected_rid[r_count] || s_rlast !== expected_last[r_count])
                $fatal(1, "upstream R mismatch beat=%0d id=%0d last=%0d",
                       r_count, s_rid, s_rlast);
            r_count <= r_count + 1;
        end
        if (cycles > 2000)
            $fatal(1, "timeout ar=%0d r=%0d", ar_count, r_count);
    end

    integer beat, id;
    initial begin
        for (beat = 0; beat < 4; beat = beat + 1)
            for (id = 4; id >= 1; id = id - 1) begin
                expected_rid[beat * 4 + 4-id] = id[3:0];
                expected_last[beat * 4 + 4-id] = beat == 3;
            end
        repeat (8) @(negedge clk);
        resetn = 1;
        repeat (4) @(negedge clk);
        send_ar(1, 32'h1000); send_ar(2, 32'h2000);
        send_ar(3, 32'h3000); send_ar(4, 32'h4000);
        if (ar_count != 4) $fatal(1, "crossbar accepted only %0d AR", ar_count);
        for (beat = 0; beat < 4; beat = beat + 1)
            for (id = 4; id >= 1; id = id - 1)
                send_r(id[3:0], {24'b0, beat[3:0], id[3:0]}, beat == 3);
        wait (r_count == 16);
        $display("PASS: axi_2x1_mux_2025 preserved four interleaved RIDs under backpressure");
        $finish;
    end
endmodule
