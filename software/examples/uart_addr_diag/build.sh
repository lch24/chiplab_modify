#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIRCHHOFF_HOME="${KIRCHHOFF_HOME:-/home/lch/work/Kirchhoff-II}"
CHIPLAB_HOME="${CHIPLAB_HOME:-$KIRCHHOFF_HOME/chiplab}"

if [ -f "$CHIPLAB_HOME/env.sh" ]; then
    # shellcheck source=/dev/null
    source "$CHIPLAB_HOME/env.sh"
fi

CROSS_COMPILE="${CROSS_COMPILE:-loongarch32r-linux-gnusf-}"
IMAGE_BASE="${IMAGE_BASE:-0xa0200000}"

mkdir -p "$SCRIPT_DIR/obj"
cd "$SCRIPT_DIR"

build_one() {
    local name="$1"
    local uart_base="$2"
    local msg0="$3"
    local msg1="$4"
    local extra_define="${5:-}"

    "${CROSS_COMPILE}gcc" \
        -DUART_BASE="$uart_base" \
        -DMSG0="$msg0" \
        -DMSG1="$msg1" \
        ${extra_define:+"$extra_define"} \
        -nostdlib -nostartfiles -Wl,-T,linker.ld -Wl,--defsym,IMAGE_BASE="$IMAGE_BASE" \
        start.S -o "obj/$name.elf"
    "${CROSS_COMPILE}objdump" -d "obj/$name.elf" > "obj/$name.s"
    "${CROSS_COMPILE}readelf" -h "obj/$name.elf" > "obj/$name.readelf"
}

build_one uart_bfe_no_setup  0xbfe001e0 0x4e 0x30
build_one uart_bfe_with_dmw  0xbfe001e0 0x44 0x30 -DSET_DMW
build_one uart_1fe_with_dmw  0x1fe001e0 0x4c 0x30 -DSET_DMW

echo "built:"
ls -l obj/*.elf
