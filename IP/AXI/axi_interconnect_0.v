/*
 * Project-local replacement for the old Xilinx axi_interconnect_0 IP.
 *
 * Matches the generated 2023.2 axi_interconnect_0 port list used by
 * soc_demo/loongson/soc_top.v:
 *   S00: AXI4 32-bit read/write, aclk domain
 *   S01: AXI4 32-bit read/write, aclk domain
 *   S02: AXI4 64-bit read/write, aclk domain
 *   M00: AXI4 32-bit read/write, MIG c1_clk0 domain
 *
 * Supported subset is deliberately narrow but matches the project traffic:
 * INCR bursts, one active write, multiple active reads on M00, FIFO-backed CDC,
 * and per-ID 64/32 read conversion for S02.
 */
module axi_interconnect_0 (
    input         INTERCONNECT_ACLK,
    input         INTERCONNECT_ARESETN,

    output        S00_AXI_ARESET_OUT_N,
    input         S00_AXI_ACLK,
    input  [3:0]  S00_AXI_AWID,
    input  [31:0] S00_AXI_AWADDR,
    input  [7:0]  S00_AXI_AWLEN,
    input  [2:0]  S00_AXI_AWSIZE,
    input  [1:0]  S00_AXI_AWBURST,
    input         S00_AXI_AWLOCK,
    input  [3:0]  S00_AXI_AWCACHE,
    input  [2:0]  S00_AXI_AWPROT,
    input  [3:0]  S00_AXI_AWQOS,
    input         S00_AXI_AWVALID,
    output        S00_AXI_AWREADY,
    input  [31:0] S00_AXI_WDATA,
    input  [3:0]  S00_AXI_WSTRB,
    input         S00_AXI_WLAST,
    input         S00_AXI_WVALID,
    output        S00_AXI_WREADY,
    output [3:0]  S00_AXI_BID,
    output [1:0]  S00_AXI_BRESP,
    output        S00_AXI_BVALID,
    input         S00_AXI_BREADY,
    input  [3:0]  S00_AXI_ARID,
    input  [31:0] S00_AXI_ARADDR,
    input  [7:0]  S00_AXI_ARLEN,
    input  [2:0]  S00_AXI_ARSIZE,
    input  [1:0]  S00_AXI_ARBURST,
    input         S00_AXI_ARLOCK,
    input  [3:0]  S00_AXI_ARCACHE,
    input  [2:0]  S00_AXI_ARPROT,
    input  [3:0]  S00_AXI_ARQOS,
    input         S00_AXI_ARVALID,
    output        S00_AXI_ARREADY,
    output [3:0]  S00_AXI_RID,
    output [31:0] S00_AXI_RDATA,
    output [1:0]  S00_AXI_RRESP,
    output        S00_AXI_RLAST,
    output        S00_AXI_RVALID,
    input         S00_AXI_RREADY,

    output        S01_AXI_ARESET_OUT_N,
    input         S01_AXI_ACLK,
    input  [3:0]  S01_AXI_AWID,
    input  [31:0] S01_AXI_AWADDR,
    input  [7:0]  S01_AXI_AWLEN,
    input  [2:0]  S01_AXI_AWSIZE,
    input  [1:0]  S01_AXI_AWBURST,
    input         S01_AXI_AWLOCK,
    input  [3:0]  S01_AXI_AWCACHE,
    input  [2:0]  S01_AXI_AWPROT,
    input  [3:0]  S01_AXI_AWQOS,
    input         S01_AXI_AWVALID,
    output        S01_AXI_AWREADY,
    input  [31:0] S01_AXI_WDATA,
    input  [3:0]  S01_AXI_WSTRB,
    input         S01_AXI_WLAST,
    input         S01_AXI_WVALID,
    output        S01_AXI_WREADY,
    output [3:0]  S01_AXI_BID,
    output [1:0]  S01_AXI_BRESP,
    output        S01_AXI_BVALID,
    input         S01_AXI_BREADY,
    input  [3:0]  S01_AXI_ARID,
    input  [31:0] S01_AXI_ARADDR,
    input  [7:0]  S01_AXI_ARLEN,
    input  [2:0]  S01_AXI_ARSIZE,
    input  [1:0]  S01_AXI_ARBURST,
    input         S01_AXI_ARLOCK,
    input  [3:0]  S01_AXI_ARCACHE,
    input  [2:0]  S01_AXI_ARPROT,
    input  [3:0]  S01_AXI_ARQOS,
    input         S01_AXI_ARVALID,
    output        S01_AXI_ARREADY,
    output [3:0]  S01_AXI_RID,
    output [31:0] S01_AXI_RDATA,
    output [1:0]  S01_AXI_RRESP,
    output        S01_AXI_RLAST,
    output        S01_AXI_RVALID,
    input         S01_AXI_RREADY,

    output        S02_AXI_ARESET_OUT_N,
    input         S02_AXI_ACLK,
    input  [3:0]  S02_AXI_AWID,
    input  [31:0] S02_AXI_AWADDR,
    input  [7:0]  S02_AXI_AWLEN,
    input  [2:0]  S02_AXI_AWSIZE,
    input  [1:0]  S02_AXI_AWBURST,
    input         S02_AXI_AWLOCK,
    input  [3:0]  S02_AXI_AWCACHE,
    input  [2:0]  S02_AXI_AWPROT,
    input  [3:0]  S02_AXI_AWQOS,
    input         S02_AXI_AWVALID,
    output        S02_AXI_AWREADY,
    input  [63:0] S02_AXI_WDATA,
    input  [7:0]  S02_AXI_WSTRB,
    input         S02_AXI_WLAST,
    input         S02_AXI_WVALID,
    output        S02_AXI_WREADY,
    output [3:0]  S02_AXI_BID,
    output [1:0]  S02_AXI_BRESP,
    output        S02_AXI_BVALID,
    input         S02_AXI_BREADY,
    input  [3:0]  S02_AXI_ARID,
    input  [31:0] S02_AXI_ARADDR,
    input  [7:0]  S02_AXI_ARLEN,
    input  [2:0]  S02_AXI_ARSIZE,
    input  [1:0]  S02_AXI_ARBURST,
    input         S02_AXI_ARLOCK,
    input  [3:0]  S02_AXI_ARCACHE,
    input  [2:0]  S02_AXI_ARPROT,
    input  [3:0]  S02_AXI_ARQOS,
    input         S02_AXI_ARVALID,
    output        S02_AXI_ARREADY,
    output [3:0]  S02_AXI_RID,
    output [63:0] S02_AXI_RDATA,
    output [1:0]  S02_AXI_RRESP,
    output        S02_AXI_RLAST,
    output        S02_AXI_RVALID,
    input         S02_AXI_RREADY,

    output        M00_AXI_ARESET_OUT_N,
    input         M00_AXI_ACLK,
    output [7:0]  M00_AXI_AWID,
    output [31:0] M00_AXI_AWADDR,
    output [7:0]  M00_AXI_AWLEN,
    output [2:0]  M00_AXI_AWSIZE,
    output [1:0]  M00_AXI_AWBURST,
    output        M00_AXI_AWLOCK,
    output [3:0]  M00_AXI_AWCACHE,
    output [2:0]  M00_AXI_AWPROT,
    output [3:0]  M00_AXI_AWQOS,
    output        M00_AXI_AWVALID,
    input         M00_AXI_AWREADY,
    output [31:0] M00_AXI_WDATA,
    output [3:0]  M00_AXI_WSTRB,
    output        M00_AXI_WLAST,
    output        M00_AXI_WVALID,
    input         M00_AXI_WREADY,
    input  [7:0]  M00_AXI_BID,
    input  [1:0]  M00_AXI_BRESP,
    input         M00_AXI_BVALID,
    output        M00_AXI_BREADY,
    output [7:0]  M00_AXI_ARID,
    output [31:0] M00_AXI_ARADDR,
    output [7:0]  M00_AXI_ARLEN,
    output [2:0]  M00_AXI_ARSIZE,
    output [1:0]  M00_AXI_ARBURST,
    output        M00_AXI_ARLOCK,
    output [3:0]  M00_AXI_ARCACHE,
    output [2:0]  M00_AXI_ARPROT,
    output [3:0]  M00_AXI_ARQOS,
    output        M00_AXI_ARVALID,
    input         M00_AXI_ARREADY,
    input  [7:0]  M00_AXI_RID,
    input  [31:0] M00_AXI_RDATA,
    input  [1:0]  M00_AXI_RRESP,
    input         M00_AXI_RLAST,
    input         M00_AXI_RVALID,
    output        M00_AXI_RREADY
);

