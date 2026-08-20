`include "config.h"

`ifndef KIRCHHOFF_CPU
`define KIRCHHOFF_CPU
`endif

`ifdef KIRCHHOFF_CPU

module kirchhoff_core_top #(
    parameter TLBNUM = 32
)(
    input           aclk,
    input           aresetn,
    input    [ 7:0] intrpt,

    output   [ 3:0] arid,
    output   [31:0] araddr,
    output   [ 7:0] arlen,
    output   [ 2:0] arsize,
    output   [ 1:0] arburst,
    output   [ 1:0] arlock,
    output   [ 3:0] arcache,
    output   [ 2:0] arprot,
    output          arvalid,
    input           arready,

    input    [ 3:0] rid,
    input    [31:0] rdata,
    input    [ 1:0] rresp,
    input           rlast,
    input           rvalid,
    output          rready,

    output   [ 3:0] awid,
    output   [31:0] awaddr,
    output   [ 7:0] awlen,
    output   [ 2:0] awsize,
    output   [ 1:0] awburst,
    output   [ 1:0] awlock,
    output   [ 3:0] awcache,
    output   [ 2:0] awprot,
    output          awvalid,
    input           awready,

    output   [ 3:0] wid,
    output   [31:0] wdata,
    output   [ 3:0] wstrb,
    output          wlast,
    output          wvalid,
    input           wready,

    input    [ 3:0] bid,
    input    [ 1:0] bresp,
    input           bvalid,
    output          bready,

    input           break_point,
    input           infor_flag,
    input    [ 4:0] reg_num,
    output          ws_valid,
    output   [31:0] rf_rdata,

    output   [31:0] debug0_wb_pc,
    output   [ 3:0] debug0_wb_rf_wen,
    output   [ 4:0] debug0_wb_rf_wnum,
    output   [31:0] debug0_wb_rf_wdata,
    output   [31:0] debug0_wb_inst,
    output          diag_commit_valid,
    output   [31:0] diag_commit_pc,
    output   [31:0] diag_rob_head_pc,
    output   [31:0] diag_rob_status,
    output   [31:0] diag_sb_head_paddr,
    output   [31:0] diag_sb_status,
    output   [31:0] diag_mshr_status,
    output   [31:0] diag_dcache_status,
    output   [31:0] diag_csr_era,
    output   [31:0] diag_csr_eentry,
    output   [31:0] diag_csr_boundary_pc,
    output   [31:0] diag_csr_vector_pc,
    output   [31:0] diag_csr_crmd,
    output   [31:0] diag_csr_prmd,
    output   [31:0] diag_csr_estat,
    output   [31:0] diag_csr_badv,
    output   [31:0] diag_csr_tlbrentry
`ifdef CPU_2CMT
   ,
    output   [31:0] debug1_wb_pc,
    output   [ 3:0] debug1_wb_rf_wen,
    output   [ 4:0] debug1_wb_rf_wnum,
    output   [31:0] debug1_wb_rf_wdata
