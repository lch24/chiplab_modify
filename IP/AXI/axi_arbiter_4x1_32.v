/*
 * Minimal AXI4 4-to-1 arbiter for the DDR/MIG clock domain.
 *
 * This block assumes all ports are already in the same clock domain and use
 * 32-bit data. Clock-domain crossing and 64/32 width conversion must be done
 * before this arbiter.
 *
 * Supported subset:
 * - AXI4 INCR bursts.
 * - One active read transaction and one active write transaction at a time.
 * - Independent read/write arbitration.
 */
module axi_arbiter_4x1_32 (
    input         aclk,
    input         aresetn,

    input  [3:0]  s0_awid,
    input  [31:0] s0_awaddr,
    input  [7:0]  s0_awlen,
    input  [2:0]  s0_awsize,
    input  [1:0]  s0_awburst,
    input         s0_awlock,
    input  [3:0]  s0_awcache,
    input  [2:0]  s0_awprot,
    input         s0_awvalid,
    output        s0_awready,
    input  [31:0] s0_wdata,
    input  [3:0]  s0_wstrb,
    input         s0_wlast,
    input         s0_wvalid,
    output        s0_wready,
    output [3:0]  s0_bid,
    output [1:0]  s0_bresp,
    output        s0_bvalid,
    input         s0_bready,
    input  [3:0]  s0_arid,
    input  [31:0] s0_araddr,
    input  [7:0]  s0_arlen,
    input  [2:0]  s0_arsize,
    input  [1:0]  s0_arburst,
    input         s0_arlock,
    input  [3:0]  s0_arcache,
    input  [2:0]  s0_arprot,
    input         s0_arvalid,
    output        s0_arready,
    output [3:0]  s0_rid,
    output [31:0] s0_rdata,
    output [1:0]  s0_rresp,
    output        s0_rlast,
    output        s0_rvalid,
    input         s0_rready,

    input  [3:0]  s1_awid,
    input  [31:0] s1_awaddr,
    input  [7:0]  s1_awlen,
    input  [2:0]  s1_awsize,
    input  [1:0]  s1_awburst,
    input         s1_awlock,
    input  [3:0]  s1_awcache,
    input  [2:0]  s1_awprot,
    input         s1_awvalid,
    output        s1_awready,
    input  [31:0] s1_wdata,
    input  [3:0]  s1_wstrb,
    input         s1_wlast,
    input         s1_wvalid,
    output        s1_wready,
    output [3:0]  s1_bid,
    output [1:0]  s1_bresp,
    output        s1_bvalid,
    input         s1_bready,
    input  [3:0]  s1_arid,
    input  [31:0] s1_araddr,
    input  [7:0]  s1_arlen,
    input  [2:0]  s1_arsize,
    input  [1:0]  s1_arburst,
    input         s1_arlock,
    input  [3:0]  s1_arcache,
    input  [2:0]  s1_arprot,
    input         s1_arvalid,
    output        s1_arready,
    output [3:0]  s1_rid,
    output [31:0] s1_rdata,
    output [1:0]  s1_rresp,
    output        s1_rlast,
    output        s1_rvalid,
    input         s1_rready,

    input  [3:0]  s2_awid,
    input  [31:0] s2_awaddr,
    input  [7:0]  s2_awlen,
    input  [2:0]  s2_awsize,
    input  [1:0]  s2_awburst,
    input         s2_awlock,
    input  [3:0]  s2_awcache,
    input  [2:0]  s2_awprot,
    input         s2_awvalid,
    output        s2_awready,
    input  [31:0] s2_wdata,
    input  [3:0]  s2_wstrb,
    input         s2_wlast,
    input         s2_wvalid,
    output        s2_wready,
    output [3:0]  s2_bid,
    output [1:0]  s2_bresp,
    output        s2_bvalid,
    input         s2_bready,
    input  [3:0]  s2_arid,
    input  [31:0] s2_araddr,
    input  [7:0]  s2_arlen,
    input  [2:0]  s2_arsize,
    input  [1:0]  s2_arburst,
    input         s2_arlock,
    input  [3:0]  s2_arcache,
    input  [2:0]  s2_arprot,
    input         s2_arvalid,
    output        s2_arready,
    output [3:0]  s2_rid,
    output [31:0] s2_rdata,
    output [1:0]  s2_rresp,
    output        s2_rlast,
    output        s2_rvalid,
    input         s2_rready,

    input  [3:0]  s3_awid,
    input  [31:0] s3_awaddr,
    input  [7:0]  s3_awlen,
    input  [2:0]  s3_awsize,
    input  [1:0]  s3_awburst,
    input         s3_awlock,
    input  [3:0]  s3_awcache,
    input  [2:0]  s3_awprot,
    input         s3_awvalid,
    output        s3_awready,
    input  [31:0] s3_wdata,
    input  [3:0]  s3_wstrb,
    input         s3_wlast,
    input         s3_wvalid,
    output        s3_wready,
    output [3:0]  s3_bid,
    output [1:0]  s3_bresp,
    output        s3_bvalid,
    input         s3_bready,
    input  [3:0]  s3_arid,
    input  [31:0] s3_araddr,
    input  [7:0]  s3_arlen,
    input  [2:0]  s3_arsize,
    input  [1:0]  s3_arburst,
    input         s3_arlock,
    input  [3:0]  s3_arcache,
    input  [2:0]  s3_arprot,
    input         s3_arvalid,
    output        s3_arready,
    output [3:0]  s3_rid,
    output [31:0] s3_rdata,
    output [1:0]  s3_rresp,
    output        s3_rlast,
    output        s3_rvalid,
    input         s3_rready,

    output [7:0]  m_awid,
    output [31:0] m_awaddr,
    output [7:0]  m_awlen,
    output [2:0]  m_awsize,
    output [1:0]  m_awburst,
    output        m_awlock,
    output [3:0]  m_awcache,
    output [2:0]  m_awprot,
    output        m_awvalid,
    input         m_awready,
    output [31:0] m_wdata,
    output [3:0]  m_wstrb,
    output        m_wlast,
    output        m_wvalid,
    input         m_wready,
    input  [7:0]  m_bid,
    input  [1:0]  m_bresp,
    input         m_bvalid,
    output        m_bready,
    output [7:0]  m_arid,
    output [31:0] m_araddr,
    output [7:0]  m_arlen,
    output [2:0]  m_arsize,
    output [1:0]  m_arburst,
    output        m_arlock,
    output [3:0]  m_arcache,
    output [2:0]  m_arprot,
    output        m_arvalid,
    input         m_arready,
    input  [7:0]  m_rid,
    input  [31:0] m_rdata,
    input  [1:0]  m_rresp,
    input         m_rlast,
    input         m_rvalid,
    output        m_rready
);