// AXI address payload: ID(4) + ADDR(32) + LEN(8) + SIZE(3) + BURST(2)
//                    + LOCK(1) + CACHE(4) + PROT(3) = 57 bits.
// Keep this as a field-width sum: declaring 55 here silently discarded ID[3:2]
// when the concatenation was written into the asynchronous FIFO.
localparam AW32_W = 4 + 32 + 8 + 3 + 2 + 1 + 4 + 3;
localparam AR32_W = 4 + 32 + 8 + 3 + 2 + 1 + 4 + 3;
localparam AW64_W = 4 + 32 + 8 + 3 + 2 + 1 + 4 + 3;
localparam AR64_W = 4 + 32 + 8 + 3 + 2 + 1 + 4 + 3;
localparam W32_W  = 37;
localparam W64_W  = 73;
localparam B_W    = 6;
localparam R32_W  = 39;
localparam R64_W  = 71;

assign S00_AXI_ARESET_OUT_N = INTERCONNECT_ARESETN;
assign S01_AXI_ARESET_OUT_N = INTERCONNECT_ARESETN;
assign S02_AXI_ARESET_OUT_N = INTERCONNECT_ARESETN;
assign M00_AXI_ARESET_OUT_N = INTERCONNECT_ARESETN;

wire s00_rstn = INTERCONNECT_ARESETN;
wire s01_rstn = INTERCONNECT_ARESETN;
wire s02_rstn = INTERCONNECT_ARESETN;
wire m_rstn   = INTERCONNECT_ARESETN;

wire [AW32_W-1:0] s00_aw_din = {S00_AXI_AWID, S00_AXI_AWADDR, S00_AXI_AWLEN, S00_AXI_AWSIZE,
                                S00_AXI_AWBURST, S00_AXI_AWLOCK, S00_AXI_AWCACHE, S00_AXI_AWPROT};
