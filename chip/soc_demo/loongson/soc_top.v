/*------------------------------------------------------------------------------
--------------------------------------------------------------------------------
Copyright (c) 2016, Loongson Technology Corporation Limited.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this 
list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, 
this list of conditions and the following disclaimer in the documentation and/or
other materials provided with the distribution.

3. Neither the name of Loongson Technology Corporation Limited nor the names of 
its contributors may be used to endorse or promote products derived from this 
software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
DISCLAIMED. IN NO EVENT SHALL LOONGSON TECHNOLOGY CORPORATION LIMITED BE LIABLE
TO ANY PARTY FOR DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE 
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--------------------------------------------------------------------------------
------------------------------------------------------------------------------*/

`include "config.h"

module soc_top(
    input         resetn, 
    input         clk,

    //------gpio----------------
    output [15:0] led,
    output [1 :0] led_rg0,
    output [1 :0] led_rg1,
    output [7 :0] num_csn,
    output [6 :0] num_a_g,
    input  [7 :0] switch, 
    output [3 :0] btn_key_col,
    input  [3 :0] btn_key_row,
    input  [1 :0] btn_step,

    //------DDR3 interface------
    inout  [15:0] ddr3_dq,
    output [12:0] ddr3_addr,
    output [2 :0] ddr3_ba,
    output        ddr3_ras_n,
    output        ddr3_cas_n,
    output        ddr3_we_n,
    output        ddr3_odt,
    output        ddr3_reset_n,
    output        ddr3_cke,
    output [1:0]  ddr3_dm,
    inout  [1:0]  ddr3_dqs_p,
    inout  [1:0]  ddr3_dqs_n,
    output        ddr3_ck_p,
    output        ddr3_ck_n,

    //------mac controller-------
    //TX
    input         mtxclk_0,     
    output        mtxen_0,      
    output [3:0]  mtxd_0,       
    output        mtxerr_0,
    //RX
    input         mrxclk_0,      
    input         mrxdv_0,     
    input  [3:0]  mrxd_0,        
    input         mrxerr_0,
    input         mcoll_0,
    input         mcrs_0,
    // MIIM
    output        mdc_0,
    inout         mdio_0,
    
    output        phy_rstn,
 
    //------EJTAG-------
    input         EJTAG_TRST,
    input         EJTAG_TCK,
    input         EJTAG_TDI,
    input         EJTAG_TMS,
    output        EJTAG_TDO,

    //------uart-------
    inout         UART_RX,
    inout         UART_TX,

    //------debug-uart------
    input         UART_RX2,
    output        UART_TX2,

    //------nand-------
    output        NAND_CLE ,
    output        NAND_ALE ,
    input         NAND_RDY ,
    inout [7:0]   NAND_DATA,
    output        NAND_RD  ,
    output        NAND_CE  ,  //low active
    output        NAND_WR  ,  
       
    //------spi flash-------
    output        SPI_CLK,
    output        SPI_CS,
    inout         SPI_MISO,
    inout         SPI_MOSI,

    //------lcd-------
    output        lcd_rst,       // LCD reset (active low)
    output        lcd_cs,        // LCD chip select (active low, tied to 0)
    output        lcd_rs,        // LCD command/data select (0=cmd, 1=data)
    output        lcd_wr,        // LCD write strobe (active low)
    output        lcd_rd,        // LCD read strobe (tied to 1)
    output        lcd_bl_ctr,    // LCD backlight control
    output [15:0] lcd_data,      // LCD 16-bit data bus (DB1-DB17)
    input         lcd_t_pen,     // Touch screen interrupt
    inout         lcd_t_mosi,    // Touch screen SPI data
    output        lcd_t_clk,     // Touch screen SPI clock
    output        lcd_t_cs_rst,   // Touch screen chip select/reset

    //------USB3500 UTMI+------
    input         USB_CLKOUT,
    inout  [7:0]  USB_DATA,
    output        USB_TXVALID,
    input         USB_TXREADY,
    input         USB_RXVALID,
    input         USB_RXACTIVE,
    input         USB_RXERROR,
    input  [1:0]  USB_LINESTATE,
    output [1:0]  USB_XCVRSEL,
    output        USB_TERMSEL,
    output [1:0]  USB_OPMODE,
    output        USB_SUSPENDN,
    output        USB_PHY_RESET,
    output        USB_DPPD,
    output        USB_DMPD,
    output        USB_CHRGVBUS,
    output        USB_DISCHRGVBUS,
    output        USB_IDPULLUP,
    input         USB_VBUSVLD,
    input         USB_SESSVLD,
    input         USB_SESSEND,
    input         USB_HOSTDISC,
    input         USB_IDDIG,

    //------ps2-------
    inout         PS2_CLK,
    inout         PS2_DATA
);
wire        aclk;
wire        aresetn;
wire        cpu_clk;
wire        uncore_clk;

// Software reset is requested through CONFREG at 0x1fd0_f034.  CONFREG and
// this controller both run on aclk, so the request does not cross a clock
// boundary.  The controller is reset only by the external reset pin; the
// software-generated reset therefore cannot truncate its own pulse.
wire        soft_reset_req;
reg         soft_reset_req_d;
reg  [8:0]  soft_reset_count;
reg         system_resetn;

always @(posedge aclk or negedge resetn) begin
    if (!resetn) begin
        soft_reset_req_d  <= 1'b0;
        soft_reset_count  <= 9'd0;
        system_resetn     <= 1'b0;
    end else begin
        soft_reset_req_d <= soft_reset_req;

        if (soft_reset_req && !soft_reset_req_d) begin
            system_resetn    <= 1'b0;
            soft_reset_count <= 9'd329; // 10 us at 33 MHz
        end else if (!system_resetn) begin
            if (soft_reset_count == 9'd0) begin
                system_resetn <= 1'b1;
            end else begin
                soft_reset_count <= soft_reset_count - 9'd1;
            end
        end
    end
end

wire [`LID         -1 :0] m0_awid;
wire [`Lawaddr     -1 :0] m0_awaddr;
wire [`Lawlen      -1 :0] m0_awlen;
wire [`Lawsize     -1 :0] m0_awsize;
wire [`Lawburst    -1 :0] m0_awburst;
wire [`Lawlock     -1 :0] m0_awlock;
wire [`Lawcache    -1 :0] m0_awcache;
wire [`Lawprot     -1 :0] m0_awprot;
wire                      m0_awvalid;
wire                      m0_awready;
wire [`LID         -1 :0] m0_wid;
wire [`Lwdata      -1 :0] m0_wdata;
wire [`Lwstrb      -1 :0] m0_wstrb;
wire                      m0_wlast;
wire                      m0_wvalid;
wire                      m0_wready;
wire [`LID         -1 :0] m0_bid;
wire [`Lbresp      -1 :0] m0_bresp;
wire                      m0_bvalid;
wire                      m0_bready;
wire [`LID         -1 :0] m0_arid;
wire [`Laraddr     -1 :0] m0_araddr;
wire [`Larlen      -1 :0] m0_arlen;
wire [`Larsize     -1 :0] m0_arsize;
wire [`Larburst    -1 :0] m0_arburst;
wire [`Larlock     -1 :0] m0_arlock;
wire [`Larcache    -1 :0] m0_arcache;
wire [`Larprot     -1 :0] m0_arprot;
wire                      m0_arvalid;
wire                      m0_arready;
wire [`LID         -1 :0] m0_rid;
wire [`Lrdata      -1 :0] m0_rdata;
wire [`Lrresp      -1 :0] m0_rresp;
wire                      m0_rlast;
wire                      m0_rvalid;
wire                      m0_rready;

wire [`LID         -1 :0] m0_async_awid;
wire [`Lawaddr     -1 :0] m0_async_awaddr;
wire [`Lawlen      -1 :0] m0_async_awlen;
wire [`Lawsize     -1 :0] m0_async_awsize;
wire [`Lawburst    -1 :0] m0_async_awburst;
wire [`Lawlock     -1 :0] m0_async_awlock;
wire [`Lawcache    -1 :0] m0_async_awcache;
wire [`Lawprot     -1 :0] m0_async_awprot;
wire                      m0_async_awvalid;
wire                      m0_async_awready;
wire [`LID         -1 :0] m0_async_wid;
wire [`Lwdata      -1 :0] m0_async_wdata;
wire [`Lwstrb      -1 :0] m0_async_wstrb;
wire                      m0_async_wlast;
wire                      m0_async_wvalid;
wire                      m0_async_wready;
wire [`LID         -1 :0] m0_async_bid;
wire [`Lbresp      -1 :0] m0_async_bresp;
wire                      m0_async_bvalid;
wire                      m0_async_bready;
wire [`LID         -1 :0] m0_async_arid;
wire [`Laraddr     -1 :0] m0_async_araddr;
wire [`Larlen      -1 :0] m0_async_arlen;
wire [`Larsize     -1 :0] m0_async_arsize;
wire [`Larburst    -1 :0] m0_async_arburst;
wire [`Larlock     -1 :0] m0_async_arlock;
wire [`Larcache    -1 :0] m0_async_arcache;
wire [`Larprot     -1 :0] m0_async_arprot;
wire                      m0_async_arvalid;
wire                      m0_async_arready;
wire [`LID         -1 :0] m0_async_rid;
wire [`Lrdata      -1 :0] m0_async_rdata;
wire [`Lrresp      -1 :0] m0_async_rresp;
wire                      m0_async_rlast;
wire                      m0_async_rvalid;
wire                      m0_async_rready;

wire [`LID         -1 :0] spi_s_awid;
wire [`Lawaddr     -1 :0] spi_s_awaddr;
wire [`Lawlen      -1 :0] spi_s_awlen;
wire [`Lawsize     -1 :0] spi_s_awsize;
wire [`Lawburst    -1 :0] spi_s_awburst;
wire [`Lawlock     -1 :0] spi_s_awlock;
wire [`Lawcache    -1 :0] spi_s_awcache;
wire [`Lawprot     -1 :0] spi_s_awprot;
wire                      spi_s_awvalid;
wire                      spi_s_awready;
wire [`LID         -1 :0] spi_s_wid;
wire [`Lwdata      -1 :0] spi_s_wdata;
wire [`Lwstrb      -1 :0] spi_s_wstrb;
wire                      spi_s_wlast;
wire                      spi_s_wvalid;
wire                      spi_s_wready;
wire [`LID         -1 :0] spi_s_bid;
wire [`Lbresp      -1 :0] spi_s_bresp;
wire                      spi_s_bvalid;
wire                      spi_s_bready;
wire [`LID         -1 :0] spi_s_arid;
wire [`Laraddr     -1 :0] spi_s_araddr;
wire [`Larlen      -1 :0] spi_s_arlen;
wire [`Larsize     -1 :0] spi_s_arsize;
wire [`Larburst    -1 :0] spi_s_arburst;
wire [`Larlock     -1 :0] spi_s_arlock;
wire [`Larcache    -1 :0] spi_s_arcache;
wire [`Larprot     -1 :0] spi_s_arprot;
wire                      spi_s_arvalid;
wire                      spi_s_arready;
wire [`LID         -1 :0] spi_s_rid;
wire [`Lrdata      -1 :0] spi_s_rdata;
wire [`Lrresp      -1 :0] spi_s_rresp;
wire                      spi_s_rlast;
wire                      spi_s_rvalid;
wire                      spi_s_rready;

wire [`LID         -1 :0] conf_s_awid;
wire [`Lawaddr     -1 :0] conf_s_awaddr;
wire [`Lawlen      -1 :0] conf_s_awlen;
wire [`Lawsize     -1 :0] conf_s_awsize;
wire [`Lawburst    -1 :0] conf_s_awburst;
wire [`Lawlock     -1 :0] conf_s_awlock;
wire [`Lawcache    -1 :0] conf_s_awcache;
wire [`Lawprot     -1 :0] conf_s_awprot;
wire                      conf_s_awvalid;
wire                      conf_s_awready;
wire [`LID         -1 :0] conf_s_wid;
wire [`Lwdata      -1 :0] conf_s_wdata;
wire [`Lwstrb      -1 :0] conf_s_wstrb;
wire                      conf_s_wlast;
wire                      conf_s_wvalid;
wire                      conf_s_wready;
wire [`LID         -1 :0] conf_s_bid;
wire [`Lbresp      -1 :0] conf_s_bresp;
wire                      conf_s_bvalid;
wire                      conf_s_bready;
wire [`LID         -1 :0] conf_s_arid;
wire [`Laraddr     -1 :0] conf_s_araddr;
wire [`Larlen      -1 :0] conf_s_arlen;
wire [`Larsize     -1 :0] conf_s_arsize;
wire [`Larburst    -1 :0] conf_s_arburst;
wire [`Larlock     -1 :0] conf_s_arlock;
wire [`Larcache    -1 :0] conf_s_arcache;
wire [`Larprot     -1 :0] conf_s_arprot;
wire                      conf_s_arvalid;
wire                      conf_s_arready;
wire [`LID         -1 :0] conf_s_rid;
wire [`Lrdata      -1 :0] conf_s_rdata;
wire [`Lrresp      -1 :0] conf_s_rresp;
wire                      conf_s_rlast;
wire                      conf_s_rvalid;
wire                      conf_s_rready;

wire [`LID         -1 :0] mac_s_awid;
wire [`Lawaddr     -1 :0] mac_s_awaddr;
wire [`Lawlen      -1 :0] mac_s_awlen;
wire [`Lawsize     -1 :0] mac_s_awsize;
wire [`Lawburst    -1 :0] mac_s_awburst;
wire [`Lawlock     -1 :0] mac_s_awlock;
wire [`Lawcache    -1 :0] mac_s_awcache;
wire [`Lawprot     -1 :0] mac_s_awprot;
wire                      mac_s_awvalid;
wire                      mac_s_awready;
wire [`LID         -1 :0] mac_s_wid;
wire [`Lwdata      -1 :0] mac_s_wdata;
wire [`Lwstrb      -1 :0] mac_s_wstrb;
wire                      mac_s_wlast;
wire                      mac_s_wvalid;
wire                      mac_s_wready;
wire [`LID         -1 :0] mac_s_bid;
wire [`Lbresp      -1 :0] mac_s_bresp;
wire                      mac_s_bvalid;
wire                      mac_s_bready;
wire [`LID         -1 :0] mac_s_arid;
wire [`Laraddr     -1 :0] mac_s_araddr;
wire [`Larlen      -1 :0] mac_s_arlen;
wire [`Larsize     -1 :0] mac_s_arsize;
wire [`Larburst    -1 :0] mac_s_arburst;
wire [`Larlock     -1 :0] mac_s_arlock;
wire [`Larcache    -1 :0] mac_s_arcache;
wire [`Larprot     -1 :0] mac_s_arprot;
wire                      mac_s_arvalid;
wire                      mac_s_arready;
wire [`LID         -1 :0] mac_s_rid;
wire [`Lrdata      -1 :0] mac_s_rdata;
wire [`Lrresp      -1 :0] mac_s_rresp;
wire                      mac_s_rlast;
wire                      mac_s_rvalid;
wire                      mac_s_rready;

wire [`LID         -1 :0] lcd_s_awid;
wire [`Lawaddr     -1 :0] lcd_s_awaddr;
wire [`Lawlen      -1 :0] lcd_s_awlen;
wire [`Lawsize     -1 :0] lcd_s_awsize;
wire [`Lawburst    -1 :0] lcd_s_awburst;
wire [`Lawlock     -1 :0] lcd_s_awlock;
wire [`Lawcache    -1 :0] lcd_s_awcache;
wire [`Lawprot     -1 :0] lcd_s_awprot;
wire                      lcd_s_awvalid;
wire                      lcd_s_awready;
wire [`LID         -1 :0] lcd_s_wid;
wire [`Lwdata      -1 :0] lcd_s_wdata;
wire [`Lwstrb      -1 :0] lcd_s_wstrb;
wire                      lcd_s_wlast;
wire                      lcd_s_wvalid;
wire                      lcd_s_wready;
wire [`LID         -1 :0] lcd_s_bid;
wire [`Lbresp      -1 :0] lcd_s_bresp;
wire                      lcd_s_bvalid;
wire                      lcd_s_bready;
wire [`LID         -1 :0] lcd_s_arid;
wire [`Laraddr     -1 :0] lcd_s_araddr;
wire [`Larlen      -1 :0] lcd_s_arlen;
wire [`Larsize     -1 :0] lcd_s_arsize;
wire [`Larburst    -1 :0] lcd_s_arburst;
wire [`Larlock     -1 :0] lcd_s_arlock;
wire [`Larcache    -1 :0] lcd_s_arcache;
wire [`Larprot     -1 :0] lcd_s_arprot;
wire                      lcd_s_arvalid;
wire                      lcd_s_arready;
wire [`LID         -1 :0] lcd_s_rid;
wire [`Lrdata      -1 :0] lcd_s_rdata;
wire [`Lrresp      -1 :0] lcd_s_rresp;
wire                      lcd_s_rlast;
wire                      lcd_s_rvalid;
wire                      lcd_s_rready;

wire [`LID-1:0]        ps2_s_awid;
wire [`Lawaddr-1:0]    ps2_s_awaddr;
wire [`Lawlen-1:0]     ps2_s_awlen;
wire [`Lawsize-1:0]    ps2_s_awsize;
wire [`Lawburst-1:0]   ps2_s_awburst;
wire [`Lawlock-1:0]    ps2_s_awlock;
wire [`Lawcache-1:0]   ps2_s_awcache;
wire [`Lawprot-1:0]    ps2_s_awprot;
wire                   ps2_s_awvalid;
wire                   ps2_s_awready;
wire [`Lwid-1:0]       ps2_s_wid;
wire [`Lwdata-1:0]     ps2_s_wdata;
wire [`Lwstrb-1:0]     ps2_s_wstrb;
wire                   ps2_s_wlast;
wire                   ps2_s_wvalid;
wire                   ps2_s_wready;
wire [`Lbid-1:0]       ps2_s_bid;
wire [`Lbresp-1:0]     ps2_s_bresp;
wire                   ps2_s_bvalid;
wire                   ps2_s_bready;
wire [`Larid-1:0]      ps2_s_arid;
wire [`Laraddr-1:0]    ps2_s_araddr;
wire [`Larlen-1:0]     ps2_s_arlen;
wire [`Larsize-1:0]    ps2_s_arsize;
wire [`Larburst-1:0]   ps2_s_arburst;
wire [`Larlock-1:0]    ps2_s_arlock;
wire [`Larcache-1:0]   ps2_s_arcache;
wire [`Larprot-1:0]    ps2_s_arprot;
wire                   ps2_s_arvalid;
wire                   ps2_s_arready;
wire [`Lrid-1:0]       ps2_s_rid;
wire [`Lrdata-1:0]     ps2_s_rdata;
wire [`Lrresp-1:0]     ps2_s_rresp;
wire                   ps2_s_rlast;
wire                   ps2_s_rvalid;
wire                   ps2_s_rready;

wire [`LID-1:0]        usb_s_awid;
wire [`Lawaddr-1:0]    usb_s_awaddr;
wire [`Lawlen-1:0]     usb_s_awlen;
wire [`Lawsize-1:0]    usb_s_awsize;
wire [`Lawburst-1:0]   usb_s_awburst;
wire [`Lawlock-1:0]    usb_s_awlock;
wire [`Lawcache-1:0]   usb_s_awcache;
wire [`Lawprot-1:0]    usb_s_awprot;
wire                   usb_s_awvalid;
wire                   usb_s_awready;
wire [`Lwid-1:0]       usb_s_wid;
wire [`Lwdata-1:0]     usb_s_wdata;
wire [`Lwstrb-1:0]     usb_s_wstrb;
wire                   usb_s_wlast;
wire                   usb_s_wvalid;
wire                   usb_s_wready;
wire [`Lbid-1:0]       usb_s_bid;
wire [`Lbresp-1:0]     usb_s_bresp;
wire                   usb_s_bvalid;
wire                   usb_s_bready;
wire [`Larid-1:0]      usb_s_arid;
wire [`Laraddr-1:0]    usb_s_araddr;
wire [`Larlen-1:0]     usb_s_arlen;
wire [`Larsize-1:0]    usb_s_arsize;
wire [`Larburst-1:0]   usb_s_arburst;
wire [`Larlock-1:0]    usb_s_arlock;
wire [`Larcache-1:0]   usb_s_arcache;
wire [`Larprot-1:0]    usb_s_arprot;
wire                   usb_s_arvalid;
wire                   usb_s_arready;
wire [`Lrid-1:0]       usb_s_rid;
wire [`Lrdata-1:0]     usb_s_rdata;
wire [`Lrresp-1:0]     usb_s_rresp;
wire                   usb_s_rlast;
wire                   usb_s_rvalid;
wire                   usb_s_rready;

wire [`LID         -1 :0] mac_m_awid;
wire [`Lawaddr     -1 :0] mac_m_awaddr;
wire [`Lawlen      -1 :0] mac_m_awlen;
wire [`Lawsize     -1 :0] mac_m_awsize;
wire [`Lawburst    -1 :0] mac_m_awburst;
wire [`Lawlock     -1 :0] mac_m_awlock;
wire [`Lawcache    -1 :0] mac_m_awcache;
wire [`Lawprot     -1 :0] mac_m_awprot;
wire                      mac_m_awvalid;
wire                      mac_m_awready;
wire [`LID         -1 :0] mac_m_wid;
wire [`Lwdata      -1 :0] mac_m_wdata;
wire [`Lwstrb      -1 :0] mac_m_wstrb;
wire                      mac_m_wlast;
wire                      mac_m_wvalid;
wire                      mac_m_wready;
wire [`LID         -1 :0] mac_m_bid;
wire [`Lbresp      -1 :0] mac_m_bresp;
wire                      mac_m_bvalid;
wire                      mac_m_bready;
wire [`LID         -1 :0] mac_m_arid;
wire [`Laraddr     -1 :0] mac_m_araddr;
wire [`Larlen      -1 :0] mac_m_arlen;
wire [`Larsize     -1 :0] mac_m_arsize;
wire [`Larburst    -1 :0] mac_m_arburst;
wire [`Larlock     -1 :0] mac_m_arlock;
wire [`Larcache    -1 :0] mac_m_arcache;
wire [`Larprot     -1 :0] mac_m_arprot;
wire                      mac_m_arvalid;
wire                      mac_m_arready;
wire [`LID         -1 :0] mac_m_rid;
wire [`Lrdata      -1 :0] mac_m_rdata;
wire [`Lrresp      -1 :0] mac_m_rresp;
wire                      mac_m_rlast;
wire                      mac_m_rvalid;
wire                      mac_m_rready;

wire [`LID         -1 :0] s0_awid;
wire [`Lawaddr     -1 :0] s0_awaddr;
wire [`Lawlen      -1 :0] s0_awlen;
wire [`Lawsize     -1 :0] s0_awsize;
wire [`Lawburst    -1 :0] s0_awburst;
wire [`Lawlock     -1 :0] s0_awlock;
wire [`Lawcache    -1 :0] s0_awcache;
wire [`Lawprot     -1 :0] s0_awprot;
wire                      s0_awvalid;
wire                      s0_awready;
wire [`LID         -1 :0] s0_wid;
wire [`Lwdata      -1 :0] s0_wdata;
wire [`Lwstrb      -1 :0] s0_wstrb;
wire                      s0_wlast;
wire                      s0_wvalid;
wire                      s0_wready;
wire [`LID         -1 :0] s0_bid;
wire [`Lbresp      -1 :0] s0_bresp;
wire                      s0_bvalid;
wire                      s0_bready;
wire [`LID         -1 :0] s0_arid;
wire [`Laraddr     -1 :0] s0_araddr;
wire [`Larlen      -1 :0] s0_arlen;
wire [`Larsize     -1 :0] s0_arsize;
wire [`Larburst    -1 :0] s0_arburst;
wire [`Larlock     -1 :0] s0_arlock;
wire [`Larcache    -1 :0] s0_arcache;
wire [`Larprot     -1 :0] s0_arprot;
wire                      s0_arvalid;
wire                      s0_arready;
wire [`LID         -1 :0] s0_rid;
wire [`Lrdata      -1 :0] s0_rdata;
wire [`Lrresp      -1 :0] s0_rresp;
wire                      s0_rlast;
wire                      s0_rvalid;
wire                      s0_rready;

wire [8            -1 :0] mig_awid;
wire [`Lawaddr     -1 :0] mig_awaddr;
wire [8            -1 :0] mig_awlen;
wire [`Lawsize     -1 :0] mig_awsize;
wire [`Lawburst    -1 :0] mig_awburst;
wire [`Lawlock     -1 :0] mig_awlock;
wire [`Lawcache    -1 :0] mig_awcache;
wire [`Lawprot     -1 :0] mig_awprot;
wire                      mig_awvalid;
wire                      mig_awready;
wire [8            -1 :0] mig_wid;
wire [`Lwdata      -1 :0] mig_wdata;
wire [`Lwstrb      -1 :0] mig_wstrb;
wire                      mig_wlast;
wire                      mig_wvalid;
wire                      mig_wready;
wire [8            -1 :0] mig_bid;
wire [`Lbresp      -1 :0] mig_bresp;
wire                      mig_bvalid;
wire                      mig_bready;
wire [8            -1 :0] mig_arid;
wire [`Laraddr     -1 :0] mig_araddr;
wire [8            -1 :0] mig_arlen;
wire [`Larsize     -1 :0] mig_arsize;
wire [`Larburst    -1 :0] mig_arburst;
wire [`Larlock     -1 :0] mig_arlock;
wire [`Larcache    -1 :0] mig_arcache;
wire [`Larprot     -1 :0] mig_arprot;
wire                      mig_arvalid;
wire                      mig_arready;
wire [8            -1 :0] mig_rid;
wire [`Lrdata      -1 :0] mig_rdata;
wire [`Lrresp      -1 :0] mig_rresp;
wire                      mig_rlast;
wire                      mig_rvalid;
wire                      mig_rready;