localparam PORT0 = 2'd0;
localparam PORT1 = 2'd1;
localparam PORT2 = 2'd2;
localparam PORT3 = 2'd3;

reg [1:0] wr_sel;
reg       wr_active;
reg [1:0] rd_sel;
reg       rd_active;

wire [3:0] aw_req = {s3_awvalid, s2_awvalid, s1_awvalid, s0_awvalid};
wire [3:0] ar_req = {s3_arvalid, s2_arvalid, s1_arvalid, s0_arvalid};

function [1:0] pick_port;
    input [3:0] req;
    begin
        if (req[0])
            pick_port = PORT0;
        else if (req[1])
            pick_port = PORT1;
        else if (req[2])
            pick_port = PORT2;
        else
            pick_port = PORT3;
    end
endfunction

wire [1:0] aw_pick = pick_port(aw_req);
wire [1:0] ar_pick = pick_port(ar_req);
wire [1:0] aw_mux_sel = wr_active ? wr_sel : aw_pick;
wire [1:0] ar_mux_sel = rd_active ? rd_sel : ar_pick;

wire aw_mux_valid = (aw_mux_sel == PORT0) ? s0_awvalid :
                    (aw_mux_sel == PORT1) ? s1_awvalid :
                    (aw_mux_sel == PORT2) ? s2_awvalid : s3_awvalid;
wire ar_mux_valid = (ar_mux_sel == PORT0) ? s0_arvalid :
                    (ar_mux_sel == PORT1) ? s1_arvalid :
                    (ar_mux_sel == PORT2) ? s2_arvalid : s3_arvalid;

assign m_awid    = {4'd0, (aw_mux_sel == PORT0) ? s0_awid :
                          (aw_mux_sel == PORT1) ? s1_awid :
                          (aw_mux_sel == PORT2) ? s2_awid : s3_awid};