wire [AW32_W-1:0] s01_aw_din = {S01_AXI_AWID, S01_AXI_AWADDR, S01_AXI_AWLEN, S01_AXI_AWSIZE,
                                S01_AXI_AWBURST, S01_AXI_AWLOCK, S01_AXI_AWCACHE, S01_AXI_AWPROT};
wire [AW64_W-1:0] s02_aw_din = {S02_AXI_AWID, S02_AXI_AWADDR, S02_AXI_AWLEN, S02_AXI_AWSIZE,
                                S02_AXI_AWBURST, S02_AXI_AWLOCK, S02_AXI_AWCACHE, S02_AXI_AWPROT};
wire [AR32_W-1:0] s00_ar_din = {S00_AXI_ARID, S00_AXI_ARADDR, S00_AXI_ARLEN, S00_AXI_ARSIZE,
                                S00_AXI_ARBURST, S00_AXI_ARLOCK, S00_AXI_ARCACHE, S00_AXI_ARPROT};
wire [AR32_W-1:0] s01_ar_din = {S01_AXI_ARID, S01_AXI_ARADDR, S01_AXI_ARLEN, S01_AXI_ARSIZE,
                                S01_AXI_ARBURST, S01_AXI_ARLOCK, S01_AXI_ARCACHE, S01_AXI_ARPROT};
wire [AR64_W-1:0] s02_ar_din = {S02_AXI_ARID, S02_AXI_ARADDR, S02_AXI_ARLEN, S02_AXI_ARSIZE,
                                S02_AXI_ARBURST, S02_AXI_ARLOCK, S02_AXI_ARCACHE, S02_AXI_ARPROT};
wire [W32_W-1:0]  s00_w_din  = {S00_AXI_WDATA, S00_AXI_WSTRB, S00_AXI_WLAST};
wire [W32_W-1:0]  s01_w_din  = {S01_AXI_WDATA, S01_AXI_WSTRB, S01_AXI_WLAST};
wire [W64_W-1:0]  s02_w_din  = {S02_AXI_WDATA, S02_AXI_WSTRB, S02_AXI_WLAST};

wire s00_aw_full, s00_w_full, s00_ar_full, s00_b_empty, s00_r_empty;
wire s01_aw_full, s01_w_full, s01_ar_full, s01_b_empty, s01_r_empty;
wire s02_aw_full, s02_w_full, s02_ar_full, s02_b_empty, s02_r_empty;
wire s00_aw_empty, s00_w_empty, s00_ar_empty, s00_b_full, s00_r_full;
wire s01_aw_empty, s01_w_empty, s01_ar_empty, s01_b_full, s01_r_full;
wire s02_aw_empty, s02_w_empty, s02_ar_empty, s02_b_full, s02_r_full;

wire [AW32_W-1:0] s00_aw_dout, s01_aw_dout;
wire [AW64_W-1:0] s02_aw_dout;
wire [W32_W-1:0]  s00_w_dout, s01_w_dout;
wire [W64_W-1:0]  s02_w_dout;
wire [AR32_W-1:0] s00_ar_dout, s01_ar_dout;
wire [AR64_W-1:0] s02_ar_dout;
wire [B_W-1:0]    s00_b_dout, s01_b_dout, s02_b_dout;
wire [R32_W-1:0]  s00_r_dout, s01_r_dout;
wire [R64_W-1:0]  s02_r_dout;

wire s00_aw_rd, s01_aw_rd, s02_aw_rd;
wire s00_w_rd,  s01_w_rd,  s02_w_rd;
wire s00_ar_rd, s01_ar_rd, s02_ar_rd;
wire s00_b_wr,  s01_b_wr,  s02_b_wr;
wire s00_r_wr,  s01_r_wr,  s02_r_wr;
wire [B_W-1:0]   s00_b_din, s01_b_din, s02_b_din;
wire [R32_W-1:0] s00_r_din, s01_r_din;
wire [R64_W-1:0] s02_r_din;

assign S00_AXI_AWREADY = !s00_aw_full;
assign S01_AXI_AWREADY = !s01_aw_full;
assign S02_AXI_AWREADY = !s02_aw_full;
assign S00_AXI_WREADY  = !s00_w_full;
assign S01_AXI_WREADY  = !s01_w_full;
assign S02_AXI_WREADY  = !s02_w_full;
assign S00_AXI_ARREADY = !s00_ar_full;
assign S01_AXI_ARREADY = !s01_ar_full;
assign S02_AXI_ARREADY = !s02_ar_full;

assign {S00_AXI_BID, S00_AXI_BRESP} = s00_b_dout;
assign {S01_AXI_BID, S01_AXI_BRESP} = s01_b_dout;
assign {S02_AXI_BID, S02_AXI_BRESP} = s02_b_dout;
assign S00_AXI_BVALID = !s00_b_empty;
assign S01_AXI_BVALID = !s01_b_empty;
assign S02_AXI_BVALID = !s02_b_empty;

