// Port-compatible wrapper around the Vivado 2025.2 AXI Interconnect block
// design.  The BD is the implementation; this file only preserves the legacy
// module/port names used by soc_demo/loongson/soc_top.v.
module axi_interconnect_0 (
    input INTERCONNECT_ACLK, input INTERCONNECT_ARESETN,
    output S00_AXI_ARESET_OUT_N, input S00_AXI_ACLK,
    input [3:0] S00_AXI_AWID, input [31:0] S00_AXI_AWADDR, input [7:0] S00_AXI_AWLEN,
    input [2:0] S00_AXI_AWSIZE, input [1:0] S00_AXI_AWBURST, input S00_AXI_AWLOCK,
    input [3:0] S00_AXI_AWCACHE, input [2:0] S00_AXI_AWPROT, input [3:0] S00_AXI_AWQOS,
    input S00_AXI_AWVALID, output S00_AXI_AWREADY, input [31:0] S00_AXI_WDATA,
    input [3:0] S00_AXI_WSTRB, input S00_AXI_WLAST, input S00_AXI_WVALID,
    output S00_AXI_WREADY, output [3:0] S00_AXI_BID, output [1:0] S00_AXI_BRESP,
    output S00_AXI_BVALID, input S00_AXI_BREADY, input [3:0] S00_AXI_ARID,
    input [31:0] S00_AXI_ARADDR, input [7:0] S00_AXI_ARLEN, input [2:0] S00_AXI_ARSIZE,
    input [1:0] S00_AXI_ARBURST, input S00_AXI_ARLOCK, input [3:0] S00_AXI_ARCACHE,
    input [2:0] S00_AXI_ARPROT, input [3:0] S00_AXI_ARQOS, input S00_AXI_ARVALID,
    output S00_AXI_ARREADY, output [3:0] S00_AXI_RID, output [31:0] S00_AXI_RDATA,
    output [1:0] S00_AXI_RRESP, output S00_AXI_RLAST, output S00_AXI_RVALID,
    input S00_AXI_RREADY,

    output S01_AXI_ARESET_OUT_N, input S01_AXI_ACLK,
    input [3:0] S01_AXI_AWID, input [31:0] S01_AXI_AWADDR, input [7:0] S01_AXI_AWLEN,
    input [2:0] S01_AXI_AWSIZE, input [1:0] S01_AXI_AWBURST, input S01_AXI_AWLOCK,
    input [3:0] S01_AXI_AWCACHE, input [2:0] S01_AXI_AWPROT, input [3:0] S01_AXI_AWQOS,
    input S01_AXI_AWVALID, output S01_AXI_AWREADY, input [31:0] S01_AXI_WDATA,
    input [3:0] S01_AXI_WSTRB, input S01_AXI_WLAST, input S01_AXI_WVALID,
    output S01_AXI_WREADY, output [3:0] S01_AXI_BID, output [1:0] S01_AXI_BRESP,
    output S01_AXI_BVALID, input S01_AXI_BREADY, input [3:0] S01_AXI_ARID,
    input [31:0] S01_AXI_ARADDR, input [7:0] S01_AXI_ARLEN, input [2:0] S01_AXI_ARSIZE,
    input [1:0] S01_AXI_ARBURST, input S01_AXI_ARLOCK, input [3:0] S01_AXI_ARCACHE,
    input [2:0] S01_AXI_ARPROT, input [3:0] S01_AXI_ARQOS, input S01_AXI_ARVALID,
    output S01_AXI_ARREADY, output [3:0] S01_AXI_RID, output [31:0] S01_AXI_RDATA,
    output [1:0] S01_AXI_RRESP, output S01_AXI_RLAST, output S01_AXI_RVALID,
    input S01_AXI_RREADY,

    output S02_AXI_ARESET_OUT_N, input S02_AXI_ACLK,
    input [3:0] S02_AXI_AWID, input [31:0] S02_AXI_AWADDR, input [7:0] S02_AXI_AWLEN,
    input [2:0] S02_AXI_AWSIZE, input [1:0] S02_AXI_AWBURST, input S02_AXI_AWLOCK,
    input [3:0] S02_AXI_AWCACHE, input [2:0] S02_AXI_AWPROT, input [3:0] S02_AXI_AWQOS,
    input S02_AXI_AWVALID, output S02_AXI_AWREADY, input [63:0] S02_AXI_WDATA,
    input [7:0] S02_AXI_WSTRB, input S02_AXI_WLAST, input S02_AXI_WVALID,
    output S02_AXI_WREADY, output [3:0] S02_AXI_BID, output [1:0] S02_AXI_BRESP,
    output S02_AXI_BVALID, input S02_AXI_BREADY, input [3:0] S02_AXI_ARID,
    input [31:0] S02_AXI_ARADDR, input [7:0] S02_AXI_ARLEN, input [2:0] S02_AXI_ARSIZE,
    input [1:0] S02_AXI_ARBURST, input S02_AXI_ARLOCK, input [3:0] S02_AXI_ARCACHE,
    input [2:0] S02_AXI_ARPROT, input [3:0] S02_AXI_ARQOS, input S02_AXI_ARVALID,
    output S02_AXI_ARREADY, output [3:0] S02_AXI_RID, output [63:0] S02_AXI_RDATA,
    output [1:0] S02_AXI_RRESP, output S02_AXI_RLAST, output S02_AXI_RVALID,
    input S02_AXI_RREADY,

    output M00_AXI_ARESET_OUT_N, input M00_AXI_ACLK,
    output [7:0] M00_AXI_AWID, output [31:0] M00_AXI_AWADDR, output [7:0] M00_AXI_AWLEN,
    output [2:0] M00_AXI_AWSIZE, output [1:0] M00_AXI_AWBURST, output M00_AXI_AWLOCK,
    output [3:0] M00_AXI_AWCACHE, output [2:0] M00_AXI_AWPROT, output [3:0] M00_AXI_AWQOS,
    output M00_AXI_AWVALID, input M00_AXI_AWREADY, output [31:0] M00_AXI_WDATA,
    output [3:0] M00_AXI_WSTRB, output M00_AXI_WLAST, output M00_AXI_WVALID,
    input M00_AXI_WREADY, input [7:0] M00_AXI_BID, input [1:0] M00_AXI_BRESP,
    input M00_AXI_BVALID, output M00_AXI_BREADY, output [7:0] M00_AXI_ARID,
    output [31:0] M00_AXI_ARADDR, output [7:0] M00_AXI_ARLEN, output [2:0] M00_AXI_ARSIZE,
    output [1:0] M00_AXI_ARBURST, output M00_AXI_ARLOCK, output [3:0] M00_AXI_ARCACHE,
    output [2:0] M00_AXI_ARPROT, output [3:0] M00_AXI_ARQOS, output M00_AXI_ARVALID,
    input M00_AXI_ARREADY, input [7:0] M00_AXI_RID, input [31:0] M00_AXI_RDATA,
    input [1:0] M00_AXI_RRESP, input M00_AXI_RLAST, input M00_AXI_RVALID,
    output M00_AXI_RREADY
);
    assign S00_AXI_ARESET_OUT_N = INTERCONNECT_ARESETN;
    assign S01_AXI_ARESET_OUT_N = INTERCONNECT_ARESETN;
    assign S02_AXI_ARESET_OUT_N = INTERCONNECT_ARESETN;
    assign M00_AXI_ARESET_OUT_N = INTERCONNECT_ARESETN;
    // The crossbar prefixes the 4-bit upstream ID with its 2-bit source-port
    // tag.  Preserve that complete 6-bit transaction identity at MIG; the MIG
    // port is 8 bits wide, so only zero-extension is required.
    wire [5:0] m00_awid;
    wire [5:0] m00_bid;
    wire [5:0] m00_arid;
    wire [5:0] m00_rid;
    assign M00_AXI_AWID = {2'b0, m00_awid};
    assign M00_AXI_ARID = {2'b0, m00_arid};
    assign m00_bid = M00_AXI_BID[5:0];
    assign m00_rid = M00_AXI_RID[5:0];

    axi_interconnect_0_bd u_bd (
        .ACLK(INTERCONNECT_ACLK), .ARESETN(INTERCONNECT_ARESETN),
        .S00_ACLK(S00_AXI_ACLK), .S00_ARESETN(INTERCONNECT_ARESETN),
        .S01_ACLK(S01_AXI_ACLK), .S01_ARESETN(INTERCONNECT_ARESETN),
        .S02_ACLK(S02_AXI_ACLK), .S02_ARESETN(INTERCONNECT_ARESETN),
        .M00_ACLK(M00_AXI_ACLK), .M00_ARESETN(INTERCONNECT_ARESETN),
        .S00_AXI_awid(S00_AXI_AWID), .S00_AXI_awaddr(S00_AXI_AWADDR), .S00_AXI_awlen(S00_AXI_AWLEN),
        .S00_AXI_awsize(S00_AXI_AWSIZE), .S00_AXI_awburst(S00_AXI_AWBURST), .S00_AXI_awlock(S00_AXI_AWLOCK),
        .S00_AXI_awcache(S00_AXI_AWCACHE), .S00_AXI_awprot(S00_AXI_AWPROT), .S00_AXI_awqos(S00_AXI_AWQOS),
        .S00_AXI_awvalid(S00_AXI_AWVALID), .S00_AXI_awready(S00_AXI_AWREADY),
        .S00_AXI_wdata(S00_AXI_WDATA), .S00_AXI_wstrb(S00_AXI_WSTRB), .S00_AXI_wlast(S00_AXI_WLAST),
        .S00_AXI_wvalid(S00_AXI_WVALID), .S00_AXI_wready(S00_AXI_WREADY),
        .S00_AXI_bid(S00_AXI_BID), .S00_AXI_bresp(S00_AXI_BRESP), .S00_AXI_bvalid(S00_AXI_BVALID), .S00_AXI_bready(S00_AXI_BREADY),
        .S00_AXI_arid(S00_AXI_ARID), .S00_AXI_araddr(S00_AXI_ARADDR), .S00_AXI_arlen(S00_AXI_ARLEN),
        .S00_AXI_arsize(S00_AXI_ARSIZE), .S00_AXI_arburst(S00_AXI_ARBURST), .S00_AXI_arlock(S00_AXI_ARLOCK),
        .S00_AXI_arcache(S00_AXI_ARCACHE), .S00_AXI_arprot(S00_AXI_ARPROT), .S00_AXI_arqos(S00_AXI_ARQOS),
        .S00_AXI_arvalid(S00_AXI_ARVALID), .S00_AXI_arready(S00_AXI_ARREADY),
        .S00_AXI_rid(S00_AXI_RID), .S00_AXI_rdata(S00_AXI_RDATA), .S00_AXI_rresp(S00_AXI_RRESP),
        .S00_AXI_rlast(S00_AXI_RLAST), .S00_AXI_rvalid(S00_AXI_RVALID), .S00_AXI_rready(S00_AXI_RREADY),

        .S01_AXI_awid(S01_AXI_AWID), .S01_AXI_awaddr(S01_AXI_AWADDR), .S01_AXI_awlen(S01_AXI_AWLEN),
        .S01_AXI_awsize(S01_AXI_AWSIZE), .S01_AXI_awburst(S01_AXI_AWBURST), .S01_AXI_awlock(S01_AXI_AWLOCK),
        .S01_AXI_awcache(S01_AXI_AWCACHE), .S01_AXI_awprot(S01_AXI_AWPROT), .S01_AXI_awqos(S01_AXI_AWQOS),
        .S01_AXI_awvalid(S01_AXI_AWVALID), .S01_AXI_awready(S01_AXI_AWREADY),
        .S01_AXI_wdata(S01_AXI_WDATA), .S01_AXI_wstrb(S01_AXI_WSTRB), .S01_AXI_wlast(S01_AXI_WLAST),
        .S01_AXI_wvalid(S01_AXI_WVALID), .S01_AXI_wready(S01_AXI_WREADY),
        .S01_AXI_bid(S01_AXI_BID), .S01_AXI_bresp(S01_AXI_BRESP), .S01_AXI_bvalid(S01_AXI_BVALID), .S01_AXI_bready(S01_AXI_BREADY),
        .S01_AXI_arid(S01_AXI_ARID), .S01_AXI_araddr(S01_AXI_ARADDR), .S01_AXI_arlen(S01_AXI_ARLEN),
        .S01_AXI_arsize(S01_AXI_ARSIZE), .S01_AXI_arburst(S01_AXI_ARBURST), .S01_AXI_arlock(S01_AXI_ARLOCK),
        .S01_AXI_arcache(S01_AXI_ARCACHE), .S01_AXI_arprot(S01_AXI_ARPROT), .S01_AXI_arqos(S01_AXI_ARQOS),
        .S01_AXI_arvalid(S01_AXI_ARVALID), .S01_AXI_arready(S01_AXI_ARREADY),
        .S01_AXI_rid(S01_AXI_RID), .S01_AXI_rdata(S01_AXI_RDATA), .S01_AXI_rresp(S01_AXI_RRESP),
        .S01_AXI_rlast(S01_AXI_RLAST), .S01_AXI_rvalid(S01_AXI_RVALID), .S01_AXI_rready(S01_AXI_RREADY),

        .S02_AXI_awid(S02_AXI_AWID), .S02_AXI_awaddr(S02_AXI_AWADDR), .S02_AXI_awlen(S02_AXI_AWLEN),
        .S02_AXI_awsize(S02_AXI_AWSIZE), .S02_AXI_awburst(S02_AXI_AWBURST), .S02_AXI_awlock(S02_AXI_AWLOCK),
        .S02_AXI_awcache(S02_AXI_AWCACHE), .S02_AXI_awprot(S02_AXI_AWPROT), .S02_AXI_awqos(S02_AXI_AWQOS),
        .S02_AXI_awvalid(S02_AXI_AWVALID), .S02_AXI_awready(S02_AXI_AWREADY),
        .S02_AXI_wdata(S02_AXI_WDATA), .S02_AXI_wstrb(S02_AXI_WSTRB), .S02_AXI_wlast(S02_AXI_WLAST),
        .S02_AXI_wvalid(S02_AXI_WVALID), .S02_AXI_wready(S02_AXI_WREADY),
        .S02_AXI_bid(S02_AXI_BID), .S02_AXI_bresp(S02_AXI_BRESP), .S02_AXI_bvalid(S02_AXI_BVALID), .S02_AXI_bready(S02_AXI_BREADY),
        .S02_AXI_arid(S02_AXI_ARID), .S02_AXI_araddr(S02_AXI_ARADDR), .S02_AXI_arlen(S02_AXI_ARLEN),
        .S02_AXI_arsize(S02_AXI_ARSIZE), .S02_AXI_arburst(S02_AXI_ARBURST), .S02_AXI_arlock(S02_AXI_ARLOCK),
        .S02_AXI_arcache(S02_AXI_ARCACHE), .S02_AXI_arprot(S02_AXI_ARPROT), .S02_AXI_arqos(S02_AXI_ARQOS),
        .S02_AXI_arvalid(S02_AXI_ARVALID), .S02_AXI_arready(S02_AXI_ARREADY),
        .S02_AXI_rid(S02_AXI_RID), .S02_AXI_rdata(S02_AXI_RDATA), .S02_AXI_rresp(S02_AXI_RRESP),
        .S02_AXI_rlast(S02_AXI_RLAST), .S02_AXI_rvalid(S02_AXI_RVALID), .S02_AXI_rready(S02_AXI_RREADY),

        .M00_AXI_awid(m00_awid), .M00_AXI_awaddr(M00_AXI_AWADDR), .M00_AXI_awlen(M00_AXI_AWLEN),
        .M00_AXI_awsize(M00_AXI_AWSIZE), .M00_AXI_awburst(M00_AXI_AWBURST), .M00_AXI_awlock(M00_AXI_AWLOCK),
        .M00_AXI_awcache(M00_AXI_AWCACHE), .M00_AXI_awprot(M00_AXI_AWPROT), .M00_AXI_awqos(M00_AXI_AWQOS),
        .M00_AXI_awvalid(M00_AXI_AWVALID), .M00_AXI_awready(M00_AXI_AWREADY),
        .M00_AXI_wdata(M00_AXI_WDATA), .M00_AXI_wstrb(M00_AXI_WSTRB), .M00_AXI_wlast(M00_AXI_WLAST),
        .M00_AXI_wvalid(M00_AXI_WVALID), .M00_AXI_wready(M00_AXI_WREADY),
        .M00_AXI_bid(m00_bid), .M00_AXI_bresp(M00_AXI_BRESP), .M00_AXI_bvalid(M00_AXI_BVALID), .M00_AXI_bready(M00_AXI_BREADY),
        .M00_AXI_arid(m00_arid), .M00_AXI_araddr(M00_AXI_ARADDR), .M00_AXI_arlen(M00_AXI_ARLEN),
        .M00_AXI_arsize(M00_AXI_ARSIZE), .M00_AXI_arburst(M00_AXI_ARBURST), .M00_AXI_arlock(M00_AXI_ARLOCK),
        .M00_AXI_arcache(M00_AXI_ARCACHE), .M00_AXI_arprot(M00_AXI_ARPROT), .M00_AXI_arqos(M00_AXI_ARQOS),
        .M00_AXI_arvalid(M00_AXI_ARVALID), .M00_AXI_arready(M00_AXI_ARREADY),
        .M00_AXI_rid(m00_rid), .M00_AXI_rdata(M00_AXI_RDATA), .M00_AXI_rresp(M00_AXI_RRESP),
        .M00_AXI_rlast(M00_AXI_RLAST), .M00_AXI_rvalid(M00_AXI_RVALID), .M00_AXI_rready(M00_AXI_RREADY)
    );
endmodule
