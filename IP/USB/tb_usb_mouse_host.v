`timescale 1ns/1ps

module tb_usb_mouse_host;
reg aclk = 0;
reg usb_clk = 0;
reg aresetn = 0;
always #15 aclk = ~aclk;

// Model the USB3500 clock-stop behavior: CLKOUT is unavailable while the
// PHY is suspended.  This catches a circular dependency between SUSPENDN and
// logic which is itself clocked by CLKOUT.
always #8.333 begin
    if (utmi_suspendn === 1'b1)
        usb_clk = ~usb_clk;
    else
        usb_clk = 1'b0;
end

reg [3:0] awid = 0;
reg [31:0] awaddr = 0;
reg awvalid = 0;
wire awready;
reg [3:0] wid = 0;
reg [31:0] wdata = 0;
reg [3:0] wstrb = 4'hf;
reg wlast = 1;
reg wvalid = 0;
wire wready;
wire [3:0] bid;
wire [1:0] bresp;
wire bvalid;
reg bready = 1;
reg [3:0] arid = 0;
reg [31:0] araddr = 0;
reg arvalid = 0;
wire arready;
wire [3:0] rid;
wire [31:0] rdata;
wire [1:0] rresp;
wire rlast, rvalid;
reg rready = 1;

reg [7:0] utmi_data_i = 0;
wire [7:0] utmi_data_o;
wire utmi_data_oe, utmi_txvalid;
wire [7:0] utmi_data_t;
reg utmi_txready = 0;
reg utmi_rxvalid = 0;
reg utmi_rxactive = 0;
reg utmi_rxerror = 0;
reg [1:0] utmi_linestate = 0;
reg model_line_activity = 0;
reg model_line_toggle = 0;
reg line_txvalid_d = 0;
integer serial_tail_remaining = 0;
integer eop_remaining = 0;
integer eop_count = 0;
integer idle_after_eop_cycles = 0;
wire [1:0] utmi_xcvrsel, utmi_opmode;
wire utmi_termsel, utmi_suspendn, utmi_reset;
wire utmi_dppd, utmi_dmpd, utmi_chrgvbus, utmi_dischrgvbus;
wire utmi_idpullup, usb_int;

// A low-speed byte occupies 320 cycles of the 60 MHz UTMI clock.  The UTMI
// specification permits the PHY to accept several bytes on consecutive
// clocks at packet start, then throttle to one byte time.  Exercise three
// consecutive accepts so the short three-byte token exactly matches the
// behavior observed on the board.  An extra output pipeline repeats the PID
// and drops the final token byte in this case.
integer txready_divider = 0;
integer accepted_in_packet = 0;
always @(posedge usb_clk) begin
    if (!utmi_txvalid) begin
        utmi_txready <= 1'b0;
        txready_divider <= 0;
        accepted_in_packet <= 0;
    end else if (utmi_txready) begin
        accepted_in_packet <= accepted_in_packet + 1;
        if (accepted_in_packet < 2) begin
            utmi_txready <= 1'b1;
        end else begin
            utmi_txready <= 1'b0;
            txready_divider <= 319;
        end
    end else if (txready_divider == 0) begin
        utmi_txready <= 1'b1;
    end else begin
        utmi_txready <= 1'b0;
        txready_divider <= txready_divider - 1;
    end
end

// LINESTATE is an asynchronous view of D+/D-.  TXVALID can fall as soon as
// the last byte enters the PHY, while queued bytes are still being serialized.
// Keep the bus active well beyond TXVALID, then emit the low-speed EOP and J.
always @(negedge usb_clk) begin
    line_txvalid_d <= utmi_txvalid;
    if (model_line_activity && utmi_txvalid) begin
        model_line_toggle <= ~model_line_toggle;
        utmi_linestate <= model_line_toggle ? 2'b10 : 2'b01;
        serial_tail_remaining <= 0;
        eop_remaining <= 0;
    end else if (model_line_activity && line_txvalid_d) begin
        model_line_toggle <= ~model_line_toggle;
        utmi_linestate <= model_line_toggle ? 2'b10 : 2'b01;
        serial_tail_remaining <= 700;
        eop_remaining <= 80;
    end else if (model_line_activity && serial_tail_remaining != 0) begin
        model_line_toggle <= ~model_line_toggle;
        utmi_linestate <= model_line_toggle ? 2'b10 : 2'b01;
        serial_tail_remaining <= serial_tail_remaining - 1;
    end else if (model_line_activity && eop_remaining != 0) begin
        utmi_linestate <= 2'b00;
        eop_remaining <= eop_remaining - 1;
        idle_after_eop_cycles <= 0;
        if (eop_remaining == 1)
            eop_count <= eop_count + 1;
    end else if (model_line_activity) begin
        model_line_toggle <= 1'b0;
        utmi_linestate <= 2'b10;
        idle_after_eop_cycles <= idle_after_eop_cycles + 1;
    end
end

usb_mouse_host dut (
    .aclk(aclk), .aresetn(aresetn),
    .s_awid(awid), .s_awaddr(awaddr), .s_awlen(4'd0),
    .s_awsize(3'd2), .s_awburst(2'd1), .s_awlock(2'd0),
    .s_awcache(4'd0), .s_awprot(3'd0), .s_awvalid(awvalid),
    .s_awready(awready), .s_wid(wid), .s_wdata(wdata),
    .s_wstrb(wstrb), .s_wlast(wlast), .s_wvalid(wvalid),
    .s_wready(wready), .s_bid(bid), .s_bresp(bresp),
    .s_bvalid(bvalid), .s_bready(bready), .s_arid(arid),
    .s_araddr(araddr), .s_arlen(4'd0), .s_arsize(3'd2),
    .s_arburst(2'd1), .s_arlock(2'd0), .s_arcache(4'd0),
    .s_arprot(3'd0), .s_arvalid(arvalid), .s_arready(arready),
    .s_rid(rid), .s_rdata(rdata), .s_rresp(rresp), .s_rlast(rlast),
    .s_rvalid(rvalid), .s_rready(rready), .usb_clk(usb_clk),
    .utmi_data_i(utmi_data_i), .utmi_data_o(utmi_data_o),
    .utmi_data_oe(utmi_data_oe), .utmi_data_t(utmi_data_t),
    .utmi_txvalid(utmi_txvalid),
    .utmi_txready(utmi_txready), .utmi_rxvalid(utmi_rxvalid),
    .utmi_rxactive(utmi_rxactive), .utmi_rxerror(utmi_rxerror),
    .utmi_linestate(utmi_linestate), .utmi_xcvrsel(utmi_xcvrsel),
    .utmi_termsel(utmi_termsel), .utmi_opmode(utmi_opmode),
    .utmi_suspendn(utmi_suspendn), .utmi_reset(utmi_reset),
    .utmi_dppd(utmi_dppd), .utmi_dmpd(utmi_dmpd),
    .utmi_chrgvbus(utmi_chrgvbus), .utmi_dischrgvbus(utmi_dischrgvbus),
    .utmi_idpullup(utmi_idpullup), .utmi_vbusvld(1'b1),
    .utmi_sessvld(1'b1), .utmi_sessend(1'b0), .utmi_hostdisc(1'b0),
    .utmi_iddig(1'b1), .usb_int(usb_int)
);

task axi_write;
    input [31:0] addr;
    input [31:0] data;
    begin
        @(negedge aclk);
        awaddr = addr;
        awvalid = 1;
        while (!awready) @(negedge aclk);
        @(negedge aclk);
        awvalid = 0;
        wdata = data;
        wvalid = 1;
        while (!wready) @(negedge aclk);
        @(negedge aclk);
        wvalid = 0;
        while (!bvalid) @(negedge aclk);
        @(negedge aclk);
    end
endtask

task axi_read;
    input [31:0] addr;
    output [31:0] data;
    begin
        @(negedge aclk);
        araddr = addr;
        arvalid = 1;
        while (!arready) @(negedge aclk);
        @(negedge aclk);
        arvalid = 0;
        while (!rvalid) @(negedge aclk);
        data = rdata;
        @(negedge aclk);
    end
endtask

reg [7:0] captured [0:31];
integer captured_count = 0;
integer packet_count = 0;
reg txvalid_d = 0;
always @(posedge usb_clk) begin
    txvalid_d <= utmi_txvalid;
    if (utmi_txvalid && utmi_txready) begin
        captured[captured_count] <= utmi_data_o;
        captured_count <= captured_count + 1;
    end
    if (txvalid_d && !utmi_txvalid) begin
        packet_count <= packet_count + 1;
    end
    if (!txvalid_d && utmi_txvalid && packet_count == 1 &&
        (eop_count < 1 || idle_after_eop_cycles < 80))
        $fatal(1, "DATA started before token EOP: eop=%0d idle=%0d",
               eop_count, idle_after_eop_cycles);
end

reg [31:0] status;
reg [31:0] report_word;
reg [31:0] debug_word;
reg [31:0] version_word;
reg [31:0] trace_meta;
reg [31:0] trace_word0;
reg [31:0] trace_word1;
reg [31:0] trace_word2;
reg [31:0] trace_word3;
initial begin
    #1;
    if (utmi_suspendn !== 1'b1)
        $fatal(1, "USB3500 must be awake before CLKOUT-dependent logic runs");
    repeat (5) @(posedge aclk);
    aresetn = 1;
    axi_write(32'h0, 32'h3); // enable host and IRQ
    wait (!utmi_reset);
    repeat (80) @(posedge usb_clk);
    utmi_linestate = 2'b10; // low-speed mouse pull-up
    wait (dut.engine_connected_usb);
    wait (usb_int);
    axi_write(32'hc, 32'h7);
    wait (!usb_int);
    model_line_activity = 1'b1;

    // The first real enumeration transaction: SETUP GET_DESCRIPTOR(device),
    // address 0 endpoint 0, DATA0, eight-byte setup payload.  The CRC16 of
    // 80 06 00 01 00 00 08 00 is 94eb (low byte transmitted first).
    fork
        begin
            wait (eop_count == 2);
            repeat (20) @(posedge usb_clk);
            utmi_rxactive = 1;
            @(posedge usb_clk);
            utmi_rxvalid = 1;
            utmi_data_i = 8'hd2;
            @(posedge usb_clk);
            utmi_rxvalid = 0;
            utmi_rxactive = 0;
        end
        begin
            axi_write(32'h40, 32'h0100_0680);
            axi_write(32'h44, 32'h0008_0000);
            axi_write(32'h8, 32'h0008_0000);
            axi_write(32'h0, 32'h7);
        end
    join

    wait (usb_int);
    axi_read(32'h4, status);
    axi_read(32'h10, version_word);
    axi_read(32'h1c, trace_meta);
    axi_read(32'hc0, trace_word0);
    axi_read(32'hc4, trace_word1);
    axi_read(32'hc8, trace_word2);
    axi_read(32'hcc, trace_word3);
    if (status[7:4] != 0)
        $fatal(1, "transaction result %0d", status[7:4]);
    if (version_word != 32'h554d_0105)
        $fatal(1, "unexpected register revision %08x", version_word);
    if (trace_meta[4:0] != 5'd14 || !trace_meta[8])
        $fatal(1, "bad TX trace metadata %08x", trace_meta);
    if (trace_word0 != 32'hc310_002d ||
        trace_word1 != 32'h0100_0680 ||
        trace_word2 != 32'h0008_0000 ||
        trace_word3 != 32'h0000_94eb)
        $fatal(1, "bad registered TX trace %08x %08x %08x %08x",
               trace_word0, trace_word1, trace_word2, trace_word3);
    if (captured_count != 14 || captured[0] != 8'h2d ||
        captured[1] != 8'h00 || captured[2] != 8'h10 ||
        captured[3] != 8'hc3 || captured[4] != 8'h80 ||
        captured[5] != 8'h06 || captured[6] != 8'h00 ||
        captured[7] != 8'h01 || captured[8] != 8'h00 ||
        captured[9] != 8'h00 || captured[10] != 8'h08 ||
        captured[11] != 8'h00 || captured[12] != 8'heb ||
        captured[13] != 8'h94)
        $fatal(1, "unexpected UTMI packet stream");
    if (utmi_data_oe)
        $fatal(1, "UTMI DATA was not released after TXVALID");
    if (utmi_data_t != 8'hff)
        $fatal(1, "per-pin UTMI DATA tri-state controls were not released");

    // Interrupt IN returning a three-byte boot mouse report.  The trailing
    // USB CRC16 for 01 05 fb is 0x2c9d, sent low byte first.
    axi_write(32'hc, 32'h7);
    wait (!usb_int);
    fork
        begin
            wait (eop_count == 3);
            repeat (20) @(posedge usb_clk);
            utmi_rxactive = 1;
            @(posedge usb_clk);
            utmi_rxvalid = 1; utmi_data_i = 8'hc3;
            @(posedge usb_clk);
            utmi_data_i = 8'h01;
            @(posedge usb_clk);
            utmi_data_i = 8'h05;
            @(posedge usb_clk);
            utmi_data_i = 8'hfb;
            @(posedge usb_clk);
            utmi_data_i = 8'h9d;
            @(posedge usb_clk);
            utmi_data_i = 8'h2c;
            @(posedge usb_clk);
            utmi_rxvalid = 0;
            utmi_rxactive = 0;
        end
        begin
            axi_write(32'h8, 32'h0400_1000);
            axi_write(32'h0, 32'h7);
        end
    join
    wait (usb_int);
    axi_read(32'h4, status);
    axi_read(32'h80, report_word);
    axi_read(32'h18, debug_word);
    if (status[7:4] != 0 || status[14:8] != 3)
        $fatal(1, "IN result=%0d len=%0d", status[7:4], status[14:8]);
    if (report_word[23:0] != 24'hfb0501)
        $fatal(1, "bad RX payload %08x", report_word);
    if (captured[17] != 8'hd2)
        $fatal(1, "host did not ACK valid IN data");
    if (debug_word[31:24] < 4 || debug_word[23:16] < 2 ||
        debug_word[2:0] != 3'b111)
        $fatal(1, "bad debug counters/flags %08x", debug_word);

    // Control-read status stage: zero-length DATA1 OUT followed by the
    // device ACK.  This is used repeatedly by enumeration after descriptors.
    axi_write(32'hc, 32'h7);
    wait (!usb_int);
    fork
        begin
            wait (captured_count >= 24);
            wait (serial_tail_remaining != 0);
            wait (serial_tail_remaining == 0 && eop_remaining == 0);
            repeat (20) @(posedge usb_clk);
            utmi_rxactive = 1;
            @(posedge usb_clk);
            utmi_rxvalid = 1;
            utmi_data_i = 8'hd2;
            @(posedge usb_clk);
            utmi_rxvalid = 0;
            utmi_rxactive = 0;
        end
        begin
            axi_write(32'h8, 32'h0000_2800);
            axi_write(32'h0, 32'h7);
        end
    join
    wait (usb_int);
    axi_read(32'h4, status);
    if (status[7:4] != 0 || captured_count < 24 ||
        captured[18] != 8'he1 || captured[19] != 8'h00 ||
        captured[20] != 8'h10 || captured[21] != 8'h4b ||
        captured[22] != 8'h00 || captured[23] != 8'h00)
        $fatal(1, "bad zero-length OUT: status=%08x count=%0d packets=%0d eop=%0d bytes=%02x %02x %02x %02x %02x %02x",
               status, captured_count, packet_count, eop_count,
               captured[18], captured[19], captured[20], captured[21],
               captured[22], captured[23]);

    $display("PASS: stressed TXREADY, SETUP/IN/OUT, CRC, ACK and debug telemetry");
    $finish;
end

initial begin
    #10000000;
    $fatal(1, "timeout");
end

endmodule
