`timescale 1ns/1ps

// Read-path regression for the exact modules used by system_run.xpr:
// CPU -> 2x1 crossbar -> async clock converter -> axi_slave_mux
//     -> S00 of the 2025.2 interconnect BD -> behavioral MIG target
//                                  `-----> behavioral APB/UART target
//
// The targets never invent an upstream RID.  The MIG model returns the exact
// 8-bit ID accepted on M00; the scoreboard checks the ID restored at the CPU.
module axi_soc_real_read_chain_tb;
    reg cpu_clk = 0, uncore_clk = 0, mig_clk = 0;
    always #6.667  cpu_clk = ~cpu_clk;       // approximately 75 MHz
    always #15.152 uncore_clk = ~uncore_clk; // approximately 33 MHz
    always #5.000  mig_clk = ~mig_clk;       // representative MIG UI clock

    reg resetn = 0;

    reg  [3:0] cpu_arid = 0;
    reg [31:0] cpu_araddr = 0;
    reg  [3:0] cpu_arlen = 0;
    reg        cpu_arvalid = 0;
    wire       cpu_arready;
    wire [3:0] cpu_rid;
    wire [31:0] cpu_rdata;
    wire [1:0] cpu_rresp;
    wire       cpu_rlast, cpu_rvalid;
    reg        cpu_rready = 0;

    wire [3:0] x_arid, x_arlen;
    wire [31:0] x_araddr;
    wire [2:0] x_arsize;
    wire [1:0] x_arburst, x_arlock;
    wire [3:0] x_arcache;
    wire [2:0] x_arprot;
    wire x_arvalid, x_arready;
    wire [3:0] x_rid;
    wire [31:0] x_rdata;
    wire [1:0] x_rresp;
    wire x_rlast, x_rvalid, x_rready;

    wire [3:0] c_arid, c_arlen;
    wire [31:0] c_araddr;
    wire [2:0] c_arsize;
    wire [1:0] c_arburst, c_arlock;
    wire [3:0] c_arcache;
    wire [2:0] c_arprot;
    wire c_arvalid, c_arready;
    wire [3:0] c_rid;
    wire [31:0] c_rdata;
    wire [1:0] c_rresp;
    wire c_rlast, c_rvalid, c_rready;

    wire [3:0] d_arid, d_arlen;
    wire [31:0] d_araddr;
    wire [2:0] d_arsize;
    wire [1:0] d_arburst, d_arlock;
    wire [3:0] d_arcache;
    wire [2:0] d_arprot;
    wire d_arvalid, d_arready;
    wire [3:0] d_rid;
    wire [31:0] d_rdata;
    wire [1:0] d_rresp;
    wire d_rlast, d_rvalid, d_rready;

    wire [3:0] apb_arid;
    wire [31:0] apb_araddr;
    wire [3:0] apb_arlen;
    wire apb_arvalid, apb_arready;
    reg [3:0] apb_rid = 0;
    reg [31:0] apb_rdata = 0;
    reg [1:0] apb_rresp = 0;
    reg apb_rlast = 0, apb_rvalid = 0;
    wire apb_rready;

    wire [7:0] mig_arid;
    wire [31:0] mig_araddr;
    wire [7:0] mig_arlen;
    wire [2:0] mig_arsize;
    wire [1:0] mig_arburst;
    wire mig_arvalid;
    reg mig_arready = 0;
    reg [7:0] mig_rid = 0;
    reg [31:0] mig_rdata = 0;
    reg [1:0] mig_rresp = 0;
    reg mig_rlast = 0, mig_rvalid = 0;
    wire mig_rready;

    axi_2x1_mux_2025_wrapper u_first_crossbar (
        .aclk(cpu_clk), .aresetn(resetn),
        .s0_arid(cpu_arid), .s0_araddr(cpu_araddr), .s0_arlen(cpu_arlen),
        .s0_arsize(3'd2), .s0_arburst(2'b01), .s0_arlock(2'b0),
        .s0_arcache(4'b0), .s0_arprot(3'b0), .s0_arvalid(cpu_arvalid),
        .s0_arready(cpu_arready), .s0_rid(cpu_rid), .s0_rdata(cpu_rdata),
        .s0_rresp(cpu_rresp), .s0_rlast(cpu_rlast), .s0_rvalid(cpu_rvalid),
        .s0_rready(cpu_rready),
        .s1_arid(4'b0), .s1_araddr(32'b0), .s1_arlen(4'b0),
        .s1_arsize(3'd2), .s1_arburst(2'b01), .s1_arlock(2'b0),
        .s1_arcache(4'b0), .s1_arprot(3'b0), .s1_arvalid(1'b0),
        .s1_rready(1'b1),
        .m_arid(x_arid), .m_araddr(x_araddr), .m_arlen(x_arlen),
        .m_arsize(x_arsize), .m_arburst(x_arburst), .m_arlock(x_arlock),
        .m_arcache(x_arcache), .m_arprot(x_arprot), .m_arvalid(x_arvalid),
        .m_arready(x_arready), .m_rid(x_rid), .m_rdata(x_rdata),
        .m_rresp(x_rresp), .m_rlast(x_rlast), .m_rvalid(x_rvalid),
        .m_rready(x_rready)
    );

    axi_clock_converter_0 u_clock_converter (
        .s_axi_aclk(cpu_clk), .s_axi_aresetn(resetn),
        .s_axi_awid(4'b0), .s_axi_awaddr(32'b0), .s_axi_awlen(4'b0),
        .s_axi_awsize(3'b0), .s_axi_awburst(2'b0), .s_axi_awlock(2'b0),
        .s_axi_awcache(4'b0), .s_axi_awprot(3'b0), .s_axi_awqos(4'b0),
        .s_axi_awvalid(1'b0), .s_axi_wid(4'b0), .s_axi_wdata(32'b0),
        .s_axi_wstrb(4'b0), .s_axi_wlast(1'b0), .s_axi_wvalid(1'b0),
        .s_axi_bready(1'b1),
        .s_axi_arid(x_arid), .s_axi_araddr(x_araddr), .s_axi_arlen(x_arlen),
        .s_axi_arsize(x_arsize), .s_axi_arburst(x_arburst),
        .s_axi_arlock(x_arlock), .s_axi_arcache(x_arcache),
        .s_axi_arprot(x_arprot), .s_axi_arqos(4'b0),
        .s_axi_arvalid(x_arvalid), .s_axi_arready(x_arready),
        .s_axi_rid(x_rid), .s_axi_rdata(x_rdata), .s_axi_rresp(x_rresp),
        .s_axi_rlast(x_rlast), .s_axi_rvalid(x_rvalid), .s_axi_rready(x_rready),
        .m_axi_aclk(uncore_clk), .m_axi_aresetn(resetn),
        .m_axi_awready(1'b0), .m_axi_wready(1'b0), .m_axi_bid(4'b0),
        .m_axi_bresp(2'b0), .m_axi_bvalid(1'b0),
        .m_axi_arid(c_arid), .m_axi_araddr(c_araddr), .m_axi_arlen(c_arlen),
        .m_axi_arsize(c_arsize), .m_axi_arburst(c_arburst),
        .m_axi_arlock(c_arlock), .m_axi_arcache(c_arcache),
        .m_axi_arprot(c_arprot), .m_axi_arvalid(c_arvalid),
        .m_axi_arready(c_arready), .m_axi_rid(c_rid), .m_axi_rdata(c_rdata),
        .m_axi_rresp(c_rresp), .m_axi_rlast(c_rlast), .m_axi_rvalid(c_rvalid),
        .m_axi_rready(c_rready)
    );

    axi_slave_mux u_slave_mux (
        .spi_boot(1'b0), .axi_s_aclk(uncore_clk), .axi_s_aresetn(resetn),
        .axi_s_awid(4'b0), .axi_s_awaddr(32'b0), .axi_s_awlen(4'b0),
        .axi_s_awsize(3'b0), .axi_s_awburst(2'b0), .axi_s_awlock(2'b0),
        .axi_s_awcache(4'b0), .axi_s_awprot(3'b0), .axi_s_awvalid(1'b0),
        .axi_s_wid(4'b0), .axi_s_wdata(32'b0), .axi_s_wstrb(4'b0),
        .axi_s_wlast(1'b0), .axi_s_wvalid(1'b0), .axi_s_bready(1'b1),
        .axi_s_arid(c_arid), .axi_s_araddr(c_araddr), .axi_s_arlen(c_arlen),
        .axi_s_arsize(c_arsize), .axi_s_arburst(c_arburst),
        .axi_s_arlock(c_arlock), .axi_s_arcache(c_arcache),
        .axi_s_arprot(c_arprot), .axi_s_arvalid(c_arvalid),
        .axi_s_arready(c_arready), .axi_s_rid(c_rid), .axi_s_rdata(c_rdata),
        .axi_s_rresp(c_rresp), .axi_s_rlast(c_rlast), .axi_s_rvalid(c_rvalid),
        .axi_s_rready(c_rready),
        .s0_arid(d_arid), .s0_araddr(d_araddr), .s0_arlen(d_arlen),
        .s0_arsize(d_arsize), .s0_arburst(d_arburst), .s0_arlock(d_arlock),
        .s0_arcache(d_arcache), .s0_arprot(d_arprot), .s0_arvalid(d_arvalid),
        .s0_arready(d_arready), .s0_rid(d_rid), .s0_rdata(d_rdata),
        .s0_rresp(d_rresp), .s0_rlast(d_rlast), .s0_rvalid(d_rvalid),
        .s0_rready(d_rready), .s0_awready(1'b0), .s0_wready(1'b0),
        .s0_bid(4'b0), .s0_bresp(2'b0), .s0_bvalid(1'b0),
        .s1_arready(1'b0), .s1_rid(4'b0), .s1_rdata(32'b0),
        .s1_rresp(2'b0), .s1_rlast(1'b0), .s1_rvalid(1'b0),
        .s1_awready(1'b0), .s1_wready(1'b0), .s1_bid(4'b0),
        .s1_bresp(2'b0), .s1_bvalid(1'b0),
        .s2_arid(apb_arid), .s2_araddr(apb_araddr), .s2_arlen(apb_arlen),
        .s2_arvalid(apb_arvalid), .s2_arready(apb_arready),
        .s2_rid(apb_rid), .s2_rdata(apb_rdata), .s2_rresp(apb_rresp),
        .s2_rlast(apb_rlast), .s2_rvalid(apb_rvalid), .s2_rready(apb_rready),
        .s2_awready(1'b0), .s2_wready(1'b0), .s2_bid(4'b0),
        .s2_bresp(2'b0), .s2_bvalid(1'b0),
        .s3_arready(1'b0), .s3_rid(4'b0), .s3_rdata(32'b0),
        .s3_rresp(2'b0), .s3_rlast(1'b0), .s3_rvalid(1'b0),
        .s3_awready(1'b0), .s3_wready(1'b0), .s3_bid(4'b0),
        .s3_bresp(2'b0), .s3_bvalid(1'b0),
        .s4_arready(1'b0), .s4_rid(4'b0), .s4_rdata(32'b0),
        .s4_rresp(2'b0), .s4_rlast(1'b0), .s4_rvalid(1'b0),
        .s4_awready(1'b0), .s4_wready(1'b0), .s4_bid(4'b0),
        .s4_bresp(2'b0), .s4_bvalid(1'b0),
        .s5_arready(1'b0), .s5_rid(4'b0), .s5_rdata(32'b0),
        .s5_rresp(2'b0), .s5_rlast(1'b0), .s5_rvalid(1'b0),
        .s5_awready(1'b0), .s5_wready(1'b0), .s5_bid(4'b0),
        .s5_bresp(2'b0), .s5_bvalid(1'b0),
        .s6_arready(1'b0), .s6_rid(4'b0), .s6_rdata(32'b0),
        .s6_rresp(2'b0), .s6_rlast(1'b0), .s6_rvalid(1'b0),
        .s6_awready(1'b0), .s6_wready(1'b0), .s6_bid(4'b0),
        .s6_bresp(2'b0), .s6_bvalid(1'b0)
    );

    axi_interconnect_0 u_ddr_interconnect (
        .INTERCONNECT_ACLK(mig_clk), .INTERCONNECT_ARESETN(resetn),
        .S00_AXI_ACLK(uncore_clk),
        .S00_AXI_AWID(4'b0), .S00_AXI_AWADDR(32'b0), .S00_AXI_AWLEN(8'b0),
        .S00_AXI_AWSIZE(3'b0), .S00_AXI_AWBURST(2'b0), .S00_AXI_AWLOCK(1'b0),
        .S00_AXI_AWCACHE(4'b0), .S00_AXI_AWPROT(3'b0), .S00_AXI_AWQOS(4'b0),
        .S00_AXI_AWVALID(1'b0), .S00_AXI_WDATA(32'b0), .S00_AXI_WSTRB(4'b0),
        .S00_AXI_WLAST(1'b0), .S00_AXI_WVALID(1'b0), .S00_AXI_BREADY(1'b1),
        .S00_AXI_ARID(d_arid), .S00_AXI_ARADDR(d_araddr),
        .S00_AXI_ARLEN({4'b0,d_arlen}), .S00_AXI_ARSIZE(d_arsize),
        .S00_AXI_ARBURST(d_arburst), .S00_AXI_ARLOCK(d_arlock[0]),
        .S00_AXI_ARCACHE(d_arcache), .S00_AXI_ARPROT(d_arprot),
        .S00_AXI_ARQOS(4'b0), .S00_AXI_ARVALID(d_arvalid),
        .S00_AXI_ARREADY(d_arready), .S00_AXI_RID(d_rid),
        .S00_AXI_RDATA(d_rdata), .S00_AXI_RRESP(d_rresp),
        .S00_AXI_RLAST(d_rlast), .S00_AXI_RVALID(d_rvalid),
        .S00_AXI_RREADY(d_rready),
        .S01_AXI_ACLK(uncore_clk), .S01_AXI_AWID(4'b0),
        .S01_AXI_AWADDR(32'b0), .S01_AXI_AWLEN(8'b0), .S01_AXI_AWSIZE(3'b0),
        .S01_AXI_AWBURST(2'b01), .S01_AXI_AWLOCK(1'b0),
        .S01_AXI_AWCACHE(4'b0), .S01_AXI_AWPROT(3'b0), .S01_AXI_AWQOS(4'b0),
        .S01_AXI_AWVALID(1'b0), .S01_AXI_WDATA(32'b0), .S01_AXI_WSTRB(4'b0),
        .S01_AXI_WLAST(1'b0), .S01_AXI_WVALID(1'b0), .S01_AXI_BREADY(1'b1),
        .S01_AXI_ARID(4'b0), .S01_AXI_ARADDR(32'b0), .S01_AXI_ARLEN(8'b0),
        .S01_AXI_ARSIZE(3'b0), .S01_AXI_ARBURST(2'b01), .S01_AXI_ARLOCK(1'b0),
        .S01_AXI_ARCACHE(4'b0), .S01_AXI_ARPROT(3'b0), .S01_AXI_ARQOS(4'b0),
        .S01_AXI_ARVALID(1'b0), .S01_AXI_RREADY(1'b1),
        .S02_AXI_ACLK(uncore_clk), .S02_AXI_AWID(4'b0),
        .S02_AXI_AWADDR(32'b0), .S02_AXI_AWLEN(8'b0), .S02_AXI_AWSIZE(3'b0),
        .S02_AXI_AWBURST(2'b01), .S02_AXI_AWLOCK(1'b0),
        .S02_AXI_AWCACHE(4'b0), .S02_AXI_AWPROT(3'b0), .S02_AXI_AWQOS(4'b0),
        .S02_AXI_AWVALID(1'b0), .S02_AXI_WDATA(64'b0), .S02_AXI_WSTRB(8'b0),
        .S02_AXI_WLAST(1'b0), .S02_AXI_WVALID(1'b0), .S02_AXI_BREADY(1'b1),
        .S02_AXI_ARID(4'b0), .S02_AXI_ARADDR(32'b0), .S02_AXI_ARLEN(8'b0),
        .S02_AXI_ARSIZE(3'b0), .S02_AXI_ARBURST(2'b01), .S02_AXI_ARLOCK(1'b0),
        .S02_AXI_ARCACHE(4'b0), .S02_AXI_ARPROT(3'b0), .S02_AXI_ARQOS(4'b0),
        .S02_AXI_ARVALID(1'b0), .S02_AXI_RREADY(1'b1),
        .M00_AXI_ACLK(mig_clk), .M00_AXI_ARID(mig_arid),
        .M00_AXI_ARADDR(mig_araddr), .M00_AXI_ARLEN(mig_arlen),
        .M00_AXI_ARSIZE(mig_arsize), .M00_AXI_ARBURST(mig_arburst),
        .M00_AXI_ARVALID(mig_arvalid), .M00_AXI_ARREADY(mig_arready),
        .M00_AXI_RID(mig_rid), .M00_AXI_RDATA(mig_rdata),
        .M00_AXI_RRESP(mig_rresp), .M00_AXI_RLAST(mig_rlast),
        .M00_AXI_RVALID(mig_rvalid), .M00_AXI_RREADY(mig_rready),
        .M00_AXI_AWREADY(1'b0), .M00_AXI_WREADY(1'b0), .M00_AXI_BID(8'b0),
        .M00_AXI_BRESP(2'b0), .M00_AXI_BVALID(1'b0)
    );

    // One request per RID is permitted by axi_slave_mux.  These arrays form
    // both the CPU scoreboard and the behavioral target state.
    reg expected_active [0:15];
    reg [31:0] expected_addr [0:15];
    integer expected_len [0:15];
    integer expected_beat [0:15];
    integer completed = 0, issued = 0;
    integer cpu_cycles = 0, last_progress = 0;
    reg [5:0] rid_seen = 0;
    reg [15:0] lfsr_cpu = 16'h1ace;

    function automatic [31:0] data_for;
        input [3:0] id;
        input [31:0] addr;
        input integer beat;
        // A memory target's data is an address property.  In particular it
        // must not infer the CPU RID from the BD's downstream ID encoding.
        // The unused id argument keeps call sites readable for diagnostics.
        begin data_for = 32'hd600_0000 ^ addr ^ beat[31:0]; end
    endfunction

    always @(posedge cpu_clk) begin
        if (!resetn) begin
            cpu_cycles <= 0; last_progress <= 0;
            lfsr_cpu <= 16'h1ace; cpu_rready <= 0;
        end else begin
            cpu_cycles <= cpu_cycles + 1;
            lfsr_cpu <= {lfsr_cpu[14:0],lfsr_cpu[15]^lfsr_cpu[13]^lfsr_cpu[12]^lfsr_cpu[10]};
            cpu_rready <= lfsr_cpu[0] | lfsr_cpu[3];
            if (cpu_rvalid && cpu_rready) begin
                if (cpu_rid > 5 || !expected_active[cpu_rid])
                    $fatal(1,"unexpected/duplicate CPU RID=%0d data=%08x",cpu_rid,cpu_rdata);
                if (cpu_rresp !== 2'b00)
                    $fatal(1,"RRESP error RID=%0d resp=%0d",cpu_rid,cpu_rresp);
                if (cpu_rdata !== data_for(cpu_rid,expected_addr[cpu_rid],expected_beat[cpu_rid]))
                    $fatal(1,"data mismatch RID=%0d beat=%0d got=%08x expected=%08x",
                        cpu_rid,expected_beat[cpu_rid],cpu_rdata,
                        data_for(cpu_rid,expected_addr[cpu_rid],expected_beat[cpu_rid]));
                if (cpu_rlast !== (expected_beat[cpu_rid] == expected_len[cpu_rid]))
                    $fatal(1,"RLAST mismatch RID=%0d beat=%0d len=%0d",
                        cpu_rid,expected_beat[cpu_rid],expected_len[cpu_rid]);
                last_progress <= cpu_cycles;
                if (cpu_rlast) begin
                    expected_active[cpu_rid] <= 0;
                    completed <= completed + 1;
                    rid_seen[cpu_rid] <= 1;
                end else expected_beat[cpu_rid] <= expected_beat[cpu_rid] + 1;
            end
            if (cpu_cycles-last_progress > 8000)
                $fatal(1,"liveness timeout issued=%0d completed=%0d active=%b mux_active=%h",
                    issued,completed,{expected_active[5],expected_active[4],expected_active[3],
                    expected_active[2],expected_active[1],expected_active[0]},u_slave_mux.rd_id_active);
        end
    end

    task automatic issue_read(input [3:0] id, input [31:0] addr, input [3:0] len);
        begin
            while (expected_active[id]) @(posedge cpu_clk);
            @(negedge cpu_clk);
            expected_active[id] = 1; expected_addr[id] = addr;
            expected_len[id] = len; expected_beat[id] = 0;
            cpu_arid = id; cpu_araddr = addr; cpu_arlen = len; cpu_arvalid = 1;
            @(posedge cpu_clk); while (!cpu_arready) @(posedge cpu_clk);
            @(negedge cpu_clk); cpu_arvalid = 0; issued = issued + 1;
        end
    endtask

    // MIG model: requests sharing a downstream ID are legal and ordered.
    // Queue every AR, then return its exact accepted ID without interpreting
    // it.  This is essential when an interconnect compresses upstream IDs.
    reg [7:0] mig_q_id [0:127];
    reg [31:0] mig_q_addr [0:127];
    integer mig_q_len [0:127];
    integer mig_q_head = 0, mig_q_tail = 0;
    integer mig_beat = 0, mig_delay = 0;
    integer mig_scan, mig_cycles = 0;
    reg [15:0] lfsr_mig = 16'hb175;
    always @(posedge mig_clk) begin
        if (!resetn) begin
            mig_arready <= 0; mig_rvalid <= 0;
            mig_delay <= 0; mig_cycles <= 0; lfsr_mig <= 16'hb175;
            mig_q_head <= 0; mig_q_tail <= 0;
        end else begin
            mig_cycles <= mig_cycles + 1;
            lfsr_mig <= {lfsr_mig[14:0],lfsr_mig[15]^lfsr_mig[14]^lfsr_mig[12]^lfsr_mig[3]};
            mig_arready <= lfsr_mig[0] | lfsr_mig[2];
            if (mig_arvalid && mig_arready) begin
                if (mig_q_tail-mig_q_head >= 120)
                    $fatal(1,"MIG request queue overflow");
                mig_q_id[mig_q_tail[6:0]] <= mig_arid;
                mig_q_addr[mig_q_tail[6:0]] <= mig_araddr;
                mig_q_len[mig_q_tail[6:0]] <= mig_arlen;
                mig_q_tail <= mig_q_tail+1;
            end
            if (mig_rvalid && mig_rready) begin
                if (mig_rlast) begin
                    mig_q_head <= mig_q_head+1;
                    mig_delay <= 2 + lfsr_mig[3:2]; mig_rvalid <= 0;
                end else begin
                    mig_beat <= mig_beat + 1;
                    mig_rdata <= data_for(0,mig_q_addr[mig_q_head[6:0]],mig_beat+1);
                    mig_rlast <= (mig_beat+1 == mig_q_len[mig_q_head[6:0]]);
                end
            end else if (!mig_rvalid) begin
                if (mig_delay != 0) mig_delay <= mig_delay-1;
                else if (mig_q_head != mig_q_tail) begin
                    mig_beat <= 0;
                    mig_rid <= mig_q_id[mig_q_head[6:0]];
                    mig_rdata <= data_for(0,mig_q_addr[mig_q_head[6:0]],0);
                    mig_rlast <= (mig_q_len[mig_q_head[6:0]] == 0);
                    mig_rresp <= 0; mig_rvalid <= 1;
                end
            end
        end
    end

    // UART/APB target deliberately overlaps the long DDR response.
    assign apb_arready = resetn && !apb_rvalid;
    always @(posedge uncore_clk) begin
        if (!resetn) begin apb_rvalid <= 0; apb_rlast <= 0; end
        else begin
            if (apb_arvalid && apb_arready) begin
                if (apb_arid != 5 || apb_arlen != 0)
                    $fatal(1,"MMIO request must be single-beat RID5, got RID=%0d len=%0d",apb_arid,apb_arlen);
                apb_rid <= apb_arid; apb_rdata <= data_for(apb_arid,apb_araddr,0);
                apb_rresp <= 0; apb_rlast <= 1; apb_rvalid <= 1;
            end
            if (apb_rvalid && apb_rready) begin apb_rvalid <= 0; apb_rlast <= 0; end
        end
    end

    integer round, idx;
    reg [3:0] order [0:5];
    initial begin
        order[0]=0; order[1]=5; order[2]=1; order[3]=2; order[4]=3; order[5]=4;
        for (idx=0;idx<16;idx=idx+1) begin
            expected_active[idx]=0; expected_addr[idx]=0;
            expected_len[idx]=0; expected_beat[idx]=0;
        end
        repeat (20) @(posedge mig_clk); resetn = 1;
        repeat (20) @(posedge cpu_clk);
        for (round=0;round<12;round=round+1)
            for (idx=0;idx<6;idx=idx+1)
                if (order[idx] == 5)
                    issue_read(5,32'h1fe0_01e0 + (round<<2),0);
                else
                    issue_read(order[idx],32'h0100_0000 + (round<<16) + (order[idx]<<8),15);
        wait (completed == 72);
        repeat (20) @(posedge cpu_clk);
        if (rid_seen !== 6'b11_1111)
            $fatal(1,"not all CPU RIDs observed: %b",rid_seen);
        $display("PASS: real CPU read chain completed %0d requests/%0d beats; RID0..5, DDR16+MMIO, async clocks and backpressure",completed,12*(5*16+1));
        $finish;
    end

    initial begin
        #20ms;
        $fatal(1,"absolute timeout issued=%0d completed=%0d",issued,completed);
    end
endmodule