assign m_awaddr  = (aw_mux_sel == PORT0) ? s0_awaddr :
                   (aw_mux_sel == PORT1) ? s1_awaddr :
                   (aw_mux_sel == PORT2) ? s2_awaddr : s3_awaddr;
assign m_awlen   = (aw_mux_sel == PORT0) ? s0_awlen :
                   (aw_mux_sel == PORT1) ? s1_awlen :
                   (aw_mux_sel == PORT2) ? s2_awlen : s3_awlen;
assign m_awsize  = (aw_mux_sel == PORT0) ? s0_awsize :
                   (aw_mux_sel == PORT1) ? s1_awsize :
                   (aw_mux_sel == PORT2) ? s2_awsize : s3_awsize;
assign m_awburst = (aw_mux_sel == PORT0) ? s0_awburst :
                   (aw_mux_sel == PORT1) ? s1_awburst :
                   (aw_mux_sel == PORT2) ? s2_awburst : s3_awburst;
assign m_awlock  = (aw_mux_sel == PORT0) ? s0_awlock :
                   (aw_mux_sel == PORT1) ? s1_awlock :
                   (aw_mux_sel == PORT2) ? s2_awlock : s3_awlock;
assign m_awcache = (aw_mux_sel == PORT0) ? s0_awcache :
                   (aw_mux_sel == PORT1) ? s1_awcache :
                   (aw_mux_sel == PORT2) ? s2_awcache : s3_awcache;
assign m_awprot  = (aw_mux_sel == PORT0) ? s0_awprot :
                   (aw_mux_sel == PORT1) ? s1_awprot :
                   (aw_mux_sel == PORT2) ? s2_awprot : s3_awprot;
assign m_awvalid = !wr_active && aw_mux_valid;

assign s0_awready = !wr_active && (aw_mux_sel == PORT0) && m_awready;
assign s1_awready = !wr_active && (aw_mux_sel == PORT1) && m_awready;
assign s2_awready = !wr_active && (aw_mux_sel == PORT2) && m_awready;
assign s3_awready = !wr_active && (aw_mux_sel == PORT3) && m_awready;

assign m_wdata  = (wr_sel == PORT0) ? s0_wdata :
                  (wr_sel == PORT1) ? s1_wdata :
                  (wr_sel == PORT2) ? s2_wdata : s3_wdata;
assign m_wstrb  = (wr_sel == PORT0) ? s0_wstrb :
                  (wr_sel == PORT1) ? s1_wstrb :
                  (wr_sel == PORT2) ? s2_wstrb : s3_wstrb;
assign m_wlast  = (wr_sel == PORT0) ? s0_wlast :
                  (wr_sel == PORT1) ? s1_wlast :
                  (wr_sel == PORT2) ? s2_wlast : s3_wlast;
assign m_wvalid = wr_active && ((wr_sel == PORT0) ? s0_wvalid :
                                (wr_sel == PORT1) ? s1_wvalid :
                                (wr_sel == PORT2) ? s2_wvalid : s3_wvalid);

assign s0_wready = wr_active && (wr_sel == PORT0) && m_wready;
assign s1_wready = wr_active && (wr_sel == PORT1) && m_wready;
assign s2_wready = wr_active && (wr_sel == PORT2) && m_wready;
assign s3_wready = wr_active && (wr_sel == PORT3) && m_wready;

assign m_bready = (wr_sel == PORT0) ? s0_bready :
                  (wr_sel == PORT1) ? s1_bready :
                  (wr_sel == PORT2) ? s2_bready : s3_bready;

assign s0_bid    = m_bid[3:0];
assign s1_bid    = m_bid[3:0];
assign s2_bid    = m_bid[3:0];
assign s3_bid    = m_bid[3:0];
assign s0_bresp  = m_bresp;
assign s1_bresp  = m_bresp;
assign s2_bresp  = m_bresp;
assign s3_bresp  = m_bresp;
assign s0_bvalid = wr_active && (wr_sel == PORT0) && m_bvalid;
assign s1_bvalid = wr_active && (wr_sel == PORT1) && m_bvalid;
assign s2_bvalid = wr_active && (wr_sel == PORT2) && m_bvalid;
assign s3_bvalid = wr_active && (wr_sel == PORT3) && m_bvalid;

