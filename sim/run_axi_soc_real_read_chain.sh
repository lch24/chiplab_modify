#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
vivado_bin="${VIVADO_BIN:-/opt/vivado/2025.2/Vivado/bin}"
sim_work="${TMPDIR:-/tmp}/kirchhoff-real-read-chain-${USER:-user}-$$"
bd_root="$repo_root/chiplab_modify/IP/xilinx_ip/2025.2/axi_interconnect_0_clean/axi_interconnect_0_ip.gen/sources_1/bd/axi_interconnect_0_bd"
mkdir -p "$sim_work"
cd "$sim_work"

mapfile -t bd_files < <(find "$bd_root" -type f -path '*/sim/*.v' | sort)

"$vivado_bin/xvlog" --sv \
  -i "$repo_root/chiplab_modify/chip/soc_demo/loongson" \
  "$repo_root/chiplab_modify/IP/xilinx_ip/2025.2/axi_2x1_mux_2025/sim/axi_2x1_mux_2025.v" \
  "$repo_root/chiplab_modify/IP/AXI/axi_2x1_mux_2025_wrapper.v" \
  "$repo_root/chiplab_modify/fpga/loongson/2023.2/system_run.ip_user_files/ip/axi_clock_converter_0/sim/axi_clock_converter_0.v" \
  "$repo_root/chiplab_modify/IP/AMBA/axi_mux_syn.v" \
  "$repo_root/chiplab_modify/IP/AXI/axi_interconnect_0_2025_wrapper.v" \
  "${bd_files[@]}" \
  "$repo_root/chiplab_modify/sim/axi_soc_real_read_chain_tb.sv" \
  /opt/vivado/2025.2/Vivado/data/verilog/src/glbl.v

"$vivado_bin/xelab" axi_soc_real_read_chain_tb glbl \
  -s real_read_chain --debug typical --relax \
  -L generic_baseblocks_v2_1_2 \
  -L axi_infrastructure_v1_1_0 \
  -L fifo_generator_v13_2_14 \
  -L blk_mem_gen_v8_4_12 \
  -L axi_data_fifo_v2_1_36 \
  -L axi_register_slice_v2_1_36 \
  -L axi_crossbar_v2_1_38 \
  -L axi_dwidth_converter_v2_1_37 \
  -L axi_clock_converter_v2_1_35 \
  -L unisims_ver -L unimacro_ver -L secureip

"$vivado_bin/xsim" real_read_chain \
  -tclbatch "$repo_root/chiplab_modify/sim/xsim_run_all.tcl" | tee run.log

# XSim can return zero after a SystemVerilog $fatal followed by $finish, so the
# transcript is part of the regression result rather than informational only.
if rg -q 'Fatal:|ERROR:' run.log || ! rg -q '^PASS: real CPU read chain' run.log; then
  echo "FAIL: see $sim_work/run.log and $sim_work/xsim.dir/real_read_chain.wdb" >&2
  exit 1
fi

echo "Simulation artifacts: $sim_work"
