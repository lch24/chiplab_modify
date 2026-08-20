`timescale 1ns/1ps
// SPDX-License-Identifier: GPL-2.0-or-later
//
// Minimal USB 1.1 host for a directly attached HID boot mouse.
// The external USB3500 supplies the UTMI+ physical layer.  This block is not
// a general purpose USB host controller: it supports one control/bulk-style
// transaction at a time and full-/low-speed devices without a hub.

module usb_mouse_host (
    input             aclk,
    input             aresetn,

    input      [3:0]  s_awid,
    input      [31:0] s_awaddr,
    input      [3:0]  s_awlen,
    input      [2:0]  s_awsize,
    input      [1:0]  s_awburst,
    input      [1:0]  s_awlock,
    input      [3:0]  s_awcache,
    input      [2:0]  s_awprot,
    input             s_awvalid,
    output            s_awready,

    input      [3:0]  s_wid,
    input      [31:0] s_wdata,
    input      [3:0]  s_wstrb,
    input             s_wlast,
    input             s_wvalid,
    output reg        s_wready,

    output     [3:0]  s_bid,
    output     [1:0]  s_bresp,
    output reg        s_bvalid,
    input             s_bready,

    input      [3:0]  s_arid,
    input      [31:0] s_araddr,
    input      [3:0]  s_arlen,
    input      [2:0]  s_arsize,
    input      [1:0]  s_arburst,
    input      [1:0]  s_arlock,
    input      [3:0]  s_arcache,
    input      [2:0]  s_arprot,
    input             s_arvalid,
    output            s_arready,

    output     [3:0]  s_rid,
    output reg [31:0] s_rdata,
    output     [1:0]  s_rresp,
    output reg        s_rlast,
    output reg        s_rvalid,
    input             s_rready,

    input             usb_clk,
    input      [7:0]  utmi_data_i,
    output     [7:0]  utmi_data_o,
    output            utmi_data_oe,
    output     [7:0]  utmi_data_t,
    output            utmi_txvalid,
    input             utmi_txready,
    input             utmi_rxvalid,
    input             utmi_rxactive,
    input             utmi_rxerror,
    input      [1:0]  utmi_linestate,

    output     [1:0]  utmi_xcvrsel,
    output            utmi_termsel,
    output     [1:0]  utmi_opmode,
    output            utmi_suspendn,
    output            utmi_reset,
    output            utmi_dppd,
    output            utmi_dmpd,
    output            utmi_chrgvbus,
    output            utmi_dischrgvbus,
    output            utmi_idpullup,

    input             utmi_vbusvld,
    input             utmi_sessvld,
    input             utmi_sessend,
    input             utmi_hostdisc,
    input             utmi_iddig,

    output            usb_int
);

localparam [7:0] REG_CONTROL = 8'h00;
localparam [7:0] REG_STATUS  = 8'h04;
localparam [7:0] REG_TOKEN   = 8'h08;
localparam [7:0] REG_IRQ     = 8'h0c;
localparam [7:0] REG_VERSION = 8'h10;
localparam [7:0] REG_PHY     = 8'h14;
localparam [7:0] REG_DEBUG   = 8'h18;
localparam [7:0] REG_TRACE   = 8'h1c;

localparam [2:0] IRQ_XFER    = 3'b001;
localparam [2:0] IRQ_RESET   = 3'b010;
localparam [2:0] IRQ_CONNECT = 3'b100;

reg host_enable;
reg irq_enable;
reg [31:0] token_reg;
reg [2:0] irq_status;
reg xfer_req_toggle;
reg reset_req_toggle;

// Buffers deliberately have one owner in each clock domain while a transfer
// is active.  The request/completion toggle is the ownership barrier.
reg [7:0] tx_buffer [0:63];
wire [511:0] tx_buffer_flat;
wire [7:0] rx_buffer_data;
wire [5:0] rx_buffer_addr;
wire [7:0] engine_utmi_data_o;
wire [7:0] engine_utmi_data_t;
wire engine_utmi_txvalid;
wire [7:0] engine_debug_tx_byte;
wire engine_debug_tx_accept;
wire engine_debug_tx_active;

// The engine registers are the sole UTMI transmit stage and are explicitly
// packed into the IOBs.  Adding another rising-edge stage here breaks UTMI:
// USB3500 may assert TXREADY on consecutive clocks, and the extra stage then
// repeats one byte while the engine advances to the following byte.
assign utmi_data_o = engine_utmi_data_o;
assign utmi_data_t = engine_utmi_data_t;
assign utmi_data_oe = engine_utmi_txvalid;
assign utmi_txvalid = engine_utmi_txvalid;

generate
    genvar tx_flat_index;
    for (tx_flat_index = 0; tx_flat_index < 64; tx_flat_index = tx_flat_index + 1) begin: flatten_tx_buffer
        assign tx_buffer_flat[tx_flat_index * 8 +: 8] = tx_buffer[tx_flat_index];
    end
endgenerate

wire engine_busy_usb;
wire engine_connected_usb;
wire engine_low_speed_usb;
wire engine_phy_ready_usb;
wire [3:0] engine_result_usb;
wire [6:0] engine_rx_len_usb;
wire xfer_done_toggle_usb;
wire reset_done_toggle_usb;
wire connect_toggle_usb;
wire [31:0] engine_debug_usb;
wire engine_trace_arm_usb;

// Capture the bytes which were present on the registered UTMI bus when the
// PHY asserted TXREADY.  Only CPU-requested transfers are armed, so periodic
// SOF packets cannot overwrite the diagnostic record.  LINESTATE activity
// is also recorded while TXVALID is asserted; this distinguishes a PHY that
// accepts parallel bytes from one that actually changes D+/D-.
reg [1:0] trace_linestate_sampled;
reg [1:0] trace_linestate_d;
reg trace_arm_d;
reg trace_line_activity;
reg [4:0] trace_count;
reg [7:0] tx_trace [0:15];
integer trace_reset_index;

always @(negedge usb_clk or negedge aresetn) begin
    if (!aresetn) begin
        trace_linestate_sampled <= 2'b00;
    end else begin
        trace_linestate_sampled <= utmi_linestate;
    end
end

always @(posedge usb_clk) begin
    if (!aresetn) begin
        trace_arm_d <= 1'b0;
        trace_line_activity <= 1'b0;
        trace_count <= 5'd0;
        trace_linestate_d <= 2'b00;
        for (trace_reset_index = 0; trace_reset_index < 16;
             trace_reset_index = trace_reset_index + 1)
            tx_trace[trace_reset_index] <= 8'd0;
    end else begin
        trace_arm_d <= engine_trace_arm_usb;
        if (engine_trace_arm_usb && !trace_arm_d) begin
            trace_line_activity <= 1'b0;
            trace_count <= 5'd0;
            trace_linestate_d <= trace_linestate_sampled;
            for (trace_reset_index = 0; trace_reset_index < 16;
                 trace_reset_index = trace_reset_index + 1)
                tx_trace[trace_reset_index] <= 8'd0;
        end else if (engine_trace_arm_usb) begin
            if (engine_debug_tx_active) begin
                if (trace_linestate_sampled != trace_linestate_d)
                    trace_line_activity <= 1'b1;
                trace_linestate_d <= trace_linestate_sampled;
            end
            if (engine_debug_tx_accept && trace_count < 5'd16) begin
                tx_trace[trace_count[3:0]] <= engine_debug_tx_byte;
                trace_count <= trace_count + 5'd1;
            end
        end
    end
end

(* ASYNC_REG = "TRUE" *) reg [1:0] busy_sync;
(* ASYNC_REG = "TRUE" *) reg [1:0] connected_sync;
(* ASYNC_REG = "TRUE" *) reg [1:0] speed_sync;
(* ASYNC_REG = "TRUE" *) reg [1:0] phy_ready_sync;
(* ASYNC_REG = "TRUE" *) reg [1:0] done_sync;
(* ASYNC_REG = "TRUE" *) reg [1:0] reset_done_sync;
(* ASYNC_REG = "TRUE" *) reg [1:0] connect_sync;
reg done_seen, reset_done_seen, connect_seen;
reg [3:0] result_sync_1, result_sync_2;
reg [6:0] rx_len_sync_1, rx_len_sync_2;
reg [1:0] linestate_sync_1, linestate_sync_2;

always @(posedge aclk) begin
    if (!aresetn) begin
        busy_sync       <= 2'b00;
        connected_sync  <= 2'b00;
        speed_sync      <= 2'b00;
        phy_ready_sync  <= 2'b00;
        done_sync       <= 2'b00;
        reset_done_sync <= 2'b00;
        connect_sync    <= 2'b00;
        done_seen       <= 1'b0;
        reset_done_seen <= 1'b0;
        connect_seen    <= 1'b0;
        result_sync_1   <= 4'd0;
        result_sync_2   <= 4'd0;
        rx_len_sync_1   <= 7'd0;
        rx_len_sync_2   <= 7'd0;
        linestate_sync_1 <= 2'b00;
        linestate_sync_2 <= 2'b00;
    end else begin
        busy_sync       <= {busy_sync[0], engine_busy_usb};
        connected_sync  <= {connected_sync[0], engine_connected_usb};
        speed_sync      <= {speed_sync[0], engine_low_speed_usb};
        phy_ready_sync  <= {phy_ready_sync[0], engine_phy_ready_usb};
        done_sync       <= {done_sync[0], xfer_done_toggle_usb};
        reset_done_sync <= {reset_done_sync[0], reset_done_toggle_usb};
        connect_sync    <= {connect_sync[0], connect_toggle_usb};
        result_sync_1   <= engine_result_usb;
        result_sync_2   <= result_sync_1;
        rx_len_sync_1   <= engine_rx_len_usb;
        rx_len_sync_2   <= rx_len_sync_1;
        linestate_sync_1 <= utmi_linestate;
        linestate_sync_2 <= linestate_sync_1;
        done_seen       <= done_sync[1];
        reset_done_seen <= reset_done_sync[1];
        connect_seen    <= connect_sync[1];
    end
end

wire xfer_done_event = done_sync[1] != done_seen;
wire reset_done_event = reset_done_sync[1] != reset_done_seen;
wire connect_event = connect_sync[1] != connect_seen;

// Simple one-beat AXI slave.  The SoC only performs 32-bit single accesses to
// this register bank; unsupported bursts still terminate normally.
reg axi_busy;
reg axi_read;
reg [3:0] axi_id;
reg [31:0] axi_addr;

wire ar_accept = s_arvalid && s_arready;
wire aw_accept = s_awvalid && s_awready;
wire w_accept  = s_wvalid && s_wready;

assign s_arready = !axi_busy;
assign s_awready = !axi_busy && !s_arvalid;
assign s_bid = axi_id;
assign s_bresp = 2'b00;
assign s_rid = axi_id;
assign s_rresp = 2'b00;

integer byte_index;
reg [31:0] read_word;
wire [7:0] rx_buffer_data_next1;
wire [7:0] rx_buffer_data_next2;
wire [7:0] rx_buffer_data_next3;
always @(*) begin
    read_word = 32'd0;
    case (axi_addr[7:0])
        REG_CONTROL: read_word = {30'd0, irq_enable, host_enable};
        REG_STATUS: read_word = {
            14'd0, linestate_sync_2, 1'b0, rx_len_sync_2,
            result_sync_2, phy_ready_sync[1], busy_sync[1],
            speed_sync[1], connected_sync[1]
        };
        REG_TOKEN: read_word = token_reg;
        REG_IRQ: read_word = {29'd0, irq_status};
        REG_VERSION: read_word = 32'h554d_0105; // "UM", revision 1.5
        REG_PHY: read_word = {
            23'd0, utmi_iddig, utmi_hostdisc, utmi_sessend,
            utmi_sessvld, utmi_vbusvld, utmi_rxerror,
            utmi_rxactive, utmi_rxvalid, utmi_txready
        };
        REG_DEBUG: read_word = engine_debug_usb;
        REG_TRACE: read_word = {
            23'd0, trace_line_activity, 3'd0, trace_count
        };
        default: begin
            if (axi_addr[7:6] == 2'b10) begin
                read_word[7:0]   = rx_buffer_data;
                read_word[15:8]  = (axi_addr[5:0] <= 6'd60) ?
                                    rx_buffer_data_next1 : 8'd0;
                read_word[23:16] = (axi_addr[5:0] <= 6'd60) ?
                                    rx_buffer_data_next2 : 8'd0;
                read_word[31:24] = (axi_addr[5:0] <= 6'd60) ?
                                    rx_buffer_data_next3 : 8'd0;
            end else if (axi_addr[7:4] == 4'hc) begin
                read_word[7:0]   = tx_trace[axi_addr[3:0]];
                read_word[15:8]  = tx_trace[axi_addr[3:0] + 4'd1];
                read_word[23:16] = tx_trace[axi_addr[3:0] + 4'd2];
                read_word[31:24] = tx_trace[axi_addr[3:0] + 4'd3];
            end
        end
    endcase
end

assign rx_buffer_addr = axi_addr[5:0];

always @(posedge aclk) begin
    if (!aresetn) begin
        axi_busy <= 1'b0;
        axi_read <= 1'b0;
        axi_id <= 4'd0;
        axi_addr <= 32'd0;
        s_wready <= 1'b0;
        s_bvalid <= 1'b0;
        s_rvalid <= 1'b0;
        s_rlast <= 1'b0;
        s_rdata <= 32'd0;
        host_enable <= 1'b0;
        irq_enable <= 1'b0;
        token_reg <= 32'd0;
        irq_status <= 3'd0;
        xfer_req_toggle <= 1'b0;
        reset_req_toggle <= 1'b0;
    end else begin
        if (xfer_done_event)
            irq_status <= irq_status | IRQ_XFER;
        if (reset_done_event)
            irq_status <= irq_status | IRQ_RESET;
        if (connect_event)
            irq_status <= irq_status | IRQ_CONNECT;

        if (ar_accept) begin
            axi_busy <= 1'b1;
            axi_read <= 1'b1;
            axi_id <= s_arid;
            axi_addr <= s_araddr;
        end else if (aw_accept) begin
            axi_busy <= 1'b1;
            axi_read <= 1'b0;
            axi_id <= s_awid;
            axi_addr <= s_awaddr;
            s_wready <= 1'b1;
        end

        if (axi_busy && axi_read && !s_rvalid) begin
            s_rdata <= read_word;
            s_rvalid <= 1'b1;
            s_rlast <= 1'b1;
        end
        if (s_rvalid && s_rready) begin
            s_rvalid <= 1'b0;
            s_rlast <= 1'b0;
            axi_busy <= 1'b0;
        end

        if (w_accept) begin
            s_wready <= 1'b0;
            case (axi_addr[7:0])
                REG_CONTROL: begin
                    if (s_wstrb[0]) begin
                        host_enable <= s_wdata[0];
                        irq_enable <= s_wdata[1];
                        if (s_wdata[2] && !busy_sync[1])
                            xfer_req_toggle <= !xfer_req_toggle;
                        if (s_wdata[3] && !busy_sync[1])
                            reset_req_toggle <= !reset_req_toggle;
                    end
                end
                REG_TOKEN: begin
                    if (s_wstrb[0]) token_reg[7:0] <= s_wdata[7:0];
                    if (s_wstrb[1]) token_reg[15:8] <= s_wdata[15:8];
                    if (s_wstrb[2]) token_reg[23:16] <= s_wdata[23:16];
                    if (s_wstrb[3]) token_reg[31:24] <= s_wdata[31:24];
                end
                REG_IRQ: begin
                    if (s_wstrb[0]) irq_status <= irq_status & ~s_wdata[2:0];
                end
                default: begin
                    if (axi_addr[7:6] == 2'b01) begin
                        byte_index = axi_addr[5:0];
                        if (s_wstrb[0]) tx_buffer[byte_index] <= s_wdata[7:0];
                        if (s_wstrb[1] && byte_index <= 60)
                            tx_buffer[byte_index + 1] <= s_wdata[15:8];
                        if (s_wstrb[2] && byte_index <= 60)
                            tx_buffer[byte_index + 2] <= s_wdata[23:16];
                        if (s_wstrb[3] && byte_index <= 60)
                            tx_buffer[byte_index + 3] <= s_wdata[31:24];
                    end
                end
            endcase
            s_bvalid <= 1'b1;
        end
        if (s_bvalid && s_bready) begin
            s_bvalid <= 1'b0;
            axi_busy <= 1'b0;
        end
    end
end

assign usb_int = irq_enable && (|irq_status);

usb_utmi_packet_engine u_engine (
    .usb_clk(usb_clk),
    .aresetn(aresetn),
    .host_enable_async(host_enable),
    .xfer_req_toggle_async(xfer_req_toggle),
    .reset_req_toggle_async(reset_req_toggle),
    .command_async(token_reg),
    .tx_buffer_flat(tx_buffer_flat),
    .rx_read_addr(rx_buffer_addr),
    .rx_read_data(rx_buffer_data),
    .rx_read_data_next1(rx_buffer_data_next1),
    .rx_read_data_next2(rx_buffer_data_next2),
    .rx_read_data_next3(rx_buffer_data_next3),
    .busy(engine_busy_usb),
    .connected(engine_connected_usb),
    .low_speed(engine_low_speed_usb),
    .phy_ready(engine_phy_ready_usb),
    .result(engine_result_usb),
    .rx_length(engine_rx_len_usb),
    .xfer_done_toggle(xfer_done_toggle_usb),
    .reset_done_toggle(reset_done_toggle_usb),
    .connect_toggle(connect_toggle_usb),
    .debug_word(engine_debug_usb),
    .debug_trace_arm(engine_trace_arm_usb),
    .debug_tx_byte(engine_debug_tx_byte),
    .debug_tx_accept(engine_debug_tx_accept),
    .debug_tx_active(engine_debug_tx_active),
    .utmi_data_i(utmi_data_i),
    .utmi_data_o(engine_utmi_data_o),
    .utmi_data_t(engine_utmi_data_t),
    .utmi_txvalid(engine_utmi_txvalid),
    .utmi_txready(utmi_txready),
    .utmi_rxvalid(utmi_rxvalid),
    .utmi_rxactive(utmi_rxactive),
    .utmi_rxerror(utmi_rxerror),
    .utmi_linestate(utmi_linestate),
    .utmi_xcvrsel(utmi_xcvrsel),
    .utmi_termsel(utmi_termsel),
    .utmi_opmode(utmi_opmode),
    .utmi_suspendn(utmi_suspendn),
    .utmi_reset(utmi_reset),
    .utmi_dppd(utmi_dppd),
    .utmi_dmpd(utmi_dmpd),
    .utmi_chrgvbus(utmi_chrgvbus),
    .utmi_dischrgvbus(utmi_dischrgvbus),
    .utmi_idpullup(utmi_idpullup)
);

endmodule


module usb_utmi_packet_engine (
    input             usb_clk,
    input             aresetn,
    input             host_enable_async,
    input             xfer_req_toggle_async,
    input             reset_req_toggle_async,
    input      [31:0] command_async,
    input      [511:0] tx_buffer_flat,
    input      [5:0]  rx_read_addr,
    output     [7:0]  rx_read_data,
    output     [7:0]  rx_read_data_next1,
    output     [7:0]  rx_read_data_next2,
    output     [7:0]  rx_read_data_next3,
    output reg        busy,
    output reg        connected,
    output reg        low_speed,
    output reg        phy_ready,
    output reg [3:0]  result,
    output reg [6:0]  rx_length,
    output reg        xfer_done_toggle,
    output reg        reset_done_toggle,
    output reg        connect_toggle,
    output     [31:0] debug_word,
    output            debug_trace_arm,
    output     [7:0]  debug_tx_byte,
    output            debug_tx_accept,
    output            debug_tx_active,
    input      [7:0]  utmi_data_i,
    (* IOB = "TRUE", DONT_TOUCH = "TRUE" *) output reg [7:0] utmi_data_o,
    (* IOB = "TRUE", DONT_TOUCH = "TRUE" *) output reg [7:0] utmi_data_t,
    (* IOB = "TRUE", DONT_TOUCH = "TRUE" *) output reg utmi_txvalid,
    input             utmi_txready,
    input             utmi_rxvalid,
    input             utmi_rxactive,
    input             utmi_rxerror,
    input      [1:0]  utmi_linestate,
    output reg [1:0]  utmi_xcvrsel,
    output reg        utmi_termsel,
    output     [1:0]  utmi_opmode,
    output            utmi_suspendn,
    output reg        utmi_reset,
    output            utmi_dppd,
    output            utmi_dmpd,
    output            utmi_chrgvbus,
    output            utmi_dischrgvbus,
    output            utmi_idpullup
);

localparam [7:0] PID_OUT   = 8'he1;
localparam [7:0] PID_IN    = 8'h69;
localparam [7:0] PID_SOF   = 8'ha5;
localparam [7:0] PID_SETUP = 8'h2d;
localparam [7:0] PID_DATA0 = 8'hc3;
localparam [7:0] PID_DATA1 = 8'h4b;
localparam [7:0] PID_ACK   = 8'hd2;
localparam [7:0] PID_NAK   = 8'h5a;
localparam [7:0] PID_STALL = 8'h1e;

localparam [3:0] RES_OK       = 4'd0;
localparam [3:0] RES_NAK      = 4'd1;
localparam [3:0] RES_STALL    = 4'd2;
localparam [3:0] RES_TIMEOUT  = 4'd3;
localparam [3:0] RES_CRC      = 4'd4;
localparam [3:0] RES_PID      = 4'd5;
localparam [3:0] RES_OVERFLOW = 4'd6;
localparam [3:0] RES_NODEV    = 4'd7;

localparam [5:0] ST_DISABLED       = 6'd0;
localparam [5:0] ST_PHY_START      = 6'd1;
localparam [5:0] ST_IDLE           = 6'd2;
localparam [5:0] ST_PORT_RESET     = 6'd3;
localparam [5:0] ST_PORT_RECOVER   = 6'd4;
localparam [5:0] ST_TX             = 6'd5;
localparam [5:0] ST_GAP            = 6'd6;
localparam [5:0] ST_RX_WAIT        = 6'd7;
localparam [5:0] ST_RX_PACKET      = 6'd8;
localparam [5:0] ST_RX_END         = 6'd9;
localparam [5:0] ST_COMPLETE       = 6'd10;
localparam [5:0] ST_XFER_PREP      = 6'd11;
localparam [5:0] ST_RX_ACK_GAP     = 6'd12;

localparam [1:0] SEND_TOKEN = 2'd0;
localparam [1:0] SEND_DATA  = 2'd1;
localparam [1:0] SEND_ACK   = 2'd2;
localparam [1:0] SEND_SOF   = 2'd3;

localparam [1:0] AFTER_TOKEN = 2'd0;
localparam [1:0] AFTER_DATA  = 2'd1;
localparam [1:0] AFTER_ACK   = 2'd2;
localparam [1:0] AFTER_SOF   = 2'd3;

function [4:0] usb_crc5;
    input [10:0] value;
    integer i;
    reg [4:0] crc;
    reg feedback;
    begin
        crc = 5'h1f;
        for (i = 0; i < 11; i = i + 1) begin
            feedback = value[i] ^ crc[0];
            crc = crc >> 1;
            if (feedback)
                crc = crc ^ 5'h14;
        end
        usb_crc5 = ~crc;
    end
endfunction

function [15:0] usb_crc16_byte;
    input [15:0] crc_in;
    input [7:0] value;
    integer i;
    reg [15:0] crc;
    reg feedback;
    begin
        crc = crc_in;
        for (i = 0; i < 8; i = i + 1) begin
            feedback = value[i] ^ crc[0];
            crc = crc >> 1;
            if (feedback)
                crc = crc ^ 16'ha001;
        end
        usb_crc16_byte = crc;
    end
endfunction

reg [7:0] rx_buffer [0:63];
reg rx_buffer_write;
reg [5:0] rx_buffer_write_addr;
reg [7:0] rx_buffer_write_data;
assign rx_read_data = rx_buffer[rx_read_addr];
assign rx_read_data_next1 = rx_buffer[rx_read_addr + 6'd1];
assign rx_read_data_next2 = rx_buffer[rx_read_addr + 6'd2];
assign rx_read_data_next3 = rx_buffer[rx_read_addr + 6'd3];

always @(posedge usb_clk) begin
    if (rx_buffer_write)
        rx_buffer[rx_buffer_write_addr] <= rx_buffer_write_data;
end

(* ASYNC_REG = "TRUE" *) reg [1:0] enable_sync;
(* ASYNC_REG = "TRUE" *) reg [1:0] request_sync;
(* ASYNC_REG = "TRUE" *) reg [1:0] reset_request_sync;
reg request_seen, reset_request_seen;

reg [5:0] state;
reg [6:0] address;
reg [3:0] endpoint;
reg [1:0] transfer_type;
reg data_toggle;
reg [6:0] tx_length;
reg [6:0] rx_max;
reg [10:0] token_value;
reg [4:0] token_crc;
reg [15:0] tx_crc;
reg [1:0] send_kind;
reg [1:0] after_send;
reg [6:0] tx_index;
reg [6:0] tx_total;
reg [7:0] data_pid;
reg [20:0] timer;
reg [16:0] timeout_count;
reg [15:0] frame_divider;
reg [10:0] frame_number;
reg frame_pending;
reg [1:0] line_candidate;
reg [15:0] line_stable_count;
reg rxactive_d;
reg [7:0] rx_pid;
reg [7:0] rx_tail0, rx_tail1;
reg [6:0] rx_after_pid_count;
reg [6:0] rx_payload_count;
reg [15:0] rx_crc;
reg rx_fault;
reg rx_overflow;
reg awaiting_handshake;
reg completing_xfer;
reg [6:0] tx_crc_count;
reg [15:0] tx_crc_work;
reg [7:0] debug_tx_packets;
reg [7:0] debug_rx_packets;
reg debug_txready_seen;
reg debug_rxactive_seen;
reg debug_rxvalid_seen;
reg debug_rxerror_seen;
reg debug_token_eop_seen;
reg [7:0] debug_tx_byte_r;
reg tx_eop_seen;

// USB3500 drives its receive-side UTMI signals 2--5 ns after the rising
// edge of CLKOUT.  Sampling them in the main rising-edge state machine puts
// the FPGA capture edge inside that output-delay window.  Latch the complete
// PHY input bundle on the falling edge, after it has settled, then consume
// the samples on the following rising edge.
reg [7:0] utmi_data_i_sampled;
reg       utmi_txready_sampled;
reg       utmi_rxvalid_sampled;
reg       utmi_rxactive_sampled;
reg       utmi_rxerror_sampled;
reg [1:0] utmi_linestate_sampled;

always @(negedge usb_clk or negedge aresetn) begin
    if (!aresetn) begin
        utmi_data_i_sampled   <= 8'd0;
        utmi_txready_sampled  <= 1'b0;
        utmi_rxvalid_sampled  <= 1'b0;
        utmi_rxactive_sampled <= 1'b0;
        utmi_rxerror_sampled  <= 1'b0;
        utmi_linestate_sampled <= 2'b00;
    end else begin
        utmi_data_i_sampled   <= utmi_data_i;
        utmi_txready_sampled  <= utmi_txready;
        utmi_rxvalid_sampled  <= utmi_rxvalid;
        utmi_rxactive_sampled <= utmi_rxactive;
        utmi_rxerror_sampled  <= utmi_rxerror;
        utmi_linestate_sampled <= utmi_linestate;
    end
end

assign debug_word = {
    debug_tx_packets, debug_rx_packets, 2'b00, state,
    3'b000, debug_token_eop_seen, debug_rxerror_seen, debug_rxvalid_seen,
    debug_rxactive_seen, debug_txready_seen
};
assign debug_trace_arm = completing_xfer;
assign debug_tx_byte = debug_tx_byte_r;
assign debug_tx_accept = (state == ST_TX) && utmi_txready_sampled;
assign debug_tx_active = (state == ST_TX);

wire request_event = request_sync[1] != request_seen;
wire reset_request_event = reset_request_sync[1] != reset_request_seen;
// TXREADY only means that a byte entered the PHY holding register.  The PHY
// may accept an entire short token in consecutive clocks and serialize it
// much later.  Therefore token-to-DATA timing starts only after LINESTATE
// exposes the transmitted EOP (SE0 followed by the speed-specific J state).
wire [15:0] interpacket_cycles = low_speed ? 16'd80 : 16'd10;
wire [1:0] bus_idle_state = low_speed ? 2'b10 : 2'b01;
// RXACTIVE falls after the received EOP, so only the two-bit response delay
// remains before the host ACK handshake.
wire [15:0] rx_to_ack_cycles = low_speed ? 16'd80 : 16'd10;

assign utmi_opmode = 2'b00;
// Keep the PHY awake independently of usb_clk.  SUSPENDN=0 stops the
// USB3500 CLKOUT, so deriving this signal from enable_sync would deadlock:
// enable_sync itself can only advance on CLKOUT.  This minimal host does not
// implement runtime PHY power management and therefore leaves SUSPENDN high.
assign utmi_suspendn = 1'b1;
assign utmi_dppd = enable_sync[1];
assign utmi_dmpd = enable_sync[1];
assign utmi_chrgvbus = 1'b0;
assign utmi_dischrgvbus = 1'b0;
assign utmi_idpullup = 1'b0;

task start_send;
    input [1:0] kind;
    input [1:0] next_action;
    begin
        send_kind <= kind;
        after_send <= next_action;
        tx_index <= 7'd0;
        case (kind)
            SEND_TOKEN: begin
                tx_total <= 7'd3;
                utmi_data_o <= (transfer_type == 2'd0) ? PID_SETUP :
                               (transfer_type == 2'd1) ? PID_OUT : PID_IN;
                debug_tx_byte_r <= (transfer_type == 2'd0) ? PID_SETUP :
                                   (transfer_type == 2'd1) ? PID_OUT : PID_IN;
            end
            SEND_DATA: begin
                tx_total <= tx_length + 7'd3;
                utmi_data_o <= data_pid;
                debug_tx_byte_r <= data_pid;
            end
            SEND_ACK: begin
                tx_total <= 7'd1;
                utmi_data_o <= PID_ACK;
                debug_tx_byte_r <= PID_ACK;
            end
            default: begin
                tx_total <= low_speed ? 7'd1 : 7'd3;
                utmi_data_o <= PID_SOF;
                debug_tx_byte_r <= PID_SOF;
            end
        endcase
        utmi_txvalid <= 1'b1;
        utmi_data_t <= 8'h00;
        tx_eop_seen <= 1'b0;
        state <= ST_TX;
    end
endtask

always @(posedge usb_clk or negedge aresetn) begin
    if (!aresetn) begin
        enable_sync <= 2'b00;
        request_sync <= 2'b00;
        reset_request_sync <= 2'b00;
    end else begin
        enable_sync <= {enable_sync[0], host_enable_async};
        request_sync <= {request_sync[0], xfer_req_toggle_async};
        reset_request_sync <= {reset_request_sync[0], reset_req_toggle_async};
    end
end

always @(posedge usb_clk or negedge aresetn) begin
    if (!aresetn) begin
        state <= ST_DISABLED;
        busy <= 1'b0;
        connected <= 1'b0;
        low_speed <= 1'b0;
        phy_ready <= 1'b0;
        result <= RES_OK;
        rx_length <= 7'd0;
        xfer_done_toggle <= 1'b0;
        reset_done_toggle <= 1'b0;
        connect_toggle <= 1'b0;
        request_seen <= 1'b0;
        reset_request_seen <= 1'b0;
        utmi_data_o <= 8'd0;
        utmi_data_t <= 8'hff;
        utmi_txvalid <= 1'b0;
        utmi_xcvrsel <= 2'b01;
        utmi_termsel <= 1'b1;
        utmi_reset <= 1'b1;
        timer <= 21'd0;
        timeout_count <= 17'd0;
        frame_divider <= 16'd0;
        frame_number <= 11'd0;
        frame_pending <= 1'b0;
        line_candidate <= 2'b00;
        line_stable_count <= 16'd0;
        rxactive_d <= 1'b0;
        rx_pid <= 8'd0;
        rx_tail0 <= 8'd0;
        rx_tail1 <= 8'd0;
        rx_after_pid_count <= 7'd0;
        rx_payload_count <= 7'd0;
        rx_crc <= 16'hffff;
        rx_fault <= 1'b0;
        rx_overflow <= 1'b0;
        awaiting_handshake <= 1'b0;
        completing_xfer <= 1'b0;
        address <= 7'd0;
        endpoint <= 4'd0;
        transfer_type <= 2'd0;
        data_toggle <= 1'b0;
        tx_length <= 7'd0;
        rx_max <= 7'd0;
        token_value <= 11'd0;
        token_crc <= 5'd0;
        tx_crc <= 16'd0;
        send_kind <= SEND_TOKEN;
        after_send <= AFTER_TOKEN;
        tx_index <= 7'd0;
        tx_total <= 7'd0;
        data_pid <= PID_DATA0;
        tx_crc_count <= 7'd0;
        tx_crc_work <= 16'hffff;
        debug_tx_packets <= 8'd0;
        debug_rx_packets <= 8'd0;
        debug_txready_seen <= 1'b0;
        debug_rxactive_seen <= 1'b0;
        debug_rxvalid_seen <= 1'b0;
        debug_rxerror_seen <= 1'b0;
        debug_token_eop_seen <= 1'b0;
        debug_tx_byte_r <= 8'd0;
        tx_eop_seen <= 1'b0;
        rx_buffer_write <= 1'b0;
        rx_buffer_write_addr <= 6'd0;
        rx_buffer_write_data <= 8'd0;
    end else begin
        rxactive_d <= utmi_rxactive_sampled;
        rx_buffer_write <= 1'b0;

        if (utmi_txready_sampled)
            debug_txready_seen <= 1'b1;
        if (utmi_rxactive_sampled)
            debug_rxactive_seen <= 1'b1;
        if (utmi_rxvalid_sampled)
            debug_rxvalid_seen <= 1'b1;
        if (utmi_rxerror_sampled)
            debug_rxerror_seen <= 1'b1;

        if (!enable_sync[1]) begin
            state <= ST_DISABLED;
            busy <= 1'b0;
            connected <= 1'b0;
            phy_ready <= 1'b0;
            utmi_reset <= 1'b1;
            utmi_txvalid <= 1'b0;
            utmi_data_t <= 8'hff;
            utmi_xcvrsel <= 2'b01;
            utmi_termsel <= 1'b1;
            timer <= 21'd0;
            frame_divider <= 16'd0;
            line_stable_count <= 16'd0;
            debug_tx_packets <= 8'd0;
            debug_rx_packets <= 8'd0;
            debug_txready_seen <= 1'b0;
            debug_rxactive_seen <= 1'b0;
            debug_rxvalid_seen <= 1'b0;
            debug_rxerror_seen <= 1'b0;
            debug_token_eop_seen <= 1'b0;
            request_seen <= request_sync[1];
            reset_request_seen <= reset_request_sync[1];
        end else begin
            // One millisecond frame cadence at the USB3500 60 MHz CLKOUT.
            if (phy_ready && connected && state != ST_PORT_RESET) begin
                if (frame_divider == 16'd59999) begin
                    frame_divider <= 16'd0;
                    frame_pending <= 1'b1;
                end else begin
                    frame_divider <= frame_divider + 16'd1;
                end
            end else begin
                frame_divider <= 16'd0;
                frame_pending <= 1'b0;
            end

            // Debounce attach/detach for 1 ms.  During initial detection the
            // transceiver is in FS mode, where an LS idle appears as K (10).
            if (phy_ready && state != ST_PORT_RESET) begin
                if (utmi_linestate_sampled == line_candidate) begin
                    if (line_stable_count != 16'hffff)
                        line_stable_count <= line_stable_count + 16'd1;
                end else begin
                    line_candidate <= utmi_linestate_sampled;
                    line_stable_count <= 16'd0;
                end
                if (!connected && line_stable_count == 16'd59999 &&
                    line_candidate != 2'b00) begin
                    connected <= 1'b1;
                    low_speed <= (line_candidate == 2'b10);
                    utmi_xcvrsel <= (line_candidate == 2'b10) ? 2'b10 : 2'b01;
                    connect_toggle <= !connect_toggle;
                end else if (connected && line_stable_count == 16'd59999 &&
                             line_candidate == 2'b00 && state == ST_IDLE) begin
                    connected <= 1'b0;
                    low_speed <= 1'b0;
                    utmi_xcvrsel <= 2'b01;
                    connect_toggle <= !connect_toggle;
                end
            end

            case (state)
                ST_DISABLED: begin
                    utmi_reset <= 1'b1;
                    phy_ready <= 1'b0;
                    timer <= 21'd0;
                    state <= ST_PHY_START;
                end

                ST_PHY_START: begin
                    // RESET deassertion is synchronous to CLKOUT.  USB3500
                    // requires at least five CLKOUT edges before TXVALID.
                    utmi_reset <= 1'b0;
                    if (timer == 21'd63) begin
                        timer <= 21'd0;
                        phy_ready <= 1'b1;
                        state <= ST_IDLE;
                    end else begin
                        timer <= timer + 21'd1;
                    end
                end

                ST_IDLE: begin
                    busy <= 1'b0;
                    utmi_txvalid <= 1'b0;
                    utmi_data_t <= 8'hff;
                    timeout_count <= 17'd0;
                    if (reset_request_event) begin
                        reset_request_seen <= reset_request_sync[1];
                        busy <= 1'b1;
                        timer <= 21'd0;
                        utmi_xcvrsel <= 2'b00;
                        utmi_termsel <= 1'b0;
                        state <= ST_PORT_RESET;
                    end else if (request_event) begin
                        request_seen <= request_sync[1];
                        busy <= 1'b1;
                        completing_xfer <= 1'b1;
                        address <= command_async[6:0];
                        endpoint <= command_async[10:7];
                        transfer_type <= command_async[12:11];
                        data_toggle <= command_async[13];
                        tx_length <= command_async[22:16];
                        rx_max <= command_async[30:24];
                        tx_crc_count <= 7'd0;
                        tx_crc_work <= 16'hffff;
                        rx_length <= 7'd0;
                        result <= connected ? RES_OK : RES_NODEV;
                        if (!connected) begin
                            state <= ST_COMPLETE;
                        end else begin
                            state <= ST_XFER_PREP;
                        end
                    end else if (frame_pending) begin
                        frame_pending <= 1'b0;
                        token_value <= frame_number;
                        token_crc <= usb_crc5(frame_number);
                        completing_xfer <= 1'b0;
                        start_send(SEND_SOF, AFTER_SOF);
                    end
                end

                ST_XFER_PREP: begin
                    token_value <= {endpoint, address};
                    token_crc <= usb_crc5({endpoint, address});
                    data_pid <= data_toggle ? PID_DATA1 : PID_DATA0;
                    if (tx_crc_count < tx_length) begin
                        tx_crc_work <= usb_crc16_byte(
                            tx_crc_work,
                            tx_buffer_flat[tx_crc_count * 8 +: 8]
                        );
                        tx_crc_count <= tx_crc_count + 7'd1;
                    end else begin
                        tx_crc <= ~tx_crc_work;
                        start_send(SEND_TOKEN, AFTER_TOKEN);
                    end
                end

                ST_PORT_RESET: begin
                    // Selecting HS transceiver/termination without TXVALID
                    // drives SE0.  Hold it for 20 ms (USB requires >=10 ms).
                    if (timer == 21'd1199999) begin
                        timer <= 21'd0;
                        utmi_xcvrsel <= low_speed ? 2'b10 : 2'b01;
                        utmi_termsel <= 1'b1;
                        state <= ST_PORT_RECOVER;
                    end else begin
                        timer <= timer + 21'd1;
                    end
                end

                ST_PORT_RECOVER: begin
                    if (timer == 21'd599999) begin
                        timer <= 21'd0;
                        busy <= 1'b0;
                        reset_done_toggle <= !reset_done_toggle;
                        state <= ST_IDLE;
                    end else begin
                        timer <= timer + 21'd1;
                    end
                end

                ST_TX: begin
                    if (utmi_txready_sampled) begin
                        if (tx_index + 7'd1 == tx_total) begin
                            utmi_txvalid <= 1'b0;
                            utmi_data_t <= 8'hff;
                            if (debug_tx_packets != 8'hff)
                                debug_tx_packets <= debug_tx_packets + 8'd1;
                            timer <= 21'd0;
                            state <= ST_GAP;
                        end else begin
                            tx_index <= tx_index + 7'd1;
                            case (send_kind)
                                SEND_TOKEN: begin
                                    if (tx_index == 7'd0) begin
                                        utmi_data_o <= token_value[7:0];
                                        debug_tx_byte_r <= token_value[7:0];
                                    end else begin
                                        utmi_data_o <= {token_crc, token_value[10:8]};
                                        debug_tx_byte_r <= {token_crc, token_value[10:8]};
                                    end
                                end
                                SEND_DATA: begin
                                    if (tx_index < tx_length) begin
                                        utmi_data_o <= tx_buffer_flat[tx_index * 8 +: 8];
                                        debug_tx_byte_r <= tx_buffer_flat[tx_index * 8 +: 8];
                                    end else if (tx_index == tx_length) begin
                                        utmi_data_o <= tx_crc[7:0];
                                        debug_tx_byte_r <= tx_crc[7:0];
                                    end else begin
                                        utmi_data_o <= tx_crc[15:8];
                                        debug_tx_byte_r <= tx_crc[15:8];
                                    end
                                end
                                SEND_SOF: begin
                                    if (tx_index == 7'd0) begin
                                        utmi_data_o <= token_value[7:0];
                                        debug_tx_byte_r <= token_value[7:0];
                                    end else begin
                                        utmi_data_o <= {token_crc, token_value[10:8]};
                                        debug_tx_byte_r <= {token_crc, token_value[10:8]};
                                    end
                                end
                                default: begin
                                    utmi_data_o <= PID_ACK;
                                    debug_tx_byte_r <= PID_ACK;
                                end
                            endcase
                        end
                    end
                end

                ST_GAP: begin
                    // For SETUP/OUT, do not infer EOP completion from the
                    // final TXREADY.  USB3500 can queue several bytes before
                    // they appear on D+/D-.  Wait for the actual SE0 -> J
                    // sequence and then the two-bit inter-packet interval.
                    if (after_send == AFTER_TOKEN && transfer_type != 2'd2 &&
                        !tx_eop_seen) begin
                        timer <= 21'd0;
                        if (utmi_linestate_sampled == 2'b00) begin
                            tx_eop_seen <= 1'b1;
                            debug_token_eop_seen <= 1'b1;
                        end
                    end else if (after_send == AFTER_TOKEN &&
                                 transfer_type != 2'd2 &&
                                 utmi_linestate_sampled != bus_idle_state) begin
                        timer <= 21'd0;
                    end else if (after_send != AFTER_TOKEN ||
                                 transfer_type == 2'd2 ||
                                 timer >= {5'd0, interpacket_cycles}) begin
                        timer <= 21'd0;
                        case (after_send)
                            AFTER_TOKEN: begin
                                if (transfer_type == 2'd2) begin
                                    awaiting_handshake <= 1'b0;
                                    state <= ST_RX_WAIT;
                                end else begin
                                    start_send(SEND_DATA, AFTER_DATA);
                                end
                            end
                            AFTER_DATA: begin
                                awaiting_handshake <= 1'b1;
                                state <= ST_RX_WAIT;
                            end
                            AFTER_ACK: begin
                                result <= RES_OK;
                                state <= ST_COMPLETE;
                            end
                            default: begin
                                frame_number <= frame_number + 11'd1;
                                state <= ST_IDLE;
                            end
                        endcase
                    end else begin
                        timer <= timer + 21'd1;
                    end
                end

                ST_RX_WAIT: begin
                    if (utmi_rxactive_sampled) begin
                        rx_after_pid_count <= 7'd0;
                        rx_payload_count <= 7'd0;
                        rx_crc <= 16'hffff;
                        rx_fault <= 1'b0;
                        rx_overflow <= 1'b0;
                        timeout_count <= 17'd0;
                        if (debug_rx_packets != 8'hff)
                            debug_rx_packets <= debug_rx_packets + 8'd1;
                        state <= ST_RX_PACKET;
                    end else if (timeout_count == 17'd119999) begin
                        result <= RES_TIMEOUT;
                        state <= ST_COMPLETE;
                    end else begin
                        timeout_count <= timeout_count + 17'd1;
                    end
                end

                ST_RX_PACKET: begin
                    if (utmi_rxerror_sampled)
                        rx_fault <= 1'b1;
                    if (utmi_rxvalid_sampled) begin
                        if (rx_after_pid_count == 7'd0) begin
                            rx_pid <= utmi_data_i_sampled;
                            rx_after_pid_count <= 7'd1;
                        end else if (!awaiting_handshake) begin
                            if (rx_after_pid_count == 7'd1) begin
                                rx_tail0 <= utmi_data_i_sampled;
                            end else if (rx_after_pid_count == 7'd2) begin
                                rx_tail1 <= utmi_data_i_sampled;
                            end else begin
                                if (rx_payload_count < rx_max && rx_payload_count < 7'd64)
                                begin
                                    rx_buffer_write <= 1'b1;
                                    rx_buffer_write_addr <= rx_payload_count[5:0];
                                    rx_buffer_write_data <= rx_tail0;
                                end
                                else
                                    rx_overflow <= 1'b1;
                                rx_payload_count <= rx_payload_count + 7'd1;
                                rx_crc <= usb_crc16_byte(rx_crc, rx_tail0);
                                rx_tail0 <= rx_tail1;
                                rx_tail1 <= utmi_data_i_sampled;
                            end
                            rx_after_pid_count <= rx_after_pid_count + 7'd1;
                        end
                    end
                    if (rxactive_d && !utmi_rxactive_sampled)
                        state <= ST_RX_END;
                end

                ST_RX_END: begin
                    if (rx_fault) begin
                        result <= RES_CRC;
                        state <= ST_COMPLETE;
                    end else if (awaiting_handshake) begin
                        if (rx_pid == PID_ACK)
                            result <= RES_OK;
                        else if (rx_pid == PID_NAK)
                            result <= RES_NAK;
                        else if (rx_pid == PID_STALL)
                            result <= RES_STALL;
                        else
                            result <= RES_PID;
                        state <= ST_COMPLETE;
                    end else if (rx_pid == PID_NAK) begin
                        result <= RES_NAK;
                        state <= ST_COMPLETE;
                    end else if (rx_pid == PID_STALL) begin
                        result <= RES_STALL;
                        state <= ST_COMPLETE;
                    end else if (rx_pid != (data_toggle ? PID_DATA1 : PID_DATA0)) begin
                        result <= RES_PID;
                        state <= ST_COMPLETE;
                    end else if (rx_after_pid_count < 7'd3 ||
                                 rx_tail0 != ~rx_crc[7:0] ||
                                 rx_tail1 != ~rx_crc[15:8]) begin
                        result <= RES_CRC;
                        state <= ST_COMPLETE;
                    end else if (rx_overflow) begin
                        result <= RES_OVERFLOW;
                        state <= ST_COMPLETE;
                    end else begin
                        rx_length <= rx_payload_count;
                        timer <= 21'd0;
                        state <= ST_RX_ACK_GAP;
                    end
                end

                ST_RX_ACK_GAP: begin
                    if (timer >= {5'd0, rx_to_ack_cycles}) begin
                        timer <= 21'd0;
                        start_send(SEND_ACK, AFTER_ACK);
                    end else begin
                        timer <= timer + 21'd1;
                    end
                end

                ST_COMPLETE: begin
                    busy <= 1'b0;
                    if (completing_xfer) begin
                        xfer_done_toggle <= !xfer_done_toggle;
                        completing_xfer <= 1'b0;
                    end
                    state <= ST_IDLE;
                end

                default: state <= ST_DISABLED;
            endcase
        end
    end
end

endmodule
