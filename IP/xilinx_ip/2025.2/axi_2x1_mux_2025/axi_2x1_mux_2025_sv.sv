// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
// -------------------------------------------------------------------------------
// This file contains confidential and proprietary information
// of AMD and is protected under U.S. and international copyright
// and other intellectual property laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// AMD, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) AMD shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or AMD had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// AMD products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of AMD products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
// DO NOT MODIFY THIS FILE.

// MODULE VLNV: xilinx.com:ip:axi_crossbar:2.1

`timescale 1ps / 1ps

`include "vivado_interfaces.svh"

module axi_2x1_mux_2025_sv (
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI" *)
  (* X_INTERFACE_MODE = "slave S00_AXI" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S00_AXI, DATA_WIDTH 32, PROTOCOL AXI3, FREQ_HZ 100000000, ID_WIDTH 4, ADDR_WIDTH 32, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 16, PHASE 0.0, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
  vivado_aximm_v1_0.slave S00_AXI,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI" *)
  (* X_INTERFACE_MODE = "master M00_AXI" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M00_AXI, DATA_WIDTH 32, PROTOCOL AXI3, FREQ_HZ 100000000, ID_WIDTH 4, ADDR_WIDTH 32, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 16, PHASE 0.0, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
  vivado_aximm_v1_0.master M00_AXI,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S01_AXI" *)
  (* X_INTERFACE_MODE = "slave S01_AXI" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S01_AXI, DATA_WIDTH 32, PROTOCOL AXI3, FREQ_HZ 100000000, ID_WIDTH 4, ADDR_WIDTH 32, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 16, PHASE 0.0, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
  vivado_aximm_v1_0.slave S01_AXI,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire aclk,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire aresetn
);

  // interface wire assignments
  wire [63:0] s_axi_araddr;
  assign s_axi_araddr[31:0] = S00_AXI.ARADDR;
  assign s_axi_araddr[63:32] = S01_AXI.ARADDR;
  wire [3:0] s_axi_arburst;
  assign s_axi_arburst[1:0] = S00_AXI.ARBURST;
  assign s_axi_arburst[3:2] = S01_AXI.ARBURST;
  wire [7:0] s_axi_arcache;
  assign s_axi_arcache[3:0] = S00_AXI.ARCACHE;
  assign s_axi_arcache[7:4] = S01_AXI.ARCACHE;
  wire [7:0] s_axi_arid;
  assign s_axi_arid[3:0] = S00_AXI.ARID;
  assign s_axi_arid[7:4] = S01_AXI.ARID;
  wire [7:0] s_axi_arlen;
  assign s_axi_arlen[3:0] = S00_AXI.ARLEN;
  assign s_axi_arlen[7:4] = S01_AXI.ARLEN;
  wire [3:0] s_axi_arlock;
  assign s_axi_arlock[1:0] = S00_AXI.ARLOCK;
  assign s_axi_arlock[3:2] = S01_AXI.ARLOCK;
  wire [5:0] s_axi_arprot;
  assign s_axi_arprot[2:0] = S00_AXI.ARPROT;
  assign s_axi_arprot[5:3] = S01_AXI.ARPROT;
  wire [7:0] s_axi_arqos;
  assign s_axi_arqos[3:0] = S00_AXI.ARQOS;
  assign s_axi_arqos[7:4] = S01_AXI.ARQOS;
  wire [1:0] s_axi_arready;
  assign s_axi_arready[0:0] = S00_AXI.ARREADY;
  assign s_axi_arready[1:1] = S01_AXI.ARREADY;
  wire [5:0] s_axi_arsize;
  assign s_axi_arsize[2:0] = S00_AXI.ARSIZE;
  assign s_axi_arsize[5:3] = S01_AXI.ARSIZE;
  wire [1:0] s_axi_arvalid;
  assign s_axi_arvalid[0:0] = S00_AXI.ARVALID;
  assign s_axi_arvalid[1:1] = S01_AXI.ARVALID;
  wire [63:0] s_axi_awaddr;
  assign s_axi_awaddr[31:0] = S00_AXI.AWADDR;
  assign s_axi_awaddr[63:32] = S01_AXI.AWADDR;
  wire [3:0] s_axi_awburst;
  assign s_axi_awburst[1:0] = S00_AXI.AWBURST;
  assign s_axi_awburst[3:2] = S01_AXI.AWBURST;
  wire [7:0] s_axi_awcache;
  assign s_axi_awcache[3:0] = S00_AXI.AWCACHE;
  assign s_axi_awcache[7:4] = S01_AXI.AWCACHE;
  wire [7:0] s_axi_awid;
  assign s_axi_awid[3:0] = S00_AXI.AWID;
  assign s_axi_awid[7:4] = S01_AXI.AWID;
  wire [7:0] s_axi_awlen;
  assign s_axi_awlen[3:0] = S00_AXI.AWLEN;
  assign s_axi_awlen[7:4] = S01_AXI.AWLEN;
  wire [3:0] s_axi_awlock;
  assign s_axi_awlock[1:0] = S00_AXI.AWLOCK;
  assign s_axi_awlock[3:2] = S01_AXI.AWLOCK;
  wire [5:0] s_axi_awprot;
  assign s_axi_awprot[2:0] = S00_AXI.AWPROT;
  assign s_axi_awprot[5:3] = S01_AXI.AWPROT;
  wire [7:0] s_axi_awqos;
  assign s_axi_awqos[3:0] = S00_AXI.AWQOS;
  assign s_axi_awqos[7:4] = S01_AXI.AWQOS;
  wire [1:0] s_axi_awready;
  assign s_axi_awready[0:0] = S00_AXI.AWREADY;
  assign s_axi_awready[1:1] = S01_AXI.AWREADY;
  wire [5:0] s_axi_awsize;
  assign s_axi_awsize[2:0] = S00_AXI.AWSIZE;
  assign s_axi_awsize[5:3] = S01_AXI.AWSIZE;
  wire [1:0] s_axi_awvalid;
  assign s_axi_awvalid[0:0] = S00_AXI.AWVALID;
  assign s_axi_awvalid[1:1] = S01_AXI.AWVALID;
  wire [7:0] s_axi_bid;
  assign s_axi_bid[3:0] = S00_AXI.BID;
  assign s_axi_bid[7:4] = S01_AXI.BID;
  wire [1:0] s_axi_bready;
  assign s_axi_bready[0:0] = S00_AXI.BREADY;
  assign s_axi_bready[1:1] = S01_AXI.BREADY;
  wire [3:0] s_axi_bresp;
  assign s_axi_bresp[1:0] = S00_AXI.BRESP;
  assign s_axi_bresp[3:2] = S01_AXI.BRESP;
  wire [1:0] s_axi_bvalid;
  assign s_axi_bvalid[0:0] = S00_AXI.BVALID;
  assign s_axi_bvalid[1:1] = S01_AXI.BVALID;
  wire [63:0] s_axi_rdata;
  assign s_axi_rdata[31:0] = S00_AXI.RDATA;
  assign s_axi_rdata[63:32] = S01_AXI.RDATA;
  wire [7:0] s_axi_rid;
  assign s_axi_rid[3:0] = S00_AXI.RID;
  assign s_axi_rid[7:4] = S01_AXI.RID;
  wire [1:0] s_axi_rlast;
  assign s_axi_rlast[0:0] = S00_AXI.RLAST;
  assign s_axi_rlast[1:1] = S01_AXI.RLAST;
  wire [1:0] s_axi_rready;
  assign s_axi_rready[0:0] = S00_AXI.RREADY;
  assign s_axi_rready[1:1] = S01_AXI.RREADY;
  wire [3:0] s_axi_rresp;
  assign s_axi_rresp[1:0] = S00_AXI.RRESP;
  assign s_axi_rresp[3:2] = S01_AXI.RRESP;
  wire [1:0] s_axi_rvalid;
  assign s_axi_rvalid[0:0] = S00_AXI.RVALID;
  assign s_axi_rvalid[1:1] = S01_AXI.RVALID;
  wire [63:0] s_axi_wdata;
  assign s_axi_wdata[31:0] = S00_AXI.WDATA;
  assign s_axi_wdata[63:32] = S01_AXI.WDATA;
  wire [7:0] s_axi_wid;
  assign s_axi_wid[3:0] = S00_AXI.WID;
  assign s_axi_wid[7:4] = S01_AXI.WID;
  wire [1:0] s_axi_wlast;
  assign s_axi_wlast[0:0] = S00_AXI.WLAST;
  assign s_axi_wlast[1:1] = S01_AXI.WLAST;
  wire [1:0] s_axi_wready;
  assign s_axi_wready[0:0] = S00_AXI.WREADY;
  assign s_axi_wready[1:1] = S01_AXI.WREADY;
  wire [7:0] s_axi_wstrb;
  assign s_axi_wstrb[3:0] = S00_AXI.WSTRB;
  assign s_axi_wstrb[7:4] = S01_AXI.WSTRB;
  wire [1:0] s_axi_wvalid;
  assign s_axi_wvalid[0:0] = S00_AXI.WVALID;
  assign s_axi_wvalid[1:1] = S01_AXI.WVALID;
  assign S00_AXI.BUSER = 0;
  assign S00_AXI.RUSER = 0;
  assign M00_AXI.ARREGION = 0;
  assign M00_AXI.ARUSER = 0;
  assign M00_AXI.AWREGION = 0;
  assign M00_AXI.AWUSER = 0;
  assign M00_AXI.WUSER = 0;
  assign S01_AXI.BUSER = 0;
  assign S01_AXI.RUSER = 0;

  axi_2x1_mux_2025 inst (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axi_awid(s_axi_awid),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awlen(s_axi_awlen),
    .s_axi_awsize(s_axi_awsize),
    .s_axi_awburst(s_axi_awburst),
    .s_axi_awlock(s_axi_awlock),
    .s_axi_awcache(s_axi_awcache),
    .s_axi_awprot(s_axi_awprot),
    .s_axi_awqos(s_axi_awqos),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wid(s_axi_wid),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wlast(s_axi_wlast),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bid(s_axi_bid),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .s_axi_arid(s_axi_arid),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arlen(s_axi_arlen),
    .s_axi_arsize(s_axi_arsize),
    .s_axi_arburst(s_axi_arburst),
    .s_axi_arlock(s_axi_arlock),
    .s_axi_arcache(s_axi_arcache),
    .s_axi_arprot(s_axi_arprot),
    .s_axi_arqos(s_axi_arqos),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rid(s_axi_rid),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rlast(s_axi_rlast),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),
    .m_axi_awid(M00_AXI.AWID),
    .m_axi_awaddr(M00_AXI.AWADDR),
    .m_axi_awlen(M00_AXI.AWLEN),
    .m_axi_awsize(M00_AXI.AWSIZE),
    .m_axi_awburst(M00_AXI.AWBURST),
    .m_axi_awlock(M00_AXI.AWLOCK),
    .m_axi_awcache(M00_AXI.AWCACHE),
    .m_axi_awprot(M00_AXI.AWPROT),
    .m_axi_awqos(M00_AXI.AWQOS),
    .m_axi_awvalid(M00_AXI.AWVALID),
    .m_axi_awready(M00_AXI.AWREADY),
    .m_axi_wid(M00_AXI.WID),
    .m_axi_wdata(M00_AXI.WDATA),
    .m_axi_wstrb(M00_AXI.WSTRB),
    .m_axi_wlast(M00_AXI.WLAST),
    .m_axi_wvalid(M00_AXI.WVALID),
    .m_axi_wready(M00_AXI.WREADY),
    .m_axi_bid(M00_AXI.BID),
    .m_axi_bresp(M00_AXI.BRESP),
    .m_axi_bvalid(M00_AXI.BVALID),
    .m_axi_bready(M00_AXI.BREADY),
    .m_axi_arid(M00_AXI.ARID),
    .m_axi_araddr(M00_AXI.ARADDR),
    .m_axi_arlen(M00_AXI.ARLEN),
    .m_axi_arsize(M00_AXI.ARSIZE),
    .m_axi_arburst(M00_AXI.ARBURST),
    .m_axi_arlock(M00_AXI.ARLOCK),
    .m_axi_arcache(M00_AXI.ARCACHE),
    .m_axi_arprot(M00_AXI.ARPROT),
    .m_axi_arqos(M00_AXI.ARQOS),
    .m_axi_arvalid(M00_AXI.ARVALID),
    .m_axi_arready(M00_AXI.ARREADY),
    .m_axi_rid(M00_AXI.RID),
    .m_axi_rdata(M00_AXI.RDATA),
    .m_axi_rresp(M00_AXI.RRESP),
    .m_axi_rlast(M00_AXI.RLAST),
    .m_axi_rvalid(M00_AXI.RVALID),
    .m_axi_rready(M00_AXI.RREADY)
  );

endmodule