`endif
);

    wire reset = ~aresetn;

`ifdef DIFFTEST_EN
    wire        cmt0_valid;
    wire [31:0] cmt0_pc;
    wire [31:0] cmt0_inst;
    wire        cmt0_dest_valid;
    wire [ 4:0] cmt0_dest;
    wire [31:0] cmt0_wdata;
    wire        cmt0_is_tlbfill;
    wire [ 4:0] cmt0_tlbfill_index;
    wire        cmt0_is_cnt;
    wire [63:0] cmt0_timer64;
    wire        cmt0_csr_rstat;
    wire [31:0] cmt0_csr_data;
    wire [ 7:0] cmt0_load_type;
    wire [31:0] cmt0_load_vaddr;
    wire [31:0] cmt0_load_paddr;
    wire [ 7:0] cmt0_store_type;
    wire [31:0] cmt0_store_vaddr;
    wire [31:0] cmt0_store_paddr;
    wire [31:0] cmt0_store_data;

    wire        cmt1_valid;
    wire [31:0] cmt1_pc;
    wire [31:0] cmt1_inst;
    wire        cmt1_dest_valid;
    wire [ 4:0] cmt1_dest;
    wire [31:0] cmt1_wdata;
    wire        cmt1_is_tlbfill;
    wire [ 4:0] cmt1_tlbfill_index;
    wire        cmt1_is_cnt;
    wire [63:0] cmt1_timer64;
    wire        cmt1_csr_rstat;
    wire [31:0] cmt1_csr_data;
    wire [ 7:0] cmt1_load_type;
    wire [31:0] cmt1_load_vaddr;
    wire [31:0] cmt1_load_paddr;
    wire [ 7:0] cmt1_store_type;
    wire [31:0] cmt1_store_vaddr;
    wire [31:0] cmt1_store_paddr;
    wire [31:0] cmt1_store_data;

    wire [31:0] diff_gpr [0:31];

    wire [31:0] csr_crmd;
    wire [31:0] csr_prmd;
    wire [31:0] csr_ecfg;
    wire [31:0] csr_estat;
    wire [31:0] csr_era;
    wire [31:0] csr_badv;
    wire [31:0] csr_eentry;
    wire [31:0] csr_tlbidx;
    wire [31:0] csr_tlbehi;
    wire [31:0] csr_tlbelo0;
    wire [31:0] csr_tlbelo1;
    wire [31:0] csr_asid;
    wire [31:0] csr_pgdl;
    wire [31:0] csr_pgdh;
    wire [31:0] csr_pgd;
    wire [31:0] csr_tlbrentry;
    wire [31:0] csr_dmw0;
    wire [31:0] csr_dmw1;
    wire [31:0] csr_save0;
    wire [31:0] csr_save1;
    wire [31:0] csr_save2;
    wire [31:0] csr_save3;
    wire [31:0] csr_tid;
    wire [31:0] csr_tcfg;
    wire [31:0] csr_tval;
    wire [31:0] csr_cntc;
    wire [31:0] csr_llbctl;
    wire [63:0] csr_timer64;
    wire [31:0] csr_lladdr;
    wire        csr_disable_cache;
    wire        diff_excp_valid;
    wire        diff_excp_eret;
    wire [31:0] diff_excp_cause;
    wire [31:0] diff_excp_pc;
    wire [31:0] diff_excp_inst;
