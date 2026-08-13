`timescale 1ns/1ps

module tb_ps2_ctrl_rx;
    reg aclk = 1'b0;
    reg aresetn = 1'b0;
    always #15 aclk = ~aclk; // 33.3 MHz

    reg ps2_clk_i = 1'b1;
    reg ps2_data_i = 1'b1;

    wire ps2_clk_o;
    wire ps2_clk_oe;
    wire ps2_data_o;
    wire ps2_data_oe;
    wire ps2_int;

    wire        s_awready;
    wire        s_wready;
    wire [3:0]  s_bid;
    wire [1:0]  s_bresp;
    wire        s_bvalid;
    wire        s_arready;
    wire [3:0]  s_rid;
    wire [31:0] s_rdata;
    wire [1:0]  s_rresp;
    wire        s_rlast;
    wire        s_rvalid;

    ps2_ctrl dut (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_awid(4'd0),
        .s_awaddr(32'd0),
        .s_awlen(4'd0),
        .s_awsize(3'd2),
        .s_awburst(2'd0),
        .s_awlock(2'd0),
        .s_awcache(4'd0),
        .s_awprot(3'd0),
        .s_awvalid(1'b0),
        .s_awready(s_awready),
        .s_wid(4'd0),
        .s_wdata(32'd0),
        .s_wstrb(4'd0),
        .s_wlast(1'b0),
        .s_wvalid(1'b0),
        .s_wready(s_wready),
        .s_bid(s_bid),
        .s_bresp(s_bresp),
        .s_bvalid(s_bvalid),
        .s_bready(1'b1),
        .s_arid(4'd0),
        .s_araddr(32'd0),
        .s_arlen(4'd0),
        .s_arsize(3'd2),
        .s_arburst(2'd0),
        .s_arlock(2'd0),
        .s_arcache(4'd0),
        .s_arprot(3'd0),
        .s_arvalid(1'b0),
        .s_arready(s_arready),
        .s_rid(s_rid),
        .s_rdata(s_rdata),
        .s_rresp(s_rresp),
        .s_rlast(s_rlast),
        .s_rvalid(s_rvalid),
        .s_rready(1'b1),
        .ps2_clk_i(ps2_clk_i),
        .ps2_clk_o(ps2_clk_o),
        .ps2_clk_oe(ps2_clk_oe),
        .ps2_data_i(ps2_data_i),
        .ps2_data_o(ps2_data_o),
        .ps2_data_oe(ps2_data_oe),
        .ps2_int(ps2_int)
    );

    task send_bit;
        input value;
        input inject_glitch;
        begin
            ps2_data_i = value;
            #5000;
            if (inject_glitch) begin
                // Seven 33 MHz samples: old 4-sample filter accepts this,
                // while the 16-sample filter must reject it.
                ps2_clk_i = 1'b0;
                #200;
                ps2_clk_i = 1'b1;
                #5000;
            end
            ps2_clk_i = 1'b0;
            #30000;
            ps2_clk_i = 1'b1;
            #30000;
        end
    endtask

    task send_byte;
        input [7:0] value;
        input inject_glitches;
        integer i;
        reg parity;
        begin
            parity = ~(^value);
            send_bit(1'b0, inject_glitches);
            for (i = 0; i < 8; i = i + 1)
                send_bit(value[i], inject_glitches);
            send_bit(parity, inject_glitches);
            send_bit(1'b1, inject_glitches);
            #30000;
        end
    endtask

    initial begin
        #300;
        aresetn = 1'b1;
        #3000;

        // Set-2 A make/break sequence, with a narrow clock glitch before
        // every real falling edge and with no software draining the FIFO.
        send_byte(8'h1c, 1'b1);
        send_byte(8'hf0, 1'b1);
        send_byte(8'h1c, 1'b1);
        #100000;

        if (dut.rx_count !== 5'd3) begin
            $display("FAIL: RX count %0d, expected 3", dut.rx_count);
            $fatal;
        end
        if (dut.rx_fifo[0] !== 8'h1c ||
            dut.rx_fifo[1] !== 8'hf0 ||
            dut.rx_fifo[2] !== 8'h1c) begin
            $display("FAIL: bytes %02x %02x %02x",
                     dut.rx_fifo[0], dut.rx_fifo[1], dut.rx_fifo[2]);
            $fatal;
        end
        if (dut.stat_rx_parity || dut.stat_rx_frame ||
            dut.stat_rx_overflow) begin
            $display("FAIL: parity=%0d frame=%0d overflow=%0d",
                     dut.stat_rx_parity, dut.stat_rx_frame,
                     dut.stat_rx_overflow);
            $fatal;
        end

        $display("PASS: back-to-back Set-2 frames survived injected glitches");
        $finish;
    end
endmodule