assign {S00_AXI_RID, S00_AXI_RDATA, S00_AXI_RRESP, S00_AXI_RLAST} = s00_r_dout;
assign {S01_AXI_RID, S01_AXI_RDATA, S01_AXI_RRESP, S01_AXI_RLAST} = s01_r_dout;
assign {S02_AXI_RID, S02_AXI_RDATA, S02_AXI_RRESP, S02_AXI_RLAST} = s02_r_dout;
assign S00_AXI_RVALID = !s00_r_empty;
assign S01_AXI_RVALID = !s01_r_empty;
assign S02_AXI_RVALID = !s02_r_empty;

axi_async_fifo #(.DATA_WIDTH(AW32_W), .ADDR_WIDTH(4)) s00_aw_fifo (
    .wr_clk(S00_AXI_ACLK), .wr_rstn(s00_rstn), .wr_en(S00_AXI_AWVALID && S00_AXI_AWREADY),
    .wr_data(s00_aw_din), .wr_full(s00_aw_full),
    .rd_clk(M00_AXI_ACLK), .rd_rstn(m_rstn), .rd_en(s00_aw_rd),
    .rd_data(s00_aw_dout), .rd_empty(s00_aw_empty)
);
axi_async_fifo #(.DATA_WIDTH(W32_W), .ADDR_WIDTH(4)) s00_w_fifo (
    .wr_clk(S00_AXI_ACLK), .wr_rstn(s00_rstn), .wr_en(S00_AXI_WVALID && S00_AXI_WREADY),
    .wr_data(s00_w_din), .wr_full(s00_w_full),
    .rd_clk(M00_AXI_ACLK), .rd_rstn(m_rstn), .rd_en(s00_w_rd),
    .rd_data(s00_w_dout), .rd_empty(s00_w_empty)
);
axi_async_fifo #(.DATA_WIDTH(B_W), .ADDR_WIDTH(4)) s00_b_fifo (
    .wr_clk(M00_AXI_ACLK), .wr_rstn(m_rstn), .wr_en(s00_b_wr),
    .wr_data(s00_b_din), .wr_full(s00_b_full),
    .rd_clk(S00_AXI_ACLK), .rd_rstn(s00_rstn), .rd_en(S00_AXI_BVALID && S00_AXI_BREADY),
    .rd_data(s00_b_dout), .rd_empty(s00_b_empty)
);
axi_async_fifo #(.DATA_WIDTH(AR32_W), .ADDR_WIDTH(4)) s00_ar_fifo (
    .wr_clk(S00_AXI_ACLK), .wr_rstn(s00_rstn), .wr_en(S00_AXI_ARVALID && S00_AXI_ARREADY),
    .wr_data(s00_ar_din), .wr_full(s00_ar_full),
    .rd_clk(M00_AXI_ACLK), .rd_rstn(m_rstn), .rd_en(s00_ar_rd),
    .rd_data(s00_ar_dout), .rd_empty(s00_ar_empty)
);
axi_async_fifo #(.DATA_WIDTH(R32_W), .ADDR_WIDTH(4)) s00_r_fifo (
    .wr_clk(M00_AXI_ACLK), .wr_rstn(m_rstn), .wr_en(s00_r_wr),
    .wr_data(s00_r_din), .wr_full(s00_r_full),
    .rd_clk(S00_AXI_ACLK), .rd_rstn(s00_rstn), .rd_en(S00_AXI_RVALID && S00_AXI_RREADY),
    .rd_data(s00_r_dout), .rd_empty(s00_r_empty)
);

axi_async_fifo #(.DATA_WIDTH(AW32_W), .ADDR_WIDTH(4)) s01_aw_fifo (
    .wr_clk(S01_AXI_ACLK), .wr_rstn(s01_rstn), .wr_en(S01_AXI_AWVALID && S01_AXI_AWREADY),
    .wr_data(s01_aw_din), .wr_full(s01_aw_full),
    .rd_clk(M00_AXI_ACLK), .rd_rstn(m_rstn), .rd_en(s01_aw_rd),
    .rd_data(s01_aw_dout), .rd_empty(s01_aw_empty)
);
axi_async_fifo #(.DATA_WIDTH(W32_W), .ADDR_WIDTH(4)) s01_w_fifo (
    .wr_clk(S01_AXI_ACLK), .wr_rstn(s01_rstn), .wr_en(S01_AXI_WVALID && S01_AXI_WREADY),
    .wr_data(s01_w_din), .wr_full(s01_w_full),
    .rd_clk(M00_AXI_ACLK), .rd_rstn(m_rstn), .rd_en(s01_w_rd),
    .rd_data(s01_w_dout), .rd_empty(s01_w_empty)
);
axi_async_fifo #(.DATA_WIDTH(B_W), .ADDR_WIDTH(4)) s01_b_fifo (
    .wr_clk(M00_AXI_ACLK), .wr_rstn(m_rstn), .wr_en(s01_b_wr),
    .wr_data(s01_b_din), .wr_full(s01_b_full),
    .rd_clk(S01_AXI_ACLK), .rd_rstn(s01_rstn), .rd_en(S01_AXI_BVALID && S01_AXI_BREADY),
    .rd_data(s01_b_dout), .rd_empty(s01_b_empty)
);
axi_async_fifo #(.DATA_WIDTH(AR32_W), .ADDR_WIDTH(4)) s01_ar_fifo (
    .wr_clk(S01_AXI_ACLK), .wr_rstn(s01_rstn), .wr_en(S01_AXI_ARVALID && S01_AXI_ARREADY),
    .wr_data(s01_ar_din), .wr_full(s01_ar_full),
    .rd_clk(M00_AXI_ACLK), .rd_rstn(m_rstn), .rd_en(s01_ar_rd),
    .rd_data(s01_ar_dout), .rd_empty(s01_ar_empty)
);
axi_async_fifo #(.DATA_WIDTH(R32_W), .ADDR_WIDTH(4)) s01_r_fifo (
    .wr_clk(M00_AXI_ACLK), .wr_rstn(m_rstn), .wr_en(s01_r_wr),
    .wr_data(s01_r_din), .wr_full(s01_r_full),
    .rd_clk(S01_AXI_ACLK), .rd_rstn(s01_rstn), .rd_en(S01_AXI_RVALID && S01_AXI_RREADY),
    .rd_data(s01_r_dout), .rd_empty(s01_r_empty)
);

