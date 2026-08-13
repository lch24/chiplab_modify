#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHIPLAB_HOME="$(cd "$SCRIPT_DIR/../../.." && pwd)"

if [ -f "$CHIPLAB_HOME/env.sh" ]; then
    # shellcheck source=/dev/null
    source "$CHIPLAB_HOME/env.sh"
fi

cd "$SCRIPT_DIR"

KIRCHHOFF_HOME="${KIRCHHOFF_HOME:-/home/lch/work/Kirchhoff-II}"
LONGXIN_HOME="${LONGXIN_HOME:-$KIRCHHOFF_HOME/longxin}"
VMLINUX="${VMLINUX:-$LONGXIN_HOME/vmlinux}"
CROSS_COMPILE="${CROSS_COMPILE:-loongarch32r-linux-gnusf-}"

if [ ! -f "$VMLINUX" ]; then
    echo "vmlinux not found: $VMLINUX" >&2
    exit 1
fi

KERNEL_ENTRY_ADDRESS="$("${CROSS_COMPILE}readelf" -s "$VMLINUX" | awk '$NF == "kernel_entry" {print $2; exit}')"
if [ -z "$KERNEL_ENTRY_ADDRESS" ]; then
    KERNEL_ENTRY_ADDRESS="$("${CROSS_COMPILE}readelf" -h "$VMLINUX" | awk '/Entry point address:/ {print $4; exit}')"
    KERNEL_ENTRY_ADDRESS="${KERNEL_ENTRY_ADDRESS#0x}"
fi
if [ -z "$KERNEL_ENTRY_ADDRESS" ]; then
    echo "kernel entry address not found in $VMLINUX" >&2
    exit 1
fi

"${CROSS_COMPILE}gcc" -DKERNEL_ENTRY_ADDRESS=0x"$KERNEL_ENTRY_ADDRESS" -c start.S -o start.o

"${CROSS_COMPILE}objdump" -d start.o > start.s
"${CROSS_COMPILE}objdump" -d "$VMLINUX" > test.s

"${CROSS_COMPILE}objcopy" -O binary -j .text start.o start.bin

"${CROSS_COMPILE}objcopy" -O binary -j .text -j __ex_table -j .notes -j .rodata -j __param -j .sdata \
                                                     -j __modver -j .data -j .data..page_aligned -j .init.text -j .init.data \
                                                     -j .exit.text "$VMLINUX" vmlinux.bin

mkdir -p obj
mv test.s obj/
mv start.s obj/
mv start.bin obj/
cp init_8f.txt obj/
cp init_5f.txt obj/
mv vmlinux.bin obj/
rm start.o
gcc ./convert.c -o convert
mv ./convert obj/
cd obj
./convert