wire [`LID         -1 :0] dma0_awid       ;
wire [`Lawaddr     -1 :0] dma0_awaddr     ;
wire [`Lawlen      -1 :0] dma0_awlen      ;
wire [`Lawsize     -1 :0] dma0_awsize     ;
wire [`Lawburst    -1 :0] dma0_awburst    ;
wire [`Lawlock     -1 :0] dma0_awlock     ;
wire [`Lawcache    -1 :0] dma0_awcache    ;
wire [`Lawprot     -1 :0] dma0_awprot     ;
wire                      dma0_awvalid    ;
wire                      dma0_awready    ;
wire [`LID         -1 :0] dma0_wid        ;
wire [64           -1 :0] dma0_wdata      ;
wire [8            -1 :0] dma0_wstrb      ;
wire                      dma0_wlast      ;
wire                      dma0_wvalid     ;
wire                      dma0_wready     ;
wire [`LID         -1 :0] dma0_bid        ;
wire [`Lbresp      -1 :0] dma0_bresp      ;
wire                      dma0_bvalid     ;
wire                      dma0_bready     ;
wire [`LID         -1 :0] dma0_arid       ;
wire [`Laraddr     -1 :0] dma0_araddr     ;
wire [`Larlen      -1 :0] dma0_arlen      ;
wire [`Larsize     -1 :0] dma0_arsize     ;
wire [`Larburst    -1 :0] dma0_arburst    ;
wire [`Larlock     -1 :0] dma0_arlock     ;
wire [`Larcache    -1 :0] dma0_arcache    ;
wire [`Larprot     -1 :0] dma0_arprot     ;
wire                      dma0_arvalid    ;
wire                      dma0_arready    ;
wire [`LID         -1 :0] dma0_rid        ;
wire [64           -1 :0] dma0_rdata      ;
wire [`Lrresp      -1 :0] dma0_rresp      ;
wire                      dma0_rlast      ;
wire                      dma0_rvalid     ;
wire                      dma0_rready     ;

//LCD DMA (用于显示的显存读取)
wire [15:0]              lcd_dma_pixel_data;
wire                     lcd_dma_pixel_valid;
wire                     lcd_dma_pixel_ready;
wire                     lcd_dma_busy;
wire                     lcd_dma_done;
wire                     lcd_dma_error;
wire                     lcd_dma_start;
wire [31:0]              lcd_dma_base_addr;
wire [31:0]              lcd_dma_pixel_count;
wire [3:0]               lcd_dma_arid;
wire [31:0]              lcd_dma_araddr;
wire [3:0]               lcd_dma_arlen;
wire [2:0]               lcd_dma_arsize;
wire [1:0]               lcd_dma_arburst;
wire                     lcd_dma_arlock;
wire [3:0]               lcd_dma_arcache;
wire [2:0]               lcd_dma_arprot;
wire                     lcd_dma_arvalid;
wire                     lcd_dma_arready;
wire [3:0]               lcd_dma_rid;
wire [63:0]              lcd_dma_rdata;
wire [1:0]               lcd_dma_rresp;
wire                     lcd_dma_rlast;
wire                     lcd_dma_rvalid;
wire                     lcd_dma_rready;
wire                     s02_slave_arready;
wire [3:0]               s02_slave_arid;
wire [31:0]              s02_slave_araddr;
wire [7:0]               s02_slave_arlen;
wire [2:0]               s02_slave_arsize;
wire [1:0]               s02_slave_arburst;
wire                     s02_slave_arlock;
wire [3:0]               s02_slave_arcache;
wire [2:0]               s02_slave_arprot;
wire                     s02_slave_arvalid;
wire [3:0]               s02_slave_rid;
wire [63:0]              s02_slave_rdata;
wire [1:0]               s02_slave_rresp;
wire                     s02_slave_rlast;
wire                     s02_slave_rvalid;
wire                     s02_slave_rready;
reg                      s02_r_owner_lcd;
reg                      s02_r_busy;
wire                     s02_ar_sel_lcd;

assign lcd_dma_start       = cr02[0];
assign lcd_dma_base_addr   = cr00;
assign lcd_dma_pixel_count = cr01;

wire [`LID         -1 :0] apb_s_awid;
wire [`Lawaddr     -1 :0] apb_s_awaddr;
wire [`Lawlen      -1 :0] apb_s_awlen;
wire [`Lawsize     -1 :0] apb_s_awsize;
wire [`Lawburst    -1 :0] apb_s_awburst;
wire [`Lawlock     -1 :0] apb_s_awlock;
wire [`Lawcache    -1 :0] apb_s_awcache;
wire [`Lawprot     -1 :0] apb_s_awprot;
wire                      apb_s_awvalid;
wire                      apb_s_awready;
wire [`LID         -1 :0] apb_s_wid;
wire [`Lwdata      -1 :0] apb_s_wdata;
wire [`Lwstrb      -1 :0] apb_s_wstrb;
wire                      apb_s_wlast;
wire                      apb_s_wvalid;
wire                      apb_s_wready;
wire [`LID         -1 :0] apb_s_bid;
wire [`Lbresp      -1 :0] apb_s_bresp;
wire                      apb_s_bvalid;
wire                      apb_s_bready;
wire [`LID         -1 :0] apb_s_arid;
wire [`Laraddr     -1 :0] apb_s_araddr;
wire [`Larlen      -1 :0] apb_s_arlen;
wire [`Larsize     -1 :0] apb_s_arsize;
wire [`Larburst    -1 :0] apb_s_arburst;
wire [`Larlock     -1 :0] apb_s_arlock;
wire [`Larcache    -1 :0] apb_s_arcache;
wire [`Larprot     -1 :0] apb_s_arprot;
wire                      apb_s_arvalid;
wire                      apb_s_arready;
wire [`LID         -1 :0] apb_s_rid;
wire [`Lrdata      -1 :0] apb_s_rdata;
wire [`Lrresp      -1 :0] apb_s_rresp;
wire                      apb_s_rlast;
wire                      apb_s_rvalid;
wire                      apb_s_rready;

wire          apb_ready_dma0;
wire          apb_start_dma0;
wire          apb_rw_dma0;
wire          apb_psel_dma0;
wire          apb_penable_dma0;
wire[31:0]    apb_addr_dma0;
wire[31:0]    apb_wdata_dma0;
wire[31:0]    apb_rdata_dma0;

wire         dma_int;
wire         dma_ack;
wire         dma_req;

wire                      dma0_gnt;
wire[31:0]                order_addr_in;
wire                      write_dma_end;
wire                      finish_read_order;
//LCD DMA与dma_master共享S02读取通道仲裁：优先保持dma_master优先，避免改动现有DMA语义
 

assign s02_ar_sel_lcd = ~s02_r_busy && lcd_dma_arvalid && ~dma0_arvalid;

assign s02_slave_arid    = s02_ar_sel_lcd ? lcd_dma_arid    : dma0_arid;
assign s02_slave_araddr  = s02_ar_sel_lcd ? lcd_dma_araddr  : dma0_araddr;
assign s02_slave_arlen   = s02_ar_sel_lcd ? {4'd0, lcd_dma_arlen}   : {4'd0,dma0_arlen};
assign s02_slave_arsize  = s02_ar_sel_lcd ? lcd_dma_arsize  : dma0_arsize;
assign s02_slave_arburst = s02_ar_sel_lcd ? lcd_dma_arburst : dma0_arburst;
assign s02_slave_arlock  = s02_ar_sel_lcd ? lcd_dma_arlock  : dma0_arlock[0:0];
assign s02_slave_arcache = s02_ar_sel_lcd ? lcd_dma_arcache : dma0_arcache[3:0];
assign s02_slave_arprot  = s02_ar_sel_lcd ? lcd_dma_arprot  : dma0_arprot;
assign s02_slave_arvalid = ~s02_r_busy &&
                           (s02_ar_sel_lcd ? lcd_dma_arvalid : dma0_arvalid);

assign dma0_arready    = ~s02_r_busy && s02_slave_arready & ~s02_ar_sel_lcd;
assign lcd_dma_arready = ~s02_r_busy && s02_slave_arready &  s02_ar_sel_lcd;

assign s02_slave_rready = s02_r_busy ? (s02_r_owner_lcd ? lcd_dma_rready : dma0_rready) : 1'b0;

assign dma0_rid   = s02_r_busy && !s02_r_owner_lcd ? s02_slave_rid : 4'd0;
assign dma0_rdata = s02_r_busy && !s02_r_owner_lcd ? s02_slave_rdata : 64'd0;
assign dma0_rresp = s02_r_busy && !s02_r_owner_lcd ? s02_slave_rresp : 2'd0;
assign dma0_rlast = s02_r_busy && !s02_r_owner_lcd ? s02_slave_rlast : 1'b0;
assign dma0_rvalid = s02_r_busy && !s02_r_owner_lcd ? s02_slave_rvalid : 1'b0;

assign lcd_dma_rid    = s02_r_busy && s02_r_owner_lcd ? s02_slave_rid : 4'd0;
assign lcd_dma_rdata  = s02_r_busy && s02_r_owner_lcd ? s02_slave_rdata : 64'd0;
assign lcd_dma_rresp  = s02_r_busy && s02_r_owner_lcd ? s02_slave_rresp : 2'd0;
assign lcd_dma_rlast  = s02_r_busy && s02_r_owner_lcd ? s02_slave_rlast : 1'b0;
assign lcd_dma_rvalid = s02_r_busy && s02_r_owner_lcd ? s02_slave_rvalid : 1'b0;

wire s02_slave_rdone = s02_r_busy && s02_slave_rvalid && s02_slave_rready && s02_slave_rlast;
always @(posedge aclk) begin
    if (~aresetn) begin
        s02_r_busy       <= 1'b0;
        s02_r_owner_lcd <= 1'b0;
    end else begin
        if (!s02_r_busy) begin
            if (s02_slave_arready && s02_slave_arvalid) begin
                s02_r_busy       <= 1'b1;
                s02_r_owner_lcd <= s02_ar_sel_lcd;
            end
        end else if (s02_slave_rdone) begin
            s02_r_busy <= 1'b0;
        end
    end
end

	//spi
wire [3:0]spi_csn_o ;
wire [3:0]spi_csn_en;
wire spi_sck_o ;
wire spi_sdo_i ;
wire spi_sdo_o ;
wire spi_sdo_en;
wire spi_sdi_i ;
wire spi_sdi_o ;
wire spi_sdi_en;
wire spi_inta_o;
assign     SPI_CLK = spi_sck_o;
assign     SPI_CS  = ~spi_csn_en[0] & spi_csn_o[0];
assign     SPI_MOSI = spi_sdo_en ? 1'bz : spi_sdo_o ;
assign     SPI_MISO = spi_sdi_en ? 1'bz : spi_sdi_o ;
assign     spi_sdo_i = SPI_MOSI;
assign     spi_sdi_i = SPI_MISO;

// confreg 
wire   [31:0] cr00,cr01,cr02,cr03,cr04,cr05,cr06,cr07;

//mac
wire md_i_0;      // MII data input (from I/O cell)
wire md_o_0;      // MII data output (to I/O cell)
wire md_oe_0;     // MII data output enable (to I/O cell)
IOBUF mac_mdio(.IO(mdio_0),.I(md_o_0),.T(~md_oe_0),.O(md_i_0));
assign phy_rstn = aresetn;

//ps2
wire ps2_clk_i, ps2_clk_o, ps2_clk_oe;
wire ps2_data_i, ps2_data_o, ps2_data_oe;

IOBUF ps2_clk_iobuf(.IO(PS2_CLK), .I(ps2_clk_o), .T(~ps2_clk_oe), .O(ps2_clk_i));
IOBUF ps2_data_iobuf(.IO(PS2_DATA), .I(ps2_data_o), .T(~ps2_data_oe), .O(ps2_data_i));

// USB3500 presents a 60 MHz source-synchronous UTMI bus.  DATA is driven by
// the FPGA only while TXVALID is asserted.
wire usb_clk;
wire [7:0] usb_data_i;
wire [7:0] usb_data_o;
wire usb_data_oe;
wire [7:0] usb_data_t;
BUFG usb_clk_buf(.I(USB_CLKOUT), .O(usb_clk));
generate
    genvar usb_data_index;
    for (usb_data_index = 0; usb_data_index < 8; usb_data_index = usb_data_index + 1) begin: usb_data_iobufs
        IOBUF usb_data_iobuf(
            .IO(USB_DATA[usb_data_index]),
            .I(usb_data_o[usb_data_index]),
            .T(usb_data_t[usb_data_index]),
            .O(usb_data_i[usb_data_index])
        );
    end
endgenerate

//nand
wire       nand_cle   ;
wire       nand_ale   ;
wire [3:0] nand_rdy   ;
wire [3:0] nand_ce    ;
wire       nand_rd    ;
wire       nand_wr    ;
wire       nand_dat_oe;
wire [7:0] nand_dat_i ;
wire [7:0] nand_dat_o ;
wire       nand_int   ;
assign     NAND_CLE = nand_cle;
assign     NAND_ALE = nand_ale;
assign     nand_rdy = {3'd0,NAND_RDY};
assign     NAND_RD  = nand_rd;
assign     NAND_CE  = nand_ce[0];  //low active
assign     NAND_WR  = nand_wr;  
generate
    genvar i;
    for(i=0;i<8;i=i+1)
    begin: nand_data_loop
        IOBUF nand_data(.IO(NAND_DATA[i]),.I(nand_dat_o[i]),.T(nand_dat_oe),.O(nand_dat_i[i]));
    end
endgenerate

//uart
wire UART_CTS,   UART_RTS;
wire UART_DTR,   UART_DSR;
wire UART_RI,    UART_DCD;
assign UART_CTS = 1'b0;
assign UART_DSR = 1'b0;
assign UART_DCD = 1'b0;
wire uart0_int   ;
wire uart0_txd_o ;
wire uart0_txd_i ;
wire uart0_txd_oe;
wire uart0_rxd_o ;
wire uart0_rxd_i ;
wire uart0_rxd_oe;
wire uart0_rts_o ;
wire uart0_cts_i ;
wire uart0_dsr_i ;
wire uart0_dcd_i ;
wire uart0_dtr_o ;
wire uart0_ri_i  ;
assign     UART_RX     = uart0_rxd_oe ? 1'bz : uart0_rxd_o ;
assign     UART_TX     = uart0_txd_oe ? 1'bz : uart0_txd_o ;
assign     UART_RTS    = uart0_rts_o ;
assign     UART_DTR    = uart0_dtr_o ;
assign     uart0_txd_i = UART_TX;
assign     uart0_rxd_i = UART_RX;
assign     uart0_cts_i = UART_CTS;
assign     uart0_dcd_i = UART_DCD;
assign     uart0_dsr_i = UART_DSR;
assign     uart0_ri_i  = UART_RI ;

//interrupt
wire mac_int;
wire ps2_int;
wire usb_int;
wire [6:0] int_out;
wire [6:0] int_n_i;
assign int_out = {ps2_int, usb_int, dma_int,nand_int,spi_inta_o,uart0_int,mac_int};
assign int_n_i = ~int_out;

reg cpu_aresetn_1;
reg cpu_aresetn_2;

wire cpu_aresetn;

always @(posedge cpu_clk) begin
    cpu_aresetn_1 <= aresetn;
    cpu_aresetn_2 <= cpu_aresetn_1;
end

assign cpu_aresetn = cpu_aresetn_2;

//debug signals
wire [31:0] debug_wb_pc;
wire [3 :0] debug_wb_rf_wen;
wire [4 :0] debug_wb_rf_wnum;
wire [31:0] debug_wb_rf_wdata;
wire [31:0] debug_wb_inst;
wire        ws_valid;
wire        diag_commit_valid;
wire [31:0] diag_commit_pc;
wire [31:0] diag_rob_head_pc;
wire [31:0] diag_rob_status;
wire [31:0] diag_sb_head_paddr;
wire [31:0] diag_sb_status;
wire [31:0] diag_mshr_status;
wire [31:0] diag_dcache_status;
wire [31:0] diag_csr_era;
wire [31:0] diag_csr_eentry;
wire [31:0] diag_csr_boundary_pc;
wire [31:0] diag_csr_vector_pc;
wire [31:0] diag_csr_crmd;
wire [31:0] diag_csr_prmd;
wire [31:0] diag_csr_estat;
wire [31:0] diag_csr_badv;
wire [31:0] diag_csr_tlbrentry;
wire        break_point;
wire        infor_flag;
wire [ 4:0] reg_num;
wire [31:0] rf_rdata;
wire [7 :0] conf_num_csn;
wire [6 :0] conf_num_a_g;
wire [7 :0] axi_diag_num_csn;
wire [6 :0] axi_diag_num_a_g;
wire [31:0] axi_diag_num_data;

// SW7 enables the non-intrusive AXI read-path diagnostic display.  With SW7
// clear, CONFREG retains full ownership of the seven-segment display.
assign num_csn = switch[7] ? axi_diag_num_csn : conf_num_csn;
assign num_a_g = switch[7] ? axi_diag_num_a_g : conf_num_a_g;

//uart_ram signals
wire [3 :0] uart_arid   ;
wire [31:0] uart_araddr ;
wire [7 :0] uart_arlen  ;
wire [2 :0] uart_arsize ;
wire [1 :0] uart_arburst;
wire [1 :0] uart_arlock ;
wire [3 :0] uart_arcache;
wire [2 :0] uart_arprot ;
wire        uart_arvalid;
wire        uart_arready;
wire [3 :0] uart_rid    ;
wire [31:0] uart_rdata  ;
wire [1 :0] uart_rresp  ;
wire        uart_rlast  ;
wire        uart_rvalid ;
wire        uart_rready ;

wire        infom_flag;
wire [31:0] start_addr;
wire        mem_flag;
wire [ 7:0] mem_rdata;

//axi_2x1 signals
wire [`LID         -1 :0] m1_arid;
wire [`Laraddr     -1 :0] m1_araddr;
wire [`Larlen      -1 :0] m1_arlen;
wire [`Larsize     -1 :0] m1_arsize;
wire [`Larburst    -1 :0] m1_arburst;
wire [`Larlock     -1 :0] m1_arlock;
wire [`Larcache    -1 :0] m1_arcache;
wire [`Larprot     -1 :0] m1_arprot;
wire                      m1_arvalid;
wire                      m1_arready;
wire [`LID         -1 :0] m1_rid;
wire [`Lrdata      -1 :0] m1_rdata;
wire [`Lrresp      -1 :0] m1_rresp;
wire                      m1_rlast;
wire                      m1_rvalid;
wire                      m1_rready;

debug_top u_debug_top(
    .sys_clk              (cpu_clk          ), // input,  50MHz CPU时钟, 来自clk_pll_33
    .sys_rst_n            (cpu_aresetn      ), // input,  CPU时钟域同步释放复位
    .uart_rxd             (UART_RX2         ), // input,  调试串口接收, 来自外部引脚UART_RX2
    .debug_wb_pc          (debug_wb_pc      ), // input,  写回级PC值, 来自core_top.debug0_wb_pc
    .debug_wb_rf_wnum     (debug_wb_rf_wnum ), // input,  写回级写寄存器号, 来自core_top.debug0_wb_rf_wnum
    .debug_wb_rf_wdata    (debug_wb_rf_wdata), // input,  写回级写寄存器数据, 来自core_top.debug0_wb_rf_wdata
    .ws_valid             (ws_valid         ), // input,  写回级有效信号, 来自core_top.ws_valid
    .break_point          (break_point      ), // output, 断点/单步触发标志, 连接core_top.break_point
    .infor_flag           (infor_flag       ), // output, 查询寄存器请求标志, 连接core_top.infor_flag
    .reg_num              (reg_num          ), // output, 待查询的寄存器编号, 连接core_top.reg_num
    .rf_rdata             (rf_rdata         ), // input,  寄存器读出数据, 来自core_top.rf_rdata
    .infom_flag           (infom_flag       ), // output, 查询内存请求标志, 连接debug_sram.infom_flag
    .start_addr           (start_addr       ), // output, 待查询的内存地址, 连接debug_sram.start_addr
    .mem_flag             (mem_flag         ), // input,  内存查询结果有效, 来自debug_sram.mem_flag
    .mem_rdata            (mem_rdata        ), // input,  内存查询返回数据(8bit), 来自debug_sram.mem_rdata
    .uart_txd             (UART_TX2         )  // output, 调试串口发送, 连接外部引脚UART_TX2

);


debug_sram u_debug_sram(
    .clk       (cpu_clk        ), // input,  50MHz CPU时钟, 来自clk_pll_33
    .aresetn   (cpu_aresetn    ), // input,  CPU时钟域同步释放复位

    .arid      (uart_arid      ), // output, AXI读请求ID, 连接axi_2x1_mux.S01_AXI_ARID
    .araddr    (uart_araddr    ), // output, AXI读请求地址(调试查询目标地址), 连接axi_2x1_mux.S01_AXI_ARADDR
    .arlen     (uart_arlen     ), // output, AXI读请求突发长度, 连接axi_2x1_mux.S01_AXI_ARLEN
    .arsize    (uart_arsize    ), // output, AXI读请求数据宽度, 连接axi_2x1_mux.S01_AXI_ARSIZE
    .arburst   (uart_arburst   ), // output, AXI读请求突发类型, 连接axi_2x1_mux.S01_AXI_ARBURST
    .arlock    (uart_arlock    ), // output, AXI读请求锁类型, 连接axi_2x1_mux.S01_AXI_ARLOCK
    .arcache   (uart_arcache   ), // output, AXI读请求Cache属性, 连接axi_2x1_mux.S01_AXI_ARCACHE
    .arprot    (uart_arprot    ), // output, AXI读请求保护类型, 连接axi_2x1_mux.S01_AXI_ARPROT
    .arvalid   (uart_arvalid   ), // output, AXI读请求有效信号, 连接axi_2x1_mux.S01_AXI_ARVALID
    .arready   (uart_arready   ), // input,  AXI读请求就绪信号, 来自axi_2x1_mux.S01_AXI_ARREADY

    .rid       (uart_rid       ), // input,  AXI读响应ID, 来自axi_2x1_mux.S01_AXI_RID
    .rdata     (uart_rdata     ), // input,  AXI读响应数据(调试查询到的内存内容), 来自axi_2x1_mux.S01_AXI_RDATA
    .rresp     (uart_rresp     ), // input,  AXI读响应状态, 来自axi_2x1_mux.S01_AXI_RRESP
    .rlast     (uart_rlast     ), // input,  AXI读响应最后拍标志, 来自axi_2x1_mux.S01_AXI_RLAST
    .rvalid    (uart_rvalid    ), // input,  AXI读响应有效信号, 来自axi_2x1_mux.S01_AXI_RVALID
    .rready    (uart_rready    ), // output, AXI读响应就绪信号, 连接axi_2x1_mux.S01_AXI_RREADY

    .break_point(              ), // input,  断点标志(用于协调与CPU访存冲突), 悬空未接
    .cpu_rready (              ), // input,  CPU读就绪(用于协调与CPU访存冲突), 悬空未接
    .rvalid_r   (              ), // output, 暂存的CPU读响应有效(冲突缓冲), 悬空未接
    .rid_r      (              ), // output, 暂存的CPU读响应ID(冲突缓冲), 悬空未接
    .rdata_r    (              ), // output, 暂存的CPU读响应数据(冲突缓冲), 悬空未接
    .rlast_r    (              ), // output, 暂存的CPU读响应last标志(冲突缓冲), 悬空未接
    .flag       (              ), // output, 有暂存CPU响应待处理的标志, 悬空未接

    .infom_flag(infom_flag    ), // input,  内存查询请求标志, 来自debug_top.infom_flag
    .start_addr(start_addr    ), // input,  内存查询目标地址, 来自debug_top.start_addr
    .mem_flag  (mem_flag      ), // output, 内存查询结果有效标志, 连接debug_top.mem_flag
    .mem_rdata (mem_rdata     )  // output, 内存查询返回数据(8bit字节), 连接debug_top.mem_rdata

);

