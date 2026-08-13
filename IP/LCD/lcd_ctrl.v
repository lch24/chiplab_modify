module lcd_ctrl(
    input         aclk,
    input         aresetn,

    // AXI slave AW channel
    input  [3 :0] s_awid,
    input  [31:0] s_awaddr,
    input  [7 :0] s_awlen,
    input  [2 :0] s_awsize,
    input  [1 :0] s_awburst,
    input         s_awlock,
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
    output        s_wready,

    // AXI slave B channel
    output [3 :0] s_bid,
    output [1 :0] s_bresp,
    output        s_bvalid,
    input         s_bready,

    // AXI slave AR channel
    input  [3 :0] s_arid,
    input  [31:0] s_araddr,
    input  [7 :0] s_arlen,
    input  [2 :0] s_arsize,
    input  [1 :0] s_arburst,
    input         s_arlock,
    input  [3 :0] s_arcache,
    input  [2 :0] s_arprot,
    input         s_arvalid,
    output        s_arready,

    // AXI slave R channel
    output [3 :0] s_rid,
    output [31:0] s_rdata,
    output [1 :0] s_rresp,
    output        s_rlast,
    output        s_rvalid,
    input         s_rready,

    // LCD 8080 parallel interface
    output reg         lcd_rst,      // LCD reset (active low)
    output             lcd_cs,       // LCD chip select (active low, tied to 0)
    output reg         lcd_rs,       // 0=command, 1=data
    output reg         lcd_wr,       // Write strobe (active low)
    output             lcd_rd,       // Read strobe (tied to 1)
    output reg         lcd_bl_ctr,   // Backlight control
    output reg  [15:0] lcd_data,     // 16-bit data bus (DB1-DB17)

    // Touch screen pins (pass-through, not used yet)
    input         lcd_t_pen,
    inout         lcd_t_mosi,
    output        lcd_t_clk,
    output        lcd_t_cs_rst,

    // Optional DMA pixel stream input (RGB565)
    input  [15:0] dma_pixel_data,
    input         dma_pixel_valid,
    output        dma_pixel_ready
);

// LCD control signals hardwired (same as reference design)
assign lcd_cs  = 1'b0;    // Always selected
assign lcd_rd  = 1'b1;    // Never read

// Touch screen: pass through as unused for now
assign lcd_t_clk    = 1'b0;
assign lcd_t_cs_rst = 1'b1;

//----------------------------------------------------------------------------
// Register definitions
//----------------------------------------------------------------------------
`define CMD_REG_ADDR   4'h0   // 0x00: write command (RS=0)
`define DATA_REG_ADDR  4'h1   // 0x04: write data (RS=1)
`define STAT_REG_ADDR  4'h2   // 0x08: status register
`define CTRL_REG_ADDR  4'h3   // 0x0C: control register

//----------------------------------------------------------------------------
// AXI protocol handling (pattern from CONFREG)
//----------------------------------------------------------------------------
reg busy, write, R_or_W;
reg s_wready;

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

//----------------------------------------------------------------------------
// Command/data FIFO
//----------------------------------------------------------------------------
localparam FIFO_DEPTH = 16;
localparam FIFO_AW    = 4;

reg        fifo_rs [0:FIFO_DEPTH-1];
reg [15:0] fifo_data [0:FIFO_DEPTH-1];
reg [FIFO_AW-1:0] fifo_rptr;
reg [FIFO_AW-1:0] fifo_wptr;
reg [FIFO_AW:0]   fifo_count;

wire fifo_empty = (fifo_count == 0);
wire fifo_full  = (fifo_count == FIFO_DEPTH);

wire aw_targets_fifo = (s_awaddr[3:2] == `CMD_REG_ADDR) |
                       (s_awaddr[3:2] == `DATA_REG_ADDR);
wire write_targets_fifo = write & ((buf_addr[3:2] == `CMD_REG_ADDR) |
                                   (buf_addr[3:2] == `DATA_REG_ADDR));

always @(posedge aclk)
    if (~aresetn)
        s_wready <= 1'b0;
    else if (aw_enter)
        s_wready <= !(aw_targets_fifo & fifo_full);
    else if (write & !s_wready & write_targets_fifo & !fifo_full)
        s_wready <= 1'b1;
    else if (w_enter & s_wlast)
        s_wready <= 1'b0;

