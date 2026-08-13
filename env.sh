#!/usr/bin/env bash

export KIRCHHOFF_HOME="${KIRCHHOFF_HOME:-/home/lch/work/Kirchhoff-II}"
export CHIPLAB_HOME="${CHIPLAB_HOME:-$KIRCHHOFF_HOME/chiplab}"
export LONGXIN_HOME="${LONGXIN_HOME:-$KIRCHHOFF_HOME/longxin}"

CHIPLAB_TOOLCHAIN="$CHIPLAB_HOME/toolchains/loongson-gnu-toolchain-8.3-x86_64-loongarch32r-linux-gnusf-v2.0/bin"
VIVADO_HOME="${VIVADO_HOME:-/opt/vivado/2025.2/Vivado}"

case ":$PATH:" in
  *":$CHIPLAB_TOOLCHAIN:"*) ;;
  *) export PATH="$CHIPLAB_TOOLCHAIN:$PATH" ;;
esac

if [ -d "$VIVADO_HOME/bin" ]; then
  case ":$PATH:" in
    *":$VIVADO_HOME/bin:"*) ;;
    *) export PATH="$VIVADO_HOME/bin:$PATH" ;;
  esac
fi

export CROSS_COMPILE="${CROSS_COMPILE:-loongarch32r-linux-gnusf-}"
export ARCH="${ARCH:-loongarch}"
export VMLINUX="${VMLINUX:-$KIRCHHOFF_HOME/vmlinux}"
export ROOTFS_CPIO_GZ="${ROOTFS_CPIO_GZ:-$LONGXIN_HOME/rootfs.cpio.gz}"