axi_async_fifo #(.DATA_WIDTH(AW64_W), .ADDR_WIDTH(4)) s02_aw_fifo (
    .wr_clk(S02_AXI_ACLK), .wr_rstn(s02_rstn), .wr_en(S02_AXI_AWVALID && S02_AXI_AWREADY),
    .wr_data(s02_aw_din), .wr_full(s02_aw_full),
    .rd_clk(M00_AXI_ACLK), .rd_rstn(m_rstn), .rd_en(s02_aw_rd),
    .rd_data(s02_aw_dout), .rd_empty(s02_aw_empty)
);
axi_async_fifo #(.DATA_WIDTH(W64_W), .ADDR_WIDTH(4)) s02_w_fifo (
    .wr_clk(S02_AXI_ACLK), .wr_rstn(s02_rstn), .wr_en(S02_AXI_WVALID && S02_AXI_WREADY),
    .wr_data(s02_w_din), .wr_full(s02_w_full),
    .rd_clk(M00_AXI_ACLK), .rd_rstn(m_rstn), .rd_en(s02_w_rd),
    .rd_data(s02_w_dout), .rd_empty(s02_w_empty)
);
axi_async_fifo #(.DATA_WIDTH(B_W), .ADDR_WIDTH(4)) s02_b_fifo (
    .wr_clk(M00_AXI_ACLK), .wr_rstn(m_rstn), .wr_en(s02_b_wr),
    .wr_data(s02_b_din), .wr_full(s02_b_full),
    .rd_clk(S02_AXI_ACLK), .rd_rstn(s02_rstn), .rd_en(S02_AXI_BVALID && S02_AXI_BREADY),
    .rd_data(s02_b_dout), .rd_empty(s02_b_empty)
);
axi_async_fifo #(.DATA_WIDTH(AR64_W), .ADDR_WIDTH(4)) s02_ar_fifo (
    .wr_clk(S02_AXI_ACLK), .wr_rstn(s02_rstn), .wr_en(S02_AXI_ARVALID && S02_AXI_ARREADY),
    .wr_data(s02_ar_din), .wr_full(s02_ar_full),
    .rd_clk(M00_AXI_ACLK), .rd_rstn(m_rstn), .rd_en(s02_ar_rd),
    .rd_data(s02_ar_dout), .rd_empty(s02_ar_empty)
);
axi_async_fifo #(.DATA_WIDTH(R64_W), .ADDR_WIDTH(4)) s02_r_fifo (
    .wr_clk(M00_AXI_ACLK), .wr_rstn(m_rstn), .wr_en(s02_r_wr),
    .wr_data(s02_r_din), .wr_full(s02_r_full),
    .rd_clk(S02_AXI_ACLK), .rd_rstn(s02_rstn), .rd_en(S02_AXI_RVALID && S02_AXI_RREADY),
    .rd_data(s02_r_dout), .rd_empty(s02_r_empty)
);

localparam P0 = 2'd0;
localparam P1 = 2'd1;
localparam P2 = 2'd2;

reg [2:0]  wr_state;
reg [1:0]  wr_port;
reg [3:0]  wr_id;
reg [31:0] wr_addr;
reg [7:0]  wr_len;
reg [2:0]  wr_size;
reg [1:0]  wr_burst;
reg        wr_lock;
reg [3:0]  wr_cache;
reg [2:0]  wr_prot;
reg [63:0] wr64_data;
reg [7:0]  wr64_strb;
reg        wr64_last;
reg        wr64_loaded;

reg        rd_state;
reg [1:0]  rd_port;
reg [3:0]  rd_id;
reg [31:0] rd_addr;
reg [7:0]  rd_len;
reg [2:0]  rd_size;
reg [1:0]  rd_burst;
reg        rd_lock;
reg [3:0]  rd_cache;
reg [2:0]  rd_prot;
reg [31:0] rd64_lo [0:15];
reg [1:0]  rd64_resp [0:15];
reg [15:0] rd64_have_lo;
integer    read_id;

