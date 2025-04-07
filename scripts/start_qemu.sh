#!/bin/bash

GIT_REPO_PATH=$(git rev-parse --show-toplevel 2>/dev/null)
source $GIT_REPO_PATH/scripts/logger.sh

BINARIES_DIR="${0%/*}/"
# shellcheck disable=SC2164
cd "${BINARIES_DIR}"

mode_serial=false
mode_sys_qemu=false
mode_debug=false
while [ "$1" ]; do
    case "$1" in
    --serial-only|serial-only) mode_serial=true; shift;;
    --use-system-qemu) mode_sys_qemu=true; shift;;
    --debug) mode_sys_qemu=true; mode_debug=true; shift;;
    --) shift; break;;
    *) echo "unknown option: $1" >&2; exit 1;;
    esac
done

if ${mode_serial}; then
    EXTRA_ARGS='-nographic'
else
    EXTRA_ARGS=''
fi

if ! ${mode_sys_qemu}; then
    export PATH="$WORK_DIR/buildroot/output/host/bin:${PATH}"
fi

if $mode_debug; then
    EXTRA_ARGS+=("-s" "-S")
    info "Debug mode enabled - QEMU will wait for GDB connection"
fi

# exec qemu-system-or1k -kernel vmlinux -nographic  ${EXTRA_ARGS} "$@"
CMD=(
    qemu-system-or1k
    -cpu or1200
    -M virt
    -smp 1
    -nographic
    -kernel "$WORK_DIR/linux/vmlinux"
    -append "root=/dev/vda console=ttyS0"
    -drive "file=$OPENRISC_KERNEL_CFG/rootfs.ext4,if=virtio,format=raw"
    "${EXTRA_ARGS[@]}"
    "$@"
)

info "Starting QEMU with command:"
printf "  %s\n" "${CMD[@]}"

exec qemu-system-or1k \
    -cpu or1200 \
    -M virt \
    -smp 1 \
    -nographic \
    -kernel $WORK_DIR/linux/vmlinux \
    -append "root=/dev/vda console=ttyS0" \
    -drive file=$OPENRISC_KERNEL_CFG/rootfs.ext4,if=virtio,format=raw \
    ${EXTRA_ARGS} "$@"