wire cpu_fifo_push = w_enter & write_targets_fifo;
wire dma_fifo_push = dma_pixel_valid & dma_pixel_ready;
wire fifo_push  = cpu_fifo_push | dma_fifo_push;
wire fifo_pop;
wire fifo_push_rs = cpu_fifo_push ? (buf_addr[3:2] == `DATA_REG_ADDR) : 1'b1;
wire [15:0] fifo_push_data = cpu_fifo_push ? s_wdata[15:0] : dma_pixel_data;

assign dma_pixel_ready = !fifo_full & !cpu_fifo_push;

always @(posedge aclk) begin
    if (~aresetn) begin
        fifo_rptr  <= {FIFO_AW{1'b0}};
        fifo_wptr  <= {FIFO_AW{1'b0}};
        fifo_count <= {(FIFO_AW+1){1'b0}};
    end
    else begin
        if (fifo_push) begin
            fifo_rs[fifo_wptr]   <= fifo_push_rs;
            fifo_data[fifo_wptr] <= fifo_push_data;
            fifo_wptr <= fifo_wptr + 1'b1;
        end

        if (fifo_pop)
            fifo_rptr <= fifo_rptr + 1'b1;

        case ({fifo_push, fifo_pop})
            2'b10: fifo_count <= fifo_count + 1'b1;
            2'b01: fifo_count <= fifo_count - 1'b1;
            default: fifo_count <= fifo_count;
        endcase
    end
end

//----------------------------------------------------------------------------
// 8080 write timing FSM
//----------------------------------------------------------------------------
localparam FSM_IDLE  = 2'd0;
localparam FSM_SETUP = 2'd1;
localparam FSM_WRITE = 2'd2;
localparam FSM_HOLD  = 2'd3;

reg [1:0] fsm_state;
reg       fsm_rs;         // 0=command, 1=data
reg [15:0] fsm_data;      // data to write

always @(posedge aclk) begin
    if (~aresetn) begin
        fsm_state <= FSM_IDLE;
        fsm_rs    <= 1'b0;
        fsm_data  <= 16'd0;
        lcd_wr    <= 1'b1;
        lcd_rs    <= 1'b0;
        lcd_data  <= 16'd0;
    end
    else begin
        case (fsm_state)
            FSM_IDLE: begin
                lcd_wr <= 1'b1;
                if (!fifo_empty) begin
                    fsm_rs    <= fifo_rs[fifo_rptr];
                    fsm_data  <= fifo_data[fifo_rptr];
                    fsm_state <= FSM_SETUP;
                end
            end
            FSM_SETUP: begin
                lcd_rs   <= fsm_rs;
                lcd_data <= fsm_data;
                lcd_wr   <= 1'b1;
                fsm_state <= FSM_WRITE;
            end
            FSM_WRITE: begin
                lcd_wr    <= 1'b0;    // WR# low, SSD1963 latches data
                fsm_state <= FSM_HOLD;
            end
            FSM_HOLD: begin
                lcd_wr    <= 1'b1;    // WR# high
                fsm_state <= FSM_IDLE;
            end
        endcase
    end
end

wire fsm_busy = (fsm_state != FSM_IDLE);
assign fifo_pop = (fsm_state == FSM_IDLE) & !fifo_empty;

// CTRL_REG bits
reg  ctrl_rst;     // bit0: 0=reset LCD, 1=normal
reg  ctrl_bl;      // bit1: 0=backlight off, 1=on

// STAT_REG bits
wire stat_busy = fsm_busy;    // bit0: 8080 FSM busy
reg  stat_init_done = 1'b0;   // bit1: (reserved for future auto-init)
reg  fsm_started = 1'b0;      // bit2: sticky flag, 1=FSM ever left IDLE
reg  [15:0] fsm_wr_cnt = 16'd0;  // bits[31:16]: 8080 write counter

// Sticky flag: FSM ever started (set on SETUP, cleared only by reset)
always @(posedge aclk)
    if (~aresetn)
        fsm_started <= 1'b0;
    else if (fsm_state == FSM_SETUP)
        fsm_started <= 1'b1;

// Increment write counter when FSM completes a write (HOLD state)
always @(posedge aclk)
    if (~aresetn)
        fsm_wr_cnt <= 16'd0;
    else if (fsm_state == FSM_HOLD)
        fsm_wr_cnt <= fsm_wr_cnt + 16'd1;

// Write registers on w_enter
wire write_ctrl = w_enter & (buf_addr[3:2] == `CTRL_REG_ADDR);

always @(posedge aclk) begin
    if (~aresetn) begin
        ctrl_rst <= 1'b0;    // LCD in reset
        ctrl_bl  <= 1'b1;    // Backlight on by default
    end
    else if (write_ctrl) begin
        ctrl_rst <= s_wdata[0];
        ctrl_bl  <= s_wdata[1];
    end
end

// Drive LCD control outputs from CTRL_REG
always @(posedge aclk) begin
    if (~aresetn)
        lcd_rst <= 1'b0;
    else
        lcd_rst <= ctrl_rst;
end

always @(posedge aclk) begin
    if (~aresetn)
        lcd_bl_ctr <= 1'b1;
    else
        lcd_bl_ctr <= ctrl_bl;
end

//----------------------------------------------------------------------------
// Read path
//----------------------------------------------------------------------------
wire [31:0] rdata_d = (buf_addr[3:2] == `STAT_REG_ADDR) ? {fsm_wr_cnt, 3'd0, fifo_count, 3'd0, fifo_full, fifo_empty, fsm_started, stat_init_done, stat_busy} :
                       (buf_addr[3:2] == `CTRL_REG_ADDR) ? {30'd0, ctrl_bl, ctrl_rst} :
                       32'd0;

reg [31:0] s_rdata;
reg        s_rvalid, s_rlast;

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
reg s_bvalid;

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
// IOBUF for touch MOSI (bidirectional, unused for now)
//----------------------------------------------------------------------------
wire t_mosi_i;
wire t_mosi_o = 1'b0;
wire t_mosi_en = 1'b1;    // High-Z (not driving)
IOBUF t_mosi_iobuf(.IO(lcd_t_mosi), .I(t_mosi_o), .T(t_mosi_en), .O(t_mosi_i));

endmodule