assign m_arid    = {4'd0, (ar_mux_sel == PORT0) ? s0_arid :
                          (ar_mux_sel == PORT1) ? s1_arid :
                          (ar_mux_sel == PORT2) ? s2_arid : s3_arid};
assign m_araddr  = (ar_mux_sel == PORT0) ? s0_araddr :
                   (ar_mux_sel == PORT1) ? s1_araddr :
                   (ar_mux_sel == PORT2) ? s2_araddr : s3_araddr;
assign m_arlen   = (ar_mux_sel == PORT0) ? s0_arlen :
                   (ar_mux_sel == PORT1) ? s1_arlen :
                   (ar_mux_sel == PORT2) ? s2_arlen : s3_arlen;
assign m_arsize  = (ar_mux_sel == PORT0) ? s0_arsize :
                   (ar_mux_sel == PORT1) ? s1_arsize :
                   (ar_mux_sel == PORT2) ? s2_arsize : s3_arsize;
assign m_arburst = (ar_mux_sel == PORT0) ? s0_arburst :
                   (ar_mux_sel == PORT1) ? s1_arburst :
                   (ar_mux_sel == PORT2) ? s2_arburst : s3_arburst;
assign m_arlock  = (ar_mux_sel == PORT0) ? s0_arlock :
                   (ar_mux_sel == PORT1) ? s1_arlock :
                   (ar_mux_sel == PORT2) ? s2_arlock : s3_arlock;
assign m_arcache = (ar_mux_sel == PORT0) ? s0_arcache :
                   (ar_mux_sel == PORT1) ? s1_arcache :
                   (ar_mux_sel == PORT2) ? s2_arcache : s3_arcache;
assign m_arprot  = (ar_mux_sel == PORT0) ? s0_arprot :
                   (ar_mux_sel == PORT1) ? s1_arprot :
                   (ar_mux_sel == PORT2) ? s2_arprot : s3_arprot;
assign m_arvalid = !rd_active && ar_mux_valid;

assign s0_arready = !rd_active && (ar_mux_sel == PORT0) && m_arready;
assign s1_arready = !rd_active && (ar_mux_sel == PORT1) && m_arready;
assign s2_arready = !rd_active && (ar_mux_sel == PORT2) && m_arready;
assign s3_arready = !rd_active && (ar_mux_sel == PORT3) && m_arready;

assign m_rready = (rd_sel == PORT0) ? s0_rready :
                  (rd_sel == PORT1) ? s1_rready :
                  (rd_sel == PORT2) ? s2_rready : s3_rready;

assign s0_rid    = m_rid[3:0];
assign s1_rid    = m_rid[3:0];
assign s2_rid    = m_rid[3:0];
assign s3_rid    = m_rid[3:0];
assign s0_rdata  = m_rdata;
assign s1_rdata  = m_rdata;
assign s2_rdata  = m_rdata;
assign s3_rdata  = m_rdata;
assign s0_rresp  = m_rresp;
assign s1_rresp  = m_rresp;
assign s2_rresp  = m_rresp;
assign s3_rresp  = m_rresp;
assign s0_rlast  = m_rlast;
assign s1_rlast  = m_rlast;
assign s2_rlast  = m_rlast;
assign s3_rlast  = m_rlast;
assign s0_rvalid = rd_active && (rd_sel == PORT0) && m_rvalid;
assign s1_rvalid = rd_active && (rd_sel == PORT1) && m_rvalid;
assign s2_rvalid = rd_active && (rd_sel == PORT2) && m_rvalid;
assign s3_rvalid = rd_active && (rd_sel == PORT3) && m_rvalid;

always @(posedge aclk) begin
    if (!aresetn) begin
        wr_sel    <= PORT0;
        wr_active <= 1'b0;
        rd_sel    <= PORT0;
        rd_active <= 1'b0;
    end else begin
        if (!wr_active && m_awvalid && m_awready) begin
            wr_sel    <= aw_mux_sel;
            wr_active <= 1'b1;
        end else if (wr_active && m_bvalid && m_bready) begin
            wr_active <= 1'b0;
        end

        if (!rd_active && m_arvalid && m_arready) begin
            rd_sel    <= ar_mux_sel;
            rd_active <= 1'b1;
        end else if (rd_active && m_rvalid && m_rready && m_rlast) begin
            rd_active <= 1'b0;
        end
    end
end

endmodule
