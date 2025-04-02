#!/bin/bash

OPENRISC_PREFIX="$HOME/env/toolchain/or1k-elf"
OPENRISC_TOOL_PREFIX="$HOME/env/toolchain/or1k-tools"

source logger.sh

export OR1K_TOOLCHAIN="$OPENRISC_PREFIX/bin"
export OR1K_QEMU="$OPENRISC_TOOL_PREFIX/qemu/bin"

export PATH=$PATH:$OR1K_TOOLCHAIN:$OR1K_QEMU
