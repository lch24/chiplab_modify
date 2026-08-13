`timescale 1ns/1ps

module axi_interconnect_multi_rid_tb;
    // S00 matches the 33 MHz uncore domain; M00 approximates the MIG UI
    // domain.  The clocks are deliberately unrelated in phase and period.
    reg s_clk = 0;
    reg m_clk = 0;
    always #15 s_clk = ~s_clk;
    always #4  m_clk = ~m_clk;

    reg rstn = 0;

    reg  [3:0]  s_arid;
    reg  [31:0] s_araddr;
    reg  [7:0]  s_arlen;
    reg  [2:0]  s_arsize;
    reg  [1:0]  s_arburst;
    reg         s_arvalid;
    wire        s_arready;
    wire [3:0]  s_rid;
    wire [31:0] s_rdata;
    wire [1:0]  s_rresp;
    wire        s_rlast;
    wire        s_rvalid;
    reg         s_rready;

    reg  [3:0]  s_awid;
    reg  [31:0] s_awaddr;
    reg  [7:0]  s_awlen;
    reg  [2:0]  s_awsize;
    reg  [1:0]  s_awburst;
    reg         s_awvalid;
    wire        s_awready;
    reg  [31:0] s_wdata;
    reg  [3:0]  s_wstrb;
    reg         s_wlast;
    reg         s_wvalid;
    wire        s_wready;
    wire [3:0]  s_bid;
    wire [1:0]  s_bresp;
    wire        s_bvalid;
    reg         s_bready;

    wire [7:0]  m_arid;
    wire [31:0] m_araddr;
    wire [7:0]  m_arlen;
    wire [2:0]  m_arsize;
    wire [1:0]  m_arburst;
    wire        m_arvalid;
    reg         m_arready;
    reg  [7:0]  m_rid;
    reg  [31:0] m_rdata;
    reg  [1:0]  m_rresp;
    reg         m_rlast;
    reg         m_rvalid;
    wire        m_rready;

    wire [7:0]  m_awid;
    wire [31:0] m_awaddr;
    wire [7:0]  m_awlen;
    wire [2:0]  m_awsize;
    wire [1:0]  m_awburst;
    wire        m_awvalid;
    reg         m_awready;
    wire [31:0] m_wdata;
    wire [3:0]  m_wstrb;
    wire        m_wlast;
    wire        m_wvalid;
    reg         m_wready;
    reg  [7:0]  m_bid;
    reg  [1:0]  m_bresp;
    reg         m_bvalid;
    wire        m_bready;

    integer request_count = 0;
    integer response_count = 0;
    integer expected_index = 0;
    reg [3:0] expected_id [0:15];
    reg [31:0] expected_data [0:15];
    reg expected_last [0:15];

    axi_interconnect_0 dut (
        .INTERCONNECT_ACLK(m_clk),
        .INTERCONNECT_ARESETN(rstn),

        .S00_AXI_ACLK(s_clk),
        .S00_AXI_AWID(s_awid), .S00_AXI_AWADDR(s_awaddr), .S00_AXI_AWLEN(s_awlen),
        .S00_AXI_AWSIZE(s_awsize), .S00_AXI_AWBURST(s_awburst), .S00_AXI_AWLOCK(1'b0),
        .S00_AXI_AWCACHE(4'b0), .S00_AXI_AWPROT(3'b0), .S00_AXI_AWQOS(4'b0),
        .S00_AXI_AWVALID(s_awvalid), .S00_AXI_AWREADY(s_awready),
        .S00_AXI_WDATA(s_wdata), .S00_AXI_WSTRB(s_wstrb),
        .S00_AXI_WLAST(s_wlast), .S00_AXI_WVALID(s_wvalid), .S00_AXI_WREADY(s_wready),
        .S00_AXI_BID(s_bid), .S00_AXI_BRESP(s_bresp), .S00_AXI_BVALID(s_bvalid),
        .S00_AXI_BREADY(s_bready),
        .S00_AXI_ARID(s_arid), .S00_AXI_ARADDR(s_araddr), .S00_AXI_ARLEN(s_arlen),
        .S00_AXI_ARSIZE(s_arsize), .S00_AXI_ARBURST(s_arburst), .S00_AXI_ARLOCK(1'b0),
        .S00_AXI_ARCACHE(4'b0), .S00_AXI_ARPROT(3'b0), .S00_AXI_ARQOS(4'b0),
        .S00_AXI_ARVALID(s_arvalid), .S00_AXI_ARREADY(s_arready),
        .S00_AXI_RID(s_rid), .S00_AXI_RDATA(s_rdata), .S00_AXI_RRESP(s_rresp),
        .S00_AXI_RLAST(s_rlast), .S00_AXI_RVALID(s_rvalid), .S00_AXI_RREADY(s_rready),

        .S01_AXI_ACLK(s_clk),
        .S01_AXI_AWID(4'b0), .S01_AXI_AWADDR(32'b0), .S01_AXI_AWLEN(8'b0),
        .S01_AXI_AWSIZE(3'b0), .S01_AXI_AWBURST(2'b01), .S01_AXI_AWLOCK(1'b0),
        .S01_AXI_AWCACHE(4'b0), .S01_AXI_AWPROT(3'b0), .S01_AXI_AWQOS(4'b0),
        .S01_AXI_AWVALID(1'b0), .S01_AXI_WDATA(32'b0), .S01_AXI_WSTRB(4'b0),
        .S01_AXI_WLAST(1'b0), .S01_AXI_WVALID(1'b0), .S01_AXI_BREADY(1'b1),
        .S01_AXI_ARID(4'b0), .S01_AXI_ARADDR(32'b0), .S01_AXI_ARLEN(8'b0),
        .S01_AXI_ARSIZE(3'b0), .S01_AXI_ARBURST(2'b01), .S01_AXI_ARLOCK(1'b0),
        .S01_AXI_ARCACHE(4'b0), .S01_AXI_ARPROT(3'b0), .S01_AXI_ARQOS(4'b0),
        .S01_AXI_ARVALID(1'b0), .S01_AXI_RREADY(1'b1),

        .S02_AXI_ACLK(s_clk),
        .S02_AXI_AWID(4'b0), .S02_AXI_AWADDR(32'b0), .S02_AXI_AWLEN(8'b0),
        .S02_AXI_AWSIZE(3'b0), .S02_AXI_AWBURST(2'b01), .S02_AXI_AWLOCK(1'b0),
        .S02_AXI_AWCACHE(4'b0), .S02_AXI_AWPROT(3'b0), .S02_AXI_AWQOS(4'b0),
        .S02_AXI_AWVALID(1'b0), .S02_AXI_WDATA(64'b0), .S02_AXI_WSTRB(8'b0),
        .S02_AXI_WLAST(1'b0), .S02_AXI_WVALID(1'b0), .S02_AXI_BREADY(1'b1),
        .S02_AXI_ARID(4'b0), .S02_AXI_ARADDR(32'b0), .S02_AXI_ARLEN(8'b0),
        .S02_AXI_ARSIZE(3'b0), .S02_AXI_ARBURST(2'b01), .S02_AXI_ARLOCK(1'b0),
        .S02_AXI_ARCACHE(4'b0), .S02_AXI_ARPROT(3'b0), .S02_AXI_ARQOS(4'b0),
        .S02_AXI_ARVALID(1'b0), .S02_AXI_RREADY(1'b1),

        .M00_AXI_ACLK(m_clk),
        .M00_AXI_AWID(m_awid), .M00_AXI_AWADDR(m_awaddr), .M00_AXI_AWLEN(m_awlen),
        .M00_AXI_AWSIZE(m_awsize), .M00_AXI_AWBURST(m_awburst),
        .M00_AXI_AWVALID(m_awvalid), .M00_AXI_AWREADY(m_awready),
        .M00_AXI_WDATA(m_wdata), .M00_AXI_WSTRB(m_wstrb), .M00_AXI_WLAST(m_wlast),
        .M00_AXI_WVALID(m_wvalid), .M00_AXI_WREADY(m_wready),
        .M00_AXI_BID(m_bid), .M00_AXI_BRESP(m_bresp), .M00_AXI_BVALID(m_bvalid),
        .M00_AXI_BREADY(m_bready),
        .M00_AXI_ARID(m_arid), .M00_AXI_ARADDR(m_araddr), .M00_AXI_ARLEN(m_arlen),
        .M00_AXI_ARSIZE(m_arsize), .M00_AXI_ARBURST(m_arburst),
        .M00_AXI_ARVALID(m_arvalid), .M00_AXI_ARREADY(m_arready),
        .M00_AXI_RID(m_rid), .M00_AXI_RDATA(m_rdata), .M00_AXI_RRESP(m_rresp),
        .M00_AXI_RLAST(m_rlast), .M00_AXI_RVALID(m_rvalid), .M00_AXI_RREADY(m_rready)
    );

    task automatic send_ar(input [3:0] id, input [31:0] addr);
        begin
            @(negedge s_clk);
            s_arid = id;
            s_araddr = addr;
            s_arvalid = 1;
            while (!s_arready) @(negedge s_clk);
            @(negedge s_clk);
            s_arvalid = 0;
        end
    endtask

    task automatic send_write(input [3:0] id, input [31:0] addr);
        integer beat;
        begin
            @(negedge s_clk);
            s_awid = id; s_awaddr = addr; s_awvalid = 1;
            while (!s_awready) @(negedge s_clk);
            @(negedge s_clk);
            s_awvalid = 0;
            for (beat = 0; beat < 4; beat = beat + 1) begin
                s_wdata = 32'hcafe_0000 + beat;
                s_wlast = (beat == 3);
                s_wvalid = 1;
                while (!s_wready) @(negedge s_clk);
                @(negedge s_clk);
                s_wvalid = 0;
            end
        end
    endtask

    task automatic complete_m_write(input [3:0] id, input [31:0] addr);
        integer beat;
        begin
            while (!(m_awvalid && m_awready)) @(posedge m_clk);
            if (m_awid !== {4'b0, id} || m_awaddr !== addr ||
                m_awlen !== 8'd3 || m_awsize !== 3'd2)
                $fatal(1, "AW payload mismatch");
            for (beat = 0; beat < 4; beat = beat + 1) begin
                while (!(m_wvalid && m_wready)) @(posedge m_clk);
                if (m_wdata !== (32'hcafe_0000 + beat) || m_wstrb !== 4'hf ||
                    m_wlast !== (beat == 3))
                    $fatal(1, "W payload mismatch at beat %0d", beat);
                @(negedge m_clk);
            end
            m_bid = {4'b0, id}; m_bresp = 0; m_bvalid = 1;
            while (!m_bready) @(negedge m_clk);
            @(negedge m_clk);
            m_bvalid = 0;
        end
    endtask

    task automatic expect_m_ar(input [3:0] id, input [31:0] addr);
        begin
            while (!(m_arvalid && m_arready)) @(posedge m_clk);
            if (m_arid !== {4'b0, id})
                $fatal(1, "ARID mismatch: expected %0d got 0x%02x", id, m_arid);
            if (m_araddr !== addr || m_arlen !== 8'd3 || m_arsize !== 3'd2)
                $fatal(1, "AR payload mismatch for id %0d", id);
            request_count = request_count + 1;
            // Do not count the same level-held VALID again before the source
            // observes the handshake and advances to the next request.
            @(negedge m_clk);
            while (m_arvalid) @(negedge m_clk);
        end
    endtask

    task automatic send_r(input [3:0] id, input [31:0] data, input last);
        begin
            @(negedge m_clk);
            m_rid = {4'b0, id};
            m_rdata = data;
            m_rresp = 0;
            m_rlast = last;
            m_rvalid = 1;
            while (!m_rready) @(negedge m_clk);
            expected_id[response_count] = id;
            expected_data[response_count] = data;
            expected_last[response_count] = last;
            response_count = response_count + 1;
            @(negedge m_clk);
            m_rvalid = 0;
        end
    endtask

    always @(posedge s_clk) begin
        if (rstn && s_rvalid && s_rready) begin
            if (expected_index >= response_count)
                $fatal(1, "unexpected upstream R beat");
            if (s_rid !== expected_id[expected_index] ||
                s_rdata !== expected_data[expected_index] ||
                s_rlast !== expected_last[expected_index] || s_rresp !== 0)
                $fatal(1, "R mismatch at %0d: id=%0d data=%08x last=%0d",
                    expected_index, s_rid, s_rdata, s_rlast);
            expected_index = expected_index + 1;
        end
    end

    initial begin
        s_arid = 0; s_araddr = 0; s_arlen = 3; s_arsize = 2;
        s_arburst = 1; s_arvalid = 0; s_rready = 1;
        m_arready = 1; m_rid = 0; m_rdata = 0; m_rresp = 0;
        m_rlast = 0; m_rvalid = 0;
        s_awid = 0; s_awaddr = 0; s_awlen = 3; s_awsize = 2;
        s_awburst = 1; s_awvalid = 0;
        s_wdata = 0; s_wstrb = 4'hf; s_wlast = 0; s_wvalid = 0;
        s_bready = 1;
        m_awready = 1; m_wready = 1; m_bid = 0; m_bresp = 0; m_bvalid = 0;

        repeat (5) @(posedge m_clk);
        rstn = 1;
        repeat (5) @(posedge s_clk);

        fork
            begin
                send_ar(1, 32'h0000_1000);
                send_ar(2, 32'h0000_2000);
                send_ar(3, 32'h0000_3000);
                send_ar(4, 32'h0000_4000);
            end
            begin
                expect_m_ar(1, 32'h0000_1000);
                expect_m_ar(2, 32'h0000_2000);
                expect_m_ar(3, 32'h0000_3000);
                expect_m_ar(4, 32'h0000_4000);
            end
            begin
                send_write(1, 32'h0000_8000);
            end
            begin
                complete_m_write(1, 32'h0000_8000);
            end
        join

        while (!s_bvalid) @(posedge s_clk);
        if (s_bid !== 4'd1 || s_bresp !== 0)
            $fatal(1, "upstream B mismatch");

        // Four bursts are returned beat-interleaved and in a completion order
        // different from their AR acceptance order.
        send_r(4, 32'h4000_0000, 0);
        send_r(2, 32'h2000_0000, 0);
        send_r(1, 32'h1000_0000, 0);
        send_r(3, 32'h3000_0000, 0);
        send_r(4, 32'h4000_0001, 0);
        send_r(2, 32'h2000_0001, 0);
        send_r(1, 32'h1000_0001, 0);
        send_r(3, 32'h3000_0001, 0);

        // Exercise upstream backpressure while the response FIFO is occupied.
        s_rready = 0;
        send_r(4, 32'h4000_0002, 0);
        send_r(4, 32'h4000_0003, 1);
        send_r(2, 32'h2000_0002, 0);
        repeat (4) @(posedge s_clk);
        s_rready = 1;

        send_r(1, 32'h1000_0002, 0);
        send_r(3, 32'h3000_0002, 0);
        send_r(2, 32'h2000_0003, 1);
        send_r(3, 32'h3000_0003, 1);
        send_r(1, 32'h1000_0003, 1);

        while (expected_index != response_count) @(posedge s_clk);
        repeat (5) @(posedge s_clk);
        if (request_count != 4 || response_count != 16 || expected_index != 16)
            $fatal(1, "count mismatch AR=%0d injectedR=%0d receivedR=%0d",
                request_count, response_count, expected_index);
        $display("PASS: axi_interconnect_0 preserved four interleaved RIDs and RLAST under backpressure");
        $finish;
    end

    initial begin
        repeat (3000) @(posedge m_clk);
        $fatal(1, "timeout");
    end
endmodule
