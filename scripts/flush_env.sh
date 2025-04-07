#!/bin/bash

OPENRISC_PREFIX="$HOME/env/toolchain/or1k-elf"
OPENRISC_TOOL_PREFIX="$HOME/env/toolchain/or1k-tools"
GIT_REPO_PATH=$(git rev-parse --show-toplevel 2>/dev/null)

source logger.sh

export OR1K_TOOLCHAIN="$OPENRISC_PREFIX/bin"
export OR1K_QEMU="$OPENRISC_TOOL_PREFIX/qemu/bin"
export OR1K_SIM="$OPENRISC_TOOL_PREFIX/or1ksim/bin"
export OR1K_OPENOCD="$OPENRISC_TOOL_PREFIX/openocd/bin"

export PATH=$PATH:$OR1K_TOOLCHAIN:$OR1K_QEMU:$OR1K_SIM:$OR1K_OPENOCD
