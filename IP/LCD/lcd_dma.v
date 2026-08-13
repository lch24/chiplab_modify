module lcd_dma(
    input         aclk,
    input         aresetn,

    input         start,
    input  [31:0] fb_addr,
    input  [31:0] pixel_count,
    output        busy,
    output reg    done,
    output reg    error,

    output [3:0]  arid,
    output [31:0] araddr,
    output [3:0]  arlen,
    output [2:0]  arsize,
    output [1:0]  arburst,
    output        arlock,
    output [3:0]  arcache,
    output [2:0]  arprot,
    output        arvalid,
    input         arready,

    input  [3:0]  rid,
    input  [63:0] rdata,
    input  [1:0]  rresp,
    input         rlast,
    input         rvalid,
    output        rready,

    output [15:0] pixel_data,
    output        pixel_valid,
    input         pixel_ready
);

localparam ST_IDLE = 2'd0;
localparam ST_AR   = 2'd1;
localparam ST_R    = 2'd2;
localparam ST_OUT  = 2'd3;

localparam [4:0] MAX_BURST_BEATS = 5'd16;

reg [1:0] state;
reg [31:0] next_addr;
reg [31:0] pixels_left;
reg [31:0] beats_left;
reg [4:0]  beats_inflight;
reg [63:0] beat_buf;
reg [1:0]  pix_sel;
reg [2:0]  pix_in_buf;

wire start_pulse = start & (state == ST_IDLE);
wire [31:0] total_beats = {2'b0, pixel_count[31:2]} +
                          ((pixel_count[1:0] != 2'b0) ? 32'd1 : 32'd0);
wire [4:0] next_burst_beats = (beats_left > MAX_BURST_BEATS) ?
                              MAX_BURST_BEATS[4:0] : beats_left[4:0];

assign busy = (state != ST_IDLE);

assign arid     = 4'd0;
assign araddr   = next_addr;
assign arlen    = next_burst_beats - 1'b1;
assign arsize   = 3'd3;       // 64-bit AXI read beat
assign arburst  = 2'b01;      // INCR
assign arlock   = 1'b0;
assign arcache  = 4'b0011;
assign arprot   = 3'b000;
assign arvalid  = (state == ST_AR);

assign rready = (state == ST_R);

assign pixel_valid = (state == ST_OUT) & (pix_in_buf != 3'd0);
assign pixel_data  = (pix_sel == 2'd0) ? beat_buf[15:0]  :
                     (pix_sel == 2'd1) ? beat_buf[31:16] :
                     (pix_sel == 2'd2) ? beat_buf[47:32] :
                                         beat_buf[63:48];

always @(posedge aclk) begin
    if (~aresetn) begin
        state          <= ST_IDLE;
        next_addr      <= 32'd0;
        pixels_left    <= 32'd0;
        beats_left     <= 32'd0;
        beats_inflight <= 5'd0;
        beat_buf       <= 64'd0;
        pix_sel        <= 2'd0;
        pix_in_buf     <= 3'd0;
        done           <= 1'b0;
        error          <= 1'b0;
    end
    else begin
        done <= 1'b0;

        case (state)
            ST_IDLE: begin
                if (start_pulse) begin
                    next_addr   <= fb_addr;
                    pixels_left <= pixel_count;
                    beats_left  <= total_beats;
                    error       <= 1'b0;
                    if (pixel_count == 32'd0) begin
                        done <= 1'b1;
                    end
                    else begin
                        state <= ST_AR;
                    end
                end
            end

            ST_AR: begin
                if (arvalid & arready) begin
                    beats_inflight <= next_burst_beats;
                    beats_left     <= beats_left - next_burst_beats;
                    next_addr      <= next_addr + {next_burst_beats, 3'b000};
                    state          <= ST_R;
                end
            end

            ST_R: begin
                if (rvalid & rready) begin
                    beat_buf   <= rdata;
                    pix_sel    <= 2'd0;
                    pix_in_buf <= (pixels_left >= 32'd4) ? 3'd4 : {1'b0, pixels_left[1:0]};
                    if (rresp != 2'b00)
                        error <= 1'b1;

                    pixels_left    <= (pixels_left >= 32'd4) ? (pixels_left - 32'd4) : 32'd0;
                    beats_inflight <= beats_inflight - 1'b1;
                    state          <= ST_OUT;
                end
            end

            ST_OUT: begin
                if (pixel_valid & pixel_ready) begin
                    pix_sel    <= pix_sel + 1'b1;
                    pix_in_buf <= pix_in_buf - 1'b1;
                    if (pix_in_buf == 3'd1) begin
                        if (beats_inflight != 5'd0)
                            state <= ST_R;
                        else if (beats_left != 32'd0)
                            state <= ST_AR;
                        else begin
                            done  <= 1'b1;
                            state <= ST_IDLE;
                        end
                    end
                end
            end
        endcase
    end
end

endmodule
