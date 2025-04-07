#!/bin/bash

GIT_REPO_PATH=$(git rev-parse --show-toplevel 2>/dev/null)
source $GIT_REPO_PATH/scripts/logger.sh

OPENOCD_BIN="$OPENRISC_TOOL_PREFIX/openocd/bin/openocd"

cat > "$GIT_REPO_PATH/openocd_temp.cfg" <<EOF
init
reset halt
load_image $WORK_DIR/linux/vmlinux
reg r3 0
reg npc 0x100
resume
EOF

$OPENOCD_BIN -f $GIT_REPO_PATH/openocd_temp.cfg