localparam WR_IDLE  = 3'd0;
localparam WR_AW    = 3'd1;
localparam WR_DATA  = 3'd2;
localparam WR_64_LO = 3'd3;
localparam WR_64_HI = 3'd4;
localparam WR_B     = 3'd5;

localparam RD_IDLE = 1'b0;
localparam RD_AR   = 1'b1;

wire choose_aw0 = !s00_aw_empty;
wire choose_aw1 = s00_aw_empty && !s01_aw_empty;
wire choose_aw2 = s00_aw_empty && s01_aw_empty && !s02_aw_empty;
wire choose_ar0 = !s00_ar_empty;
wire choose_ar1 = s00_ar_empty && !s01_ar_empty;
wire choose_ar2 = s00_ar_empty && s01_ar_empty && !s02_ar_empty;

assign s00_aw_rd = (wr_state == WR_IDLE) && choose_aw0;
assign s01_aw_rd = (wr_state == WR_IDLE) && choose_aw1;
assign s02_aw_rd = (wr_state == WR_IDLE) && choose_aw2;
assign s00_ar_rd = (rd_state == RD_IDLE) && choose_ar0;
assign s01_ar_rd = (rd_state == RD_IDLE) && choose_ar1;
assign s02_ar_rd = (rd_state == RD_IDLE) && choose_ar2;