`endif

    CoreTop u_core (
        .clock                         (aclk),
        .reset                         (reset),
        .io_axi_ar_ready               (arready),
        .io_axi_ar_valid               (arvalid),
        .io_axi_ar_bits_id             (arid),
        .io_axi_ar_bits_addr           (araddr),
        .io_axi_ar_bits_len            (arlen),
        .io_axi_ar_bits_size           (arsize),
        .io_axi_ar_bits_burst          (arburst),
        .io_axi_ar_bits_lock           (arlock),
        .io_axi_ar_bits_cache          (arcache),
        .io_axi_ar_bits_prot           (arprot),
        .io_axi_r_ready                (rready),
        .io_axi_r_valid                (rvalid),
        .io_axi_r_bits_id              (rid),
        .io_axi_r_bits_data            (rdata),
        .io_axi_r_bits_resp            (rresp),
        .io_axi_r_bits_last            (rlast),
        .io_axi_aw_ready               (awready),
        .io_axi_aw_valid               (awvalid),
        .io_axi_aw_bits_id             (awid),
        .io_axi_aw_bits_addr           (awaddr),
        .io_axi_aw_bits_len            (awlen),
        .io_axi_aw_bits_size           (awsize),
        .io_axi_aw_bits_burst          (awburst),
        .io_axi_aw_bits_lock           (awlock),
        .io_axi_aw_bits_cache          (awcache),
        .io_axi_aw_bits_prot           (awprot),
        .io_axi_w_ready                (wready),
        .io_axi_w_valid                (wvalid),
        .io_axi_w_bits_id              (wid),
        .io_axi_w_bits_data            (wdata),
        .io_axi_w_bits_strb            (wstrb),
        .io_axi_w_bits_last            (wlast),
        .io_axi_b_ready                (bready),
        .io_axi_b_valid                (bvalid),
        .io_axi_b_bits_id              (bid),
        .io_axi_b_bits_resp            (bresp),
        .io_extInterrupt               (intrpt)
       ,.io_diagCommitValid            (diag_commit_valid)
       ,.io_diagCommitPc               (diag_commit_pc)
       ,.io_diagRobHeadPc              (diag_rob_head_pc)
       ,.io_diagRobStatus              (diag_rob_status)
       ,.io_diagSbHeadPaddr            (diag_sb_head_paddr)
       ,.io_diagSbStatus               (diag_sb_status)
       ,.io_diagMshrStatus             (diag_mshr_status)
       ,.io_diagDcacheStatus           (diag_dcache_status)
       ,.io_diagCsrEra                 (diag_csr_era)
       ,.io_diagCsrEentry              (diag_csr_eentry)
       ,.io_diagCsrBoundaryPc          (diag_csr_boundary_pc)
       ,.io_diagCsrVectorPc            (diag_csr_vector_pc)
       ,.io_diagCsrCrmd                (diag_csr_crmd)
       ,.io_diagCsrPrmd                (diag_csr_prmd)
       ,.io_diagCsrEstat               (diag_csr_estat)
       ,.io_diagCsrBadv                (diag_csr_badv)
       ,.io_diagCsrTlbrentry           (diag_csr_tlbrentry)
`ifdef DIFFTEST_EN
       ,
        .io_diffTest_0_valid           (cmt0_valid),
        .io_diffTest_0_bits_pc         (cmt0_pc),
        .io_diffTest_0_bits_instWord   (cmt0_inst),
        .io_diffTest_0_bits_destValid  (cmt0_dest_valid),
        .io_diffTest_0_bits_destLreg   (cmt0_dest),
        .io_diffTest_0_bits_writebackValue(cmt0_wdata),
        .io_diffTest_1_valid           (cmt1_valid),
        .io_diffTest_1_bits_pc         (cmt1_pc),
        .io_diffTest_1_bits_instWord   (cmt1_inst),
        .io_diffTest_1_bits_destValid  (cmt1_dest_valid),
        .io_diffTest_1_bits_destLreg   (cmt1_dest),
        .io_diffTest_1_bits_writebackValue(cmt1_wdata),
        .io_diffTest_0_bits_isTlbFill  (cmt0_is_tlbfill),
        .io_diffTest_0_bits_tlbFillIndex(cmt0_tlbfill_index),
        .io_diffTest_0_bits_isCntInst  (cmt0_is_cnt),
        .io_diffTest_0_bits_timer64    (cmt0_timer64),
        .io_diffTest_0_bits_csrRstat   (cmt0_csr_rstat),
        .io_diffTest_0_bits_csrData    (cmt0_csr_data),
        .io_diffTest_0_bits_loadType   (cmt0_load_type),
        .io_diffTest_0_bits_loadVaddr  (cmt0_load_vaddr),
        .io_diffTest_0_bits_loadPaddr  (cmt0_load_paddr),
        .io_diffTest_0_bits_storeType  (cmt0_store_type),
        .io_diffTest_0_bits_storeVaddr (cmt0_store_vaddr),
        .io_diffTest_0_bits_storePaddr (cmt0_store_paddr),
        .io_diffTest_0_bits_storeData  (cmt0_store_data),
        .io_diffTest_1_bits_isTlbFill  (cmt1_is_tlbfill),
        .io_diffTest_1_bits_tlbFillIndex(cmt1_tlbfill_index),
        .io_diffTest_1_bits_isCntInst  (cmt1_is_cnt),
        .io_diffTest_1_bits_timer64    (cmt1_timer64),
        .io_diffTest_1_bits_csrRstat   (cmt1_csr_rstat),
        .io_diffTest_1_bits_csrData    (cmt1_csr_data),
        .io_diffTest_1_bits_loadType   (cmt1_load_type),
        .io_diffTest_1_bits_loadVaddr  (cmt1_load_vaddr),
        .io_diffTest_1_bits_loadPaddr  (cmt1_load_paddr),
        .io_diffTest_1_bits_storeType  (cmt1_store_type),
        .io_diffTest_1_bits_storeVaddr (cmt1_store_vaddr),
        .io_diffTest_1_bits_storePaddr (cmt1_store_paddr),
        .io_diffTest_1_bits_storeData  (cmt1_store_data),
        .io_diffGpr_0                  (diff_gpr[0]),
        .io_diffGpr_1                  (diff_gpr[1]),
        .io_diffGpr_2                  (diff_gpr[2]),
        .io_diffGpr_3                  (diff_gpr[3]),
        .io_diffGpr_4                  (diff_gpr[4]),
        .io_diffGpr_5                  (diff_gpr[5]),
        .io_diffGpr_6                  (diff_gpr[6]),
        .io_diffGpr_7                  (diff_gpr[7]),
        .io_diffGpr_8                  (diff_gpr[8]),
        .io_diffGpr_9                  (diff_gpr[9]),
        .io_diffGpr_10                 (diff_gpr[10]),
        .io_diffGpr_11                 (diff_gpr[11]),
        .io_diffGpr_12                 (diff_gpr[12]),
        .io_diffGpr_13                 (diff_gpr[13]),
        .io_diffGpr_14                 (diff_gpr[14]),
        .io_diffGpr_15                 (diff_gpr[15]),
        .io_diffGpr_16                 (diff_gpr[16]),
        .io_diffGpr_17                 (diff_gpr[17]),
        .io_diffGpr_18                 (diff_gpr[18]),
        .io_diffGpr_19                 (diff_gpr[19]),
        .io_diffGpr_20                 (diff_gpr[20]),
        .io_diffGpr_21                 (diff_gpr[21]),
        .io_diffGpr_22                 (diff_gpr[22]),
        .io_diffGpr_23                 (diff_gpr[23]),
        .io_diffGpr_24                 (diff_gpr[24]),
        .io_diffGpr_25                 (diff_gpr[25]),
        .io_diffGpr_26                 (diff_gpr[26]),
        .io_diffGpr_27                 (diff_gpr[27]),
        .io_diffGpr_28                 (diff_gpr[28]),
        .io_diffGpr_29                 (diff_gpr[29]),
        .io_diffGpr_30                 (diff_gpr[30]),
        .io_diffGpr_31                 (diff_gpr[31]),
        .io_diffCsr_crmd               (csr_crmd),
        .io_diffCsr_prmd               (csr_prmd),
        .io_diffCsr_ecfg               (csr_ecfg),
        .io_diffCsr_estat              (csr_estat),
        .io_diffCsr_era                (csr_era),
        .io_diffCsr_badv               (csr_badv),
        .io_diffCsr_eentry             (csr_eentry),
        .io_diffCsr_tlbidx             (csr_tlbidx),
        .io_diffCsr_tlbehi             (csr_tlbehi),
        .io_diffCsr_tlbelo0            (csr_tlbelo0),
        .io_diffCsr_tlbelo1            (csr_tlbelo1),
        .io_diffCsr_asid               (csr_asid),
        .io_diffCsr_pgdl               (csr_pgdl),
        .io_diffCsr_pgdh               (csr_pgdh),
        .io_diffCsr_pgd                (csr_pgd),
        .io_diffCsr_tlbrentry          (csr_tlbrentry),
        .io_diffCsr_dmw0               (csr_dmw0),
        .io_diffCsr_dmw1               (csr_dmw1),
        .io_diffCsr_save0              (csr_save0),
        .io_diffCsr_save1              (csr_save1),
        .io_diffCsr_save2              (csr_save2),
        .io_diffCsr_save3              (csr_save3),
        .io_diffCsr_tid                (csr_tid),
        .io_diffCsr_tcfg               (csr_tcfg),
        .io_diffCsr_tval               (csr_tval),
        .io_diffCsr_cntc               (csr_cntc),
        .io_diffCsr_llbctl             (csr_llbctl),
        .io_diffCsr_timer64            (csr_timer64),
        .io_diffCsr_lladdr             (csr_lladdr),
        .io_diffCsr_disableCache       (csr_disable_cache),
        .io_diffExcp_valid             (diff_excp_valid),
        .io_diffExcp_bits_eret         (diff_excp_eret),
        .io_diffExcp_bits_cause        (diff_excp_cause),
        .io_diffExcp_bits_pc           (diff_excp_pc),
        .io_diffExcp_bits_instWord     (diff_excp_inst)