// cpu
kirchhoff_core_top cpu_mid(
  .aclk             (cpu_clk),                    // input,  50MHz CPU时钟, 来自clk_pll_33
  .intrpt           ({1'b0, int_out[6:0]}),       // input,  8位中断输入[6:0]有效, 来自中断汇聚(PS2/DMA/NAND/SPI/UART/MAC)
  //.nmi              (1'b1),

  .aresetn          (cpu_aresetn  ),              // input,  CPU复位(低有效,两级同步后), 来自resetn同步
  // --- AXI读地址通道(AR) ---
  .arid         (m0_arid[3:0] ),                  // output, AXI读请求ID, 连接axi_2x1_mux.S00_AXI_ARID
  .araddr       (m0_araddr    ),                  // output, AXI读请求地址, 连接axi_2x1_mux.S00_AXI_ARADDR
  .arlen        (m0_arlen     ),                  // output, AXI读请求突发长度, 连接axi_2x1_mux.S00_AXI_ARLEN
  .arsize       (m0_arsize    ),                  // output, AXI读请求数据宽度, 连接axi_2x1_mux.S00_AXI_ARSIZE
  .arburst      (m0_arburst   ),                  // output, AXI读请求突发类型, 连接axi_2x1_mux.S00_AXI_ARBURST
  .arlock       (m0_arlock    ),                  // output, AXI读请求锁类型, 连接axi_2x1_mux.S00_AXI_ARLOCK
  .arcache      (m0_arcache   ),                  // output, AXI读请求Cache属性, 连接axi_2x1_mux.S00_AXI_ARCACHE
  .arprot       (m0_arprot    ),                  // output, AXI读请求保护类型, 连接axi_2x1_mux.S00_AXI_ARPROT
  .arvalid      (m0_arvalid   ),                  // output, AXI读请求有效信号, 连接axi_2x1_mux.S00_AXI_ARVALID
  .arready      (m0_arready   ),                  // input,  AXI读请求就绪信号, 来自axi_2x1_mux.S00_AXI_ARREADY
  // --- AXI读数据通道(R) ---
  .rid          (m0_rid[3:0]  ),                  // input,  AXI读响应ID, 来自axi_2x1_mux.S00_AXI_RID
  .rdata        (m0_rdata     ),                  // input,  AXI读响应数据, 来自axi_2x1_mux.S00_AXI_RDATA
  .rresp        (m0_rresp     ),                  // input,  AXI读响应状态, 来自axi_2x1_mux.S00_AXI_RRESP
  .rlast        (m0_rlast     ),                  // input,  AXI读响应最后拍标志, 来自axi_2x1_mux.S00_AXI_RLAST
  .rvalid       (m0_rvalid    ),                  // input,  AXI读响应有效信号, 来自axi_2x1_mux.S00_AXI_RVALID
  .rready       (m0_rready    ),                  // output, AXI读响应就绪信号, 连接axi_2x1_mux.S00_AXI_RREADY
  // --- AXI写地址通道(AW) ---
  .awid         (m0_awid[3:0] ),                  // output, AXI写请求ID, 连接AXI_CLK_CONVERTER.s_axi_awid
  .awaddr       (m0_awaddr    ),                  // output, AXI写请求地址, 连接AXI_CLK_CONVERTER.s_axi_awaddr
  .awlen        (m0_awlen     ),                  // output, AXI写请求突发长度, 连接AXI_CLK_CONVERTER.s_axi_awlen
  .awsize       (m0_awsize    ),                  // output, AXI写请求数据宽度, 连接AXI_CLK_CONVERTER.s_axi_awsize
  .awburst      (m0_awburst   ),                  // output, AXI写请求突发类型, 连接AXI_CLK_CONVERTER.s_axi_awburst
  .awlock       (m0_awlock    ),                  // output, AXI写请求锁类型, 连接AXI_CLK_CONVERTER.s_axi_awlock
  .awcache      (m0_awcache   ),                  // output, AXI写请求Cache属性, 连接AXI_CLK_CONVERTER.s_axi_awcache
  .awprot       (m0_awprot    ),                  // output, AXI写请求保护类型, 连接AXI_CLK_CONVERTER.s_axi_awprot
  .awvalid      (m0_awvalid   ),                  // output, AXI写请求有效信号, 连接AXI_CLK_CONVERTER.s_axi_awvalid
  .awready      (m0_awready   ),                  // input,  AXI写请求就绪信号, 来自AXI_CLK_CONVERTER.s_axi_awready
  // --- AXI写数据通道(W) ---
  .wid          (m0_wid[3:0]  ),                  // output, AXI写数据ID, 连接AXI_CLK_CONVERTER.s_axi_wid
  .wdata        (m0_wdata     ),                  // output, AXI写数据, 连接AXI_CLK_CONVERTER.s_axi_wdata
  .wstrb        (m0_wstrb     ),                  // output, AXI写字节使能, 连接AXI_CLK_CONVERTER.s_axi_wstrb
  .wlast        (m0_wlast     ),                  // output, AXI写数据最后拍标志, 连接AXI_CLK_CONVERTER.s_axi_wlast
  .wvalid       (m0_wvalid    ),                  // output, AXI写数据有效信号, 连接AXI_CLK_CONVERTER.s_axi_wvalid
  .wready       (m0_wready    ),                  // input,  AXI写数据就绪信号, 来自AXI_CLK_CONVERTER.s_axi_wready
  // --- AXI写响应通道(B) ---
  .bid          (m0_bid[3:0]  ),                  // input,  AXI写响应ID, 来自AXI_CLK_CONVERTER.s_axi_bid
  .bresp        (m0_bresp     ),                  // input,  AXI写响应状态, 来自AXI_CLK_CONVERTER.s_axi_bresp
  .bvalid       (m0_bvalid    ),                  // input,  AXI写响应有效信号, 来自AXI_CLK_CONVERTER.s_axi_bvalid
  .bready       (m0_bready    ),                  // output, AXI写响应就绪信号, 连接AXI_CLK_CONVERTER.s_axi_bready
  // --- 调试交互信号 ---
  .ws_valid     (ws_valid     ),                  // output, 写回级有效信号, 连接debug_top.ws_valid
  .break_point  (break_point  ),                  // input,  断点/单步触发标志, 来自debug_top.break_point
  .infor_flag   (infor_flag   ),                  // input,  查询寄存器请求标志, 来自debug_top.infor_flag
  .reg_num      (reg_num      ),                  // input,  待查询的寄存器编号, 来自debug_top.reg_num
  .rf_rdata     (rf_rdata     ),                  // output, 寄存器读出数据, 连接debug_top.rf_rdata
  // --- 调试观测输出 ---
  .debug0_wb_pc        (debug_wb_pc      ),       // output, 写回级PC值, 连接debug_top.debug_wb_pc
  .debug0_wb_rf_wen    (debug_wb_rf_wen  ),       // output, 写回级寄存器写使能, 未被debug_top使用
  .debug0_wb_rf_wnum   (debug_wb_rf_wnum ),       // output, 写回级写寄存器号, 连接debug_top.debug_wb_rf_wnum
  .debug0_wb_rf_wdata  (debug_wb_rf_wdata),       // output, 写回级写寄存器数据, 连接debug_top.debug_wb_rf_wdata
  .debug0_wb_inst      (debug_wb_inst    ),       // output, 兼容调试口（综合配置固定为0）
  .diag_commit_valid   (diag_commit_valid),       // output, 真实ROB退休事件
  .diag_commit_pc      (diag_commit_pc   ),       // output, 真实ROB最后退休PC
  .diag_rob_head_pc    (diag_rob_head_pc ),       // output, 当前ROB队头PC
  .diag_rob_status     (diag_rob_status  ),       // output, ROB队头阻塞状态
  .diag_sb_head_paddr  (diag_sb_head_paddr),      // output, StoreBuffer完成FIFO头地址
  .diag_sb_status      (diag_sb_status   ),       // output, StoreBuffer状态
  .diag_mshr_status    (diag_mshr_status ),        // output, MSHR状态
  .diag_dcache_status  (diag_dcache_status),       // output, DCache Store/维护状态
  .diag_csr_era        (diag_csr_era),             // output, CSR ERA/EPC
  .diag_csr_eentry     (diag_csr_eentry),          // output, CSR EENTRY
  .diag_csr_boundary_pc (diag_csr_boundary_pc),    // output, 最近一次CSR边界写入ERA的PC
  .diag_csr_vector_pc  (diag_csr_vector_pc),       // output, 最近一次CSR边界入口PC
  .diag_csr_crmd       (diag_csr_crmd),            // output, CSR CRMD
  .diag_csr_prmd       (diag_csr_prmd),            // output, CSR PRMD
  .diag_csr_estat      (diag_csr_estat),           // output, CSR ESTAT
  .diag_csr_badv       (diag_csr_badv),            // output, CSR BADV
  .diag_csr_tlbrentry  (diag_csr_tlbrentry)        // output, CSR TLBRENTRY
);

// AXI 2x1 read interconnect (Vivado 2025.2 AXI Crossbar)
axi_2x1_mux_2025_wrapper u_axi_2x1_mux (
    .aclk       (cpu_clk),
    .aresetn    (cpu_aresetn),

    .s0_arid    (m0_arid),
    .s0_araddr  (m0_araddr),
    .s0_arlen   (m0_arlen),
    .s0_arsize  (m0_arsize),
    .s0_arburst (m0_arburst),
    .s0_arlock  (m0_arlock),
    .s0_arcache (m0_arcache),
    .s0_arprot  (m0_arprot),
    .s0_arvalid (m0_arvalid),
    .s0_arready (m0_arready),
    .s0_rid     (m0_rid),
    .s0_rdata   (m0_rdata),
    .s0_rresp   (m0_rresp),
    .s0_rlast   (m0_rlast),
    .s0_rvalid  (m0_rvalid),
    .s0_rready  (m0_rready),

    .s1_arid    (uart_arid),
    .s1_araddr  (uart_araddr),
    .s1_arlen   (uart_arlen[3:0]),
    .s1_arsize  (uart_arsize),
    .s1_arburst (uart_arburst),
    .s1_arlock  (uart_arlock),
    .s1_arcache (uart_arcache),
    .s1_arprot  (uart_arprot),
    .s1_arvalid (uart_arvalid),
    .s1_arready (uart_arready),
    .s1_rid     (uart_rid),
    .s1_rdata   (uart_rdata),
    .s1_rresp   (uart_rresp),
    .s1_rlast   (uart_rlast),
    .s1_rvalid  (uart_rvalid),
    .s1_rready  (uart_rready),

    .m_arid     (m1_arid),
    .m_araddr   (m1_araddr),
    .m_arlen    (m1_arlen),
    .m_arsize   (m1_arsize),
    .m_arburst  (m1_arburst),
    .m_arlock   (m1_arlock),
    .m_arcache  (m1_arcache),
    .m_arprot   (m1_arprot),
    .m_arvalid  (m1_arvalid),
    .m_arready  (m1_arready),
    .m_rid      (m1_rid),
    .m_rdata    (m1_rdata),
    .m_rresp    (m1_rresp),
    .m_rlast    (m1_rlast),
    .m_rvalid   (m1_rvalid),
    .m_rready   (m1_rready)
);
// cpu_axi asyn
axi_clock_converter_0 AXI_CLK_CONVERTER (
    // ===================== 从端(s_axi): cpu_clk(50MHz)域 =====================
    // --- AW通道: CPU写请求, 直连core_top ---
    .s_axi_awid       (m0_awid[3:0]       ), // input,  从端写请求ID, 来自core_top.awid
    .s_axi_awaddr     (m0_awaddr          ), // input,  从端写请求地址, 来自core_top.awaddr
    .s_axi_awlen      (m0_awlen           ), // input,  从端写请求突发长度, 来自core_top.awlen
    .s_axi_awsize     (m0_awsize          ), // input,  从端写请求数据宽度, 来自core_top.awsize
    .s_axi_awburst    (m0_awburst         ), // input,  从端写请求突发类型, 来自core_top.awburst
    .s_axi_awlock     (m0_awlock          ), // input,  从端写请求锁类型, 来自core_top.awlock
    .s_axi_awcache    (m0_awcache         ), // input,  从端写请求Cache属性, 来自core_top.awcache
    .s_axi_awprot     (m0_awprot          ), // input,  从端写请求保护类型, 来自core_top.awprot
    .s_axi_awqos      (4'b0               ), // input,  从端写请求QoS, 固定0
    .s_axi_awvalid    (m0_awvalid         ), // input,  从端写请求有效, 来自core_top.awvalid
    .s_axi_awready    (m0_awready         ), // output, 从端写请求就绪, 连接core_top.awready
    // --- W通道: CPU写数据, 直连core_top ---
    .s_axi_wid        (m0_wid[3:0]        ), // input,  从端写数据ID, 来自core_top.wid
    .s_axi_wdata      (m0_wdata           ), // input,  从端写数据, 来自core_top.wdata
    .s_axi_wstrb      (m0_wstrb           ), // input,  从端写字节使能, 来自core_top.wstrb
    .s_axi_wlast      (m0_wlast           ), // input,  从端写数据最后拍, 来自core_top.wlast
    .s_axi_wvalid     (m0_wvalid          ), // input,  从端写数据有效, 来自core_top.wvalid
    .s_axi_wready     (m0_wready          ), // output, 从端写数据就绪, 连接core_top.wready
    // --- B通道: 写响应 → core_top ---
    .s_axi_bid        (m0_bid[3:0]        ), // output, 从端写响应ID, 连接core_top.bid
    .s_axi_bresp      (m0_bresp           ), // output, 从端写响应状态, 连接core_top.bresp
    .s_axi_bvalid     (m0_bvalid          ), // output, 从端写响应有效, 连接core_top.bvalid
    .s_axi_bready     (m0_bready          ), // input,  从端写响应就绪, 来自core_top.bready
    // --- AR通道: 合并后读请求, 来自axi_2x1_mux.M00 ---
    .s_axi_arid       (m1_arid[3:0]       ), // input,  从端读请求ID, 来自axi_2x1_mux.M00_AXI_ARID
    .s_axi_araddr     (m1_araddr          ), // input,  从端读请求地址, 来自axi_2x1_mux.M00_AXI_ARADDR
    .s_axi_arlen      (m1_arlen           ), // input,  从端读请求突发长度, 来自axi_2x1_mux.M00_AXI_ARLEN
    .s_axi_arsize     (m1_arsize          ), // input,  从端读请求数据宽度, 来自axi_2x1_mux.M00_AXI_ARSIZE
    .s_axi_arburst    (m1_arburst         ), // input,  从端读请求突发类型, 来自axi_2x1_mux.M00_AXI_ARBURST
    .s_axi_arlock     (m1_arlock          ), // input,  从端读请求锁类型, 来自axi_2x1_mux.M00_AXI_ARLOCK
    .s_axi_arcache    (m1_arcache         ), // input,  从端读请求Cache属性, 来自axi_2x1_mux.M00_AXI_ARCACHE
    .s_axi_arprot     (m1_arprot          ), // input,  从端读请求保护类型, 来自axi_2x1_mux.M00_AXI_ARPROT
    .s_axi_arqos      (4'b0               ), // input,  从端读请求QoS, 固定0
    .s_axi_arvalid    (m1_arvalid         ), // input,  从端读请求有效, 来自axi_2x1_mux.M00_AXI_ARVALID
    .s_axi_arready    (m1_arready         ), // output, 从端读请求就绪, 连接axi_2x1_mux.M00_AXI_ARREADY
    // --- R通道: 读响应 → axi_2x1_mux.M00 ---
    .s_axi_rid        (m1_rid[3:0]        ), // output, 从端读响应ID, 连接axi_2x1_mux.M00_AXI_RID
    .s_axi_rdata      (m1_rdata           ), // output, 从端读响应数据, 连接axi_2x1_mux.M00_AXI_RDATA
    .s_axi_rresp      (m1_rresp           ), // output, 从端读响应状态, 连接axi_2x1_mux.M00_AXI_RRESP
    .s_axi_rlast      (m1_rlast           ), // output, 从端读响应最后拍, 连接axi_2x1_mux.M00_AXI_RLAST
    .s_axi_rvalid     (m1_rvalid          ), // output, 从端读响应有效, 连接axi_2x1_mux.M00_AXI_RVALID
    .s_axi_rready     (m1_rready          ), // input,  从端读响应就绪, 来自axi_2x1_mux.M00_AXI_RREADY
    // --- 从端时钟/复位 ---
    .s_axi_aclk	      (cpu_clk            ), // input,  从端时钟(50MHz), 来自clk_pll_33
    .s_axi_aresetn    (cpu_aresetn        ), // input,  从端复位(低有效,两级同步后), 来自resetn同步

    // ===================== 主端(m_axi): aclk(33MHz)域 =====================
    // --- AW通道: 异步写请求 → axi_slave_mux ---
    .m_axi_awid       (m0_async_awid[3:0] ), // output, 主端写请求ID, 连接axi_slave_mux.axi_s_awid
    .m_axi_awaddr     (m0_async_awaddr    ), // output, 主端写请求地址, 连接axi_slave_mux.axi_s_awaddr
    .m_axi_awlen      (m0_async_awlen     ), // output, 主端写请求突发长度, 连接axi_slave_mux.axi_s_awlen
    .m_axi_awsize     (m0_async_awsize    ), // output, 主端写请求数据宽度, 连接axi_slave_mux.axi_s_awsize
    .m_axi_awburst    (m0_async_awburst   ), // output, 主端写请求突发类型, 连接axi_slave_mux.axi_s_awburst
    .m_axi_awlock     (m0_async_awlock    ), // output, 主端写请求锁类型, 连接axi_slave_mux.axi_s_awlock
    .m_axi_awcache    (m0_async_awcache   ), // output, 主端写请求Cache属性, 连接axi_slave_mux.axi_s_awcache
    .m_axi_awprot     (m0_async_awprot    ), // output, 主端写请求保护类型, 连接axi_slave_mux.axi_s_awprot
    .m_axi_awqos      (                   ), // output, 主端写请求QoS, 悬空未接
    .m_axi_awvalid    (m0_async_awvalid   ), // output, 主端写请求有效, 连接axi_slave_mux.axi_s_awvalid
    .m_axi_awready    (m0_async_awready   ), // input,  主端写请求就绪, 来自axi_slave_mux.axi_s_awready
    // --- W通道: 异步写数据 → axi_slave_mux ---
    .m_axi_wid        (m0_async_wid[3:0]  ), // output, 主端写数据ID, 连接axi_slave_mux.axi_s_wid
    .m_axi_wdata      (m0_async_wdata     ), // output, 主端写数据, 连接axi_slave_mux.axi_s_wdata
    .m_axi_wstrb      (m0_async_wstrb     ), // output, 主端写字节使能, 连接axi_slave_mux.axi_s_wstrb
    .m_axi_wlast      (m0_async_wlast     ), // output, 主端写数据最后拍, 连接axi_slave_mux.axi_s_wlast
    .m_axi_wvalid     (m0_async_wvalid    ), // output, 主端写数据有效, 连接axi_slave_mux.axi_s_wvalid
    .m_axi_wready     (m0_async_wready    ), // input,  主端写数据就绪, 来自axi_slave_mux.axi_s_wready
    // --- B通道: 异步写响应 ← axi_slave_mux ---
    .m_axi_bid        (m0_async_bid[3:0]  ), // input,  主端写响应ID, 来自axi_slave_mux.axi_s_bid
    .m_axi_bresp      (m0_async_bresp     ), // input,  主端写响应状态, 来自axi_slave_mux.axi_s_bresp
    .m_axi_bvalid     (m0_async_bvalid    ), // input,  主端写响应有效, 来自axi_slave_mux.axi_s_bvalid
    .m_axi_bready     (m0_async_bready    ), // output, 主端写响应就绪, 连接axi_slave_mux.axi_s_bready
    // --- AR通道: 异步读请求 → axi_slave_mux ---
    .m_axi_arid       (m0_async_arid[3:0] ), // output, 主端读请求ID, 连接axi_slave_mux.axi_s_arid
    .m_axi_araddr     (m0_async_araddr    ), // output, 主端读请求地址, 连接axi_slave_mux.axi_s_araddr
    .m_axi_arlen      (m0_async_arlen     ), // output, 主端读请求突发长度, 连接axi_slave_mux.axi_s_arlen
    .m_axi_arsize     (m0_async_arsize    ), // output, 主端读请求数据宽度, 连接axi_slave_mux.axi_s_arsize
    .m_axi_arburst    (m0_async_arburst   ), // output, 主端读请求突发类型, 连接axi_slave_mux.axi_s_arburst
    .m_axi_arlock     (m0_async_arlock    ), // output, 主端读请求锁类型, 连接axi_slave_mux.axi_s_arlock
    .m_axi_arcache    (m0_async_arcache   ), // output, 主端读请求Cache属性, 连接axi_slave_mux.axi_s_arcache
    .m_axi_arprot     (m0_async_arprot    ), // output, 主端读请求保护类型, 连接axi_slave_mux.axi_s_arprot
    .m_axi_arqos      (                   ), // output, 主端读请求QoS, 悬空未接
    .m_axi_arvalid    (m0_async_arvalid   ), // output, 主端读请求有效, 连接axi_slave_mux.axi_s_arvalid
    .m_axi_arready    (m0_async_arready   ), // input,  主端读请求就绪, 来自axi_slave_mux.axi_s_arready
    // --- R通道: 异步读响应 ← axi_slave_mux ---
    .m_axi_rid        (m0_async_rid[3:0]  ), // input,  主端读响应ID, 来自axi_slave_mux.axi_s_rid
    .m_axi_rdata      (m0_async_rdata     ), // input,  主端读响应数据, 来自axi_slave_mux.axi_s_rdata
    .m_axi_rresp      (m0_async_rresp     ), // input,  主端读响应状态, 来自axi_slave_mux.axi_s_rresp
    .m_axi_rlast      (m0_async_rlast     ), // input,  主端读响应最后拍, 来自axi_slave_mux.axi_s_rlast
    .m_axi_rvalid     (m0_async_rvalid    ), // input,  主端读响应有效, 来自axi_slave_mux.axi_s_rvalid
    .m_axi_rready     (m0_async_rready    ), // output, 主端读响应就绪, 连接axi_slave_mux.axi_s_rready
    // --- 主端时钟/复位 ---
    .m_axi_aclk	      (aclk               ), // input,  主端时钟(33MHz uncore_clk), 来自clk_pll_33
    .m_axi_aresetn    (aresetn            )  // input,  主端复位(低有效), 来自外部引脚resetn
);

// AXI_MUX
axi_slave_mux AXI_SLAVE_MUX
(
.axi_s_aresetn     (aresetn              ),
.spi_boot          (1'b1                 ),  

.axi_s_awid        (m0_async_awid        ),
.axi_s_awaddr      (m0_async_awaddr      ),
.axi_s_awlen       (m0_async_awlen       ),
.axi_s_awsize      (m0_async_awsize      ),
.axi_s_awburst     (m0_async_awburst     ),
.axi_s_awlock      (m0_async_awlock      ),
.axi_s_awcache     (m0_async_awcache     ),
.axi_s_awprot      (m0_async_awprot      ),
.axi_s_awvalid     (m0_async_awvalid     ),
.axi_s_awready     (m0_async_awready     ),
.axi_s_wready      (m0_async_wready      ),
.axi_s_wid         (m0_async_wid         ),
.axi_s_wdata       (m0_async_wdata       ),
.axi_s_wstrb       (m0_async_wstrb       ),
.axi_s_wlast       (m0_async_wlast       ),
.axi_s_wvalid      (m0_async_wvalid      ),
.axi_s_bid         (m0_async_bid         ),
.axi_s_bresp       (m0_async_bresp       ),
.axi_s_bvalid      (m0_async_bvalid      ),
.axi_s_bready      (m0_async_bready      ),
.axi_s_arid        (m0_async_arid        ),
.axi_s_araddr      (m0_async_araddr      ),
.axi_s_arlen       (m0_async_arlen       ),
.axi_s_arsize      (m0_async_arsize      ),
.axi_s_arburst     (m0_async_arburst     ),
.axi_s_arlock      (m0_async_arlock      ),
.axi_s_arcache     (m0_async_arcache     ),
.axi_s_arprot      (m0_async_arprot      ),
.axi_s_arvalid     (m0_async_arvalid     ),
.axi_s_arready     (m0_async_arready     ),
.axi_s_rready      (m0_async_rready      ),
.axi_s_rid         (m0_async_rid         ),
.axi_s_rdata       (m0_async_rdata       ),
.axi_s_rresp       (m0_async_rresp       ),
.axi_s_rlast       (m0_async_rlast       ),
.axi_s_rvalid      (m0_async_rvalid      ),

.s0_awid           (s0_awid         ),
.s0_awaddr         (s0_awaddr       ),
.s0_awlen          (s0_awlen        ),
.s0_awsize         (s0_awsize       ),
.s0_awburst        (s0_awburst      ),
.s0_awlock         (s0_awlock       ),
.s0_awcache        (s0_awcache      ),
.s0_awprot         (s0_awprot       ),
.s0_awvalid        (s0_awvalid      ),
.s0_awready        (s0_awready      ),
.s0_wid            (s0_wid          ),
.s0_wdata          (s0_wdata        ),
.s0_wstrb          (s0_wstrb        ),
.s0_wlast          (s0_wlast        ),
.s0_wvalid         (s0_wvalid       ),
.s0_wready         (s0_wready       ),
.s0_bid            (s0_bid          ),
.s0_bresp          (s0_bresp        ),
.s0_bvalid         (s0_bvalid       ),
.s0_bready         (s0_bready       ),
.s0_arid           (s0_arid         ),
.s0_araddr         (s0_araddr       ),
.s0_arlen          (s0_arlen        ),
.s0_arsize         (s0_arsize       ),
.s0_arburst        (s0_arburst      ),
.s0_arlock         (s0_arlock       ),
.s0_arcache        (s0_arcache      ),
.s0_arprot         (s0_arprot       ),
.s0_arvalid        (s0_arvalid      ),
.s0_arready        (s0_arready      ),
.s0_rid            (s0_rid          ),
.s0_rdata          (s0_rdata        ),
.s0_rresp          (s0_rresp        ),
.s0_rlast          (s0_rlast        ),
.s0_rvalid         (s0_rvalid       ),
.s0_rready         (s0_rready       ),

.s1_awid           (spi_s_awid          ),
.s1_awaddr         (spi_s_awaddr        ),
.s1_awlen          (spi_s_awlen         ),
.s1_awsize         (spi_s_awsize        ),
.s1_awburst        (spi_s_awburst       ),
.s1_awlock         (spi_s_awlock        ),
.s1_awcache        (spi_s_awcache       ),
.s1_awprot         (spi_s_awprot        ),
.s1_awvalid        (spi_s_awvalid       ),
.s1_awready        (spi_s_awready       ),
.s1_wid            (spi_s_wid           ),
.s1_wdata          (spi_s_wdata         ),
.s1_wstrb          (spi_s_wstrb         ),
.s1_wlast          (spi_s_wlast         ),
.s1_wvalid         (spi_s_wvalid        ),
.s1_wready         (spi_s_wready        ),
.s1_bid            (spi_s_bid           ),
.s1_bresp          (spi_s_bresp         ),
.s1_bvalid         (spi_s_bvalid        ),
.s1_bready         (spi_s_bready        ),
.s1_arid           (spi_s_arid          ),
.s1_araddr         (spi_s_araddr        ),
.s1_arlen          (spi_s_arlen         ),
.s1_arsize         (spi_s_arsize        ),
.s1_arburst        (spi_s_arburst       ),
.s1_arlock         (spi_s_arlock        ),
.s1_arcache        (spi_s_arcache       ),
.s1_arprot         (spi_s_arprot        ),
.s1_arvalid        (spi_s_arvalid       ),
.s1_arready        (spi_s_arready       ),
.s1_rid            (spi_s_rid           ),
.s1_rdata          (spi_s_rdata         ),
.s1_rresp          (spi_s_rresp         ),
.s1_rlast          (spi_s_rlast         ),
.s1_rvalid         (spi_s_rvalid        ),
.s1_rready         (spi_s_rready        ),

.s2_awid           (apb_s_awid         ),
.s2_awaddr         (apb_s_awaddr       ),
.s2_awlen          (apb_s_awlen        ),
.s2_awsize         (apb_s_awsize       ),
.s2_awburst        (apb_s_awburst      ),
.s2_awlock         (apb_s_awlock       ),
.s2_awcache        (apb_s_awcache      ),
.s2_awprot         (apb_s_awprot       ),
.s2_awvalid        (apb_s_awvalid      ),
.s2_awready        (apb_s_awready      ),
.s2_wid            (apb_s_wid          ),
.s2_wdata          (apb_s_wdata        ),
.s2_wstrb          (apb_s_wstrb        ),
.s2_wlast          (apb_s_wlast        ),
.s2_wvalid         (apb_s_wvalid       ),
.s2_wready         (apb_s_wready       ),
.s2_bid            (apb_s_bid          ),
.s2_bresp          (apb_s_bresp        ),
.s2_bvalid         (apb_s_bvalid       ),
.s2_bready         (apb_s_bready       ),
.s2_arid           (apb_s_arid         ),
.s2_araddr         (apb_s_araddr       ),
.s2_arlen          (apb_s_arlen        ),
.s2_arsize         (apb_s_arsize       ),
.s2_arburst        (apb_s_arburst      ),
.s2_arlock         (apb_s_arlock       ),
.s2_arcache        (apb_s_arcache      ),
.s2_arprot         (apb_s_arprot       ),
.s2_arvalid        (apb_s_arvalid      ),
.s2_arready        (apb_s_arready      ),
.s2_rid            (apb_s_rid          ),
.s2_rdata          (apb_s_rdata        ),
.s2_rresp          (apb_s_rresp        ),
.s2_rlast          (apb_s_rlast        ),
.s2_rvalid         (apb_s_rvalid       ),
.s2_rready         (apb_s_rready       ),

.s3_awid           (conf_s_awid         ),
.s3_awaddr         (conf_s_awaddr       ),
.s3_awlen          (conf_s_awlen        ),
.s3_awsize         (conf_s_awsize       ),
.s3_awburst        (conf_s_awburst      ),
.s3_awlock         (conf_s_awlock       ),
.s3_awcache        (conf_s_awcache      ),
.s3_awprot         (conf_s_awprot       ),
.s3_awvalid        (conf_s_awvalid      ),
.s3_awready        (conf_s_awready      ),
.s3_wid            (conf_s_wid          ),
.s3_wdata          (conf_s_wdata        ),
.s3_wstrb          (conf_s_wstrb        ),
.s3_wlast          (conf_s_wlast        ),
.s3_wvalid         (conf_s_wvalid       ),
.s3_wready         (conf_s_wready       ),
.s3_bid            (conf_s_bid          ),
.s3_bresp          (conf_s_bresp        ),
.s3_bvalid         (conf_s_bvalid       ),
.s3_bready         (conf_s_bready       ),
.s3_arid           (conf_s_arid         ),
.s3_araddr         (conf_s_araddr       ),
.s3_arlen          (conf_s_arlen        ),
.s3_arsize         (conf_s_arsize       ),
.s3_arburst        (conf_s_arburst      ),
.s3_arlock         (conf_s_arlock       ),
.s3_arcache        (conf_s_arcache      ),
.s3_arprot         (conf_s_arprot       ),
.s3_arvalid        (conf_s_arvalid      ),
.s3_arready        (conf_s_arready      ),
.s3_rid            (conf_s_rid          ),
.s3_rdata          (conf_s_rdata        ),
.s3_rresp          (conf_s_rresp        ),
.s3_rlast          (conf_s_rlast        ),
.s3_rvalid         (conf_s_rvalid       ),
.s3_rready         (conf_s_rready       ),

.s4_awid           (mac_s_awid         ),
.s4_awaddr         (mac_s_awaddr       ),
.s4_awlen          (mac_s_awlen        ),
.s4_awsize         (mac_s_awsize       ),
.s4_awburst        (mac_s_awburst      ),
.s4_awlock         (mac_s_awlock       ),
.s4_awcache        (mac_s_awcache      ),
.s4_awprot         (mac_s_awprot       ),
.s4_awvalid        (mac_s_awvalid      ),
.s4_awready        (mac_s_awready      ),
.s4_wid            (mac_s_wid          ),
.s4_wdata          (mac_s_wdata        ),
.s4_wstrb          (mac_s_wstrb        ),
.s4_wlast          (mac_s_wlast        ),
.s4_wvalid         (mac_s_wvalid       ),
.s4_wready         (mac_s_wready       ),
.s4_bid            (mac_s_bid          ),
.s4_bresp          (mac_s_bresp        ),
.s4_bvalid         (mac_s_bvalid       ),
.s4_bready         (mac_s_bready       ),
.s4_arid           (mac_s_arid         ),
.s4_araddr         (mac_s_araddr       ),
.s4_arlen          (mac_s_arlen        ),
.s4_arsize         (mac_s_arsize       ),
.s4_arburst        (mac_s_arburst      ),
.s4_arlock         (mac_s_arlock       ),
.s4_arcache        (mac_s_arcache      ),
.s4_arprot         (mac_s_arprot       ),
.s4_arvalid        (mac_s_arvalid      ),
.s4_arready        (mac_s_arready      ),
.s4_rid            (mac_s_rid          ),
.s4_rdata          (mac_s_rdata        ),
.s4_rresp          (mac_s_rresp        ),
.s4_rlast          (mac_s_rlast        ),
.s4_rvalid         (mac_s_rvalid       ),
.s4_rready         (mac_s_rready       ),

.s5_awid           (lcd_s_awid         ),
.s5_awaddr         (lcd_s_awaddr       ),
.s5_awlen          (lcd_s_awlen        ),
.s5_awsize         (lcd_s_awsize       ),
.s5_awburst        (lcd_s_awburst      ),
.s5_awlock         (lcd_s_awlock       ),
.s5_awcache        (lcd_s_awcache      ),
.s5_awprot         (lcd_s_awprot       ),
.s5_awvalid        (lcd_s_awvalid      ),
.s5_awready        (lcd_s_awready      ),
.s5_wid            (lcd_s_wid          ),
.s5_wdata          (lcd_s_wdata        ),
.s5_wstrb          (lcd_s_wstrb        ),
.s5_wlast          (lcd_s_wlast        ),
.s5_wvalid         (lcd_s_wvalid       ),
.s5_wready         (lcd_s_wready       ),
.s5_bid            (lcd_s_bid          ),
.s5_bresp          (lcd_s_bresp        ),
.s5_bvalid         (lcd_s_bvalid       ),
.s5_bready         (lcd_s_bready       ),
.s5_arid           (lcd_s_arid         ),
.s5_araddr         (lcd_s_araddr       ),
.s5_arlen          (lcd_s_arlen        ),
.s5_arsize         (lcd_s_arsize       ),
.s5_arburst        (lcd_s_arburst      ),
.s5_arlock         (lcd_s_arlock       ),
.s5_arcache        (lcd_s_arcache      ),
.s5_arprot         (lcd_s_arprot       ),
.s5_arvalid        (lcd_s_arvalid      ),
.s5_arready        (lcd_s_arready      ),
.s5_rid            (lcd_s_rid          ),
.s5_rdata          (lcd_s_rdata        ),
.s5_rresp          (lcd_s_rresp        ),
.s5_rlast          (lcd_s_rlast        ),
.s5_rvalid         (lcd_s_rvalid       ),
.s5_rready         (lcd_s_rready       ),

.s6_awid           (ps2_s_awid),
.s6_awaddr         (ps2_s_awaddr),
.s6_awlen          (ps2_s_awlen),
.s6_awsize         (ps2_s_awsize),
.s6_awburst        (ps2_s_awburst),
.s6_awlock         (ps2_s_awlock),
.s6_awcache        (ps2_s_awcache),
.s6_awprot         (ps2_s_awprot),
.s6_awvalid        (ps2_s_awvalid),
.s6_awready        (ps2_s_awready),
.s6_wid            (ps2_s_wid),
.s6_wdata          (ps2_s_wdata),
.s6_wstrb          (ps2_s_wstrb),
.s6_wlast          (ps2_s_wlast),
.s6_wvalid         (ps2_s_wvalid),
.s6_wready         (ps2_s_wready),
.s6_bid            (ps2_s_bid),
.s6_bresp          (ps2_s_bresp),
.s6_bvalid         (ps2_s_bvalid),
.s6_bready         (ps2_s_bready),
.s6_arid           (ps2_s_arid),
.s6_araddr         (ps2_s_araddr),
.s6_arlen          (ps2_s_arlen),
.s6_arsize         (ps2_s_arsize),
.s6_arburst        (ps2_s_arburst),
.s6_arlock         (ps2_s_arlock),
.s6_arcache        (ps2_s_arcache),
.s6_arprot         (ps2_s_arprot),
.s6_arvalid        (ps2_s_arvalid),
.s6_arready        (ps2_s_arready),
.s6_rid            (ps2_s_rid),
.s6_rdata          (ps2_s_rdata),
.s6_rresp          (ps2_s_rresp),
.s6_rlast          (ps2_s_rlast),
.s6_rvalid         (ps2_s_rvalid),
.s6_rready         (ps2_s_rready),

.s7_awid           (usb_s_awid),
.s7_awaddr         (usb_s_awaddr),
.s7_awlen          (usb_s_awlen),
.s7_awsize         (usb_s_awsize),
.s7_awburst        (usb_s_awburst),
.s7_awlock         (usb_s_awlock),
.s7_awcache        (usb_s_awcache),
.s7_awprot         (usb_s_awprot),
.s7_awvalid        (usb_s_awvalid),
.s7_awready        (usb_s_awready),
.s7_wid            (usb_s_wid),
.s7_wdata          (usb_s_wdata),
.s7_wstrb          (usb_s_wstrb),
.s7_wlast          (usb_s_wlast),
.s7_wvalid         (usb_s_wvalid),
.s7_wready         (usb_s_wready),
.s7_bid            (usb_s_bid),
.s7_bresp          (usb_s_bresp),
.s7_bvalid         (usb_s_bvalid),
.s7_bready         (usb_s_bready),
.s7_arid           (usb_s_arid),
.s7_araddr         (usb_s_araddr),
.s7_arlen          (usb_s_arlen),
.s7_arsize         (usb_s_arsize),
.s7_arburst        (usb_s_arburst),
.s7_arlock         (usb_s_arlock),
.s7_arcache        (usb_s_arcache),
.s7_arprot         (usb_s_arprot),
.s7_arvalid        (usb_s_arvalid),
.s7_arready        (usb_s_arready),
.s7_rid            (usb_s_rid),
.s7_rdata          (usb_s_rdata),
.s7_rresp          (usb_s_rresp),
.s7_rlast          (usb_s_rlast),
.s7_rvalid         (usb_s_rvalid),
.s7_rready         (usb_s_rready),

.axi_s_aclk        (aclk                )
);

//SPI
spi_flash_ctrl SPI
(
    // --- 全局信号 ---
.aclk           (aclk              ),       // input,  工作时钟(33MHz), 来自clk_pll_33
.aresetn        (aresetn           ),       // input,  复位(低有效), 来自外部引脚resetn
.spi_addr       (16'h1fe8          ),       // input,  SPI控制器基地址偏移, 固定1fe8
.fast_startup   (1'b0              ),       // input,  快速启动模式, 关闭
    // --- AXI从端AW通道: 写请求 ← axi_slave_mux.S1 ---
.s_awid         (spi_s_awid        ),       // input,  写请求ID, 来自axi_slave_mux.s1_awid
.s_awaddr       (spi_s_awaddr      ),       // input,  写请求地址, 来自axi_slave_mux.s1_awaddr
.s_awlen        (spi_s_awlen       ),       // input,  写请求突发长度, 来自axi_slave_mux.s1_awlen
.s_awsize       (spi_s_awsize      ),       // input,  写请求数据宽度, 来自axi_slave_mux.s1_awsize
.s_awburst      (spi_s_awburst     ),       // input,  写请求突发类型, 来自axi_slave_mux.s1_awburst
.s_awlock       (spi_s_awlock      ),       // input,  写请求锁类型, 来自axi_slave_mux.s1_awlock
.s_awcache      (spi_s_awcache     ),       // input,  写请求Cache属性, 来自axi_slave_mux.s1_awcache
.s_awprot       (spi_s_awprot      ),       // input,  写请求保护类型, 来自axi_slave_mux.s1_awprot
.s_awvalid      (spi_s_awvalid     ),       // input,  写请求有效, 来自axi_slave_mux.s1_awvalid
.s_awready      (spi_s_awready     ),       // output, 写请求就绪, 连接axi_slave_mux.s1_awready
    // --- AXI从端W通道: 写数据 ← axi_slave_mux.S1 ---
.s_wready       (spi_s_wready      ),       // output, 写数据就绪, 连接axi_slave_mux.s1_wready
.s_wid          (spi_s_wid         ),       // input,  写数据ID, 来自axi_slave_mux.s1_wid
.s_wdata        (spi_s_wdata       ),       // input,  写数据, 来自axi_slave_mux.s1_wdata
.s_wstrb        (spi_s_wstrb       ),       // input,  写字节使能, 来自axi_slave_mux.s1_wstrb
.s_wlast        (spi_s_wlast       ),       // input,  写数据最后拍, 来自axi_slave_mux.s1_wlast
.s_wvalid       (spi_s_wvalid      ),       // input,  写数据有效, 来自axi_slave_mux.s1_wvalid
    // --- AXI从端B通道: 写响应 → axi_slave_mux.S1 ---
.s_bid          (spi_s_bid         ),       // output, 写响应ID, 连接axi_slave_mux.s1_bid
.s_bresp        (spi_s_bresp       ),       // output, 写响应状态, 连接axi_slave_mux.s1_bresp
.s_bvalid       (spi_s_bvalid      ),       // output, 写响应有效, 连接axi_slave_mux.s1_bvalid
.s_bready       (spi_s_bready      ),       // input,  写响应就绪, 来自axi_slave_mux.s1_bready
    // --- AXI从端AR通道: 读请求 ← axi_slave_mux.S1 ---
.s_arid         (spi_s_arid        ),       // input,  读请求ID, 来自axi_slave_mux.s1_arid
.s_araddr       (spi_s_araddr      ),       // input,  读请求地址, 来自axi_slave_mux.s1_araddr
.s_arlen        (spi_s_arlen       ),       // input,  读请求突发长度, 来自axi_slave_mux.s1_arlen
.s_arsize       (spi_s_arsize      ),       // input,  读请求数据宽度, 来自axi_slave_mux.s1_arsize
.s_arburst      (spi_s_arburst     ),       // input,  读请求突发类型, 来自axi_slave_mux.s1_arburst
.s_arlock       (spi_s_arlock      ),       // input,  读请求锁类型, 来自axi_slave_mux.s1_arlock
.s_arcache      (spi_s_arcache     ),       // input,  读请求Cache属性, 来自axi_slave_mux.s1_arcache
.s_arprot       (spi_s_arprot      ),       // input,  读请求保护类型, 来自axi_slave_mux.s1_arprot
.s_arvalid      (spi_s_arvalid     ),       // input,  读请求有效, 来自axi_slave_mux.s1_arvalid
.s_arready      (spi_s_arready     ),       // output, 读请求就绪, 连接axi_slave_mux.s1_arready
    // --- AXI从端R通道: 读响应 → axi_slave_mux.S1 ---
.s_rready       (spi_s_rready      ),       // input,  读响应就绪, 来自axi_slave_mux.s1_rready
.s_rid          (spi_s_rid         ),       // output, 读响应ID, 连接axi_slave_mux.s1_rid
.s_rdata        (spi_s_rdata       ),       // output, 读响应数据(SPI Flash读取内容), 连接axi_slave_mux.s1_rdata
.s_rresp        (spi_s_rresp       ),       // output, 读响应状态, 连接axi_slave_mux.s1_rresp
.s_rlast        (spi_s_rlast       ),       // output, 读响应最后拍, 连接axi_slave_mux.s1_rlast
.s_rvalid       (spi_s_rvalid      ),       // output, 读响应有效, 连接axi_slave_mux.s1_rvalid
    // --- 电源管理 ---
.power_down_req (1'b0              ),       // input,  掉电请求, 固定0(不使用)
.power_down_ack (                  ),       // output, 掉电确认, 悬空未接
    // --- SPI物理接口 → 外部SPI Flash芯片 ---
.csn_o          (spi_csn_o         ),       // output, SPI片选输出[3:0], 连接片选逻辑
.csn_en         (spi_csn_en        ),       // output, SPI片选使能[3:0], 连接片选逻辑
.sck_o          (spi_sck_o         ),       // output, SPI时钟输出, 连接外部引脚SPI_CLK
.sdo_i          (spi_sdo_i         ),       // input,  SPI主出数据输入(回环), 来自SPI_MOSI
.sdo_o          (spi_sdo_o         ),       // output, SPI主出数据输出, 连接外部引脚SPI_MOSI
.sdo_en         (spi_sdo_en        ),       // output, SPI主出使能(低有效), 控制MOSI方向
.sdi_i          (spi_sdi_i         ),       // input,  SPI主入数据输入, 来自SPI_MISO
.sdi_o          (spi_sdi_o         ),       // output, SPI主入数据输出, 连接外部引脚SPI_MISO
.sdi_en         (spi_sdi_en        ),       // output, SPI主入使能, 控制MISO方向
.inta_o         (spi_inta_o        )        // output, SPI中断输出, 连接中断汇聚int_out[3]
);

//confreg
confreg CONFREG(
    // --- 全局信号 ---
.aclk              (aclk               ),       // input,  工作时钟(33MHz), 来自clk_pll_33
.aresetn           (aresetn            ),       // input,  复位(低有效), 来自外部引脚resetn
    // --- AXI从端AW通道: 写请求 ← axi_slave_mux.S3 ---
.s_awid            (conf_s_awid        ),       // input,  写请求ID, 来自axi_slave_mux.s3_awid
.s_awaddr          (conf_s_awaddr      ),       // input,  写请求地址, 来自axi_slave_mux.s3_awaddr
.s_awlen           (conf_s_awlen       ),       // input,  写请求突发长度, 来自axi_slave_mux.s3_awlen
.s_awsize          (conf_s_awsize      ),       // input,  写请求数据宽度, 来自axi_slave_mux.s3_awsize
.s_awburst         (conf_s_awburst     ),       // input,  写请求突发类型, 来自axi_slave_mux.s3_awburst
.s_awlock          (conf_s_awlock      ),       // input,  写请求锁类型, 来自axi_slave_mux.s3_awlock
.s_awcache         (conf_s_awcache     ),       // input,  写请求Cache属性, 来自axi_slave_mux.s3_awcache
.s_awprot          (conf_s_awprot      ),       // input,  写请求保护类型, 来自axi_slave_mux.s3_awprot
.s_awvalid         (conf_s_awvalid     ),       // input,  写请求有效, 来自axi_slave_mux.s3_awvalid
.s_awready         (conf_s_awready     ),       // output, 写请求就绪, 连接axi_slave_mux.s3_awready
    // --- AXI从端W通道: 写数据 ← axi_slave_mux.S3 ---
.s_wready          (conf_s_wready      ),       // output, 写数据就绪, 连接axi_slave_mux.s3_wready
.s_wid             (conf_s_wid         ),       // input,  写数据ID, 来自axi_slave_mux.s3_wid
.s_wdata           (conf_s_wdata       ),       // input,  写数据(LED/数码管/定时器等), 来自axi_slave_mux.s3_wdata
.s_wstrb           (conf_s_wstrb       ),       // input,  写字节使能, 来自axi_slave_mux.s3_wstrb
.s_wlast           (conf_s_wlast       ),       // input,  写数据最后拍, 来自axi_slave_mux.s3_wlast
.s_wvalid          (conf_s_wvalid      ),       // input,  写数据有效, 来自axi_slave_mux.s3_wvalid
    // --- AXI从端B通道: 写响应 → axi_slave_mux.S3 ---
.s_bid             (conf_s_bid         ),       // output, 写响应ID, 连接axi_slave_mux.s3_bid
.s_bresp           (conf_s_bresp       ),       // output, 写响应状态, 连接axi_slave_mux.s3_bresp
.s_bvalid          (conf_s_bvalid      ),       // output, 写响应有效, 连接axi_slave_mux.s3_bvalid
.s_bready          (conf_s_bready      ),       // input,  写响应就绪, 来自axi_slave_mux.s3_bready
    // --- AXI从端AR通道: 读请求 ← axi_slave_mux.S3 ---
.s_arid            (conf_s_arid        ),       // input,  读请求ID, 来自axi_slave_mux.s3_arid
.s_araddr          (conf_s_araddr      ),       // input,  读请求地址, 来自axi_slave_mux.s3_araddr
.s_arlen           (conf_s_arlen       ),       // input,  读请求突发长度, 来自axi_slave_mux.s3_arlen
.s_arsize          (conf_s_arsize      ),       // input,  读请求数据宽度, 来自axi_slave_mux.s3_arsize
.s_arburst         (conf_s_arburst     ),       // input,  读请求突发类型, 来自axi_slave_mux.s3_arburst
.s_arlock          (conf_s_arlock      ),       // input,  读请求锁类型, 来自axi_slave_mux.s3_arlock
.s_arcache         (conf_s_arcache     ),       // input,  读请求Cache属性, 来自axi_slave_mux.s3_arcache
.s_arprot          (conf_s_arprot      ),       // input,  读请求保护类型, 来自axi_slave_mux.s3_arprot
.s_arvalid         (conf_s_arvalid     ),       // input,  读请求有效, 来自axi_slave_mux.s3_arvalid
.s_arready         (conf_s_arready     ),       // output, 读请求就绪, 连接axi_slave_mux.s3_arready
    // --- AXI从端R通道: 读响应 → axi_slave_mux.S3 ---
.s_rready          (conf_s_rready      ),       // input,  读响应就绪, 来自axi_slave_mux.s3_rready
.s_rid             (conf_s_rid         ),       // output, 读响应ID, 连接axi_slave_mux.s3_rid
.s_rdata           (conf_s_rdata       ),       // output, 读响应数据(开关/按键/定时器/LED等), 连接axi_slave_mux.s3_rdata
.s_rresp           (conf_s_rresp       ),       // output, 读响应状态, 连接axi_slave_mux.s3_rresp
.s_rlast           (conf_s_rlast       ),       // output, 读响应最后拍, 连接axi_slave_mux.s3_rlast
.s_rvalid          (conf_s_rvalid      ),       // output, 读响应有效, 连接axi_slave_mux.s3_rvalid

    // --- DMA交互 ---
.order_addr_reg    (order_addr_in      ),       // output, DMA订单地址寄存器(bit2=读请求,bit3=写完成,bit4=启动), 连接dma_master.order_addr_in
.write_dma_end     (write_dma_end      ),       // input,  DMA写完成标志, 来自dma_master.write_dma_end
.finish_read_order (finish_read_order  ),       // input,  DMA读订单完成标志, 来自dma_master.finish_read_order
.soft_reset_req    (soft_reset_req     ),       // output, 软件复位粘滞请求

    // --- 通用配置寄存器cr00~cr07 ---
.cr00              (cr00        ),               // output, 通用配置寄存器0, 未被其他模块使用
.cr01              (cr01        ),               // output, 通用配置寄存器1, 未被其他模块使用
.cr02              (cr02        ),               // output, 通用配置寄存器2, 未被其他模块使用
.cr03              (cr03        ),               // output, 通用配置寄存器3, 未被其他模块使用
.cr04              (cr04        ),               // output, 通用配置寄存器4, 未被其他模块使用
.cr05              (cr05        ),               // output, 通用配置寄存器5, 未被其他模块使用
.cr06              (cr06        ),               // output, 通用配置寄存器6, 未被其他模块使用
.cr07              (cr07        ),               // output, 通用配置寄存器7, 未被其他模块使用

    // --- FPGA板载外设 → 外部引脚 ---
.led               (led         ),               // output, 16位LED灯, 连接外部引脚led[15:0]
.led_rg0           (led_rg0     ),               // output, 2位双色LED0, 连接外部引脚led_rg0[1:0]
.led_rg1           (led_rg1     ),               // output, 2位双色LED1, 连接外部引脚led_rg1[1:0]
.num_csn           (conf_num_csn),               // output, 8位数码管片选(低有效), 连接外部引脚num_csn[7:0]
.num_a_g           (conf_num_a_g),               // output, 7段数码管段选, 连接外部引脚num_a_g[6:0]
.switch            (switch      ),               // input,  8位拨码开关, 来自外部引脚switch[7:0]
.btn_key_col       (btn_key_col ),               // output, 4×4矩阵键盘列扫描输出, 连接外部引脚btn_key_col[3:0]
.btn_key_row       (btn_key_row ),               // input,  4×4矩阵键盘行输入, 来自外部引脚btn_key_row[3:0]
.btn_step          (btn_step    )                // input,  2位步进按键, 来自外部引脚btn_step[1:0]
);

//LCD DMA：从DDR3读取像素并提供16bit流给LCD控制器
lcd_dma LCD_DMA (
    .aclk        (aclk),
    .aresetn     (aresetn),
    .start       (lcd_dma_start),
    .fb_addr     (lcd_dma_base_addr),
    .pixel_count (lcd_dma_pixel_count),
    .busy        (lcd_dma_busy),
    .done        (lcd_dma_done),
    .error       (lcd_dma_error),
    .arid        (lcd_dma_arid),
    .araddr      (lcd_dma_araddr),
    .arlen       (lcd_dma_arlen),
    .arsize      (lcd_dma_arsize),
    .arburst     (lcd_dma_arburst),
    .arlock      (lcd_dma_arlock),
    .arcache     (lcd_dma_arcache),
    .arprot      (lcd_dma_arprot),
    .arvalid     (lcd_dma_arvalid),
    .arready     (lcd_dma_arready),
    .rid         (lcd_dma_rid),
    .rdata       (lcd_dma_rdata),
    .rresp       (lcd_dma_rresp),
    .rlast       (lcd_dma_rlast),
    .rvalid      (lcd_dma_rvalid),
    .rready      (lcd_dma_rready),
    .pixel_data  (lcd_dma_pixel_data),
    .pixel_valid (lcd_dma_pixel_valid),
    .pixel_ready (lcd_dma_pixel_ready)
);

//MAC top
ethernet_top ETHERNET_TOP(

    // --- 全局信号 ---
    .hclk       (aclk   ),                       // input,  工作时钟(33MHz), 来自clk_pll_33
    .hrst_      (aresetn),                       // input,  复位(低有效), 来自外部引脚resetn
    // ===================== AXI主端: MAC DMA读写DDR3 → axi_interconnect_0.S01 =====================
    // --- AW通道: DMA写请求 → DDR3 ---
    .mawid_o    (mac_m_awid    ),                // output, 主端写请求ID, 连接axi_interconnect_0.S01_AXI_AWID
    .mawaddr_o  (mac_m_awaddr  ),                // output, 主端写请求地址(DDR3缓冲区地址), 连接axi_interconnect_0.S01_AXI_AWADDR
    .mawlen_o   (mac_m_awlen   ),                // output, 主端写请求突发长度, 连接axi_interconnect_0.S01_AXI_AWLEN
    .mawsize_o  (mac_m_awsize  ),                // output, 主端写请求数据宽度, 连接axi_interconnect_0.S01_AXI_AWSIZE
    .mawburst_o (mac_m_awburst ),                // output, 主端写请求突发类型, 连接axi_interconnect_0.S01_AXI_AWBURST
    .mawlock_o  (mac_m_awlock  ),                // output, 主端写请求锁类型, 连接axi_interconnect_0.S01_AXI_AWLOCK
    .mawcache_o (mac_m_awcache ),                // output, 主端写请求Cache属性, 连接axi_interconnect_0.S01_AXI_AWCACHE
    .mawprot_o  (mac_m_awprot  ),                // output, 主端写请求保护类型, 连接axi_interconnect_0.S01_AXI_AWPROT
    .mawvalid_o (mac_m_awvalid ),                // output, 主端写请求有效, 连接axi_interconnect_0.S01_AXI_AWVALID
    .mawready_i (mac_m_awready ),                // input,  主端写请求就绪, 来自axi_interconnect_0.S01_AXI_AWREADY
    // --- W通道: DMA写数据 → DDR3 ---
    .mwid_o     (mac_m_wid     ),                // output, 主端写数据ID, 连接axi_interconnect_0.S01_AXI_WID
    .mwdata_o   (mac_m_wdata   ),                // output, 主端写数据(RX帧写入DDR3), 连接axi_interconnect_0.S01_AXI_WDATA
    .mwstrb_o   (mac_m_wstrb   ),                // output, 主端写字节使能, 连接axi_interconnect_0.S01_AXI_WSTRB
    .mwlast_o   (mac_m_wlast   ),                // output, 主端写数据最后拍, 连接axi_interconnect_0.S01_AXI_WLAST
    .mwvalid_o  (mac_m_wvalid  ),                // output, 主端写数据有效, 连接axi_interconnect_0.S01_AXI_WVALID
    .mwready_i  (mac_m_wready  ),                // input,  主端写数据就绪, 来自axi_interconnect_0.S01_AXI_WREADY
    // --- B通道: DMA写响应 ← DDR3 ---
    .mbid_i     (mac_m_bid     ),                // input,  主端写响应ID, 来自axi_interconnect_0.S01_AXI_BID
    .mbresp_i   (mac_m_bresp   ),                // input,  主端写响应状态, 来自axi_interconnect_0.S01_AXI_BRESP
    .mbvalid_i  (mac_m_bvalid  ),                // input,  主端写响应有效, 来自axi_interconnect_0.S01_AXI_BVALID
    .mbready_o  (mac_m_bready  ),                // output, 主端写响应就绪, 连接axi_interconnect_0.S01_AXI_BREADY
    // --- AR通道: DMA读请求 → DDR3 ---
    .marid_o    (mac_m_arid    ),                // output, 主端读请求ID, 连接axi_interconnect_0.S01_AXI_ARID
    .maraddr_o  (mac_m_araddr  ),                // output, 主端读请求地址(DDR3缓冲区地址), 连接axi_interconnect_0.S01_AXI_ARADDR
    .marlen_o   (mac_m_arlen   ),                // output, 主端读请求突发长度, 连接axi_interconnect_0.S01_AXI_ARLEN
    .marsize_o  (mac_m_arsize  ),                // output, 主端读请求数据宽度, 连接axi_interconnect_0.S01_AXI_ARSIZE
    .marburst_o (mac_m_arburst ),                // output, 主端读请求突发类型, 连接axi_interconnect_0.S01_AXI_ARBURST
    .marlock_o  (mac_m_arlock  ),                // output, 主端读请求锁类型, 连接axi_interconnect_0.S01_AXI_ARLOCK
    .marcache_o (mac_m_arcache ),                // output, 主端读请求Cache属性, 连接axi_interconnect_0.S01_AXI_ARCACHE
    .marprot_o  (mac_m_arprot  ),                // output, 主端读请求保护类型, 连接axi_interconnect_0.S01_AXI_ARPROT
    .marvalid_o (mac_m_arvalid ),                // output, 主端读请求有效, 连接axi_interconnect_0.S01_AXI_ARVALID
    .marready_i (mac_m_arready ),                // input,  主端读请求就绪, 来自axi_interconnect_0.S01_AXI_ARREADY
    // --- R通道: DMA读响应 ← DDR3 ---
    .mrid_i     (mac_m_rid     ),                // input,  主端读响应ID, 来自axi_interconnect_0.S01_AXI_RID
    .mrdata_i   (mac_m_rdata   ),                // input,  主端读响应数据(TX帧从DDR3读出), 来自axi_interconnect_0.S01_AXI_RDATA
    .mrresp_i   (mac_m_rresp   ),                // input,  主端读响应状态, 来自axi_interconnect_0.S01_AXI_RRESP
    .mrlast_i   (mac_m_rlast   ),                // input,  主端读响应最后拍, 来自axi_interconnect_0.S01_AXI_RLAST
    .mrvalid_i  (mac_m_rvalid  ),                // input,  主端读响应有效, 来自axi_interconnect_0.S01_AXI_RVALID
    .mrready_o  (mac_m_rready  ),                // output, 主端读响应就绪, 连接axi_interconnect_0.S01_AXI_RREADY
    // ===================== AXI从端: CPU配置MAC寄存器 ← axi_slave_mux.S4 =====================
    // --- AW通道: 写请求 ← CPU ---
    .sawid_i    (mac_s_awid    ),                // input,  从端写请求ID, 来自axi_slave_mux.s4_awid
    .sawaddr_i  (mac_s_awaddr  ),                // input,  从端写请求地址(MAC寄存器地址), 来自axi_slave_mux.s4_awaddr
    .sawlen_i   (mac_s_awlen   ),                // input,  从端写请求突发长度, 来自axi_slave_mux.s4_awlen
    .sawsize_i  (mac_s_awsize  ),                // input,  从端写请求数据宽度, 来自axi_slave_mux.s4_awsize
    .sawburst_i (mac_s_awburst ),                // input,  从端写请求突发类型, 来自axi_slave_mux.s4_awburst
    .sawlock_i  (mac_s_awlock  ),                // input,  从端写请求锁类型, 来自axi_slave_mux.s4_awlock
    .sawcache_i (mac_s_awcache ),                // input,  从端写请求Cache属性, 来自axi_slave_mux.s4_awcache
    .sawprot_i  (mac_s_awprot  ),                // input,  从端写请求保护类型, 来自axi_slave_mux.s4_awprot
    .sawvalid_i (mac_s_awvalid ),                // input,  从端写请求有效, 来自axi_slave_mux.s4_awvalid
    .sawready_o (mac_s_awready ),                // output, 从端写请求就绪, 连接axi_slave_mux.s4_awready
    // --- W通道: 写数据 ← CPU ---
    .swid_i     (mac_s_wid     ),                // input,  从端写数据ID, 来自axi_slave_mux.s4_wid
    .swdata_i   (mac_s_wdata   ),                // input,  从端写数据(MAC寄存器配置值), 来自axi_slave_mux.s4_wdata
    .swstrb_i   (mac_s_wstrb   ),                // input,  从端写字节使能, 来自axi_slave_mux.s4_wstrb
    .swlast_i   (mac_s_wlast   ),                // input,  从端写数据最后拍, 来自axi_slave_mux.s4_wlast
    .swvalid_i  (mac_s_wvalid  ),                // input,  从端写数据有效, 来自axi_slave_mux.s4_wvalid
    .swready_o  (mac_s_wready  ),                // output, 从端写数据就绪, 连接axi_slave_mux.s4_wready
    // --- B通道: 写响应 → CPU ---
    .sbid_o     (mac_s_bid     ),                // output, 从端写响应ID, 连接axi_slave_mux.s4_bid
    .sbresp_o   (mac_s_bresp   ),                // output, 从端写响应状态, 连接axi_slave_mux.s4_bresp
    .sbvalid_o  (mac_s_bvalid  ),                // output, 从端写响应有效, 连接axi_slave_mux.s4_bvalid
    .sbready_i  (mac_s_bready  ),                // input,  从端写响应就绪, 来自axi_slave_mux.s4_bready
    // --- AR通道: 读请求 ← CPU ---
    .sarid_i    (mac_s_arid    ),                // input,  从端读请求ID, 来自axi_slave_mux.s4_arid
    .saraddr_i  (mac_s_araddr  ),                // input,  从端读请求地址(MAC寄存器地址), 来自axi_slave_mux.s4_araddr
    .sarlen_i   (mac_s_arlen   ),                // input,  从端读请求突发长度, 来自axi_slave_mux.s4_arlen
    .sarsize_i  (mac_s_arsize  ),                // input,  从端读请求数据宽度, 来自axi_slave_mux.s4_arsize
    .sarburst_i (mac_s_arburst ),                // input,  从端读请求突发类型, 来自axi_slave_mux.s4_arburst
    .sarlock_i  (mac_s_arlock  ),                // input,  从端读请求锁类型, 来自axi_slave_mux.s4_arlock
    .sarcache_i (mac_s_arcache ),                // input,  从端读请求Cache属性, 来自axi_slave_mux.s4_arcache
    .sarprot_i  (mac_s_arprot  ),                // input,  从端读请求保护类型, 来自axi_slave_mux.s4_arprot
    .sarvalid_i (mac_s_arvalid ),                // input,  从端读请求有效, 来自axi_slave_mux.s4_arvalid
    .sarready_o (mac_s_arready ),                // output, 从端读请求就绪, 连接axi_slave_mux.s4_arready
    // --- R通道: 读响应 → CPU ---
    .srid_o     (mac_s_rid     ),                // output, 从端读响应ID, 连接axi_slave_mux.s4_rid
    .srdata_o   (mac_s_rdata   ),                // output, 从端读响应数据(MAC寄存器状态), 连接axi_slave_mux.s4_rdata
    .srresp_o   (mac_s_rresp   ),                // output, 从端读响应状态, 连接axi_slave_mux.s4_rresp
    .srlast_o   (mac_s_rlast   ),                // output, 从端读响应最后拍, 连接axi_slave_mux.s4_rlast
    .srvalid_o  (mac_s_rvalid  ),                // output, 从端读响应有效, 连接axi_slave_mux.s4_rvalid
    .srready_i  (mac_s_rready  ),                // input,  从端读响应就绪, 来自axi_slave_mux.s4_rready

    // --- 中断 ---
    .interrupt_0 (mac_int),                      // output, MAC中断输出, 连接中断汇聚int_out[1]

    // ===================== MII物理接口 → 外部以太网PHY芯片 =====================
    //TX
    .mtxclk_0    (mtxclk_0 ),                    // input,  MII TX时钟(来自PHY), 来自外部引脚mtxclk_0
    .mtxen_0     (mtxen_0  ),                    // output, MII TX使能, 连接外部引脚mtxen_0
    .mtxd_0      (mtxd_0   ),                    // output, MII TX数据[3:0], 连接外部引脚mtxd_0
    .mtxerr_0    (mtxerr_0 ),                    // output, MII TX错误指示, 连接外部引脚mtxerr_0
    //RX
    .mrxclk_0    (mrxclk_0 ),                    // input,  MII RX时钟(来自PHY), 来自外部引脚mrxclk_0
    .mrxdv_0     (mrxdv_0  ),                    // input,  MII RX数据有效, 来自外部引脚mrxdv_0
    .mrxd_0      (mrxd_0   ),                    // input,  MII RX数据[3:0], 来自外部引脚mrxd_0
    .mrxerr_0    (mrxerr_0 ),                    // input,  MII RX错误指示, 来自外部引脚mrxerr_0
    .mcoll_0     (mcoll_0  ),                    // input,  MII 冲突检测, 来自外部引脚mcoll_0
    .mcrs_0      (mcrs_0   ),                    // input,  MII 载波侦听, 来自外部引脚mcrs_0
    // MIIM (PHY管理接口)
    .mdc_0       (mdc_0    ),                    // output, MIIM管理时钟, 连接外部引脚mdc_0
    .md_i_0      (md_i_0   ),                    // input,  MIIM管理数据输入(从PHY读回), 来自IOBUF.mdio_0
    .md_o_0      (md_o_0   ),                    // output, MIIM管理数据输出(向PHY写入), 连接IOBUF.mdio_0
    .md_oe_0     (md_oe_0  )                     // output, MIIM管理数据输出使能, 控制mdio_0方向

);

//ddr3
wire   c1_sys_clk_i;
wire   c1_clk_ref_i;
wire   c1_sys_rst_i;
wire   c1_calib_done;
wire   c1_clk0;
wire   c1_rst0;
wire        ddr_aresetn;
reg         interconnect_aresetn;

clk_pll_33  clk_pll_33
 (
  // Clock out ports
  .clk_out1(cpu_clk),  //50MHz
  .clk_out2(uncore_clk), //33MHz
 // Clock in ports
  .clk_in1(clk)        //100MHz
 );

clk_wiz_0  clk_pll_1
(
    .clk_out1(c1_clk_ref_i),  //200MHz
    .clk_in1(clk)             //100MHz
);

assign c1_sys_clk_i      = clk;
assign c1_sys_rst_i      = system_resetn;
assign aclk              = uncore_clk;
//assign aclk              = c1_clk0;
// Reset to the AXI shim
reg c1_calib_done_0;
reg c1_calib_done_1;
reg c1_rst0_0;
reg c1_rst0_1;
reg interconnect_aresetn_0;
/*always @(posedge aclk)
begin
    c1_calib_done_0 <= c1_calib_done;
    c1_calib_done_1 <= c1_calib_done_0;
    c1_rst0_0       <= c1_rst0;
    c1_rst0_1       <= c1_rst0_0;

    interconnect_aresetn_0 <= ~c1_rst0_1 && c1_calib_done_1;
    interconnect_aresetn   <= interconnect_aresetn_0 ;
end*/
always @(posedge c1_clk0)
begin
    interconnect_aresetn <= ~c1_rst0 && c1_calib_done;
end

//axi 3x1
axi_interconnect_0 mig_axi_interconnect (
    // --- 全局信号(运行在c1_clk0=DDR控制器时钟域) ---
    .INTERCONNECT_ACLK    (c1_clk0             ), // input,  Interconnect工作时钟, 来自mig_axi_32.ui_clk
    .INTERCONNECT_ARESETN (interconnect_aresetn), // input,  Interconnect复位(DDR校准完成后释放), 来自复位逻辑
    // ===================== S00: CPU经axi_slave_mux解码后的DDR访问 =====================
    .S00_AXI_ARESET_OUT_N (aresetn             ), // output, S00复位输出, 连接axi_slave_mux复位
    .S00_AXI_ACLK         (aclk                ), // input,  S00从端时钟(33MHz), 来自clk_pll_33
    // --- S00 AW通道: CPU写请求 → DDR3 ---
    .S00_AXI_AWID         (s0_awid[3:0]        ), // input,  写请求ID, 来自axi_slave_mux.s0_awid
    .S00_AXI_AWADDR       (s0_awaddr           ), // input,  写请求地址, 来自axi_slave_mux.s0_awaddr
    .S00_AXI_AWLEN        ({4'b0,s0_awlen}     ), // input,  写请求突发长度(4bit→8bit扩展), 来自axi_slave_mux.s0_awlen
    .S00_AXI_AWSIZE       (s0_awsize           ), // input,  写请求数据宽度, 来自axi_slave_mux.s0_awsize
    .S00_AXI_AWBURST      (s0_awburst          ), // input,  写请求突发类型, 来自axi_slave_mux.s0_awburst
    .S00_AXI_AWLOCK       (s0_awlock[0:0]      ), // input,  写请求锁类型(2bit→1bit截取), 来自axi_slave_mux.s0_awlock
    .S00_AXI_AWCACHE      (s0_awcache          ), // input,  写请求Cache属性, 来自axi_slave_mux.s0_awcache
    .S00_AXI_AWPROT       (s0_awprot           ), // input,  写请求保护类型, 来自axi_slave_mux.s0_awprot
    .S00_AXI_AWQOS        (4'b0                ), // input,  写请求QoS, 固定0
    .S00_AXI_AWVALID      (s0_awvalid          ), // input,  写请求有效, 来自axi_slave_mux.s0_awvalid
    .S00_AXI_AWREADY      (s0_awready          ), // output, 写请求就绪, 连接axi_slave_mux.s0_awready
    // --- S00 W通道: CPU写数据 → DDR3 ---
    .S00_AXI_WDATA        (s0_wdata            ), // input,  写数据, 来自axi_slave_mux.s0_wdata
    .S00_AXI_WSTRB        (s0_wstrb            ), // input,  写字节使能, 来自axi_slave_mux.s0_wstrb
    .S00_AXI_WLAST        (s0_wlast            ), // input,  写数据最后拍, 来自axi_slave_mux.s0_wlast
    .S00_AXI_WVALID       (s0_wvalid           ), // input,  写数据有效, 来自axi_slave_mux.s0_wvalid
    .S00_AXI_WREADY       (s0_wready           ), // output, 写数据就绪, 连接axi_slave_mux.s0_wready
    // --- S00 B通道: 写响应 ← DDR3 ---
    .S00_AXI_BID          (s0_bid[3:0]         ), // output, 写响应ID, 连接axi_slave_mux.s0_bid
    .S00_AXI_BRESP        (s0_bresp            ), // output, 写响应状态, 连接axi_slave_mux.s0_bresp
    .S00_AXI_BVALID       (s0_bvalid           ), // output, 写响应有效, 连接axi_slave_mux.s0_bvalid
    .S00_AXI_BREADY       (s0_bready           ), // input,  写响应就绪, 来自axi_slave_mux.s0_bready
    // --- S00 AR通道: CPU读请求 → DDR3 ---
    .S00_AXI_ARID         (s0_arid[3:0]        ), // input,  读请求ID, 来自axi_slave_mux.s0_arid
    .S00_AXI_ARADDR       (s0_araddr           ), // input,  读请求地址, 来自axi_slave_mux.s0_araddr
    .S00_AXI_ARLEN        ({4'b0,s0_arlen}     ), // input,  读请求突发长度(4bit→8bit扩展), 来自axi_slave_mux.s0_arlen
    .S00_AXI_ARSIZE       (s0_arsize           ), // input,  读请求数据宽度, 来自axi_slave_mux.s0_arsize
    .S00_AXI_ARBURST      (s0_arburst          ), // input,  读请求突发类型, 来自axi_slave_mux.s0_arburst
    .S00_AXI_ARLOCK       (s0_arlock[0:0]      ), // input,  读请求锁类型(2bit→1bit截取), 来自axi_slave_mux.s0_arlock
    .S00_AXI_ARCACHE      (s0_arcache          ), // input,  读请求Cache属性, 来自axi_slave_mux.s0_arcache
    .S00_AXI_ARPROT       (s0_arprot           ), // input,  读请求保护类型, 来自axi_slave_mux.s0_arprot
    .S00_AXI_ARQOS        (4'b0                ), // input,  读请求QoS, 固定0
    .S00_AXI_ARVALID      (s0_arvalid          ), // input,  读请求有效, 来自axi_slave_mux.s0_arvalid
    .S00_AXI_ARREADY      (s0_arready          ), // output, 读请求就绪, 连接axi_slave_mux.s0_arready
    // --- S00 R通道: 读响应 ← DDR3 ---
    .S00_AXI_RID          (s0_rid[3:0]         ), // output, 读响应ID, 连接axi_slave_mux.s0_rid
    .S00_AXI_RDATA        (s0_rdata            ), // output, 读响应数据(DDR3返回内容), 连接axi_slave_mux.s0_rdata
    .S00_AXI_RRESP        (s0_rresp            ), // output, 读响应状态, 连接axi_slave_mux.s0_rresp
    .S00_AXI_RLAST        (s0_rlast            ), // output, 读响应最后拍, 连接axi_slave_mux.s0_rlast
    .S00_AXI_RVALID       (s0_rvalid           ), // output, 读响应有效, 连接axi_slave_mux.s0_rvalid
    .S00_AXI_RREADY       (s0_rready           ), // input,  读响应就绪, 来自axi_slave_mux.s0_rready
    // ===================== S01: MAC DMA访问DDR3 =====================
    .S01_AXI_ARESET_OUT_N (                    ), // output, S01复位输出, 悬空未接
    .S01_AXI_ACLK         (aclk                ), // input,  S01从端时钟(33MHz), 来自clk_pll_33
    // --- S01 AW通道: MAC DMA写请求(RX帧→DDR3) ---
    .S01_AXI_AWID         (mac_m_awid[3:0]     ), // input,  写请求ID, 来自ethernet_top.mawid_o
    .S01_AXI_AWADDR       (mac_m_awaddr        ), // input,  写请求地址(RX缓冲区), 来自ethernet_top.mawaddr_o
    .S01_AXI_AWLEN        ({4'b0,mac_m_awlen}  ), // input,  写请求突发长度(4bit→8bit), 来自ethernet_top.mawlen_o
    .S01_AXI_AWSIZE       (mac_m_awsize        ), // input,  写请求数据宽度, 来自ethernet_top.mawsize_o
    .S01_AXI_AWBURST      (mac_m_awburst       ), // input,  写请求突发类型, 来自ethernet_top.mawburst_o
    .S01_AXI_AWLOCK       (mac_m_awlock[0:0]   ), // input,  写请求锁类型, 来自ethernet_top.mawlock_o
    .S01_AXI_AWCACHE      (mac_m_awcache       ), // input,  写请求Cache属性, 来自ethernet_top.mawcache_o
    .S01_AXI_AWPROT       (mac_m_awprot        ), // input,  写请求保护类型, 来自ethernet_top.mawprot_o
    .S01_AXI_AWQOS        (4'b0                ), // input,  写请求QoS, 固定0
    .S01_AXI_AWVALID      (mac_m_awvalid       ), // input,  写请求有效, 来自ethernet_top.mawvalid_o
    .S01_AXI_AWREADY      (mac_m_awready       ), // output, 写请求就绪, 连接ethernet_top.mawready_i
    // --- S01 W通道: MAC DMA写数据(RX帧→DDR3) ---
    .S01_AXI_WDATA        (mac_m_wdata         ), // input,  写数据(RX帧内容), 来自ethernet_top.mwdata_o
    .S01_AXI_WSTRB        (mac_m_wstrb         ), // input,  写字节使能, 来自ethernet_top.mwstrb_o
    .S01_AXI_WLAST        (mac_m_wlast         ), // input,  写数据最后拍, 来自ethernet_top.mwlast_o
    .S01_AXI_WVALID       (mac_m_wvalid        ), // input,  写数据有效, 来自ethernet_top.mwvalid_o
    .S01_AXI_WREADY       (mac_m_wready        ), // output, 写数据就绪, 连接ethernet_top.mwready_i
    // --- S01 B通道: MAC DMA写响应 ← DDR3 ---
    .S01_AXI_BID          (mac_m_bid[3:0]      ), // output, 写响应ID, 连接ethernet_top.mbid_i
    .S01_AXI_BRESP        (mac_m_bresp         ), // output, 写响应状态, 连接ethernet_top.mbresp_i
    .S01_AXI_BVALID       (mac_m_bvalid        ), // output, 写响应有效, 连接ethernet_top.mbvalid_i
    .S01_AXI_BREADY       (mac_m_bready        ), // input,  写响应就绪, 来自ethernet_top.mbready_o
    // --- S01 AR通道: MAC DMA读请求(TX帧←DDR3) ---
    .S01_AXI_ARID         (mac_m_arid[3:0]     ), // input,  读请求ID, 来自ethernet_top.marid_o
    .S01_AXI_ARADDR       (mac_m_araddr        ), // input,  读请求地址(TX缓冲区), 来自ethernet_top.maraddr_o
    .S01_AXI_ARLEN        ({4'b0,mac_m_arlen}  ), // input,  读请求突发长度(4bit→8bit), 来自ethernet_top.marlen_o
    .S01_AXI_ARSIZE       (mac_m_arsize        ), // input,  读请求数据宽度, 来自ethernet_top.marsize_o
    .S01_AXI_ARBURST      (mac_m_arburst       ), // input,  读请求突发类型, 来自ethernet_top.marburst_o
    .S01_AXI_ARLOCK       (mac_m_arlock[0:0]   ), // input,  读请求锁类型, 来自ethernet_top.marlock_o
    .S01_AXI_ARCACHE      (mac_m_arcache       ), // input,  读请求Cache属性, 来自ethernet_top.marcache_o
    .S01_AXI_ARPROT       (mac_m_arprot        ), // input,  读请求保护类型, 来自ethernet_top.marprot_o
    .S01_AXI_ARQOS        (4'b0                ), // input,  读请求QoS, 固定0
    .S01_AXI_ARVALID      (mac_m_arvalid       ), // input,  读请求有效, 来自ethernet_top.marvalid_o
    .S01_AXI_ARREADY      (mac_m_arready       ), // output, 读请求就绪, 连接ethernet_top.marready_i
    // --- S01 R通道: MAC DMA读响应 ← DDR3 ---
    .S01_AXI_RID          (mac_m_rid[3:0]      ), // output, 读响应ID, 连接ethernet_top.mrid_i
    .S01_AXI_RDATA        (mac_m_rdata         ), // output, 读响应数据(TX帧内容), 连接ethernet_top.mrdata_i
    .S01_AXI_RRESP        (mac_m_rresp         ), // output, 读响应状态, 连接ethernet_top.mrresp_i
    .S01_AXI_RLAST        (mac_m_rlast         ), // output, 读响应最后拍, 连接ethernet_top.mrlast_i
    .S01_AXI_RVALID       (mac_m_rvalid        ), // output, 读响应有效, 连接ethernet_top.mrvalid_i
    .S01_AXI_RREADY       (mac_m_rready        ), // input,  读响应就绪, 来自ethernet_top.mrready_o
    // ===================== S02: DMA控制器访问DDR3 =====================
    .S02_AXI_ARESET_OUT_N (                    ), // output, S02复位输出, 悬空未接
    .S02_AXI_ACLK         (aclk                ), // input,  S02从端时钟(33MHz), 来自clk_pll_33
    // --- S02 AW通道: DMA写请求 → DDR3 ---
    .S02_AXI_AWID         (dma0_awid           ), // input,  写请求ID, 来自dma_master.awid
    .S02_AXI_AWADDR       (dma0_awaddr         ), // input,  写请求地址, 来自dma_master.awaddr
    .S02_AXI_AWLEN        ({4'd0,dma0_awlen}   ), // input,  写请求突发长度(4bit→8bit), 来自dma_master.awlen
    .S02_AXI_AWSIZE       (dma0_awsize         ), // input,  写请求数据宽度, 来自dma_master.awsize
    .S02_AXI_AWBURST      (dma0_awburst        ), // input,  写请求突发类型, 来自dma_master.awburst
    .S02_AXI_AWLOCK       (dma0_awlock[0:0]    ), // input,  写请求锁类型, 来自dma_master.awlock
    .S02_AXI_AWCACHE      (dma0_awcache        ), // input,  写请求Cache属性, 来自dma_master.awcache
    .S02_AXI_AWPROT       (dma0_awprot         ), // input,  写请求保护类型, 来自dma_master.awprot
    .S02_AXI_AWQOS        (4'b0                ), // input,  写请求QoS, 固定0
    .S02_AXI_AWVALID      (dma0_awvalid        ), // input,  写请求有效, 来自dma_master.awvalid
    .S02_AXI_AWREADY      (dma0_awready        ), // output, 写请求就绪, 连接dma_master.awready
    // --- S02 W通道: DMA写数据 → DDR3 ---
    .S02_AXI_WDATA        (dma0_wdata          ), // input,  写数据(64bit宽,外设→DDR3), 来自dma_master.wdata
    .S02_AXI_WSTRB        (dma0_wstrb          ), // input,  写字节使能, 来自dma_master.wstrb
    .S02_AXI_WLAST        (dma0_wlast          ), // input,  写数据最后拍, 来自dma_master.wlast
    .S02_AXI_WVALID       (dma0_wvalid         ), // input,  写数据有效, 来自dma_master.wvalid
    .S02_AXI_WREADY       (dma0_wready         ), // output, 写数据就绪, 连接dma_master.wready
    // --- S02 B通道: DMA写响应 ← DDR3 ---
    .S02_AXI_BID          (dma0_bid            ), // output, 写响应ID, 连接dma_master.bid
    .S02_AXI_BRESP        (dma0_bresp          ), // output, 写响应状态, 连接dma_master.bresp
    .S02_AXI_BVALID       (dma0_bvalid         ), // output, 写响应有效, 连接dma_master.bvalid
    .S02_AXI_BREADY       (dma0_bready         ), // input,  写响应就绪, 来自dma_master.bready
    // --- S02 AR通道: DMA读请求 → DDR3 ---
    .S02_AXI_ARID         (s02_slave_arid      ), // input,  读请求ID, 来自S02仲裁输出
    .S02_AXI_ARADDR       (s02_slave_araddr    ), // input,  读请求地址, 来自S02仲裁输出
    .S02_AXI_ARLEN        (s02_slave_arlen     ), // input,  读请求突发长度, 来自S02仲裁输出
    .S02_AXI_ARSIZE       (s02_slave_arsize    ), // input,  读请求数据宽度, 来自S02仲裁输出
    .S02_AXI_ARBURST      (s02_slave_arburst   ), // input,  读请求突发类型, 来自S02仲裁输出
    .S02_AXI_ARLOCK       (s02_slave_arlock    ), // input,  读请求锁类型, 来自S02仲裁输出
    .S02_AXI_ARCACHE      (s02_slave_arcache   ), // input,  读请求Cache属性, 来自S02仲裁输出
    .S02_AXI_ARPROT       (s02_slave_arprot    ), // input,  读请求保护类型, 来自S02仲裁输出
    .S02_AXI_ARQOS        (4'b0                ), // input,  读请求QoS, 固定0
    .S02_AXI_ARVALID      (s02_slave_arvalid   ), // input,  读请求有效, 来自S02仲裁输出
    .S02_AXI_ARREADY      (s02_slave_arready   ), // output, 读请求就绪, 来自S02仲裁输出
    // --- S02 R通道: DMA读响应 ← DDR3 ---
    .S02_AXI_RID          (s02_slave_rid       ), // output, 读响应ID, 连接S02仲裁输出
    .S02_AXI_RDATA        (s02_slave_rdata     ), // output, 读响应数据(64bit), 连接S02仲裁输出
    .S02_AXI_RRESP        (s02_slave_rresp     ), // output, 读响应状态, 连接S02仲裁输出
    .S02_AXI_RLAST        (s02_slave_rlast     ), // output, 读响应最后拍, 连接S02仲裁输出
    .S02_AXI_RVALID       (s02_slave_rvalid    ), // output, 读响应有效, 连接S02仲裁输出
    .S02_AXI_RREADY       (s02_slave_rready    ), // input,  读响应就绪, 连接S02仲裁输出
    // ===================== M00: 合并输出 → DDR3控制器 =====================
    .M00_AXI_ARESET_OUT_N (ddr_aresetn         ), // output, M00复位输出, 连接mig_axi_32.aresetn
    .M00_AXI_ACLK         (c1_clk0             ), // input,  M00主端时钟, 来自mig_axi_32.ui_clk
    // --- M00 AW通道: 合并写请求 → mig_axi_32 ---
    .M00_AXI_AWID         (mig_awid            ), // output, 写请求ID(8bit), 连接mig_axi_32.s_axi_awid
    .M00_AXI_AWADDR       (mig_awaddr          ), // output, 写请求地址, 连接mig_axi_32.s_axi_awaddr
    .M00_AXI_AWLEN        ({mig_awlen}         ), // output, 写请求突发长度(8bit), 连接mig_axi_32.s_axi_awlen
    .M00_AXI_AWSIZE       (mig_awsize          ), // output, 写请求数据宽度, 连接mig_axi_32.s_axi_awsize
    .M00_AXI_AWBURST      (mig_awburst         ), // output, 写请求突发类型, 连接mig_axi_32.s_axi_awburst
    .M00_AXI_AWLOCK       (mig_awlock[0:0]     ), // output, 写请求锁类型, 连接mig_axi_32.s_axi_awlock
    .M00_AXI_AWCACHE      (mig_awcache         ), // output, 写请求Cache属性, 连接mig_axi_32.s_axi_awcache
    .M00_AXI_AWPROT       (mig_awprot          ), // output, 写请求保护类型, 连接mig_axi_32.s_axi_awprot
    .M00_AXI_AWQOS        (                    ), // output, 写请求QoS, 悬空未接
    .M00_AXI_AWVALID      (mig_awvalid         ), // output, 写请求有效, 连接mig_axi_32.s_axi_awvalid
    .M00_AXI_AWREADY      (mig_awready         ), // input,  写请求就绪, 来自mig_axi_32.s_axi_awready
    // --- M00 W通道: 合并写数据 → mig_axi_32 ---
    .M00_AXI_WDATA        (mig_wdata           ), // output, 写数据, 连接mig_axi_32.s_axi_wdata
    .M00_AXI_WSTRB        (mig_wstrb           ), // output, 写字节使能, 连接mig_axi_32.s_axi_wstrb
    .M00_AXI_WLAST        (mig_wlast           ), // output, 写数据最后拍, 连接mig_axi_32.s_axi_wlast
    .M00_AXI_WVALID       (mig_wvalid          ), // output, 写数据有效, 连接mig_axi_32.s_axi_wvalid
    .M00_AXI_WREADY       (mig_wready          ), // input,  写数据就绪, 来自mig_axi_32.s_axi_wready
    // --- M00 B通道: 合并写响应 ← mig_axi_32 ---
    .M00_AXI_BID          (mig_bid             ), // input,  写响应ID(8bit), 来自mig_axi_32.s_axi_bid
    .M00_AXI_BRESP        (mig_bresp           ), // input,  写响应状态, 来自mig_axi_32.s_axi_bresp
    .M00_AXI_BVALID       (mig_bvalid          ), // input,  写响应有效, 来自mig_axi_32.s_axi_bvalid
    .M00_AXI_BREADY       (mig_bready          ), // output, 写响应就绪, 连接mig_axi_32.s_axi_bready
    // --- M00 AR通道: 合并读请求 → mig_axi_32 ---
    .M00_AXI_ARID         (mig_arid            ), // output, 读请求ID(8bit), 连接mig_axi_32.s_axi_arid
    .M00_AXI_ARADDR       (mig_araddr          ), // output, 读请求地址, 连接mig_axi_32.s_axi_araddr
    .M00_AXI_ARLEN        ({mig_arlen}         ), // output, 读请求突发长度(8bit), 连接mig_axi_32.s_axi_arlen
    .M00_AXI_ARSIZE       (mig_arsize          ), // output, 读请汽数据宽度, 连接mig_axi_32.s_axi_arsize
    .M00_AXI_ARBURST      (mig_arburst         ), // output, 读请求突发类型, 连接mig_axi_32.s_axi_arburst
    .M00_AXI_ARLOCK       (mig_arlock[0:0]     ), // output, 读请求锁类型, 连接mig_axi_32.s_axi_arlock
    .M00_AXI_ARCACHE      (mig_arcache         ), // output, 读请求Cache属性, 连接mig_axi_32.s_axi_arcache
    .M00_AXI_ARPROT       (mig_arprot          ), // output, 读请求保护类型, 连接mig_axi_32.s_axi_arprot
    .M00_AXI_ARQOS        (                    ), // output, 读请求QoS, 悬空未接
    .M00_AXI_ARVALID      (mig_arvalid         ), // output, 读请求有效, 连接mig_axi_32.s_axi_arvalid
    .M00_AXI_ARREADY      (mig_arready         ), // input,  读请求就绪, 来自mig_axi_32.s_axi_arready
    // --- M00 R通道: 合并读响应 ← mig_axi_32 ---
    .M00_AXI_RID          (mig_rid             ), // input,  读响应ID(8bit), 来自mig_axi_32.s_axi_rid
    .M00_AXI_RDATA        (mig_rdata           ), // input,  读响应数据, 来自mig_axi_32.s_axi_rdata
    .M00_AXI_RRESP        (mig_rresp           ), // input,  读响应状态, 来自mig_axi_32.s_axi_rresp
    .M00_AXI_RLAST        (mig_rlast           ), // input,  读响应最后拍, 来自mig_axi_32.s_axi_rlast
    .M00_AXI_RVALID       (mig_rvalid          ), // input,  读响应有效, 来自mig_axi_32.s_axi_rvalid
    .M00_AXI_RREADY       (mig_rready          )  // output, 读响应就绪, 连接mig_axi_32.s_axi_rready
);
//ddr3 controller
mig_axi_32 mig_axi (
    // ===================== DDR3物理接口 → 外部DDR3 SDRAM芯片 =====================
    .ddr3_dq             (ddr3_dq         ),  // inout,  DDR3数据总线[15:0], 连接外部引脚ddr3_dq
    .ddr3_dqs_p          (ddr3_dqs_p      ),  // inout,  DDR3数据选通正端[1:0], 连接外部引脚ddr3_dqs_p
    .ddr3_dqs_n          (ddr3_dqs_n      ),  // inout,  DDR3数据选通负端[1:0], 连接外部引脚ddr3_dqs_n
    .ddr3_addr           (ddr3_addr       ),  // output, DDR3地址线[12:0], 连接外部引脚ddr3_addr
    .ddr3_ba             (ddr3_ba         ),  // output, DDR3Bank地址[2:0], 连接外部引脚ddr3_ba
    .ddr3_ras_n          (ddr3_ras_n      ),  // output, DDR3行地址选通(低有效), 连接外部引脚ddr3_ras_n
    .ddr3_cas_n          (ddr3_cas_n      ),  // output, DDR3列地址选通(低有效), 连接外部引脚ddr3_cas_n
    .ddr3_we_n           (ddr3_we_n       ),  // output, DDR3写使能(低有效), 连接外部引脚ddr3_we_n
    .ddr3_reset_n        (ddr3_reset_n    ),  // output, DDR3复位(低有效), 连接外部引脚ddr3_reset_n
    .ddr3_ck_p           (ddr3_ck_p       ),  // output, DDR3差分时钟正端, 连接外部引脚ddr3_ck_p
    .ddr3_ck_n           (ddr3_ck_n       ),  // output, DDR3差分时钟负端, 连接外部引脚ddr3_ck_n
    .ddr3_cke            (ddr3_cke        ),  // output, DDR3时钟使能, 连接外部引脚ddr3_cke
    .ddr3_dm             (ddr3_dm         ),  // output, DDR3数据掩码[1:0], 连接外部引脚ddr3_dm
    .ddr3_odt            (ddr3_odt        ),  // output, DDR3片上终端电阻, 连接外部引脚ddr3_odt

    // ===================== 控制器时钟与状态 =====================
    .ui_clk              (c1_clk0         ),  // output, 控制器输出用户时钟, 连接axi_interconnect_0/复位逻辑
    .ui_clk_sync_rst     (c1_rst0         ),  // output, 与ui_clk同步的复位(高有效), 连接复位逻辑
    .sys_clk_i           (c1_sys_clk_i    ),  // input,  系统时钟输入(100MHz), 来自外部引脚clk
    .sys_rst             (c1_sys_rst_i    ),  // input,  系统复位输入(高有效), 来自外部引脚resetn取反
    .init_calib_complete (c1_calib_done   ),  // output, DDR3校准完成标志, 连接复位逻辑(interconnect_aresetn依赖此信号)
    .clk_ref_i           (c1_clk_ref_i    ),  // input,  参考时钟输入(200MHz), 来自clk_wiz_0
    .mmcm_locked         (                ),  // output, MMCM锁定状态, 悬空未接

    // ===================== 应用级控制(未使用) =====================
    .app_sr_active       (                ),  // output, 自刷新状态指示, 悬空未接
    .app_ref_ack         (                ),  // output, 刷新请求确认, 悬空未接
    .app_zq_ack          (                ),  // output, ZQ校准确认, 悬空未接
    .app_sr_req          (1'b0            ),  // input,  自刷新请求, 固定0(不使用)
    .app_ref_req         (1'b0            ),  // input,  刷新请求, 固定0(不使用)
    .app_zq_req          (1'b0            ),  // input,  ZQ校准请求, 固定0(不使用)

    // ===================== AXI从端 ← axi_interconnect_0.M00 =====================
    .aresetn             (ddr_aresetn     ),  // input,  AXI复位(低有效), 来自axi_interconnect_0.M00_AXI_ARESET_OUT_N
    // --- AW通道: 合并写请求 ← axi_interconnect_0 ---
    .s_axi_awid          (mig_awid        ),  // input,  写请求ID(8bit), 来自axi_interconnect_0.M00_AXI_AWID
    .s_axi_awaddr        (mig_awaddr[26:0]),  // input,  写请求地址(27bit,最大128MB), 来自axi_interconnect_0.M00_AXI_AWADDR
    .s_axi_awlen         ({mig_awlen}     ),  // input,  写请求突发长度(8bit), 来自axi_interconnect_0.M00_AXI_AWLEN
    .s_axi_awsize        (mig_awsize      ),  // input,  写请求数据宽度, 来自axi_interconnect_0.M00_AXI_AWSIZE
    .s_axi_awburst       (mig_awburst     ),  // input,  写请求突发类型, 来自axi_interconnect_0.M00_AXI_AWBURST
    .s_axi_awlock        (mig_awlock[0:0] ),  // input,  写请求锁类型, 来自axi_interconnect_0.M00_AXI_AWLOCK
    .s_axi_awcache       (mig_awcache     ),  // input,  写请求Cache属性, 来自axi_interconnect_0.M00_AXI_AWCACHE
    .s_axi_awprot        (mig_awprot      ),  // input,  写请求保护类型, 来自axi_interconnect_0.M00_AXI_AWPROT
    .s_axi_awqos         (4'b0            ),  // input,  写请求QoS, 固定0
    .s_axi_awvalid       (mig_awvalid     ),  // input,  写请求有效, 来自axi_interconnect_0.M00_AXI_AWVALID
    .s_axi_awready       (mig_awready     ),  // output, 写请求就绪, 连接axi_interconnect_0.M00_AXI_AWREADY
    // --- W通道: 合并写数据 ← axi_interconnect_0 ---
    .s_axi_wdata         (mig_wdata       ),  // input,  写数据, 来自axi_interconnect_0.M00_AXI_WDATA
    .s_axi_wstrb         (mig_wstrb       ),  // input,  写字节使能, 来自axi_interconnect_0.M00_AXI_WSTRB
    .s_axi_wlast         (mig_wlast       ),  // input,  写数据最后拍, 来自axi_interconnect_0.M00_AXI_WLAST
    .s_axi_wvalid        (mig_wvalid      ),  // input,  写数据有效, 来自axi_interconnect_0.M00_AXI_WVALID
    .s_axi_wready        (mig_wready      ),  // output, 写数据就绪, 连接axi_interconnect_0.M00_AXI_WREADY
    // --- B通道: 写响应 → axi_interconnect_0 ---
    .s_axi_bid           (mig_bid         ),  // output, 写响应ID(8bit), 连接axi_interconnect_0.M00_AXI_BID
    .s_axi_bresp         (mig_bresp       ),  // output, 写响应状态, 连接axi_interconnect_0.M00_AXI_BRESP
    .s_axi_bvalid        (mig_bvalid      ),  // output, 写响应有效, 连接axi_interconnect_0.M00_AXI_BVALID
    .s_axi_bready        (mig_bready      ),  // input,  写响应就绪, 来自axi_interconnect_0.M00_AXI_BREADY
    // --- AR通道: 合并读请求 ← axi_interconnect_0 ---
    .s_axi_arid          (mig_arid        ),  // input,  读请求ID(8bit), 来自axi_interconnect_0.M00_AXI_ARID
    .s_axi_araddr        (mig_araddr[26:0]),  // input,  读请求地址(27bit,最大128MB), 来自axi_interconnect_0.M00_AXI_ARADDR
    .s_axi_arlen         ({mig_arlen}     ),  // input,  读请求突发长度(8bit), 来自axi_interconnect_0.M00_AXI_ARLEN
    .s_axi_arsize        (mig_arsize      ),  // input,  读请求数据宽度, 来自axi_interconnect_0.M00_AXI_ARSIZE
    .s_axi_arburst       (mig_arburst     ),  // input,  读请求突发类型, 来自axi_interconnect_0.M00_AXI_ARBURST
    .s_axi_arlock        (mig_arlock[0:0] ),  // input,  读请求锁类型, 来自axi_interconnect_0.M00_AXI_ARLOCK
    .s_axi_arcache       (mig_arcache     ),  // input,  读请求Cache属性, 来自axi_interconnect_0.M00_AXI_ARCACHE
    .s_axi_arprot        (mig_arprot      ),  // input,  读请求保护类型, 来自axi_interconnect_0.M00_AXI_ARPROT
    .s_axi_arqos         (4'b0            ),  // input,  读请求QoS, 固定0
    .s_axi_arvalid       (mig_arvalid     ),  // input,  读请求有效, 来自axi_interconnect_0.M00_AXI_ARVALID
    .s_axi_arready       (mig_arready     ),  // output, 读请求就绪, 连接axi_interconnect_0.M00_AXI_ARREADY
    // --- R通道: 读响应 → axi_interconnect_0 ---
    .s_axi_rid           (mig_rid         ),  // output, 读响应ID(8bit), 连接axi_interconnect_0.M00_AXI_RID
    .s_axi_rdata         (mig_rdata       ),  // output, 读响应数据(DDR3返回内容), 连接axi_interconnect_0.M00_AXI_RDATA
    .s_axi_rresp         (mig_rresp       ),  // output, 读响应状态, 连接axi_interconnect_0.M00_AXI_RRESP
    .s_axi_rlast         (mig_rlast       ),  // output, 读响应最后拍, 连接axi_interconnect_0.M00_AXI_RLAST
    .s_axi_rvalid        (mig_rvalid      ),  // output, 读响应有效, 连接axi_interconnect_0.M00_AXI_RVALID
    .s_axi_rready        (mig_rready      )   // input,  读响应就绪, 来自axi_interconnect_0.M00_AXI_RREADY
);

//DMA
dma_master DMA_MASTER0
(
    // --- 全局信号 ---
.clk                (aclk                   ), // input,  工作时钟(33MHz), 来自clk_pll_33
.rst_n		        (aresetn                ), // input,  复位(低有效), 来自外部引脚resetn
    // --- AXI主端AW通道: DMA写请求 → DDR3(经axi_interconnect_0.S02) ---
.awid               (dma0_awid              ), // output, 写请求ID, 连接axi_interconnect_0.S02_AXI_AWID
.awaddr             (dma0_awaddr            ), // output, 写请求地址(DDR3目标地址), 连接axi_interconnect_0.S02_AXI_AWADDR
.awlen              (dma0_awlen             ), // output, 写请求突发长度, 连接axi_interconnect_0.S02_AXI_AWLEN
.awsize             (dma0_awsize            ), // output, 写请求数据宽度, 连接axi_interconnect_0.S02_AXI_AWSIZE
.awburst            (dma0_awburst           ), // output, 写请求突发类型, 连接axi_interconnect_0.S02_AXI_AWBURST
.awlock             (dma0_awlock            ), // output, 写请求锁类型, 连接axi_interconnect_0.S02_AXI_AWLOCK
.awcache            (dma0_awcache           ), // output, 写请求Cache属性, 连接axi_interconnect_0.S02_AXI_AWCACHE
.awprot             (dma0_awprot            ), // output, 写请求保护类型, 连接axi_interconnect_0.S02_AXI_AWPROT
.awvalid            (dma0_awvalid           ), // output, 写请求有效, 连接axi_interconnect_0.S02_AXI_AWVALID
.awready            (dma0_awready           ), // input,  写请求就绪, 来自axi_interconnect_0.S02_AXI_AWREADY
    // --- AXI主端W通道: DMA写数据 → DDR3 ---
.wid                (dma0_wid               ), // output, 写数据ID, 连接axi_interconnect_0.S02_AXI_WID
.wdata              (dma0_wdata             ), // output, 写数据(64bit宽), 连接axi_interconnect_0.S02_AXI_WDATA
.wstrb              (dma0_wstrb             ), // output, 写字节使能(8bit), 连接axi_interconnect_0.S02_AXI_WSTRB
.wlast              (dma0_wlast             ), // output, 写数据最后拍, 连接axi_interconnect_0.S02_AXI_WLAST
.wvalid             (dma0_wvalid            ), // output, 写数据有效, 连接axi_interconnect_0.S02_AXI_WVALID
.wready             (dma0_wready            ), // input,  写数据就绪, 来自axi_interconnect_0.S02_AXI_WREADY
    // --- AXI主端B通道: DMA写响应 ← DDR3 ---
.bid                (dma0_bid               ), // input,  写响应ID, 来自axi_interconnect_0.S02_AXI_BID
.bresp              (dma0_bresp             ), // input,  写响应状态, 来自axi_interconnect_0.S02_AXI_BRESP
.bvalid             (dma0_bvalid            ), // input,  写响应有效, 来自axi_interconnect_0.S02_AXI_BVALID
.bready             (dma0_bready            ), // output, 写响应就绪, 连接axi_interconnect_0.S02_AXI_BREADY
    // --- AXI主端AR通道: DMA读请求 → DDR3(经axi_interconnect_0.S02) ---
.arid               (dma0_arid              ), // output, 读请求ID, 连接axi_interconnect_0.S02_AXI_ARID
.araddr             (dma0_araddr            ), // output, 读请求地址(DDR3源地址), 连接axi_interconnect_0.S02_AXI_ARADDR
.arlen              (dma0_arlen             ), // output, 读请求突发长度, 连接axi_interconnect_0.S02_AXI_ARLEN
.arsize             (dma0_arsize            ), // output, 读请求数据宽度, 连接axi_interconnect_0.S02_AXI_ARSIZE
.arburst            (dma0_arburst           ), // output, 读请求突发类型, 连接axi_interconnect_0.S02_AXI_ARBURST
.arlock             (dma0_arlock            ), // output, 读请求锁类型, 连接axi_interconnect_0.S02_AXI_ARLOCK
.arcache            (dma0_arcache           ), // output, 读请求Cache属性, 连接axi_interconnect_0.S02_AXI_ARCACHE
.arprot             (dma0_arprot            ), // output, 读请求保护类型, 连接axi_interconnect_0.S02_AXI_ARPROT
.arvalid            (dma0_arvalid           ), // output, 读请求有效, 连接axi_interconnect_0.S02_AXI_ARVALID
.arready            (dma0_arready           ), // input,  读请求就绪, 来自axi_interconnect_0.S02_AXI_ARREADY
    // --- AXI主端R通道: DMA读响应 ← DDR3 ---
.rid                (dma0_rid               ), // input,  读响应ID, 来自axi_interconnect_0.S02_AXI_RID
.rdata              (dma0_rdata             ), // input,  读响应数据(64bit宽,DDR3→外设), 来自axi_interconnect_0.S02_AXI_RDATA
.rresp              (dma0_rresp             ), // input,  读响应状态, 来自axi_interconnect_0.S02_AXI_RRESP
.rlast              (dma0_rlast             ), // input,  读响应最后拍, 来自axi_interconnect_0.S02_AXI_RLAST
.rvalid             (dma0_rvalid            ), // input,  读响应有效, 来自axi_interconnect_0.S02_AXI_RVALID
.rready             (dma0_rready            ), // output, 读响应就绪, 连接axi_interconnect_0.S02_AXI_RREADY

    // --- DMA中断与握手 ---
.dma_int            (dma_int                ), // output, DMA中断输出, 连接中断汇聚int_out[5]
.dma_req_in         (dma_req                ), // input,  DMA总线请求, 来自axi2apb_misc.dma_req_o
.dma_ack_out        (dma_ack                ), // output, DMA总线应答, 连接axi2apb_misc.dma_ack_i

    // --- APB从端接口: DMA通过APB读写慢速外设(UART/NAND) ---
.dma_gnt            (dma0_gnt               ), // input,  APB总线授权(DMA获得APB控制权), 来自axi2apb_misc.dma_grant
.apb_rw             (apb_rw_dma0            ), // output, APB读写方向(0=读,1=写), 连接axi2apb_misc.apb_rw_dma
.apb_psel           (apb_psel_dma0          ), // output, APB外设选择, 连接axi2apb_misc.apb_psel_dma
.apb_valid_req      (apb_start_dma0	        ), // output, APB有效请求, 连接axi2apb_misc.apb_valid_dma
.apb_penable        (apb_penable_dma0       ), // output, APB使能(传输第二拍), 连接axi2apb_misc.apb_enab_dma
.apb_addr           (apb_addr_dma0          ), // output, APB地址, 连接axi2apb_misc.apb_addr_dma
.apb_wdata          (apb_wdata_dma0         ), // output, APB写数据(DDR3→外设方向), 连接axi2apb_misc.apb_wdata_dma
.apb_rdata          (apb_rdata_dma0         ), // input,  APB读数据(外设→DDR3方向), 来自axi2apb_misc.apb_rdata_dma

    // --- DMA订单交互 ← CONFREG ---
.order_addr_in      (order_addr_in          ), // input,  DMA订单寄存器(bit2=读请求,bit3=写完成,bit4=启动,bit[1:0]=设备号), 来自CONFREG.order_addr_reg
.write_dma_end      (write_dma_end          ), // output, DMA写完成标志, 连接CONFREG.write_dma_end(清除bit[2])
.finish_read_order  (finish_read_order      )  // output, DMA读订单完成标志, 连接CONFREG.finish_read_order(清除bit[3])
);

//AXI2APB
axi2apb_misc APB_DEV
(
    // --- 全局信号 ---
.clk                (aclk               ), // input,  工作时钟(33MHz), 来自clk_pll_33
.rst_n              (aresetn            ), // input,  复位(低有效), 来自外部引脚resetn

    // --- AXI从端AW通道: CPU写请求 ← axi_slave_mux.S2 ---
.axi_s_awid         (apb_s_awid         ), // input,  写请求ID, 来自axi_slave_mux.s2_awid
.axi_s_awaddr       (apb_s_awaddr       ), // input,  写请求地址(UART/NAND寄存器地址), 来自axi_slave_mux.s2_awaddr
.axi_s_awlen        (apb_s_awlen        ), // input,  写请求突发长度, 来自axi_slave_mux.s2_awlen
.axi_s_awsize       (apb_s_awsize       ), // input,  写请求数据宽度, 来自axi_slave_mux.s2_awsize
.axi_s_awburst      (apb_s_awburst      ), // input,  写请求突发类型, 来自axi_slave_mux.s2_awburst
.axi_s_awlock       (apb_s_awlock       ), // input,  写请求锁类型, 来自axi_slave_mux.s2_awlock
.axi_s_awcache      (apb_s_awcache      ), // input,  写请求Cache属性, 来自axi_slave_mux.s2_awcache
.axi_s_awprot       (apb_s_awprot       ), // input,  写请求保护类型, 来自axi_slave_mux.s2_awprot
.axi_s_awvalid      (apb_s_awvalid      ), // input,  写请求有效, 来自axi_slave_mux.s2_awvalid
.axi_s_awready      (apb_s_awready      ), // output, 写请求就绪, 连接axi_slave_mux.s2_awready
    // --- AXI从端W通道: CPU写数据 ← axi_slave_mux.S2 ---
.axi_s_wid          (apb_s_wid          ), // input,  写数据ID, 来自axi_slave_mux.s2_wid
.axi_s_wdata        (apb_s_wdata        ), // input,  写数据(UART/NAND寄存器配置值), 来自axi_slave_mux.s2_wdata
.axi_s_wstrb        (apb_s_wstrb        ), // input,  写字节使能, 来自axi_slave_mux.s2_wstrb
.axi_s_wlast        (apb_s_wlast        ), // input,  写数据最后拍, 来自axi_slave_mux.s2_wlast
.axi_s_wvalid       (apb_s_wvalid       ), // input,  写数据有效, 来自axi_slave_mux.s2_wvalid
.axi_s_wready       (apb_s_wready       ), // output, 写数据就绪, 连接axi_slave_mux.s2_wready
    // --- AXI从端B通道: 写响应 → axi_slave_mux.S2 ---
.axi_s_bid          (apb_s_bid          ), // output, 写响应ID, 连接axi_slave_mux.s2_bid
.axi_s_bresp        (apb_s_bresp        ), // output, 写响应状态, 连接axi_slave_mux.s2_bresp
.axi_s_bvalid       (apb_s_bvalid       ), // output, 写响应有效, 连接axi_slave_mux.s2_bvalid
.axi_s_bready       (apb_s_bready       ), // input,  写响应就绪, 来自axi_slave_mux.s2_bready
    // --- AXI从端AR通道: CPU读请求 ← axi_slave_mux.S2 ---
.axi_s_arid         (apb_s_arid         ), // input,  读请求ID, 来自axi_slave_mux.s2_arid
.axi_s_araddr       (apb_s_araddr       ), // input,  读请求地址(UART/NAND寄存器地址), 来自axi_slave_mux.s2_araddr
.axi_s_arlen        (apb_s_arlen        ), // input,  读请求突发长度, 来自axi_slave_mux.s2_arlen
.axi_s_arsize       (apb_s_arsize       ), // input,  读请求数据宽度, 来自axi_slave_mux.s2_arsize
.axi_s_arburst      (apb_s_arburst      ), // input,  读请求突发类型, 来自axi_slave_mux.s2_arburst
.axi_s_arlock       (apb_s_arlock       ), // input,  读请求锁类型, 来自axi_slave_mux.s2_arlock
.axi_s_arcache      (apb_s_arcache      ), // input,  读请求Cache属性, 来自axi_slave_mux.s2_arcache
.axi_s_arprot       (apb_s_arprot       ), // input,  读请求保护类型, 来自axi_slave_mux.s2_arprot
.axi_s_arvalid      (apb_s_arvalid      ), // input,  读请求有效, 来自axi_slave_mux.s2_arvalid
.axi_s_arready      (apb_s_arready      ), // output, 读请求就绪, 连接axi_slave_mux.s2_arready
    // --- AXI从端R通道: 读响应 → axi_slave_mux.S2 ---
.axi_s_rid          (apb_s_rid          ), // output, 读响应ID, 连接axi_slave_mux.s2_rid
.axi_s_rdata        (apb_s_rdata        ), // output, 读响应数据(UART/NAND寄存器状态), 连接axi_slave_mux.s2_rdata
.axi_s_rresp        (apb_s_rresp        ), // output, 读响应状态, 连接axi_slave_mux.s2_rresp
.axi_s_rlast        (apb_s_rlast        ), // output, 读响应最后拍, 连接axi_slave_mux.s2_rlast
.axi_s_rvalid       (apb_s_rvalid       ), // output, 读响应有效, 连接axi_slave_mux.s2_rvalid
.axi_s_rready       (apb_s_rready       ), // input,  读响应就绪, 来自axi_slave_mux.s2_rready

    // --- APB DMA接口: 与dma_master共享APB总线 ---
.apb_rw_dma         (apb_rw_dma0        ), // input,  DMA的APB读写方向(0=读,1=写), 来自dma_master.apb_rw
.apb_psel_dma       (apb_psel_dma0      ), // input,  DMA的APB外设选择, 来自dma_master.apb_psel
.apb_enab_dma       (apb_penable_dma0   ), // input,  DMA的APB使能, 来自dma_master.apb_penable
.apb_addr_dma       (apb_addr_dma0[19:0]), // input,  DMA的APB地址(低20bit), 来自dma_master.apb_addr
.apb_valid_dma      (apb_start_dma0     ), // input,  DMA的APB有效请求, 来自dma_master.apb_valid_req
.apb_wdata_dma      (apb_wdata_dma0     ), // input,  DMA的APB写数据, 来自dma_master.apb_wdata
.apb_rdata_dma      (apb_rdata_dma0     ), // output, DMA的APB读数据, 连接dma_master.apb_rdata
.apb_ready_dma      (                   ), // output, DMA的APB就绪, 悬空未接
.dma_grant          (dma0_gnt           ), // output, APB总线授权(DMA获得控制权), 连接dma_master.dma_gnt

    // --- APB总线仲裁握手 ---
.dma_req_o          (dma_req            ), // output, APB总线请求(DMA请求使用APB), 连接dma_master.dma_req_in
.dma_ack_i          (dma_ack            ), // input,  APB总线应答(DMA确认释放APB), 来自dma_master.dma_ack_out

    // --- UART0接口 → 外部引脚 ---
.uart0_txd_i        (uart0_txd_i      ), // input,  UART0发送数据输入(回环), 来自UART_TX引脚
.uart0_txd_o        (uart0_txd_o      ), // output, UART0发送数据输出, 连接UART_TX引脚
.uart0_txd_oe       (uart0_txd_oe     ), // output, UART0发送输出使能, 控制UART_TX方向
.uart0_rxd_i        (uart0_rxd_i      ), // input,  UART0接收数据输入, 来自UART_RX引脚
.uart0_rxd_o        (uart0_rxd_o      ), // output, UART0接收数据输出(回环), 连接UART_RX引脚
.uart0_rxd_oe       (uart0_rxd_oe     ), // output, UART0接收输出使能, 控制UART_RX方向
.uart0_rts_o        (uart0_rts_o      ), // output, UART0请求发送(Modem), 连接外部引脚UART_RTS
.uart0_dtr_o        (uart0_dtr_o      ), // output, UART0数据终端就绪(Modem), 连接外部引脚UART_DTR
.uart0_cts_i        (uart0_cts_i      ), // input,  UART0允许发送(Modem), 来自外部引脚UART_CTS
.uart0_dsr_i        (uart0_dsr_i      ), // input,  UART0数据设备就绪(Modem), 来自外部引脚UART_DSR
.uart0_dcd_i        (uart0_dcd_i      ), // input,  UART0载波检测(Modem), 来自外部引脚UART_DCD
.uart0_ri_i         (uart0_ri_i       ), // input,  UART0振铃指示(Modem), 来自外部引脚UART_RI
.uart0_int          (uart0_int        ), // output, UART0中断输出, 连接中断汇聚int_out[2]

    // --- NAND Flash接口 → 外部NAND芯片 ---
.nand_type          (2'h2             ), // input,  NAND芯片类型(2=1Gbit), 固定2
.nand_cle           (nand_cle         ), // output, NAND命令锁存使能, 连接外部引脚NAND_CLE
.nand_ale           (nand_ale         ), // output, NAND地址锁存使能, 连接外部引脚NAND_ALE
.nand_rdy           (nand_rdy         ), // input,  NAND就绪/忙碌[3:0], 来自外部引脚NAND_RDY
.nand_rd            (nand_rd          ), // output, NAND读使能, 连接外部引脚NAND_RD
.nand_ce            (nand_ce          ), // output, NAND片选[3:0](低有效), 连接外部引脚NAND_CE
.nand_wr            (nand_wr          ), // output, NAND写使能, 连接外部引脚NAND_WR
.nand_dat_i         (nand_dat_i       ), // input,  NAND数据输入(从芯片读回), 来自IOBUF.NAND_DATA
.nand_dat_o         (nand_dat_o       ), // output, NAND数据输出(向芯片写入), 连接IOBUF.NAND_DATA
.nand_dat_oe        (nand_dat_oe      ), // output, NAND数据输出使能, 控制NAND_DATA方向

    // --- NAND中断 ---
.nand_int           (nand_int         )  // output, NAND中断输出, 连接中断汇聚int_out[4]
);

//LCD
lcd_ctrl LCD_CTRL(
    // --- 全局信号 ---
.aclk           (aclk              ),       // input,  工作时钟(33MHz), 来自clk_pll_33
.aresetn        (aresetn           ),       // input,  复位(低有效), 来自外部引脚resetn
    // --- AXI从端AW通道: 写请求 ← axi_slave_mux.S5 ---
.s_awid         (lcd_s_awid        ),       // input,  写请求ID, 来自axi_slave_mux.s5_awid
.s_awaddr       (lcd_s_awaddr      ),       // input,  写请求地址, 来自axi_slave_mux.s5_awaddr
.s_awlen        (lcd_s_awlen       ),       // input,  写请求突发长度, 来自axi_slave_mux.s5_awlen
.s_awsize       (lcd_s_awsize      ),       // input,  写请求数据宽度, 来自axi_slave_mux.s5_awsize
.s_awburst      (lcd_s_awburst     ),       // input,  写请求突发类型, 来自axi_slave_mux.s5_awburst
.s_awlock       (lcd_s_awlock      ),       // input,  写请求锁类型, 来自axi_slave_mux.s5_awlock
.s_awcache      (lcd_s_awcache     ),       // input,  写请求Cache属性, 来自axi_slave_mux.s5_awcache
.s_awprot       (lcd_s_awprot      ),       // input,  写请求保护类型, 来自axi_slave_mux.s5_awprot
.s_awvalid      (lcd_s_awvalid     ),       // input,  写请求有效, 来自axi_slave_mux.s5_awvalid
.s_awready      (lcd_s_awready     ),       // output, 写请求就绪, 连接axi_slave_mux.s5_awready
    // --- AXI从端W通道: 写数据 ← axi_slave_mux.S5 ---
.s_wready       (lcd_s_wready      ),       // output, 写数据就绪, 连接axi_slave_mux.s5_wready
.s_wid          (lcd_s_wid         ),       // input,  写数据ID, 来自axi_slave_mux.s5_wid
.s_wdata        (lcd_s_wdata       ),       // input,  写数据(命令/像素值), 来自axi_slave_mux.s5_wdata
.s_wstrb        (lcd_s_wstrb       ),       // input,  写字节使能, 来自axi_slave_mux.s5_wstrb
.s_wlast        (lcd_s_wlast       ),       // input,  写数据最后拍, 来自axi_slave_mux.s5_wlast
.s_wvalid       (lcd_s_wvalid      ),       // input,  写数据有效, 来自axi_slave_mux.s5_wvalid
    // --- AXI从端B通道: 写响应 → axi_slave_mux.S5 ---
.s_bid          (lcd_s_bid         ),       // output, 写响应ID, 连接axi_slave_mux.s5_bid
.s_bresp        (lcd_s_bresp       ),       // output, 写响应状态, 连接axi_slave_mux.s5_bresp
.s_bvalid       (lcd_s_bvalid      ),       // output, 写响应有效, 连接axi_slave_mux.s5_bvalid
.s_bready       (lcd_s_bready      ),       // input,  写响应就绪, 来自axi_slave_mux.s5_bready
    // --- AXI从端AR通道: 读请求 ← axi_slave_mux.S5 ---
.s_arid         (lcd_s_arid        ),       // input,  读请求ID, 来自axi_slave_mux.s5_arid
.s_araddr       (lcd_s_araddr      ),       // input,  读请求地址, 来自axi_slave_mux.s5_araddr
.s_arlen        (lcd_s_arlen       ),       // input,  读请求突发长度, 来自axi_slave_mux.s5_arlen
.s_arsize       (lcd_s_arsize      ),       // input,  读请求数据宽度, 来自axi_slave_mux.s5_arsize
.s_arburst      (lcd_s_arburst     ),       // input,  读请求突发类型, 来自axi_slave_mux.s5_arburst
.s_arlock       (lcd_s_arlock      ),       // input,  读请求锁类型, 来自axi_slave_mux.s5_arlock
.s_arcache      (lcd_s_arcache     ),       // input,  读请求Cache属性, 来自axi_slave_mux.s5_arcache
.s_arprot       (lcd_s_arprot      ),       // input,  读请求保护类型, 来自axi_slave_mux.s5_arprot
.s_arvalid      (lcd_s_arvalid     ),       // input,  读请求有效, 来自axi_slave_mux.s5_arvalid
.s_arready      (lcd_s_arready     ),       // output, 读请求就绪, 连接axi_slave_mux.s5_arready
    // --- AXI从端R通道: 读响应 → axi_slave_mux.S5 ---
.s_rready       (lcd_s_rready      ),       // input,  读响应就绪, 来自axi_slave_mux.s5_rready
.s_rid          (lcd_s_rid         ),       // output, 读响应ID, 连接axi_slave_mux.s5_rid
.s_rdata        (lcd_s_rdata       ),       // output, 读响应数据(状态/控制寄存器), 连接axi_slave_mux.s5_rdata
.s_rresp        (lcd_s_rresp       ),       // output, 读响应状态, 连接axi_slave_mux.s5_rresp
.s_rlast        (lcd_s_rlast       ),       // output, 读响应最后拍, 连接axi_slave_mux.s5_rlast
.s_rvalid       (lcd_s_rvalid      ),       // output, 读响应有效, 连接axi_slave_mux.s5_rvalid
    // --- LCD 8080并行接口 → SSD1963 ---
.lcd_rst        (lcd_rst           ),       // output, LCD复位(低有效), 连接外部引脚lcd_rst
.lcd_cs         (lcd_cs            ),       // output, LCD片选(常低), 连接外部引脚lcd_cs
.lcd_rs         (lcd_rs            ),       // output, LCD命令/数据选择, 连接外部引脚lcd_rs
.lcd_wr         (lcd_wr            ),       // output, LCD写信号(低有效), 连接外部引脚lcd_wr
.lcd_rd         (lcd_rd            ),       // output, LCD读信号(常高), 连接外部引脚lcd_rd
.lcd_bl_ctr     (lcd_bl_ctr        ),       // output, LCD背光控制, 连接外部引脚lcd_bl_ctr
.lcd_data       (lcd_data          ),       // output, LCD 16位数据总线, 连接外部引脚lcd_data[15:0]
    // --- 触摸屏接口 → 外部触摸控制器 ---
.lcd_t_pen      (lcd_t_pen         ),       // input,  触摸中断, 来自外部引脚lcd_t_pen
.lcd_t_mosi     (lcd_t_mosi        ),       // inout,  触摸SPI数据, 连接外部引脚lcd_t_mosi
.lcd_t_clk      (lcd_t_clk         ),       // output, 触摸SPI时钟, 连接外部引脚lcd_t_clk
.lcd_t_cs_rst   (lcd_t_cs_rst      ),       // output, 触摸片选/复位, 连接外部引脚lcd_t_cs_rst
    // --- LCD DMA像素流入口：接入lcd_dma ---
    .dma_pixel_data (lcd_dma_pixel_data ),       // input,  DMA像素数据(RGB565)
    .dma_pixel_valid(lcd_dma_pixel_valid),       // input,  DMA像素有效
    .dma_pixel_ready(lcd_dma_pixel_ready)        // output, DMA像素接收就绪
);

//PS2
ps2_ctrl PS2_CTRL(
    .aclk           (aclk),
    .aresetn        (aresetn),
    .s_awid         (ps2_s_awid),
    .s_awaddr       (ps2_s_awaddr),
    .s_awlen        (ps2_s_awlen),
    .s_awsize       (ps2_s_awsize),
    .s_awburst      (ps2_s_awburst),
    .s_awlock       (ps2_s_awlock),
    .s_awcache      (ps2_s_awcache),
    .s_awprot       (ps2_s_awprot),
    .s_awvalid      (ps2_s_awvalid),
    .s_awready      (ps2_s_awready),
    .s_wid          (ps2_s_wid),
    .s_wdata        (ps2_s_wdata),
    .s_wstrb        (ps2_s_wstrb),
    .s_wlast        (ps2_s_wlast),
    .s_wvalid       (ps2_s_wvalid),
    .s_wready       (ps2_s_wready),
    .s_bid          (ps2_s_bid),
    .s_bresp        (ps2_s_bresp),
    .s_bvalid       (ps2_s_bvalid),
    .s_bready       (ps2_s_bready),
    .s_arid         (ps2_s_arid),
    .s_araddr       (ps2_s_araddr),
    .s_arlen        (ps2_s_arlen),
    .s_arsize       (ps2_s_arsize),
    .s_arburst      (ps2_s_arburst),
    .s_arlock       (ps2_s_arlock),
    .s_arcache      (ps2_s_arcache),
    .s_arprot       (ps2_s_arprot),
    .s_arvalid      (ps2_s_arvalid),
    .s_arready      (ps2_s_arready),
    .s_rid          (ps2_s_rid),
    .s_rdata        (ps2_s_rdata),
    .s_rresp        (ps2_s_rresp),
    .s_rlast        (ps2_s_rlast),
    .s_rvalid       (ps2_s_rvalid),
    .s_rready       (ps2_s_rready),
    .ps2_clk_i      (ps2_clk_i),
    .ps2_clk_o      (ps2_clk_o),
    .ps2_clk_oe     (ps2_clk_oe),
    .ps2_data_i     (ps2_data_i),
    .ps2_data_o     (ps2_data_o),
    .ps2_data_oe    (ps2_data_oe),
    .ps2_int        (ps2_int)
);

// Dedicated USB boot-mouse host.  Software performs enumeration and polling
// through the 0x1fa0_0000 register window.
usb_mouse_host USB_MOUSE_HOST(
    .aclk               (aclk),
    .aresetn            (aresetn),
    .s_awid             (usb_s_awid),
    .s_awaddr           (usb_s_awaddr),
    .s_awlen            (usb_s_awlen),
    .s_awsize           (usb_s_awsize),
    .s_awburst          (usb_s_awburst),
    .s_awlock           (usb_s_awlock),
    .s_awcache          (usb_s_awcache),
    .s_awprot           (usb_s_awprot),
    .s_awvalid          (usb_s_awvalid),
    .s_awready          (usb_s_awready),
    .s_wid              (usb_s_wid),
    .s_wdata            (usb_s_wdata),
    .s_wstrb            (usb_s_wstrb),
    .s_wlast            (usb_s_wlast),
    .s_wvalid           (usb_s_wvalid),
    .s_wready           (usb_s_wready),
    .s_bid              (usb_s_bid),
    .s_bresp            (usb_s_bresp),
    .s_bvalid           (usb_s_bvalid),
    .s_bready           (usb_s_bready),
    .s_arid             (usb_s_arid),
    .s_araddr           (usb_s_araddr),
    .s_arlen            (usb_s_arlen),
    .s_arsize           (usb_s_arsize),
    .s_arburst          (usb_s_arburst),
    .s_arlock           (usb_s_arlock),
    .s_arcache          (usb_s_arcache),
    .s_arprot           (usb_s_arprot),
    .s_arvalid          (usb_s_arvalid),
    .s_arready          (usb_s_arready),
    .s_rid              (usb_s_rid),
    .s_rdata            (usb_s_rdata),
    .s_rresp            (usb_s_rresp),
    .s_rlast            (usb_s_rlast),
    .s_rvalid           (usb_s_rvalid),
    .s_rready           (usb_s_rready),
    .usb_clk            (usb_clk),
    .utmi_data_i        (usb_data_i),
    .utmi_data_o        (usb_data_o),
    .utmi_data_oe       (usb_data_oe),
    .utmi_data_t        (usb_data_t),
    .utmi_txvalid       (USB_TXVALID),
    .utmi_txready       (USB_TXREADY),
    .utmi_rxvalid       (USB_RXVALID),
    .utmi_rxactive      (USB_RXACTIVE),
    .utmi_rxerror       (USB_RXERROR),
    .utmi_linestate     (USB_LINESTATE),
    .utmi_xcvrsel       (USB_XCVRSEL),
    .utmi_termsel       (USB_TERMSEL),
    .utmi_opmode        (USB_OPMODE),
    .utmi_suspendn      (USB_SUSPENDN),
    .utmi_reset         (USB_PHY_RESET),
    .utmi_dppd          (USB_DPPD),
    .utmi_dmpd          (USB_DMPD),
    .utmi_chrgvbus      (USB_CHRGVBUS),
    .utmi_dischrgvbus   (USB_DISCHRGVBUS),
    .utmi_idpullup      (USB_IDPULLUP),
    .utmi_vbusvld       (USB_VBUSVLD),
    .utmi_sessvld       (USB_SESSVLD),
    .utmi_sessend       (USB_SESSEND),
    .utmi_hostdisc      (USB_HOSTDISC),
    .utmi_iddig         (USB_IDDIG),
    .usb_int            (usb_int)
);

// -------------------------------------------------------------------------
// Non-intrusive CPU AXI read-path diagnostics
//
// Set SW7=1 to take over the seven-segment display.  SW[6:5] selects a bank
// and SW[2:0] selects a page (SW[4:3] are ignored):
//   bank 0: 0 CPU AR addr, 1 CPU R status, 2 CDC AR addr, 3 CDC R status,
//           4 DDR-S00 AR addr, 5 DDR-S00 R status, 6 MIG AR addr, 7 MIG R status
//   bank 1: 0 last committed PC, 1 last committed instruction,
//           2 commit counter, 3 CPU execution status,
//           4 CPU AW addr, 5 CPU write status, 6 CPU AR addr, 7 CPU R status
//   bank 2: 0 CDC AW addr, 1 CDC write status, 2 DDR-S00 AW addr,
//           3 DDR-S00 write status, 4 MIG AW addr, 5 MIG write status,
//           6 StoreBuffer status, 7 MSHR status
//   bank 3: 0 APB/UART AR addr, 1 APB/UART read status,
//           2 APB/UART AW addr, 3 APB/UART write status,
//           4 current ROB-head PC, 5 ROB-head status,
//           6 StoreBuffer completion-head paddr, 7 StoreBuffer status
//
// Status word (eight hexadecimal digits):
//   [31:28] last event: A=AR, b=R beat, C=RLAST, E=RRESP, F=timeout/unowned
//   [27:24] last ARID, [23:20] last RID, [19:16] last ARLEN low nibble
//   [15:12] live ARVALID/ARREADY/RVALID/RREADY
//   [11] RLAST, [10:9] RRESP, [8] any ID active
//   [7] timeout sticky, [6] unowned RID sticky, [5] RRESP error sticky
//   [4:0] accepted R-beat count modulo 32
wire [31:0] axi_diag_cpu_addr;
wire [31:0] axi_diag_cpu_status;
wire [31:0] axi_diag_cdc_addr;
wire [31:0] axi_diag_cdc_status;
wire [31:0] axi_diag_s00_addr;
wire [31:0] axi_diag_s00_status;
wire [31:0] axi_diag_mig_addr;
wire [31:0] axi_diag_mig_status;
wire [31:0] axi_diag_cpu_waddr;
wire [31:0] axi_diag_cpu_wstatus;
wire [31:0] axi_diag_cdc_waddr;
wire [31:0] axi_diag_cdc_wstatus;
wire [31:0] axi_diag_s00_waddr;
wire [31:0] axi_diag_s00_wstatus;
wire [31:0] axi_diag_mig_waddr;
wire [31:0] axi_diag_mig_wstatus;
wire [31:0] axi_diag_apb_raddr;
wire [31:0] axi_diag_apb_rstatus;
wire [31:0] axi_diag_apb_waddr;
wire [31:0] axi_diag_apb_wstatus;

reg [31:0] axi_diag_commit_pc;
reg [31:0] axi_diag_commit_inst;
reg [31:0] axi_diag_commit_count;
reg [25:0] axi_diag_commit_idle;
reg        axi_diag_commit_stalled;
always @(posedge cpu_clk or negedge cpu_aresetn) begin
    if (!cpu_aresetn) begin
        axi_diag_commit_pc      <= 32'd0;
        axi_diag_commit_inst    <= 32'd0;
        axi_diag_commit_count   <= 32'd0;
        axi_diag_commit_idle    <= 26'd0;
        axi_diag_commit_stalled <= 1'b0;
    end else if (diag_commit_valid) begin
        axi_diag_commit_pc    <= diag_commit_pc;
        axi_diag_commit_inst  <= 32'd0;
        axi_diag_commit_count <= axi_diag_commit_count + 32'd1;
        axi_diag_commit_idle  <= 26'd0;
        axi_diag_commit_stalled <= 1'b0;
    end else begin
        axi_diag_commit_idle <= axi_diag_commit_idle + 26'd1;
        if (&axi_diag_commit_idle)
            axi_diag_commit_stalled <= 1'b1;
    end
end

axi_read_diag_probe #(.ID_WIDTH(4), .LEN_WIDTH(4)) AXI_DIAG_CPU (
    .clk(cpu_clk), .resetn(cpu_aresetn),
    .arid(m0_arid), .araddr(m0_araddr), .arlen(m0_arlen),
    .arvalid(m0_arvalid), .arready(m0_arready),
    .rid(m0_rid), .rresp(m0_rresp), .rlast(m0_rlast),
    .rvalid(m0_rvalid), .rready(m0_rready),
    .last_araddr(axi_diag_cpu_addr), .status(axi_diag_cpu_status)
);

axi_read_diag_probe #(.ID_WIDTH(4), .LEN_WIDTH(4)) AXI_DIAG_CDC (
    .clk(aclk), .resetn(aresetn),
    .arid(m0_async_arid), .araddr(m0_async_araddr), .arlen(m0_async_arlen),
    .arvalid(m0_async_arvalid), .arready(m0_async_arready),
    .rid(m0_async_rid), .rresp(m0_async_rresp), .rlast(m0_async_rlast),
    .rvalid(m0_async_rvalid), .rready(m0_async_rready),
    .last_araddr(axi_diag_cdc_addr), .status(axi_diag_cdc_status)
);

axi_read_diag_probe #(.ID_WIDTH(4), .LEN_WIDTH(4)) AXI_DIAG_S00 (
    .clk(aclk), .resetn(aresetn),
    .arid(s0_arid), .araddr(s0_araddr), .arlen(s0_arlen),
    .arvalid(s0_arvalid), .arready(s0_arready),
    .rid(s0_rid), .rresp(s0_rresp), .rlast(s0_rlast),
    .rvalid(s0_rvalid), .rready(s0_rready),
    .last_araddr(axi_diag_s00_addr), .status(axi_diag_s00_status)
);

axi_read_diag_probe #(.ID_WIDTH(6), .LEN_WIDTH(8)) AXI_DIAG_MIG (
    .clk(c1_clk0), .resetn(interconnect_aresetn),
    .arid(mig_arid[5:0]), .araddr(mig_araddr), .arlen(mig_arlen),
    .arvalid(mig_arvalid), .arready(mig_arready),
    .rid(mig_rid[5:0]), .rresp(mig_rresp), .rlast(mig_rlast),
    .rvalid(mig_rvalid), .rready(mig_rready),
    .last_araddr(axi_diag_mig_addr), .status(axi_diag_mig_status)
);

axi_read_diag_probe #(.ID_WIDTH(4), .LEN_WIDTH(4)) AXI_DIAG_APB_READ (
    .clk(aclk), .resetn(aresetn),
    .arid(apb_s_arid), .araddr(apb_s_araddr), .arlen(apb_s_arlen),
    .arvalid(apb_s_arvalid), .arready(apb_s_arready),
    .rid(apb_s_rid), .rresp(apb_s_rresp), .rlast(apb_s_rlast),
    .rvalid(apb_s_rvalid), .rready(apb_s_rready),
    .last_araddr(axi_diag_apb_raddr), .status(axi_diag_apb_rstatus)
);

axi_write_diag_probe #(.ID_WIDTH(4), .LEN_WIDTH(4)) AXI_DIAG_CPU_WRITE (
    .clk(cpu_clk), .resetn(cpu_aresetn),
    .awid(m0_awid), .awaddr(m0_awaddr), .awlen(m0_awlen),
    .awvalid(m0_awvalid), .awready(m0_awready),
    .wlast(m0_wlast), .wvalid(m0_wvalid), .wready(m0_wready),
    .bid(m0_bid), .bresp(m0_bresp), .bvalid(m0_bvalid), .bready(m0_bready),
    .last_awaddr(axi_diag_cpu_waddr), .status(axi_diag_cpu_wstatus)
);

axi_write_diag_probe #(.ID_WIDTH(4), .LEN_WIDTH(4)) AXI_DIAG_CDC_WRITE (
    .clk(aclk), .resetn(aresetn),
    .awid(m0_async_awid), .awaddr(m0_async_awaddr), .awlen(m0_async_awlen),
    .awvalid(m0_async_awvalid), .awready(m0_async_awready),
    .wlast(m0_async_wlast), .wvalid(m0_async_wvalid), .wready(m0_async_wready),
    .bid(m0_async_bid), .bresp(m0_async_bresp),
    .bvalid(m0_async_bvalid), .bready(m0_async_bready),
    .last_awaddr(axi_diag_cdc_waddr), .status(axi_diag_cdc_wstatus)
);

axi_write_diag_probe #(.ID_WIDTH(4), .LEN_WIDTH(4)) AXI_DIAG_S00_WRITE (
    .clk(aclk), .resetn(aresetn),
    .awid(s0_awid), .awaddr(s0_awaddr), .awlen(s0_awlen),
    .awvalid(s0_awvalid), .awready(s0_awready),
    .wlast(s0_wlast), .wvalid(s0_wvalid), .wready(s0_wready),
    .bid(s0_bid), .bresp(s0_bresp), .bvalid(s0_bvalid), .bready(s0_bready),
    .last_awaddr(axi_diag_s00_waddr), .status(axi_diag_s00_wstatus)
);

axi_write_diag_probe #(.ID_WIDTH(6), .LEN_WIDTH(8)) AXI_DIAG_MIG_WRITE (
    .clk(c1_clk0), .resetn(interconnect_aresetn),
    .awid(mig_awid[5:0]), .awaddr(mig_awaddr), .awlen(mig_awlen),
    .awvalid(mig_awvalid), .awready(mig_awready),
    .wlast(mig_wlast), .wvalid(mig_wvalid), .wready(mig_wready),
    .bid(mig_bid[5:0]), .bresp(mig_bresp),
    .bvalid(mig_bvalid), .bready(mig_bready),
    .last_awaddr(axi_diag_mig_waddr), .status(axi_diag_mig_wstatus)
);

axi_write_diag_probe #(.ID_WIDTH(4), .LEN_WIDTH(4)) AXI_DIAG_APB_WRITE (
    .clk(aclk), .resetn(aresetn),
    .awid(apb_s_awid), .awaddr(apb_s_awaddr), .awlen(apb_s_awlen),
    .awvalid(apb_s_awvalid), .awready(apb_s_awready),
    .wlast(apb_s_wlast), .wvalid(apb_s_wvalid), .wready(apb_s_wready),
    .bid(apb_s_bid), .bresp(apb_s_bresp),
    .bvalid(apb_s_bvalid), .bready(apb_s_bready),
    .last_awaddr(axi_diag_apb_waddr), .status(axi_diag_apb_wstatus)
);

// The probe outputs change only on AXI handshakes.  Two-stage sampling gives a
// best-effort human-readable snapshot after a stall (a changing multi-bit word
// may momentarily tear); these signals never feed back into functional logic.
reg [31:0] axi_diag_cpu_addr_meta, axi_diag_cpu_addr_sync;
reg [31:0] axi_diag_cpu_status_meta, axi_diag_cpu_status_sync;
reg [31:0] axi_diag_mig_addr_meta, axi_diag_mig_addr_sync;
reg [31:0] axi_diag_mig_status_meta, axi_diag_mig_status_sync;
reg [31:0] axi_diag_cpu_waddr_meta, axi_diag_cpu_waddr_sync;
reg [31:0] axi_diag_cpu_wstatus_meta, axi_diag_cpu_wstatus_sync;
reg [31:0] axi_diag_mig_waddr_meta, axi_diag_mig_waddr_sync;
reg [31:0] axi_diag_mig_wstatus_meta, axi_diag_mig_wstatus_sync;
reg [31:0] axi_diag_commit_pc_meta, axi_diag_commit_pc_sync;
reg [31:0] axi_diag_commit_inst_meta, axi_diag_commit_inst_sync;
reg [31:0] axi_diag_commit_count_meta, axi_diag_commit_count_sync;
reg [31:0] axi_diag_rob_head_pc_meta, axi_diag_rob_head_pc_sync;
reg [31:0] axi_diag_rob_status_meta, axi_diag_rob_status_sync;
reg [31:0] axi_diag_sb_head_paddr_meta, axi_diag_sb_head_paddr_sync;
reg [31:0] axi_diag_sb_status_meta, axi_diag_sb_status_sync;
reg [31:0] axi_diag_mshr_status_meta, axi_diag_mshr_status_sync;
reg [31:0] axi_diag_dcache_status_meta, axi_diag_dcache_status_sync;
reg [31:0] axi_diag_csr_era_meta, axi_diag_csr_era_sync;
reg [31:0] axi_diag_csr_eentry_meta, axi_diag_csr_eentry_sync;
reg [31:0] axi_diag_csr_boundary_pc_meta, axi_diag_csr_boundary_pc_sync;
reg [31:0] axi_diag_csr_vector_pc_meta, axi_diag_csr_vector_pc_sync;
reg [31:0] axi_diag_csr_crmd_meta, axi_diag_csr_crmd_sync;
reg [31:0] axi_diag_csr_prmd_meta, axi_diag_csr_prmd_sync;
reg [31:0] axi_diag_csr_estat_meta, axi_diag_csr_estat_sync;
reg [31:0] axi_diag_csr_badv_meta, axi_diag_csr_badv_sync;
reg [31:0] axi_diag_csr_tlbrentry_meta, axi_diag_csr_tlbrentry_sync;
reg        axi_diag_commit_stalled_meta, axi_diag_commit_stalled_sync;
reg        axi_diag_ws_valid_meta, axi_diag_ws_valid_sync;
always @(posedge aclk or negedge resetn) begin
    if (!resetn) begin
        axi_diag_cpu_addr_meta   <= 32'd0;
        axi_diag_cpu_addr_sync   <= 32'd0;
        axi_diag_cpu_status_meta <= 32'd0;
        axi_diag_cpu_status_sync <= 32'd0;
        axi_diag_mig_addr_meta   <= 32'd0;
        axi_diag_mig_addr_sync   <= 32'd0;
        axi_diag_mig_status_meta <= 32'd0;
        axi_diag_mig_status_sync <= 32'd0;
        axi_diag_cpu_waddr_meta   <= 32'd0;
        axi_diag_cpu_waddr_sync   <= 32'd0;
        axi_diag_cpu_wstatus_meta <= 32'd0;
        axi_diag_cpu_wstatus_sync <= 32'd0;
        axi_diag_mig_waddr_meta   <= 32'd0;
        axi_diag_mig_waddr_sync   <= 32'd0;
        axi_diag_mig_wstatus_meta <= 32'd0;
        axi_diag_mig_wstatus_sync <= 32'd0;
        axi_diag_commit_pc_meta   <= 32'd0;
        axi_diag_commit_pc_sync   <= 32'd0;
        axi_diag_commit_inst_meta <= 32'd0;
        axi_diag_commit_inst_sync <= 32'd0;
        axi_diag_commit_count_meta <= 32'd0;
        axi_diag_commit_count_sync <= 32'd0;
        axi_diag_rob_head_pc_meta <= 32'd0;
        axi_diag_rob_head_pc_sync <= 32'd0;
        axi_diag_rob_status_meta <= 32'd0;
        axi_diag_rob_status_sync <= 32'd0;
        axi_diag_sb_head_paddr_meta <= 32'd0;
        axi_diag_sb_head_paddr_sync <= 32'd0;
        axi_diag_sb_status_meta <= 32'd0;
        axi_diag_sb_status_sync <= 32'd0;
        axi_diag_mshr_status_meta <= 32'd0;
        axi_diag_mshr_status_sync <= 32'd0;
        axi_diag_dcache_status_meta <= 32'd0;
        axi_diag_dcache_status_sync <= 32'd0;
        axi_diag_csr_era_meta <= 32'd0;
        axi_diag_csr_era_sync <= 32'd0;
        axi_diag_csr_eentry_meta <= 32'd0;
        axi_diag_csr_eentry_sync <= 32'd0;
        axi_diag_csr_boundary_pc_meta <= 32'd0;
        axi_diag_csr_boundary_pc_sync <= 32'd0;
        axi_diag_csr_vector_pc_meta <= 32'd0;
        axi_diag_csr_vector_pc_sync <= 32'd0;
        axi_diag_csr_crmd_meta <= 32'd0;
        axi_diag_csr_crmd_sync <= 32'd0;
        axi_diag_csr_prmd_meta <= 32'd0;
        axi_diag_csr_prmd_sync <= 32'd0;
        axi_diag_csr_estat_meta <= 32'd0;
        axi_diag_csr_estat_sync <= 32'd0;
        axi_diag_csr_badv_meta <= 32'd0;
        axi_diag_csr_badv_sync <= 32'd0;
        axi_diag_csr_tlbrentry_meta <= 32'd0;
        axi_diag_csr_tlbrentry_sync <= 32'd0;
        axi_diag_commit_stalled_meta <= 1'b0;
        axi_diag_commit_stalled_sync <= 1'b0;
        axi_diag_ws_valid_meta <= 1'b0;
        axi_diag_ws_valid_sync <= 1'b0;
    end else begin
        axi_diag_cpu_addr_meta   <= axi_diag_cpu_addr;
        axi_diag_cpu_addr_sync   <= axi_diag_cpu_addr_meta;
        axi_diag_cpu_status_meta <= axi_diag_cpu_status;
        axi_diag_cpu_status_sync <= axi_diag_cpu_status_meta;
        axi_diag_mig_addr_meta   <= axi_diag_mig_addr;
        axi_diag_mig_addr_sync   <= axi_diag_mig_addr_meta;
        axi_diag_mig_status_meta <= axi_diag_mig_status;
        axi_diag_mig_status_sync <= axi_diag_mig_status_meta;
        axi_diag_cpu_waddr_meta   <= axi_diag_cpu_waddr;
        axi_diag_cpu_waddr_sync   <= axi_diag_cpu_waddr_meta;
        axi_diag_cpu_wstatus_meta <= axi_diag_cpu_wstatus;
        axi_diag_cpu_wstatus_sync <= axi_diag_cpu_wstatus_meta;
        axi_diag_mig_waddr_meta   <= axi_diag_mig_waddr;
        axi_diag_mig_waddr_sync   <= axi_diag_mig_waddr_meta;
        axi_diag_mig_wstatus_meta <= axi_diag_mig_wstatus;
        axi_diag_mig_wstatus_sync <= axi_diag_mig_wstatus_meta;
        axi_diag_commit_pc_meta   <= axi_diag_commit_pc;
        axi_diag_commit_pc_sync   <= axi_diag_commit_pc_meta;
        axi_diag_commit_inst_meta <= axi_diag_commit_inst;
        axi_diag_commit_inst_sync <= axi_diag_commit_inst_meta;
        axi_diag_commit_count_meta <= axi_diag_commit_count;
        axi_diag_commit_count_sync <= axi_diag_commit_count_meta;
        axi_diag_rob_head_pc_meta <= diag_rob_head_pc;
        axi_diag_rob_head_pc_sync <= axi_diag_rob_head_pc_meta;
        axi_diag_rob_status_meta <= diag_rob_status;
        axi_diag_rob_status_sync <= axi_diag_rob_status_meta;
        axi_diag_sb_head_paddr_meta <= diag_sb_head_paddr;
        axi_diag_sb_head_paddr_sync <= axi_diag_sb_head_paddr_meta;
        axi_diag_sb_status_meta <= diag_sb_status;
        axi_diag_sb_status_sync <= axi_diag_sb_status_meta;
        axi_diag_mshr_status_meta <= diag_mshr_status;
        axi_diag_mshr_status_sync <= axi_diag_mshr_status_meta;
        axi_diag_dcache_status_meta <= diag_dcache_status;
        axi_diag_dcache_status_sync <= axi_diag_dcache_status_meta;
        axi_diag_csr_era_meta <= diag_csr_era;
        axi_diag_csr_era_sync <= axi_diag_csr_era_meta;
        axi_diag_csr_eentry_meta <= diag_csr_eentry;
        axi_diag_csr_eentry_sync <= axi_diag_csr_eentry_meta;
        axi_diag_csr_boundary_pc_meta <= diag_csr_boundary_pc;
        axi_diag_csr_boundary_pc_sync <= axi_diag_csr_boundary_pc_meta;
        axi_diag_csr_vector_pc_meta <= diag_csr_vector_pc;
        axi_diag_csr_vector_pc_sync <= axi_diag_csr_vector_pc_meta;
        axi_diag_csr_crmd_meta <= diag_csr_crmd;
        axi_diag_csr_crmd_sync <= axi_diag_csr_crmd_meta;
        axi_diag_csr_prmd_meta <= diag_csr_prmd;
        axi_diag_csr_prmd_sync <= axi_diag_csr_prmd_meta;
        axi_diag_csr_estat_meta <= diag_csr_estat;
        axi_diag_csr_estat_sync <= axi_diag_csr_estat_meta;
        axi_diag_csr_badv_meta <= diag_csr_badv;
        axi_diag_csr_badv_sync <= axi_diag_csr_badv_meta;
        axi_diag_csr_tlbrentry_meta <= diag_csr_tlbrentry;
        axi_diag_csr_tlbrentry_sync <= axi_diag_csr_tlbrentry_meta;
        axi_diag_commit_stalled_meta <= axi_diag_commit_stalled;
        axi_diag_commit_stalled_sync <= axi_diag_commit_stalled_meta;
        axi_diag_ws_valid_meta <= diag_commit_valid;
        axi_diag_ws_valid_sync <= axi_diag_ws_valid_meta;
    end
end

wire [31:0] axi_diag_read_page =
    (switch[2:0] == 3'd0) ? axi_diag_cpu_addr_sync   :
    (switch[2:0] == 3'd1) ? axi_diag_cpu_status_sync :
    (switch[2:0] == 3'd2) ? axi_diag_cdc_addr        :
    (switch[2:0] == 3'd3) ? axi_diag_cdc_status      :
    (switch[2:0] == 3'd4) ? axi_diag_s00_addr        :
    (switch[2:0] == 3'd5) ? axi_diag_s00_status      :
    (switch[2:0] == 3'd6) ? axi_diag_mig_addr_sync   :
                             axi_diag_mig_status_sync;
wire [31:0] axi_diag_cpu_page =
    (switch[2:0] == 3'd0) ? axi_diag_commit_pc_sync       :
    (switch[2:0] == 3'd1) ? axi_diag_commit_inst_sync     :
    (switch[2:0] == 3'd2) ? axi_diag_commit_count_sync    :
    (switch[2:0] == 3'd3) ? {axi_diag_commit_stalled_sync,
                              30'd0, axi_diag_ws_valid_sync} :
    (switch[2:0] == 3'd4) ? axi_diag_cpu_waddr_sync       :
    (switch[2:0] == 3'd5) ? axi_diag_cpu_wstatus_sync     :
    (switch[2:0] == 3'd6) ? axi_diag_cpu_addr_sync        :
                             axi_diag_cpu_status_sync;
wire [31:0] axi_diag_write_page =
    (switch[2:0] == 3'd0) ? axi_diag_cdc_waddr        :
    (switch[2:0] == 3'd1) ? axi_diag_cdc_wstatus      :
    (switch[2:0] == 3'd2) ? axi_diag_s00_waddr        :
    (switch[2:0] == 3'd3) ? axi_diag_s00_wstatus      :
    (switch[2:0] == 3'd4) ? axi_diag_mig_waddr_sync   :
    (switch[2:0] == 3'd5) ? axi_diag_mig_wstatus_sync :
    (switch[2:0] == 3'd6) ? axi_diag_dcache_status_sync :
                             axi_diag_mshr_status_sync;
wire [31:0] axi_diag_csr_boundary_page =
    (switch[2:0] == 3'd0) ? axi_diag_csr_era_sync :
    (switch[2:0] == 3'd1) ? axi_diag_csr_eentry_sync :
    (switch[2:0] == 3'd2) ? axi_diag_csr_boundary_pc_sync :
    (switch[2:0] == 3'd3) ? axi_diag_csr_vector_pc_sync :
    (switch[2:0] == 3'd4) ? axi_diag_rob_head_pc_sync :
    (switch[2:0] == 3'd5) ? axi_diag_rob_status_sync :
    (switch[2:0] == 3'd6) ? axi_diag_sb_head_paddr_sync :
                             axi_diag_sb_status_sync;
wire [31:0] axi_diag_csr_state_page =
    (switch[2:0] == 3'd0) ? axi_diag_csr_crmd_sync :
    (switch[2:0] == 3'd1) ? axi_diag_csr_prmd_sync :
    (switch[2:0] == 3'd2) ? axi_diag_csr_estat_sync :
    (switch[2:0] == 3'd3) ? axi_diag_csr_badv_sync :
    (switch[2:0] == 3'd4) ? axi_diag_csr_tlbrentry_sync :
    (switch[2:0] == 3'd5) ? axi_diag_csr_eentry_sync :
    (switch[2:0] == 3'd6) ? axi_diag_csr_era_sync :
                             axi_diag_csr_vector_pc_sync;
wire [31:0] axi_diag_apb_page =
    (switch[4:3] == 2'd1) ? axi_diag_csr_state_page :
                            axi_diag_csr_boundary_page;
assign axi_diag_num_data = (switch[6:5] == 2'd0) ? axi_diag_read_page  :
                           (switch[6:5] == 2'd1) ? axi_diag_cpu_page   :
                           (switch[6:5] == 2'd2) ? axi_diag_write_page :
                                                  axi_diag_apb_page;

axi_hex_display AXI_DIAG_DISPLAY (
    .clk(aclk), .resetn(resetn), .value(axi_diag_num_data),
    .num_csn(axi_diag_num_csn), .num_a_g(axi_diag_num_a_g)
);
endmodule

module axi_read_diag_probe #(
    parameter integer ID_WIDTH = 4,
    parameter integer LEN_WIDTH = 4
) (
    input  wire                 clk,
    input  wire                 resetn,
    input  wire [ID_WIDTH-1:0]  arid,
    input  wire [31:0]          araddr,
    input  wire [LEN_WIDTH-1:0] arlen,
    input  wire                 arvalid,
    input  wire                 arready,
    input  wire [ID_WIDTH-1:0]  rid,
    input  wire [1:0]           rresp,
    input  wire                 rlast,
    input  wire                 rvalid,
    input  wire                 rready,
    output reg  [31:0]          last_araddr,
    output wire [31:0]          status
);
localparam integer ID_COUNT = (1 << ID_WIDTH);
wire ar_fire = arvalid && arready;
wire r_fire = rvalid && rready;
wire rlast_fire = r_fire && rlast;

reg [ID_COUNT-1:0] active_ids;
reg [3:0] last_arid;
reg [3:0] last_rid;
reg [3:0] last_arlen;
reg [3:0] last_event;
reg [4:0] rbeat_count;
reg [24:0] watchdog;
reg timeout_sticky;
reg unowned_sticky;
reg rresp_sticky;

wire rid_was_owned = active_ids[rid] || (ar_fire && arid == rid);

always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        active_ids      <= {ID_COUNT{1'b0}};
        last_araddr     <= 32'd0;
        last_arid       <= 4'd0;
        last_rid        <= 4'd0;
        last_arlen      <= 4'd0;
        last_event      <= 4'd0;
        rbeat_count     <= 5'd0;
        watchdog        <= 25'd0;
        timeout_sticky  <= 1'b0;
        unowned_sticky  <= 1'b0;
        rresp_sticky    <= 1'b0;
    end else begin
        if (rlast_fire)
            active_ids[rid] <= 1'b0;
        if (ar_fire) begin
            active_ids[arid] <= 1'b1;
            last_araddr <= araddr;
            last_arid   <= arid[3:0];
            last_arlen  <= arlen[3:0];
            last_event  <= 4'hA;
        end

        if (r_fire) begin
            last_rid    <= rid[3:0];
            rbeat_count <= rbeat_count + 5'd1;
            last_event  <= rlast ? 4'hC : 4'hB;
            watchdog    <= 25'd0;
            if (rresp != 2'b00) begin
                rresp_sticky <= 1'b1;
                last_event   <= 4'hE;
            end
            if (!rid_was_owned) begin
                unowned_sticky <= 1'b1;
                last_event     <= 4'hF;
            end
        end else if (|active_ids) begin
            watchdog <= watchdog + 25'd1;
            if (&watchdog) begin
                timeout_sticky <= 1'b1;
                last_event     <= 4'hF;
            end
        end else begin
            watchdog <= 25'd0;
        end
    end
end

assign status = {last_event, last_arid, last_rid, last_arlen,
                 arvalid, arready, rvalid, rready,
                 rlast, rresp, |active_ids,
                 timeout_sticky, unowned_sticky, rresp_sticky,
                 rbeat_count};
endmodule

// Write status word:
//   [31:28] A=AW, d=WLAST, b=B response, E=BRESP error, F=timeout/unowned B
//   [27:24] last AWID, [23:20] last BID, [19:16] last AWLEN low nibble
//   [15:10] AWVALID/AWREADY/WVALID/WREADY/BVALID/BREADY
//   [9] WLAST, [8] write active
//   [7] timeout sticky, [6] unowned B sticky, [5] BRESP error sticky
//   [4:0] completed write count modulo 32
module axi_write_diag_probe #(
    parameter integer ID_WIDTH = 4,
    parameter integer LEN_WIDTH = 4
) (
    input  wire                 clk,
    input  wire                 resetn,
    input  wire [ID_WIDTH-1:0]  awid,
    input  wire [31:0]          awaddr,
    input  wire [LEN_WIDTH-1:0] awlen,
    input  wire                 awvalid,
    input  wire                 awready,
    input  wire                 wlast,
    input  wire                 wvalid,
    input  wire                 wready,
    input  wire [ID_WIDTH-1:0]  bid,
    input  wire [1:0]           bresp,
    input  wire                 bvalid,
    input  wire                 bready,
    output reg  [31:0]          last_awaddr,
    output wire [31:0]          status
);
wire aw_fire = awvalid && awready;
wire wlast_fire = wvalid && wready && wlast;
wire b_fire = bvalid && bready;

reg write_active;
reg [3:0] last_awid;
reg [3:0] last_bid;
reg [3:0] last_awlen;
reg [3:0] last_event;
reg [4:0] complete_count;
reg [24:0] watchdog;
reg timeout_sticky;
reg unowned_sticky;
reg bresp_sticky;
wire b_was_owned = write_active || aw_fire;

always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        write_active   <= 1'b0;
        last_awaddr    <= 32'd0;
        last_awid      <= 4'd0;
        last_bid       <= 4'd0;
        last_awlen     <= 4'd0;
        last_event     <= 4'd0;
        complete_count <= 5'd0;
        watchdog       <= 25'd0;
        timeout_sticky <= 1'b0;
        unowned_sticky <= 1'b0;
        bresp_sticky   <= 1'b0;
    end else begin
        if (aw_fire) begin
            write_active <= 1'b1;
            last_awaddr  <= awaddr;
            last_awid    <= awid[3:0];
            last_awlen   <= awlen[3:0];
            last_event   <= 4'hA;
        end
        if (wlast_fire)
            last_event <= 4'hD;

        if (b_fire) begin
            // A new AW may be accepted in the same cycle as the previous B.
            write_active   <= aw_fire;
            last_bid       <= bid[3:0];
            last_event     <= 4'hB;
            complete_count <= complete_count + 5'd1;
            watchdog       <= 25'd0;
            if (bresp != 2'b00) begin
                bresp_sticky <= 1'b1;
                last_event   <= 4'hE;
            end
            if (!b_was_owned) begin
                unowned_sticky <= 1'b1;
                last_event     <= 4'hF;
            end
        end else if (write_active) begin
            watchdog <= watchdog + 25'd1;
            if (&watchdog) begin
                timeout_sticky <= 1'b1;
                last_event     <= 4'hF;
            end
        end else begin
            watchdog <= 25'd0;
        end
    end
end

assign status = {last_event, last_awid, last_bid, last_awlen,
                 awvalid, awready, wvalid, wready, bvalid, bready,
                 wlast, write_active,
                 timeout_sticky, unowned_sticky, bresp_sticky,
                 complete_count};
endmodule

module axi_hex_display (
    input  wire        clk,
    input  wire        resetn,
    input  wire [31:0] value,
    output reg  [7:0]  num_csn,
    output reg  [6:0]  num_a_g
);
reg [19:0] scan_count;
reg [3:0] digit;

always @(posedge clk or negedge resetn) begin
    if (!resetn)
        scan_count <= 20'd0;
    else
        scan_count <= scan_count + 20'd1;
end

always @(*) begin
    case (scan_count[19:17])
        3'd0: begin num_csn = 8'b0111_1111; digit = value[31:28]; end
        3'd1: begin num_csn = 8'b1011_1111; digit = value[27:24]; end
        3'd2: begin num_csn = 8'b1101_1111; digit = value[23:20]; end
        3'd3: begin num_csn = 8'b1110_1111; digit = value[19:16]; end
        3'd4: begin num_csn = 8'b1111_0111; digit = value[15:12]; end
        3'd5: begin num_csn = 8'b1111_1011; digit = value[11:8];  end
        3'd6: begin num_csn = 8'b1111_1101; digit = value[7:4];   end
        default: begin num_csn = 8'b1111_1110; digit = value[3:0]; end
    endcase
    case (digit)
        4'h0: num_a_g = 7'b1111110;
        4'h1: num_a_g = 7'b0110000;
        4'h2: num_a_g = 7'b1101101;
        4'h3: num_a_g = 7'b1111001;
        4'h4: num_a_g = 7'b0110011;
        4'h5: num_a_g = 7'b1011011;
        4'h6: num_a_g = 7'b1011111;
        4'h7: num_a_g = 7'b1110000;
        4'h8: num_a_g = 7'b1111111;
        4'h9: num_a_g = 7'b1111011;
        4'hA: num_a_g = 7'b1110111;
        4'hB: num_a_g = 7'b0011111;
        4'hC: num_a_g = 7'b1001110;
        4'hD: num_a_g = 7'b0111101;
        4'hE: num_a_g = 7'b1001111;
        default: num_a_g = 7'b1000111;
    endcase
end
endmodule
