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

mkdir -p "$SCRIPT_DIR/obj"
cd "$SCRIPT_DIR"

build_one() {
    local name="$1"
    local image_base="$2"
    local dst_byte="$3"
    local dst_word="$4"
    local ddr_pat="$5"

    "${CROSS_COMPILE}gcc" \
        -DDST_BYTE="$dst_byte" -DDST_WORD="$dst_word" -DDDR_PAT="$ddr_pat" \
        -nostdlib -nostartfiles -Wl,-T,linker.ld -Wl,--defsym,IMAGE_BASE="$image_base" \
        start.S -o "obj/$name.elf"
    "${CROSS_COMPILE}objdump" -d "obj/$name.elf" > "obj/$name.s"
    "${CROSS_COMPILE}readelf" -h "obj/$name.elf" > "obj/$name.readelf"
}

build_one rom_ddr_diag_a040 0xa0200000 0xa0400000 0xa0500000 0xa0600000
build_one rom_ddr_diag_a020 0xa0300000 0xa0200000 0xa0260000 0xa02c0000

echo "built:"
ls -l "$SCRIPT_DIR"/obj/*.elf