`endif
    );

`ifdef DIFFTEST_EN
    wire cmt0_wen = cmt0_valid & cmt0_dest_valid & (cmt0_dest != 5'd0);
    wire cmt1_wen = cmt1_valid & cmt1_dest_valid & (cmt1_dest != 5'd0);

    assign debug0_wb_rf_wen   = {4{cmt0_wen}};
    assign debug0_wb_rf_wnum  = cmt0_dest;
    assign debug0_wb_rf_wdata = cmt0_wdata;
    assign debug0_wb_inst     = cmt0_inst;

`ifdef CPU_2CMT
    assign debug1_wb_pc       = cmt1_pc;
    assign debug1_wb_rf_wen   = {4{cmt1_wen}};
    assign debug1_wb_rf_wnum  = cmt1_dest;
    assign debug1_wb_rf_wdata = cmt1_wdata;
`endif
`else
    assign debug0_wb_rf_wen   = 4'b0;
    assign debug0_wb_rf_wnum  = 5'b0;
    assign debug0_wb_rf_wdata = 32'b0;
    assign debug0_wb_inst     = 32'b0;

`ifdef CPU_2CMT
    assign debug1_wb_pc       = 32'b0;
    assign debug1_wb_rf_wen   = 4'b0;
    assign debug1_wb_rf_wnum  = 5'b0;
    assign debug1_wb_rf_wdata = 32'b0;
`endif
`endif

    assign debug0_wb_pc = 32'b0;
    assign ws_valid     = 1'b0;

    assign rf_rdata           = 32'b0;

`ifdef DIFFTEST_EN
    reg [63:0] cycleCnt;
    reg [63:0] instrCnt;

    wire [1:0] cmt_count = {1'b0, cmt0_valid} + {1'b0, cmt1_valid};
    reg        cmt_excp_valid;
    reg        cmt_excp_eret;
    reg [31:0] cmt_excp_cause;
    reg [31:0] cmt_excp_pc;
    reg [31:0] cmt_excp_inst;

    always @(posedge aclk) begin
        if (reset) begin
            cycleCnt <= 64'b0;
            instrCnt <= 64'b0;
            cmt_excp_valid <= 1'b0;
            cmt_excp_eret  <= 1'b0;
            cmt_excp_cause <= 32'b0;
            cmt_excp_pc    <= 32'b0;
            cmt_excp_inst  <= 32'b0;
        end else begin
            cycleCnt <= cycleCnt + 64'd1;
            instrCnt <= instrCnt + {62'b0, cmt_count};
            cmt_excp_valid <= diff_excp_valid;
            cmt_excp_eret  <= diff_excp_eret;
            cmt_excp_cause <= diff_excp_cause;
            cmt_excp_pc    <= diff_excp_pc;
            cmt_excp_inst  <= diff_excp_inst;
        end
    end

    DifftestInstrCommit DifftestInstrCommit_0 (
        .clock          (aclk),
        .coreid         (8'd0),
        .index          (8'd0),
        .valid          (cmt0_valid),
        .pc             ({32'b0, cmt0_pc}),
        .instr          (cmt0_inst),
        .skip           (1'b0),
        .is_TLBFILL     (cmt0_is_tlbfill),
        .TLBFILL_index  (cmt0_tlbfill_index),
        .is_CNTinst     (cmt0_is_cnt),
        .timer_64_value (cmt0_timer64),
        .wen            (cmt0_wen),
        .wdest          ({3'b0, cmt0_dest}),
        .wdata          ({32'b0, cmt0_wdata}),
        .csr_rstat      (cmt0_csr_rstat),
        .csr_data       (cmt0_csr_data)
    );

    DifftestInstrCommit DifftestInstrCommit_1 (
        .clock          (aclk),
        .coreid         (8'd0),
        .index          (8'd1),
        .valid          (cmt1_valid),
        .pc             ({32'b0, cmt1_pc}),
        .instr          (cmt1_inst),
        .skip           (1'b0),
        .is_TLBFILL     (cmt1_is_tlbfill),
        .TLBFILL_index  (cmt1_tlbfill_index),
        .is_CNTinst     (cmt1_is_cnt),
        .timer_64_value (cmt1_timer64),
        .wen            (cmt1_wen),
        .wdest          ({3'b0, cmt1_dest}),
        .wdata          ({32'b0, cmt1_wdata}),
        .csr_rstat      (cmt1_csr_rstat),
        .csr_data       (cmt1_csr_data)
    );

    DifftestExcpEvent DifftestExcpEvent (
        .clock          (aclk),
        .coreid         (8'd0),
        .excp_valid     (cmt_excp_valid),
        .eret           (cmt_excp_eret),
        .intrNo         ({21'b0, csr_estat[12:2]}),
        .cause          (cmt_excp_cause),
        .exceptionPC    ({32'b0, cmt_excp_pc}),
        .exceptionInst  (cmt_excp_inst)
    );

    DifftestTrapEvent DifftestTrapEvent (
        .clock          (aclk),
        .coreid         (8'd0),
        .valid          (1'b0),
        .code           (3'b0),
        .pc             ({32'b0, cmt0_pc}),
        .cycleCnt       (cycleCnt),
        .instrCnt       (instrCnt)
    );

    DifftestStoreEvent DifftestStoreEvent_0 (
        .clock          (aclk),
        .coreid         (8'd0),
        .index          (8'd0),
        .valid          (cmt0_store_type),
        .storePAddr     ({32'b0, cmt0_store_paddr}),
        .storeVAddr     ({32'b0, cmt0_store_vaddr}),
        .storeData      ({32'b0, cmt0_store_data})
    );

    DifftestStoreEvent DifftestStoreEvent_1 (
        .clock          (aclk),
        .coreid         (8'd0),
        .index          (8'd1),
        .valid          (cmt1_store_type),
        .storePAddr     ({32'b0, cmt1_store_paddr}),
        .storeVAddr     ({32'b0, cmt1_store_vaddr}),
        .storeData      ({32'b0, cmt1_store_data})
    );

    DifftestLoadEvent DifftestLoadEvent_0 (
        .clock          (aclk),
        .coreid         (8'd0),
        .index          (8'd0),
        .valid          (cmt0_load_type),
        .paddr          ({32'b0, cmt0_load_paddr}),
        .vaddr          ({32'b0, cmt0_load_vaddr})
    );

    DifftestLoadEvent DifftestLoadEvent_1 (
        .clock          (aclk),
        .coreid         (8'd0),
        .index          (8'd1),
        .valid          (cmt1_load_type),
        .paddr          ({32'b0, cmt1_load_paddr}),
        .vaddr          ({32'b0, cmt1_load_vaddr})
    );

    DifftestCSRRegState DifftestCSRRegState (
        .clock          (aclk),
        .coreid         (8'd0),
        .crmd           ({32'b0, csr_crmd}),
        .prmd           ({32'b0, csr_prmd}),
        .euen           (64'b0),
        .ecfg           ({32'b0, csr_ecfg}),
        .estat          ({32'b0, csr_estat}),
        .era            ({32'b0, csr_era}),
        .badv           ({32'b0, csr_badv}),
        .eentry         ({32'b0, csr_eentry}),
        .tlbidx         ({32'b0, csr_tlbidx}),
        .tlbehi         ({32'b0, csr_tlbehi}),
        .tlbelo0        ({32'b0, csr_tlbelo0}),
        .tlbelo1        ({32'b0, csr_tlbelo1}),
        .asid           ({32'b0, csr_asid}),
        .pgdl           ({32'b0, csr_pgdl}),
        .pgdh           ({32'b0, csr_pgdh}),
        .save0          ({32'b0, csr_save0}),
        .save1          ({32'b0, csr_save1}),
        .save2          ({32'b0, csr_save2}),
        .save3          ({32'b0, csr_save3}),
        .tid            ({32'b0, csr_tid}),
        .tcfg           ({32'b0, csr_tcfg}),
        .tval           ({32'b0, csr_tval}),
        .ticlr          (64'b0),
        .llbctl         ({32'b0, csr_llbctl}),
        .tlbrentry      ({32'b0, csr_tlbrentry}),
        .dmw0           ({32'b0, csr_dmw0}),
        .dmw1           ({32'b0, csr_dmw1})
    );

    DifftestGRegState DifftestGRegState (
        .clock          (aclk),
        .coreid         (8'd0),
        .gpr_0          ({32'b0, diff_gpr[0]}),
        .gpr_1          ({32'b0, diff_gpr[1]}),
        .gpr_2          ({32'b0, diff_gpr[2]}),
        .gpr_3          ({32'b0, diff_gpr[3]}),
        .gpr_4          ({32'b0, diff_gpr[4]}),
        .gpr_5          ({32'b0, diff_gpr[5]}),
        .gpr_6          ({32'b0, diff_gpr[6]}),
        .gpr_7          ({32'b0, diff_gpr[7]}),
        .gpr_8          ({32'b0, diff_gpr[8]}),
        .gpr_9          ({32'b0, diff_gpr[9]}),
        .gpr_10         ({32'b0, diff_gpr[10]}),
        .gpr_11         ({32'b0, diff_gpr[11]}),
        .gpr_12         ({32'b0, diff_gpr[12]}),
        .gpr_13         ({32'b0, diff_gpr[13]}),
        .gpr_14         ({32'b0, diff_gpr[14]}),
        .gpr_15         ({32'b0, diff_gpr[15]}),
        .gpr_16         ({32'b0, diff_gpr[16]}),
        .gpr_17         ({32'b0, diff_gpr[17]}),
        .gpr_18         ({32'b0, diff_gpr[18]}),
        .gpr_19         ({32'b0, diff_gpr[19]}),
        .gpr_20         ({32'b0, diff_gpr[20]}),
        .gpr_21         ({32'b0, diff_gpr[21]}),
        .gpr_22         ({32'b0, diff_gpr[22]}),
        .gpr_23         ({32'b0, diff_gpr[23]}),
        .gpr_24         ({32'b0, diff_gpr[24]}),
        .gpr_25         ({32'b0, diff_gpr[25]}),
        .gpr_26         ({32'b0, diff_gpr[26]}),
        .gpr_27         ({32'b0, diff_gpr[27]}),
        .gpr_28         ({32'b0, diff_gpr[28]}),
        .gpr_29         ({32'b0, diff_gpr[29]}),
        .gpr_30         ({32'b0, diff_gpr[30]}),
        .gpr_31         ({32'b0, diff_gpr[31]})
    );
`endif

endmodule

`endif