assign M00_AXI_AWID    = {4'b0, wr_id};
assign M00_AXI_AWADDR  = wr_addr;
assign M00_AXI_AWLEN   = (wr_port == P2) ? {wr_len[6:0], 1'b1} : wr_len;
assign M00_AXI_AWSIZE  = (wr_port == P2) ? 3'b010 : wr_size;
assign M00_AXI_AWBURST = wr_burst;
assign M00_AXI_AWLOCK  = wr_lock;
assign M00_AXI_AWCACHE = wr_cache;
assign M00_AXI_AWPROT  = wr_prot;
assign M00_AXI_AWQOS   = 4'b0;
assign M00_AXI_AWVALID = (wr_state == WR_AW);

assign M00_AXI_WDATA  = (wr_port == P2 && wr_state == WR_64_HI) ? wr64_data[63:32] :
                        (wr_port == P2) ? wr64_data[31:0] :
                        (wr_port == P1) ? s01_w_dout[36:5] : s00_w_dout[36:5];
assign M00_AXI_WSTRB  = (wr_port == P2 && wr_state == WR_64_HI) ? wr64_strb[7:4] :
                        (wr_port == P2) ? wr64_strb[3:0] :
                        (wr_port == P1) ? s01_w_dout[4:1] : s00_w_dout[4:1];
assign M00_AXI_WLAST  = (wr_port == P2 && wr_state == WR_64_HI) ? wr64_last :
                        (wr_port == P2) ? 1'b0 :
                        (wr_port == P1) ? s01_w_dout[0] : s00_w_dout[0];
assign M00_AXI_WVALID = (wr_state == WR_DATA && wr_port != P2 &&
                         ((wr_port == P0 && !s00_w_empty) || (wr_port == P1 && !s01_w_empty))) ||
                        (wr_state == WR_64_LO && wr64_loaded) ||
                        (wr_state == WR_64_HI && wr64_loaded);
assign M00_AXI_BREADY = (wr_state == WR_B) &&
                        ((wr_port == P0 && !s00_b_full) ||
                         (wr_port == P1 && !s01_b_full) ||
                         (wr_port == P2 && !s02_b_full));

assign s00_w_rd = (wr_state == WR_DATA) && (wr_port == P0) && M00_AXI_WVALID && M00_AXI_WREADY;
assign s01_w_rd = (wr_state == WR_DATA) && (wr_port == P1) && M00_AXI_WVALID && M00_AXI_WREADY;
assign s02_w_rd = (wr_state == WR_DATA) && (wr_port == P2) && !wr64_loaded && !s02_w_empty;

assign s00_b_wr  = (wr_state == WR_B) && (wr_port == P0) && M00_AXI_BVALID && M00_AXI_BREADY;
assign s01_b_wr  = (wr_state == WR_B) && (wr_port == P1) && M00_AXI_BVALID && M00_AXI_BREADY;
assign s02_b_wr  = (wr_state == WR_B) && (wr_port == P2) && M00_AXI_BVALID && M00_AXI_BREADY;
assign s00_b_din = {M00_AXI_BID[3:0], M00_AXI_BRESP};
assign s01_b_din = {M00_AXI_BID[3:0], M00_AXI_BRESP};
assign s02_b_din = {M00_AXI_BID[3:0], M00_AXI_BRESP};

// Preserve the complete request identity through the MIG.  Bits [5:4] encode
// the source port and bits [3:0] retain that source's AXI RID.  Unlike an
// acceptance-order route FIFO, this remains correct when the MIG returns
// different IDs out of order or interleaves their read beats.
assign M00_AXI_ARID    = {2'b00, rd_port, rd_id};
assign M00_AXI_ARADDR  = rd_addr;
assign M00_AXI_ARLEN   = (rd_port == P2) ? {rd_len[6:0], 1'b1} : rd_len;
assign M00_AXI_ARSIZE  = (rd_port == P2) ? 3'b010 : rd_size;
assign M00_AXI_ARBURST = rd_burst;
assign M00_AXI_ARLOCK  = rd_lock;
assign M00_AXI_ARCACHE = rd_cache;
assign M00_AXI_ARPROT  = rd_prot;
assign M00_AXI_ARQOS   = 4'b0;
assign M00_AXI_ARVALID = (rd_state == RD_AR);
wire [1:0] response_port = M00_AXI_RID[5:4];
wire [3:0] response_id   = M00_AXI_RID[3:0];
wire       response_known = response_port == P0 || response_port == P1 || response_port == P2;

assign M00_AXI_RREADY  = response_known &&
                         ((response_port == P0 && !s00_r_full) ||
                          (response_port == P1 && !s01_r_full) ||
                          (response_port == P2 && !s02_r_full));

assign s00_r_wr  = (response_port == P0) && M00_AXI_RVALID && M00_AXI_RREADY;
assign s01_r_wr  = (response_port == P1) && M00_AXI_RVALID && M00_AXI_RREADY;
assign s02_r_wr  = (response_port == P2) && M00_AXI_RVALID && M00_AXI_RREADY && rd64_have_lo[response_id];
assign s00_r_din = {response_id, M00_AXI_RDATA, M00_AXI_RRESP, M00_AXI_RLAST};
assign s01_r_din = {response_id, M00_AXI_RDATA, M00_AXI_RRESP, M00_AXI_RLAST};
assign s02_r_din = {response_id, M00_AXI_RDATA, rd64_lo[response_id],
                    (rd64_resp[response_id] | M00_AXI_RRESP), M00_AXI_RLAST};

always @(posedge M00_AXI_ACLK) begin
    if (!m_rstn) begin
        wr_state    <= WR_IDLE;
        wr_port     <= P0;
        wr_id       <= 4'b0;
        wr_addr     <= 32'b0;
        wr_len      <= 8'b0;
        wr_size     <= 3'b0;
        wr_burst    <= 2'b01;
        wr_lock     <= 1'b0;
        wr_cache    <= 4'b0;
        wr_prot     <= 3'b0;
        wr64_data   <= 64'b0;
        wr64_strb   <= 8'b0;
        wr64_last   <= 1'b0;
        wr64_loaded <= 1'b0;
    end else begin
        case (wr_state)
        WR_IDLE: begin
            wr64_loaded <= 1'b0;
            if (choose_aw0) begin
                {wr_id, wr_addr, wr_len, wr_size, wr_burst, wr_lock, wr_cache, wr_prot} <= s00_aw_dout;
                wr_port  <= P0;
                wr_state <= WR_AW;
            end else if (choose_aw1) begin
                {wr_id, wr_addr, wr_len, wr_size, wr_burst, wr_lock, wr_cache, wr_prot} <= s01_aw_dout;
                wr_port  <= P1;
                wr_state <= WR_AW;
            end else if (choose_aw2) begin
                {wr_id, wr_addr, wr_len, wr_size, wr_burst, wr_lock, wr_cache, wr_prot} <= s02_aw_dout;
                wr_port  <= P2;
                wr_state <= WR_AW;
            end
        end
        WR_AW: begin
            if (M00_AXI_AWVALID && M00_AXI_AWREADY)
                wr_state <= (wr_port == P2) ? WR_DATA : WR_DATA;
        end
        WR_DATA: begin
            if (wr_port == P2) begin
                if (!wr64_loaded && !s02_w_empty) begin
                    {wr64_data, wr64_strb, wr64_last} <= s02_w_dout;
                    wr64_loaded <= 1'b1;
                    wr_state    <= WR_64_LO;
                end
            end else if (M00_AXI_WVALID && M00_AXI_WREADY && M00_AXI_WLAST) begin
                wr_state <= WR_B;
            end
        end
        WR_64_LO: begin
            if (M00_AXI_WVALID && M00_AXI_WREADY)
                wr_state <= WR_64_HI;
        end
        WR_64_HI: begin
            if (M00_AXI_WVALID && M00_AXI_WREADY) begin
                wr64_loaded <= 1'b0;
                wr_state <= wr64_last ? WR_B : WR_DATA;
            end
        end
        WR_B: begin
            if (M00_AXI_BVALID && M00_AXI_BREADY)
                wr_state <= WR_IDLE;
        end
        default:
            wr_state <= WR_IDLE;
        endcase
    end
end

always @(posedge M00_AXI_ACLK) begin
    if (!m_rstn) begin
        rd_state      <= RD_IDLE;
        rd_port       <= P0;
        rd_id         <= 4'b0;
        rd_addr       <= 32'b0;
        rd_len        <= 8'b0;
        rd_size       <= 3'b0;
        rd_burst      <= 2'b01;
        rd_lock       <= 1'b0;
        rd_cache      <= 4'b0;
        rd_prot       <= 3'b0;
        rd64_have_lo  <= 16'b0;
        for (read_id = 0; read_id < 16; read_id = read_id + 1) begin
            rd64_lo[read_id]   <= 32'b0;
            rd64_resp[read_id] <= 2'b0;
        end
    end else begin
        case (rd_state)
        RD_IDLE: begin
            if (choose_ar0) begin
                {rd_id, rd_addr, rd_len, rd_size, rd_burst, rd_lock, rd_cache, rd_prot} <= s00_ar_dout;
                rd_port  <= P0;
                rd_state <= RD_AR;
            end else if (choose_ar1) begin
                {rd_id, rd_addr, rd_len, rd_size, rd_burst, rd_lock, rd_cache, rd_prot} <= s01_ar_dout;
                rd_port  <= P1;
                rd_state <= RD_AR;
            end else if (choose_ar2) begin
                {rd_id, rd_addr, rd_len, rd_size, rd_burst, rd_lock, rd_cache, rd_prot} <= s02_ar_dout;
                rd_port  <= P2;
                rd_state <= RD_AR;
            end
        end
        RD_AR: begin
            if (M00_AXI_ARVALID && M00_AXI_ARREADY)
                rd_state <= RD_IDLE;
        end
        default:
            rd_state <= RD_IDLE;
        endcase

        if (M00_AXI_RVALID && M00_AXI_RREADY && response_port == P2) begin
            if (!rd64_have_lo[response_id]) begin
                rd64_lo[response_id]      <= M00_AXI_RDATA;
                rd64_resp[response_id]    <= M00_AXI_RRESP;
                rd64_have_lo[response_id] <= 1'b1;
            end else begin
                rd64_have_lo[response_id] <= 1'b0;
            end
        end
    end
end

endmodule

module axi_async_fifo #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 4
) (
    input                  wr_clk,
    input                  wr_rstn,
    input                  wr_en,
    input  [DATA_WIDTH-1:0] wr_data,
    output                 wr_full,

    input                  rd_clk,
    input                  rd_rstn,
    input                  rd_en,
    output [DATA_WIDTH-1:0] rd_data,
    output                 rd_empty
);

localparam PTR_WIDTH = ADDR_WIDTH + 1;
localparam DEPTH = (1 << ADDR_WIDTH);

reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
reg [PTR_WIDTH-1:0] wr_bin;
reg [PTR_WIDTH-1:0] wr_gray;
reg [PTR_WIDTH-1:0] rd_bin;
reg [PTR_WIDTH-1:0] rd_gray;
reg                 wr_full_reg;
reg                 rd_empty_reg;

(* ASYNC_REG = "TRUE" *) reg [PTR_WIDTH-1:0] rd_gray_w1;
(* ASYNC_REG = "TRUE" *) reg [PTR_WIDTH-1:0] rd_gray_w2;
(* ASYNC_REG = "TRUE" *) reg [PTR_WIDTH-1:0] wr_gray_r1;
(* ASYNC_REG = "TRUE" *) reg [PTR_WIDTH-1:0] wr_gray_r2;

wire                 wr_push      = wr_en && !wr_full_reg;
wire                 rd_pop       = rd_en && !rd_empty_reg;
wire [PTR_WIDTH-1:0] wr_bin_next  = wr_bin + (wr_push ? 1'b1 : 1'b0);
wire [PTR_WIDTH-1:0] wr_gray_next = (wr_bin_next >> 1) ^ wr_bin_next;
wire [PTR_WIDTH-1:0] rd_bin_next  = rd_bin + (rd_pop ? 1'b1 : 1'b0);
wire [PTR_WIDTH-1:0] rd_gray_next = (rd_bin_next >> 1) ^ rd_bin_next;
wire                 wr_full_next = (wr_gray_next == {~rd_gray_w2[PTR_WIDTH-1:PTR_WIDTH-2], rd_gray_w2[PTR_WIDTH-3:0]});
wire                 rd_empty_next = (rd_gray_next == wr_gray_r2);

assign wr_full  = wr_full_reg;
assign rd_empty = rd_empty_reg;
assign rd_data  = mem[rd_bin[ADDR_WIDTH-1:0]];

always @(posedge wr_clk) begin
    if (!wr_rstn) begin
        wr_bin      <= {PTR_WIDTH{1'b0}};
        wr_gray     <= {PTR_WIDTH{1'b0}};
        wr_full_reg <= 1'b0;
        rd_gray_w1 <= {PTR_WIDTH{1'b0}};
        rd_gray_w2 <= {PTR_WIDTH{1'b0}};
    end else begin
        rd_gray_w1 <= rd_gray;
        rd_gray_w2 <= rd_gray_w1;
        wr_full_reg <= wr_full_next;
        if (wr_push) begin
            mem[wr_bin[ADDR_WIDTH-1:0]] <= wr_data;
            wr_bin  <= wr_bin_next;
            wr_gray <= wr_gray_next;
        end
    end
end

always @(posedge rd_clk) begin
    if (!rd_rstn) begin
        rd_bin       <= {PTR_WIDTH{1'b0}};
        rd_gray      <= {PTR_WIDTH{1'b0}};
        rd_empty_reg <= 1'b1;
        wr_gray_r1 <= {PTR_WIDTH{1'b0}};
        wr_gray_r2 <= {PTR_WIDTH{1'b0}};
    end else begin
        wr_gray_r1 <= wr_gray;
        wr_gray_r2 <= wr_gray_r1;
        rd_empty_reg <= rd_empty_next;
        if (rd_pop) begin
            rd_bin  <= rd_bin_next;
            rd_gray <= rd_gray_next;
        end
    end
end

endmodule
