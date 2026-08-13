#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
sim_dir="$repo_root/chiplab_modify/sim"
mig_root="$repo_root/chiplab_modify/IP/xilinx_ip/2023.2/mig_axi_32_loongson/mig_axi_32"
xsim_dir="$repo_root/chiplab_modify/fpga/loongson/2023.2/system_run.ip_user_files/sim_scripts/mig_axi_32_loongson/xsim"

cd "$xsim_dir"
./mig_axi_32.sh -step compile
xvlog --relax -work xil_defaultlib \
  "$repo_root/chiplab_modify/IP/AXI/axi_interconnect_0.v" \
  "$sim_dir/axi_interconnect_mig_joint_top.v"
xvlog --relax -sv -d x1Gb -d sg125 -d x16 -i "$mig_root/example_design/sim" \
  -work xil_defaultlib "$mig_root/example_design/sim/ddr3_model.sv"
xvlog --relax -work xil_defaultlib \
  "$mig_root/example_design/sim/wiredly.v" \
  "$mig_root/example_design/sim/sim_tb_top.v"
xelab --relax --debug typical --mt auto \
  -L xil_defaultlib -L unisims_ver -L unimacro_ver -L secureip \
  --snapshot axi_interconnect_mig_joint_sim \
  xil_defaultlib.sim_tb_top xil_defaultlib.glbl
xsim axi_interconnect_mig_joint_sim -runall -onerror quit
