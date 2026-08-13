module ps2_ctrl(
    input         aclk,
    input         aresetn,

    // AXI slave AW channel
    input  [3 :0] s_awid,
    input  [31:0] s_awaddr,
    input  [3 :0] s_awlen,
    input  [2 :0] s_awsize,
    input  [1 :0] s_awburst,
    input  [1 :0] s_awlock,
    input  [3 :0] s_awcache,
    input  [2 :0] s_awprot,
    input         s_awvalid,
    output        s_awready,

    // AXI slave W channel
    input  [3 :0] s_wid,
    input  [31:0] s_wdata,
    input  [3 :0] s_wstrb,
    input         s_wlast,
    input         s_wvalid,
    output reg    s_wready,

    // AXI slave B channel
    output [3 :0] s_bid,
    output [1 :0] s_bresp,
    output reg    s_bvalid,
    input         s_bready,

    // AXI slave AR channel
    input  [3 :0] s_arid,
    input  [31:0] s_araddr,
    input  [3 :0] s_arlen,
    input  [2 :0] s_arsize,
    input  [1 :0] s_arburst,
    input  [1 :0] s_arlock,
    input  [3 :0] s_arcache,
    input  [2 :0] s_arprot,
    input         s_arvalid,
    output        s_arready,

    // AXI slave R channel
    output [3 :0] s_rid,
    output reg [31:0] s_rdata,
    output [1 :0] s_rresp,
    output reg    s_rlast,
    output reg    s_rvalid,
    input         s_rready,

    // PS/2 external interface (IOBUF in soc_top)
    input         ps2_clk_i,
    output        ps2_clk_o,
    output        ps2_clk_oe,
    input         ps2_data_i,
    output        ps2_data_o,
    output        ps2_data_oe,

    // Interrupt
    output        ps2_int
);

//----------------------------------------------------------------------------
// AXI protocol handling (pattern from CONFREG/LCD)
//----------------------------------------------------------------------------
reg busy, write, R_or_W;

wire ar_enter = s_arvalid & s_arready;
wire r_retire = s_rvalid & s_rready & s_rlast;
wire aw_enter = s_awvalid & s_awready;
wire w_enter  = s_wvalid & s_wready & s_wlast;
wire b_retire = s_bvalid & s_bready;

assign s_arready = ~busy & (!R_or_W | !s_awvalid);
assign s_awready = ~busy & ( R_or_W | !s_arvalid);

always @(posedge aclk)
    if (~aresetn) busy <= 1'b0;
    else if (ar_enter | aw_enter) busy <= 1'b1;
    else if (r_retire | b_retire) busy <= 1'b0;

reg [3:0]  buf_id;
reg [31:0] buf_addr;

always @(posedge aclk)
    if (~aresetn) begin
        R_or_W   <= 1'b0;
        buf_id   <= 4'd0;
        buf_addr <= 32'd0;
    end
    else if (ar_enter | aw_enter) begin
        R_or_W   <= ar_enter;
        buf_id   <= ar_enter ? s_arid : s_awid;
        buf_addr <= ar_enter ? s_araddr : s_awaddr;
    end

always @(posedge aclk)
    if (~aresetn) write <= 1'b0;
    else if (aw_enter) write <= 1'b1;
    else if (ar_enter) write <= 1'b0;

always @(posedge aclk)
    if (~aresetn) s_wready <= 1'b0;
    else if (aw_enter) s_wready <= 1'b1;
    else if (w_enter & s_wlast) s_wready <= 1'b0;

//----------------------------------------------------------------------------
// Register definitions
//----------------------------------------------------------------------------
localparam [1:0] REG_DATA = 2'd0;  // 0x00
localparam [1:0] REG_STAT = 2'd1;  // 0x04
localparam [1:0] REG_CTRL = 2'd2;  // 0x08
localparam [1:0] REG_TEST = 2'd3;  // 0x0C

wire [1:0] reg_sel = buf_addr[3:2];

// CTRL register bits
reg ctrl_rx_int_en;   // bit0
reg ctrl_tx_int_en;   // bit1
reg ctrl_rx_en;       // bit7

// Sticky status bits (cleared by writing 1 to CTRL bit2-5)
reg stat_rx_overflow; // bit2
reg stat_tx_nack;     // bit3
reg stat_rx_parity;   // bit4
reg stat_rx_frame;    // bit5

