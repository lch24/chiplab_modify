`timescale 1ps/1ps

// Drop-in replacement for the MIG example_design/example_top.  Keeping the
// original sim_tb_top means this test uses AMD's DDR3 pin-level model and PCB
// delay wiring, while replacing the ideal traffic generator with the actual
// project-local axi_interconnect_0.
module example_top #(
    parameter SIMULATION = "TRUE",
    parameter BEGIN_ADDRESS = 32'h0,
    parameter END_ADDRESS = 32'h00000fff,
    parameter PRBS_EADDR_MASK_POS = 32'hff000000,
    parameter COL_WIDTH = 10,
    parameter CS_WIDTH = 1,
    parameter DM_WIDTH = 2,
    parameter DQ_WIDTH = 16,
    parameter DQS_CNT_WIDTH = 1,
    parameter DRAM_WIDTH = 8,
    parameter ECC_TEST = "OFF",
    parameter RANKS = 1,
    parameter ROW_WIDTH = 13,
    parameter ADDR_WIDTH = 27,
    parameter BURST_MODE = "8",
    parameter TCQ = 100,
    parameter DRAM_TYPE = "DDR3",
    parameter nCK_PER_CLK = 4,
    parameter C_S_AXI_ID_WIDTH = 8,
    parameter C_S_AXI_ADDR_WIDTH = 27,
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_SUPPORTS_NARROW_BURST = 0,
    parameter DEBUG_PORT = "OFF",
    parameter RST_ACT_LOW = 1
) (
    inout  [15:0] ddr3_dq,
    inout  [1:0]  ddr3_dqs_n,
    inout  [1:0]  ddr3_dqs_p,
    output [12:0] ddr3_addr,
    output [2:0]  ddr3_ba,
    output        ddr3_ras_n,
    output        ddr3_cas_n,
    output        ddr3_we_n,
    output        ddr3_reset_n,
    output [0:0]  ddr3_ck_p,
    output [0:0]  ddr3_ck_n,
    output [0:0]  ddr3_cke,
    output [1:0]  ddr3_dm,
    output [0:0]  ddr3_odt,
    input         sys_clk_i,
    input         clk_ref_i,
    output reg    tg_compare_error,
    output        init_calib_complete,
    input         sys_rst
);
    wire ui_clk, ui_rst, mmcm_locked;
    reg axi_resetn = 1'b0;
    reg s_clk = 1'b0;
    always #15000 s_clk = ~s_clk; // Actual S00/uncore clock is about 33 MHz.
    always @(posedge ui_clk) axi_resetn <= ~ui_rst;

    reg [3:0] s_awid = 0, s_arid = 0;
    reg [31:0] s_awaddr = 0, s_araddr = 0, s_wdata = 0;
    reg [7:0] s_awlen = 3, s_arlen = 3;
    reg [2:0] s_awsize = 2, s_arsize = 2;
    reg [1:0] s_awburst = 1, s_arburst = 1;
    reg s_awvalid = 0, s_wvalid = 0, s_wlast = 0, s_arvalid = 0;
    reg [3:0] s_wstrb = 4'hf;
    reg s_bready = 1, s_rready = 0;
    wire s_awready, s_wready, s_bvalid, s_arready, s_rvalid, s_rlast;
    wire [3:0] s_bid, s_rid;
    wire [1:0] s_bresp, s_rresp;
    wire [31:0] s_rdata;

    wire [7:0] m_awid, m_arid, m_bid, m_rid;
    wire [31:0] m_awaddr, m_araddr, m_wdata, m_rdata;
    wire [7:0] m_awlen, m_arlen;
    wire [2:0] m_awsize, m_arsize;
    wire [1:0] m_awburst, m_arburst, m_bresp, m_rresp;
    wire m_awlock, m_arlock;
    wire [3:0] m_awcache, m_arcache, m_awqos, m_arqos, m_wstrb;
    wire [2:0] m_awprot, m_arprot;
    wire m_awvalid, m_awready, m_wlast, m_wvalid, m_wready;
    wire m_bvalid, m_bready, m_arvalid, m_arready, m_rlast, m_rvalid, m_rready;

    axi_interconnect_0 u_interconnect (
        .INTERCONNECT_ACLK(ui_clk), .INTERCONNECT_ARESETN(axi_resetn),
        .S00_AXI_ACLK(s_clk),
        .S00_AXI_AWID(s_awid), .S00_AXI_AWADDR(s_awaddr), .S00_AXI_AWLEN(s_awlen),
        .S00_AXI_AWSIZE(s_awsize), .S00_AXI_AWBURST(s_awburst), .S00_AXI_AWLOCK(1'b0),
        .S00_AXI_AWCACHE(4'b0), .S00_AXI_AWPROT(3'b0), .S00_AXI_AWQOS(4'b0),
        .S00_AXI_AWVALID(s_awvalid), .S00_AXI_AWREADY(s_awready),
        .S00_AXI_WDATA(s_wdata), .S00_AXI_WSTRB(s_wstrb), .S00_AXI_WLAST(s_wlast),
        .S00_AXI_WVALID(s_wvalid), .S00_AXI_WREADY(s_wready),
        .S00_AXI_BID(s_bid), .S00_AXI_BRESP(s_bresp), .S00_AXI_BVALID(s_bvalid),
        .S00_AXI_BREADY(s_bready),
        .S00_AXI_ARID(s_arid), .S00_AXI_ARADDR(s_araddr), .S00_AXI_ARLEN(s_arlen),
        .S00_AXI_ARSIZE(s_arsize), .S00_AXI_ARBURST(s_arburst), .S00_AXI_ARLOCK(1'b0),
        .S00_AXI_ARCACHE(4'b0), .S00_AXI_ARPROT(3'b0), .S00_AXI_ARQOS(4'b0),
        .S00_AXI_ARVALID(s_arvalid), .S00_AXI_ARREADY(s_arready),
        .S00_AXI_RID(s_rid), .S00_AXI_RDATA(s_rdata), .S00_AXI_RRESP(s_rresp),
        .S00_AXI_RLAST(s_rlast), .S00_AXI_RVALID(s_rvalid), .S00_AXI_RREADY(s_rready),

        .S01_AXI_ACLK(s_clk),
        .S01_AXI_AWID(0), .S01_AXI_AWADDR(0), .S01_AXI_AWLEN(0), .S01_AXI_AWSIZE(0),
        .S01_AXI_AWBURST(1), .S01_AXI_AWLOCK(0), .S01_AXI_AWCACHE(0),
        .S01_AXI_AWPROT(0), .S01_AXI_AWQOS(0), .S01_AXI_AWVALID(0),
        .S01_AXI_WDATA(0), .S01_AXI_WSTRB(0), .S01_AXI_WLAST(0), .S01_AXI_WVALID(0),
        .S01_AXI_BREADY(1), .S01_AXI_ARID(0), .S01_AXI_ARADDR(0), .S01_AXI_ARLEN(0),
        .S01_AXI_ARSIZE(0), .S01_AXI_ARBURST(1), .S01_AXI_ARLOCK(0),
        .S01_AXI_ARCACHE(0), .S01_AXI_ARPROT(0), .S01_AXI_ARQOS(0),
        .S01_AXI_ARVALID(0), .S01_AXI_RREADY(1),
        .S02_AXI_ACLK(s_clk),
        .S02_AXI_AWID(0), .S02_AXI_AWADDR(0), .S02_AXI_AWLEN(0), .S02_AXI_AWSIZE(0),
        .S02_AXI_AWBURST(1), .S02_AXI_AWLOCK(0), .S02_AXI_AWCACHE(0),
        .S02_AXI_AWPROT(0), .S02_AXI_AWQOS(0), .S02_AXI_AWVALID(0),
        .S02_AXI_WDATA(0), .S02_AXI_WSTRB(0), .S02_AXI_WLAST(0), .S02_AXI_WVALID(0),
        .S02_AXI_BREADY(1), .S02_AXI_ARID(0), .S02_AXI_ARADDR(0), .S02_AXI_ARLEN(0),
        .S02_AXI_ARSIZE(0), .S02_AXI_ARBURST(1), .S02_AXI_ARLOCK(0),
        .S02_AXI_ARCACHE(0), .S02_AXI_ARPROT(0), .S02_AXI_ARQOS(0),
        .S02_AXI_ARVALID(0), .S02_AXI_RREADY(1),

        .M00_AXI_ACLK(ui_clk),
        .M00_AXI_AWID(m_awid), .M00_AXI_AWADDR(m_awaddr), .M00_AXI_AWLEN(m_awlen),
        .M00_AXI_AWSIZE(m_awsize), .M00_AXI_AWBURST(m_awburst), .M00_AXI_AWLOCK(m_awlock),
        .M00_AXI_AWCACHE(m_awcache), .M00_AXI_AWPROT(m_awprot), .M00_AXI_AWQOS(m_awqos),
        .M00_AXI_AWVALID(m_awvalid), .M00_AXI_AWREADY(m_awready),
        .M00_AXI_WDATA(m_wdata), .M00_AXI_WSTRB(m_wstrb), .M00_AXI_WLAST(m_wlast),
        .M00_AXI_WVALID(m_wvalid), .M00_AXI_WREADY(m_wready),
        .M00_AXI_BID(m_bid), .M00_AXI_BRESP(m_bresp), .M00_AXI_BVALID(m_bvalid),
        .M00_AXI_BREADY(m_bready),
        .M00_AXI_ARID(m_arid), .M00_AXI_ARADDR(m_araddr), .M00_AXI_ARLEN(m_arlen),
        .M00_AXI_ARSIZE(m_arsize), .M00_AXI_ARBURST(m_arburst), .M00_AXI_ARLOCK(m_arlock),
        .M00_AXI_ARCACHE(m_arcache), .M00_AXI_ARPROT(m_arprot), .M00_AXI_ARQOS(m_arqos),
        .M00_AXI_ARVALID(m_arvalid), .M00_AXI_ARREADY(m_arready),
        .M00_AXI_RID(m_rid), .M00_AXI_RDATA(m_rdata), .M00_AXI_RRESP(m_rresp),
        .M00_AXI_RLAST(m_rlast), .M00_AXI_RVALID(m_rvalid), .M00_AXI_RREADY(m_rready)
    );

    mig_axi_32 u_mig (
        .ddr3_dq(ddr3_dq), .ddr3_dqs_n(ddr3_dqs_n), .ddr3_dqs_p(ddr3_dqs_p),
        .ddr3_addr(ddr3_addr), .ddr3_ba(ddr3_ba), .ddr3_ras_n(ddr3_ras_n),
        .ddr3_cas_n(ddr3_cas_n), .ddr3_we_n(ddr3_we_n), .ddr3_reset_n(ddr3_reset_n),
        .ddr3_ck_p(ddr3_ck_p), .ddr3_ck_n(ddr3_ck_n), .ddr3_cke(ddr3_cke),
        .ddr3_dm(ddr3_dm), .ddr3_odt(ddr3_odt), .sys_clk_i(sys_clk_i),
        .clk_ref_i(clk_ref_i), .ui_clk(ui_clk), .ui_clk_sync_rst(ui_rst),
        .mmcm_locked(mmcm_locked), .aresetn(axi_resetn), .app_sr_req(1'b0),
        .app_ref_req(1'b0), .app_zq_req(1'b0),
        .s_axi_awid(m_awid), .s_axi_awaddr(m_awaddr[26:0]), .s_axi_awlen(m_awlen),
        .s_axi_awsize(m_awsize), .s_axi_awburst(m_awburst), .s_axi_awlock(m_awlock),
        .s_axi_awcache(m_awcache), .s_axi_awprot(m_awprot), .s_axi_awqos(m_awqos),
        .s_axi_awvalid(m_awvalid), .s_axi_awready(m_awready),
        .s_axi_wdata(m_wdata), .s_axi_wstrb(m_wstrb), .s_axi_wlast(m_wlast),
        .s_axi_wvalid(m_wvalid), .s_axi_wready(m_wready),
        .s_axi_bid(m_bid), .s_axi_bresp(m_bresp), .s_axi_bvalid(m_bvalid),
        .s_axi_bready(m_bready),
        .s_axi_arid(m_arid), .s_axi_araddr(m_araddr[26:0]), .s_axi_arlen(m_arlen),
        .s_axi_arsize(m_arsize), .s_axi_arburst(m_arburst), .s_axi_arlock(m_arlock),
        .s_axi_arcache(m_arcache), .s_axi_arprot(m_arprot), .s_axi_arqos(m_arqos),
        .s_axi_arvalid(m_arvalid), .s_axi_arready(m_arready),
        .s_axi_rid(m_rid), .s_axi_rdata(m_rdata), .s_axi_rresp(m_rresp),
        .s_axi_rlast(m_rlast), .s_axi_rvalid(m_rvalid), .s_axi_rready(m_rready),
        .init_calib_complete(init_calib_complete), .sys_rst(sys_rst)
    );

    integer beat_count [0:15];
    integer responses = 0, mig_outstanding = 0, max_mig_outstanding = 0;
    reg [15:0] seen_mig_ids = 0;
    integer cycle = 0;

    function [31:0] pattern;
        input integer id;
        input integer beat;
        pattern = 32'ha5000000 | (id << 8) | beat;
    endfunction

    task send_write;
        input [3:0] id;
        input [31:0] addr;
        integer beat;
        begin
            @(negedge s_clk); s_awid = id; s_awaddr = addr; s_awvalid = 1;
            while (!s_awready) @(negedge s_clk);
            @(negedge s_clk); s_awvalid = 0;
            for (beat = 0; beat < 4; beat = beat + 1) begin
                s_wdata = pattern(id, beat); s_wlast = (beat == 3); s_wvalid = 1;
                while (!s_wready) @(negedge s_clk);
                @(negedge s_clk); s_wvalid = 0;
            end
            while (!s_bvalid) @(negedge s_clk);
            if (s_bid !== id || s_bresp !== 0) begin
                tg_compare_error = 1;
                $error("write response mismatch id=%0d bid=%0d resp=%0d", id, s_bid, s_bresp);
            end
            @(negedge s_clk);
        end
    endtask

    task send_read;
        input [3:0] id;
        input [31:0] addr;
        begin
            @(negedge s_clk); s_arid = id; s_araddr = addr; s_arvalid = 1;
            while (!s_arready) @(negedge s_clk);
            @(negedge s_clk); s_arvalid = 0;
        end
    endtask

    always @(posedge ui_clk) begin
        if (axi_resetn) begin
            case ({m_arvalid && m_arready, m_rvalid && m_rready && m_rlast})
                2'b10: mig_outstanding <= mig_outstanding + 1;
                2'b01: mig_outstanding <= mig_outstanding - 1;
                default: mig_outstanding <= mig_outstanding;
            endcase
            if (m_arvalid && m_arready) seen_mig_ids[m_arid[3:0]] <= 1'b1;
            if (mig_outstanding > max_mig_outstanding)
                max_mig_outstanding <= mig_outstanding;
        end
    end

    always @(posedge s_clk) begin
        cycle <= cycle + 1;
        if (axi_resetn) s_rready <= ((cycle % 7) != 2) && ((cycle % 11) != 5);
        if (axi_resetn && s_rvalid && s_rready) begin
            if (s_rresp !== 0 || s_rid < 1 || s_rid > 6 ||
                s_rdata !== pattern(s_rid, beat_count[s_rid]) ||
                s_rlast !== (beat_count[s_rid] == 3)) begin
                tg_compare_error <= 1;
                $error("read mismatch rid=%0d beat=%0d data=%08x last=%0d resp=%0d",
                       s_rid, beat_count[s_rid], s_rdata, s_rlast, s_rresp);
            end
            if (s_rlast) beat_count[s_rid] <= 0;
            else beat_count[s_rid] <= beat_count[s_rid] + 1;
            responses <= responses + 1;
        end
    end

    integer id;
    initial begin
        tg_compare_error = 0;
        for (id = 0; id < 16; id = id + 1) beat_count[id] = 0;
        wait (init_calib_complete && axi_resetn);
        repeat (8) @(negedge s_clk);
        $display("JOINT: calibration complete; initializing six DDR bursts");
        for (id = 1; id <= 6; id = id + 1)
            send_write(id[3:0], 32'h00001000 + id * 32'h100);
        $display("JOINT: issuing six distinct RIDs plus a concurrent write burst");
        fork
            begin
                for (id = 1; id <= 6; id = id + 1)
                    send_read(id[3:0], 32'h00001000 + id * 32'h100);
            end
            begin
                send_write(4'd7, 32'h00002000);
            end
        join
        wait (responses == 24);
        repeat (10) @(posedge ui_clk);
        if (max_mig_outstanding < 2 || (seen_mig_ids & 16'h007e) != 16'h007e) begin
            tg_compare_error = 1;
            $error("stress not achieved: max outstanding=%0d seen IDs=%04x",
                   max_mig_outstanding, seen_mig_ids);
        end else begin
            $display("JOINT PASS: 6 RIDs, 24 beats, max MIG outstanding=%0d, IDs=%04x",
                     max_mig_outstanding, seen_mig_ids);
        end
        $finish;
    end
endmodule
