# Recreate the MIG-side AXI interconnect as a Vivado 2025.2 standard IP
# Integrator block design.  This script only creates IP sources and the HDL
# wrapper; it does not launch synthesis or implementation.

set script_dir [file normalize [file dirname [info script]]]
set repo_root  [file normalize [file join $script_dir ../../../]]
set ip_dir     [file join $repo_root IP xilinx_ip 2025.2 axi_interconnect_0_clean]
set project    [file join $script_dir system_run.xpr]

file mkdir $ip_dir
create_project -force axi_interconnect_0_ip $ip_dir -part xc7a200tfbg676-2
set_property target_language Verilog [current_project]

create_bd_design axi_interconnect_0_bd
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0

# Match the old 3-to-1 interconnect topology.  Strategy 2 enables the
# crossbar; packet FIFOs provide the supported clock-domain crossings.
set_property -dict [list \
    CONFIG.NUM_SI {3} \
    CONFIG.NUM_MI {1} \
    CONFIG.STRATEGY {2} \
    CONFIG.XBAR_DATA_WIDTH {32} \
    CONFIG.S00_HAS_DATA_FIFO {2} \
    CONFIG.S01_HAS_DATA_FIFO {2} \
    CONFIG.S02_HAS_DATA_FIFO {2} \
    CONFIG.M00_HAS_DATA_FIFO {2}] [get_bd_cells axi_interconnect_0]

foreach intf {S00_AXI S01_AXI S02_AXI M00_AXI} {
    make_bd_intf_pins_external [get_bd_intf_pins axi_interconnect_0/$intf]
    set_property name $intf [get_bd_intf_ports ${intf}_0]
}

# All upstream masters use 4-bit IDs.  AXI Interconnect 2.1 records those IDs
# internally and restores BID/RID on the selected S port.  Its IPI M port is
# intentionally ID-less, so the compatibility wrapper drives MIG ID zero.
set_property -dict [list \
    CONFIG.ADDR_WIDTH {32} \
    CONFIG.DATA_WIDTH {32} \
    CONFIG.ID_WIDTH {4} \
    CONFIG.NUM_READ_THREADS {16} \
    CONFIG.NUM_WRITE_THREADS {16} \
    CONFIG.NUM_READ_OUTSTANDING {4} \
    CONFIG.NUM_WRITE_OUTSTANDING {4}] [get_bd_intf_ports S00_AXI]
set_property -dict [list \
    CONFIG.ADDR_WIDTH {32} \
    CONFIG.DATA_WIDTH {32} \
    CONFIG.ID_WIDTH {4} \
    CONFIG.NUM_READ_THREADS {16} \
    CONFIG.NUM_WRITE_THREADS {16} \
    CONFIG.NUM_READ_OUTSTANDING {2} \
    CONFIG.NUM_WRITE_OUTSTANDING {2}] [get_bd_intf_ports S01_AXI]
set_property -dict [list \
    CONFIG.ADDR_WIDTH {32} \
    CONFIG.DATA_WIDTH {64} \
    CONFIG.ID_WIDTH {4} \
    CONFIG.NUM_READ_THREADS {16} \
    CONFIG.NUM_WRITE_THREADS {16} \
    CONFIG.NUM_READ_OUTSTANDING {2} \
    CONFIG.NUM_WRITE_OUTSTANDING {2}] [get_bd_intf_ports S02_AXI]
set_property -dict [list \
    CONFIG.ADDR_WIDTH {32} \
    CONFIG.DATA_WIDTH {32} \
    CONFIG.NUM_READ_OUTSTANDING {8} \
    CONFIG.NUM_WRITE_OUTSTANDING {8}] [get_bd_intf_ports M00_AXI]

# An external AXI slave port is created with a 64 KiB placeholder address
# block and no master mappings.  ADDR_WIDTH does not enlarge/map that block.
# This interconnect sits immediately in front of MIG and must transparently
# pass the complete 32-bit physical address space for every upstream master.
set mig_addr_seg [get_bd_addr_segs M00_AXI/Reg]
foreach addr_space {S00_AXI S01_AXI S02_AXI} {
    create_bd_addr_seg -offset 0x00000000 -range 4G \
        [get_bd_addr_spaces $addr_space] $mig_addr_seg \
        SEG_MIG_4G
}

foreach pin {ACLK ARESETN S00_ACLK S00_ARESETN S01_ACLK S01_ARESETN S02_ACLK S02_ARESETN M00_ACLK M00_ARESETN} {
    make_bd_pins_external [get_bd_pins axi_interconnect_0/$pin]
    set_property name $pin [get_bd_ports ${pin}_0]
}
set_property CONFIG.ASSOCIATED_RESET {ARESETN}     [get_bd_ports ACLK]
set_property CONFIG.ASSOCIATED_RESET {S00_ARESETN} [get_bd_ports S00_ACLK]
set_property CONFIG.ASSOCIATED_RESET {S01_ARESETN} [get_bd_ports S01_ACLK]
set_property CONFIG.ASSOCIATED_RESET {S02_ARESETN} [get_bd_ports S02_ACLK]
set_property CONFIG.ASSOCIATED_RESET {M00_ARESETN} [get_bd_ports M00_ACLK]

validate_bd_design
save_bd_design
set bd_file [get_files axi_interconnect_0_bd.bd]
generate_target all $bd_file
make_wrapper -files $bd_file -top -force

close_project

# Register the BD and the stable compatibility wrapper in the SoC project.
open_project $project
set old_rtl [file join $repo_root IP AXI axi_interconnect_0.v]
if {[llength [get_files -quiet $old_rtl]] != 0} {
    remove_files [get_files $old_rtl]
}
set bd_path [file join $ip_dir axi_interconnect_0_ip.srcs sources_1 bd axi_interconnect_0_bd axi_interconnect_0_bd.bd]
# Re-adding the BD makes Vivado discard obsolete generated sub-IP filesets
# when the expanded Interconnect hierarchy changes between generations.
# Keeping an already registered external BD can leave stale OOC XDC entries
# in the top synthesis launch script (for example the removed *_mmu_0 IPs).
set registered_bd [get_files -quiet *axi_interconnect_0_bd.bd]
if {[llength $registered_bd] != 0} {
    remove_files $registered_bd
}
add_files -norecurse -fileset sources_1 $bd_path
# Re-register generated sub-IPs after recreating the BD project so stale
# filesets from an earlier generation are not carried into synthesis.
generate_target all [get_files $bd_path]
set compat_wrapper [file join $repo_root IP AXI axi_interconnect_0_2025_wrapper.v]
if {[llength [get_files -quiet $compat_wrapper]] == 0} {
    add_files -norecurse -fileset sources_1 $compat_wrapper
}
update_compile_order -fileset sources_1
close_project