//----------------------------------------------------------------------------
// PS/2 signal synchronization, glitch filtering and edge detection
//----------------------------------------------------------------------------
(* ASYNC_REG = "TRUE" *) reg ps2_clk_meta;
(* ASYNC_REG = "TRUE" *) reg ps2_clk_raw;
(* ASYNC_REG = "TRUE" *) reg ps2_data_meta;
(* ASYNC_REG = "TRUE" *) reg ps2_data_raw;
reg ps2_clk_sync, ps2_clk_prev;
reg ps2_data_sync, ps2_data_prev;

/*
 * PS/2 clocks are only 10--16.7 kHz, so requiring 16 consecutive 33 MHz
 * samples still adds less than 0.5 us of delay while rejecting the narrow
 * clock glitches that would otherwise be mistaken for extra data bits.
 * CLK and DATA use identical filters to keep their relative delay matched.
 */
localparam integer PS2_FILTER_LEN = 16;
reg [PS2_FILTER_LEN-1:0] ps2_clk_filter;
reg [PS2_FILTER_LEN-1:0] ps2_data_filter;

always @(posedge aclk) begin
    if (~aresetn) begin
        ps2_clk_meta  <= 1'b1;
        ps2_clk_raw   <= 1'b1;
        ps2_clk_sync  <= 1'b1;
        ps2_clk_prev  <= 1'b1;
        ps2_clk_filter <= {PS2_FILTER_LEN{1'b1}};
        ps2_data_meta <= 1'b1;
        ps2_data_raw  <= 1'b1;
        ps2_data_sync <= 1'b1;
        ps2_data_prev <= 1'b1;
        ps2_data_filter <= {PS2_FILTER_LEN{1'b1}};
    end
    else begin
        ps2_clk_meta  <= ps2_clk_i;
        ps2_clk_raw   <= ps2_clk_meta;
        ps2_clk_filter <= {
            ps2_clk_filter[PS2_FILTER_LEN-2:0], ps2_clk_raw
        };
        ps2_clk_prev  <= ps2_clk_sync;
        if (&ps2_clk_filter)
            ps2_clk_sync <= 1'b1;
        else if (~|ps2_clk_filter)
            ps2_clk_sync <= 1'b0;

        ps2_data_meta <= ps2_data_i;
        ps2_data_raw  <= ps2_data_meta;
        ps2_data_filter <= {
            ps2_data_filter[PS2_FILTER_LEN-2:0], ps2_data_raw
        };
        ps2_data_prev <= ps2_data_sync;
        if (&ps2_data_filter)
            ps2_data_sync <= 1'b1;
        else if (~|ps2_data_filter)
            ps2_data_sync <= 1'b0;
    end
end

wire ps2_clk_falling = ~ps2_clk_sync & ps2_clk_prev;
wire ps2_clk_rising  = ps2_clk_sync & ~ps2_clk_prev;

//----------------------------------------------------------------------------
// RX FIFO (16 x 8-bit ring buffer)
//----------------------------------------------------------------------------
reg [7:0] rx_fifo [0:15];
reg [3:0] rx_head, rx_tail;
reg [4:0] rx_count;  // 5-bit to detect overflow (max 16)

wire rx_fifo_empty = (rx_count == 5'd0);
wire rx_fifo_full  = (rx_count == 5'd16);
wire rx_ready      = ~rx_fifo_empty;

always @(posedge aclk) begin
    if (~aresetn) begin
        rx_head  <= 4'd0;
        rx_tail  <= 4'd0;
        rx_count <= 5'd0;
    end
    else if (rx_push && !rx_pop) begin
        rx_fifo[rx_head] <= rx_shift_reg;
        rx_head  <= rx_head + 4'd1;
        rx_count <= rx_count + 5'd1;
    end
    else if (rx_pop && !rx_push) begin
        rx_tail  <= rx_tail + 4'd1;
        rx_count <= rx_count - 5'd1;
    end
    // simultaneous push+pop: count unchanged, both pointers advance
    else if (rx_push && rx_pop) begin
        rx_fifo[rx_head] <= rx_shift_reg;
        rx_head <= rx_head + 4'd1;
        rx_tail <= rx_tail + 4'd1;
    end
end

//----------------------------------------------------------------------------
// RX FSM
//----------------------------------------------------------------------------
localparam [1:0] RX_IDLE   = 2'd0;
localparam [1:0] RX_DATA   = 2'd1;
localparam [1:0] RX_PARITY = 2'd2;
localparam [1:0] RX_STOP   = 2'd3;

reg [1:0]  rx_state;
reg [7:0]  rx_shift_reg;
reg [2:0]  rx_bit_cnt;
reg        rx_parity_acc;
reg        rx_parity_ok;
reg        rx_push;
reg [16:0] rx_timeout_cnt;

localparam [16:0] RX_TIMEOUT_CYCLES = 17'd66000;  // ~2ms @ 33MHz
wire rx_timeout = (rx_state != RX_IDLE) && (rx_timeout_cnt == RX_TIMEOUT_CYCLES);

always @(posedge aclk) begin
    if (~aresetn) begin
        rx_state     <= RX_IDLE;
        rx_shift_reg <= 8'd0;
        rx_bit_cnt   <= 3'd0;
        rx_parity_acc <= 1'b0;
        rx_parity_ok <= 1'b0;
        rx_push      <= 1'b0;
        rx_timeout_cnt <= 17'd0;
        stat_rx_overflow <= 1'b0;
        stat_rx_parity   <= 1'b0;
        stat_rx_frame    <= 1'b0;
    end
    else begin
        rx_push <= 1'b0;
        if (tx_busy) begin
            // TX has control of the bus, suppress RX
            rx_state <= RX_IDLE;
            rx_timeout_cnt <= 17'd0;
        end
        else if (ctrl_rx_en) begin
            if (rx_state == RX_IDLE)
                rx_timeout_cnt <= 17'd0;
            else if (ps2_clk_falling)
                rx_timeout_cnt <= 17'd0;
            else if (!rx_timeout)
                rx_timeout_cnt <= rx_timeout_cnt + 17'd1;

            if (rx_timeout && !ps2_clk_falling) begin
                rx_state <= RX_IDLE;
                rx_timeout_cnt <= 17'd0;
                stat_rx_frame <= 1'b1;
            end
            else begin
                case (rx_state)
                    RX_IDLE: begin
                        if (ps2_clk_falling && !ps2_data_sync) begin
                            rx_state      <= RX_DATA;
                            rx_shift_reg  <= 8'd0;
                            rx_bit_cnt    <= 3'd0;
                            rx_parity_acc <= 1'b0;
                            rx_parity_ok  <= 1'b0;
                        end
                    end
                    RX_DATA: begin
                        if (ps2_clk_falling) begin
                            rx_shift_reg[rx_bit_cnt] <= ps2_data_sync;
                            rx_parity_acc <= rx_parity_acc ^ ps2_data_sync;
                            if (rx_bit_cnt == 3'd7)
                                rx_state <= RX_PARITY;
                            else
                                rx_bit_cnt <= rx_bit_cnt + 3'd1;
                        end
                    end
                    RX_PARITY: begin
                        if (ps2_clk_falling) begin
                            rx_parity_ok <= rx_parity_acc ^ ps2_data_sync;
                            if (rx_parity_acc ^ ps2_data_sync)
                                stat_rx_parity <= 1'b0;
                            else
                                stat_rx_parity <= 1'b1;
                            rx_state <= RX_STOP;
                        end
                    end
                    RX_STOP: begin
                        if (ps2_clk_falling) begin
                            if (!ps2_data_sync)
                                stat_rx_frame <= 1'b1;
                            if (rx_parity_ok && ps2_data_sync) begin
                                if (rx_fifo_full)
                                    stat_rx_overflow <= 1'b1;
                                else
                                    rx_push <= 1'b1;
                            end
                            rx_state <= RX_IDLE;
                        end
                    end
                endcase
            end
        end
        else begin
            rx_state <= RX_IDLE;
            rx_timeout_cnt <= 17'd0;
        end
        // Override: clear sticky RX status on CTRL write
        if (w_enter && reg_sel == REG_CTRL) begin
            if (s_wdata[2]) stat_rx_overflow <= 1'b0;
            if (s_wdata[4]) stat_rx_parity   <= 1'b0;
            if (s_wdata[5]) stat_rx_frame    <= 1'b0;
        end
    end
end

//----------------------------------------------------------------------------
// TX FSM
//----------------------------------------------------------------------------
localparam [3:0] TX_IDLE      = 4'd0;
localparam [3:0] TX_INHIBIT   = 4'd1;
localparam [3:0] TX_DATA_LOW  = 4'd2;
localparam [3:0] TX_CLK_WAIT  = 4'd3;
localparam [3:0] TX_BITS      = 4'd4;
localparam [3:0] TX_PARITY    = 4'd5;
localparam [3:0] TX_STOP      = 4'd6;
localparam [3:0] TX_ACK       = 4'd7;

reg [3:0]  tx_state;
reg        tx_busy;
reg [7:0]  tx_byte;
reg [2:0]  tx_bit_cnt;
reg        tx_parity_acc;
reg [12:0] tx_inhibit_cnt;  // 100us @ 33MHz = 3300 cycles
reg [19:0] tx_timeout_cnt;  // 15ms @ 33MHz = ~495000 cycles
reg        tx_done_flag;

wire tx_start_pulse = w_enter & (reg_sel == REG_CTRL) & s_wdata[6];

always @(posedge aclk) begin
    if (~aresetn) begin
        tx_state        <= TX_IDLE;
        tx_busy         <= 1'b0;
        tx_byte         <= 8'd0;
        tx_bit_cnt      <= 3'd0;
        tx_parity_acc   <= 1'b0;
        tx_inhibit_cnt  <= 13'd0;
        tx_timeout_cnt  <= 20'd0;
        tx_done_flag    <= 1'b0;
        stat_tx_nack    <= 1'b0;
    end
    else begin
        case (tx_state)
            TX_IDLE: begin
                tx_done_flag <= 1'b0;
                if (tx_start_pulse) begin
                    tx_byte       <= tx_data_buf;
                    tx_busy       <= 1'b1;
                    tx_parity_acc <= 1'b0;
                    tx_bit_cnt    <= 3'd0;
                    tx_inhibit_cnt <= 13'd0;
                    tx_state      <= TX_INHIBIT;
                end
            end
            TX_INHIBIT: begin
                if (tx_inhibit_cnt == 13'd3300) begin
                    tx_state <= TX_DATA_LOW;
                end
                else
                    tx_inhibit_cnt <= tx_inhibit_cnt + 13'd1;
            end
            TX_DATA_LOW: begin
                tx_state <= TX_CLK_WAIT;
                tx_timeout_cnt <= 20'd0;
            end
            TX_CLK_WAIT: begin
                if (ps2_clk_rising) begin
                    tx_state <= TX_BITS;
                    tx_bit_cnt <= 3'd0;
                    tx_parity_acc <= 1'b0;
                end
                else if (tx_timeout_cnt == 20'd495000) begin
                    stat_tx_nack <= 1'b1;
                    tx_done_flag <= 1'b1;
                    tx_busy      <= 1'b0;
                    tx_state     <= TX_IDLE;
                end
                else
                    tx_timeout_cnt <= tx_timeout_cnt + 20'd1;
            end
            TX_BITS: begin
                if (ps2_clk_rising) begin
                    tx_parity_acc <= tx_parity_acc ^ tx_byte[tx_bit_cnt];
                    if (tx_bit_cnt == 3'd7)
                        tx_state <= TX_PARITY;
                    else
                        tx_bit_cnt <= tx_bit_cnt + 3'd1;
                end
            end
            TX_PARITY: begin
                if (ps2_clk_rising)
                    tx_state <= TX_STOP;
            end
            TX_STOP: begin
                if (ps2_clk_rising) begin
                    tx_state <= TX_ACK;
                    tx_timeout_cnt <= 20'd0;
                end
            end
            TX_ACK: begin
                if (ps2_clk_falling) begin
                    if (ps2_data_sync)
                        stat_tx_nack <= 1'b1;
                    else
                        stat_tx_nack <= 1'b0;
                    tx_done_flag <= 1'b1;
                    tx_busy      <= 1'b0;
                    tx_state     <= TX_IDLE;
                end
                else if (tx_timeout_cnt == 20'd495000) begin
                    stat_tx_nack <= 1'b1;
                    tx_done_flag <= 1'b1;
                    tx_busy      <= 1'b0;
                    tx_state     <= TX_IDLE;
                end
                else
                    tx_timeout_cnt <= tx_timeout_cnt + 20'd1;
            end
        endcase
        // Override: clear tx_done_flag on STAT read
        if (r_retire && reg_sel == REG_STAT)
            tx_done_flag <= 1'b0;
        // Override: clear stat_tx_nack on CTRL write
        if (w_enter && reg_sel == REG_CTRL && s_wdata[3])
            stat_tx_nack <= 1'b0;
    end
end

// TX data buffer (written via DATA register before tx_start)
reg [7:0] tx_data_buf;

//----------------------------------------------------------------------------
// PS/2 pin driving
//----------------------------------------------------------------------------
// TX_BITS/TX_PARITY: drive DATA based on current bit.
// PS/2 uses odd parity, so the parity bit is the inverse of the
// accumulated XOR of the 8 data bits.
wire tx_data_bit = (tx_state == TX_BITS) ? tx_byte[tx_bit_cnt] :
                   (tx_state == TX_PARITY) ? ~tx_parity_acc : 1'b1;

assign ps2_clk_o  = 1'b0;  // Only drive low (inhibit)
assign ps2_data_o = (tx_state == TX_INHIBIT) ? 1'b1 :
                    (tx_state == TX_DATA_LOW) ? 1'b0 :
                    (tx_state == TX_BITS || tx_state == TX_PARITY) ? tx_data_bit :
                    1'b1;

// OE: drive CLK during inhibit, drive DATA during TX
assign ps2_clk_oe  = (tx_state == TX_INHIBIT);  // 1=drive low to inhibit
assign ps2_data_oe = (tx_state == TX_INHIBIT || tx_state == TX_DATA_LOW ||
                      tx_state == TX_CLK_WAIT || tx_state == TX_BITS ||
                      tx_state == TX_PARITY);

// Inhibit RX when rx_en=0 (hold CLK low)
wire rx_inhibit = ~ctrl_rx_en & ~tx_busy;

//----------------------------------------------------------------------------
// Write register handling
//----------------------------------------------------------------------------
wire rx_pop = r_retire & (reg_sel == REG_DATA);

always @(posedge aclk) begin
    if (~aresetn) begin
        ctrl_rx_int_en  <= 1'b0;
        ctrl_tx_int_en  <= 1'b0;
        ctrl_rx_en      <= 1'b1;
        tx_data_buf      <= 8'd0;
    end
    else if (w_enter) begin
        case (reg_sel)
            REG_DATA: begin
                tx_data_buf <= s_wdata[7:0];
            end
            REG_CTRL: begin
                ctrl_rx_int_en <= s_wdata[0];
                ctrl_tx_int_en <= s_wdata[1];
                ctrl_rx_en <= s_wdata[7];
            end
        endcase
    end
end

//----------------------------------------------------------------------------
// Read path
//----------------------------------------------------------------------------
wire [7:0] fifo_dout = rx_fifo[rx_tail];

wire [31:0] rdata_d = (reg_sel == REG_DATA) ? {24'd0, fifo_dout} :
                      (reg_sel == REG_STAT) ? {16'd0, 3'd0, rx_count, 2'd0, stat_rx_frame, stat_rx_parity, stat_tx_nack, stat_rx_overflow, tx_busy, rx_ready} :
                      (reg_sel == REG_CTRL) ? {24'd0, ctrl_rx_en, 5'd0, ctrl_tx_int_en, ctrl_rx_int_en} :
                      (reg_sel == REG_TEST) ? {30'd0, ps2_data_sync, ps2_clk_sync} :
                      32'd0;

always @(posedge aclk)
    if (~aresetn) begin
        s_rdata  <= 32'd0;
        s_rvalid <= 1'b0;
        s_rlast  <= 1'b0;
    end
    else if (busy & !write & !r_retire) begin
        s_rdata  <= rdata_d;
        s_rvalid <= 1'b1;
        s_rlast  <= 1'b1;
    end
    else if (r_retire) begin
        s_rvalid <= 1'b0;
    end

//----------------------------------------------------------------------------
// Write response
//----------------------------------------------------------------------------
always @(posedge aclk)
    if (~aresetn) s_bvalid <= 1'b0;
    else if (w_enter) s_bvalid <= 1'b1;
    else if (b_retire) s_bvalid <= 1'b0;

//----------------------------------------------------------------------------
// AXI response IDs
//----------------------------------------------------------------------------
assign s_rid   = buf_id;
assign s_bid   = buf_id;
assign s_bresp = 2'b0;
assign s_rresp = 2'b0;

//----------------------------------------------------------------------------
// Interrupt output
//----------------------------------------------------------------------------
assign ps2_int = (ctrl_rx_int_en & rx_ready) | (ctrl_tx_int_en & tx_done_flag);

endmodule
