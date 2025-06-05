#!/bin/bash

set -eu

GIT_REPO_PATH=$(git rev-parse --show-toplevel 2>/dev/null)
source "${GIT_REPO_PATH}/logger.sh"


OR1K_WORKSPACE="${HOME}/work/openrisc"
OR1K_LINUX_WORKSPACE="${HOME}/work"

OR1K_QEMU_URL="https://gitlab.com/qemu-project/qemu.git"
OR1K_LINUX_URL="https://github.com/torvalds/linux.git"
OR1K_UTILS_URL="https://github.com/stffrdhrn/or1k-utils.git"
OR1K_ROOTFS_URL="https://github.com/stffrdhrn/or1k-rootfs-build/releases/download/or1k-20250417/buildroot-qemu-rootfs-20250417.tar.xz"
OR1K_TOOLCHAIN_URL="https://github.com/stffrdhrn/or1k-toolchain-build/releases/download/or1k-14.2.0-20250418/or1k-linux-14.2.0-20250418.tar.xz"

download_url() {
  local url="$1"
  local dest_dir="$2"
  local tmp_file="${TMPDIR:-/tmp}/download_$(basename "$url")"

  if [ -d "$dest_dir" ] && [ -n "$(ls -A "$dest_dir" 2>/dev/null)" ]; then
    info "Destination $dest_dir already exists and is not empty - skipping download"
    return 0
  fi

  # Create destination directory if it doesn't exist
  mkdir -p "$dest_dir" || {
    error "Failed to create directory: $dest_dir"
    return 1
  }

  info "Downloading $url..."

  # Download using curl if available, otherwise use wget
  if command -v curl >/dev/null 2>&1; then
    curl -L "$url" -o "$tmp_file" --progress-bar || {
      error "Download failed: $url"
      return 1
    }
  elif command -v wget >/dev/null 2>&1; then
    wget "$url" -O "$tmp_file" --progress=bar:force || {
      error "Download failed: $url"
      return 1
    }
  else
    error "Neither curl nor wget found. Please install one of them."
    return 1
  fi

  info "Extracting to $dest_dir..."

  # Determine file type and extract accordingly
  case "$tmp_file" in
  *.tar.gz | *.tgz)
    tar -xzf "$tmp_file" -C "$dest_dir" --strip-components=1
    ;;
  *.tar.bz2 | *.tbz2)
    tar -xjf "$tmp_file" -C "$dest_dir" --strip-components=1
    ;;
  *.tar.xz | *.txz)
    tar -xJf "$tmp_file" -C "$dest_dir" --strip-components=1
    ;;
  *.zip)
    unzip -q "$tmp_file" -d "$dest_dir"
    if [ "$(ls -1 "$dest_dir" | wc -l)" -eq 1 ]; then
      # If zip contains single directory, move contents up
      local subdir="$dest_dir/$(ls -1 "$dest_dir")"
      mv "$subdir"/* "$dest_dir/"
      rmdir "$subdir"
    fi
    ;;
  *)
    error "Unsupported file format: $tmp_file"
    return 1
    ;;
  esac || {
    error "Extraction failed for: $tmp_file"
    return 1
  }

  # Clean up temporary file
  rm -f "$tmp_file"
  success "Successfully downloaded and extracted to $dest_dir"
}

clone_url() {
  local repo_url="$1"
  local dest_dir="$2"
  local branch="${3:-}" # Optional branch/tag

  # Check if git is available
  if ! command -v git >/dev/null 2>&1; then
    error "Git is not installed. Please install git first."
    return 1
  fi

  # Check if destination directory exists
  if [ -d "$dest_dir" ]; then
    if [ -d "$dest_dir/.git" ]; then
      error "Repository already exists at $dest_dir, skipping clone."
      return 0
    else
      error "Destination directory $dest_dir exists but is not a git repository."
      return 1
    fi
  fi

  info "Cloning repository $repo_url to $dest_dir..."

  # Clone with branch if specified
  local clone_cmd=(git clone)
  if [ -n "$branch" ]; then
    clone_cmd+=(--branch "$branch")
  fi
  clone_cmd+=("$repo_url" "$dest_dir")
  clone_cmd+=(--depth=1)

  # Execute clone command
  if "${clone_cmd[@]}" 2>&1; then
    success "Successfully cloned repository to $dest_dir"
  else
    error "Failed to clone repository $repo_url"
    return 1
  fi
}

show_help() {
  cat <<EOF
Usage: $0 [OPTIONS]

Build and setup tools for OpenRISC development.

Options:
  --build-qemu     Build QEMU with OpenRISC support
  --build-linux    Build Linux kernel for OpenRISC
  --get-rootfs     Download and extract OpenRISC root filesystem
  --get-tools      Download and install OpenRISC toolchain
  --start-linux    Start Linux kernel in QEMU
  --clean-linux    Clean Linux workspace
  --help, -h       Show this help message and exit

Environment:
  The script uses the following directories:
  - QEMU/Linux source: $OR1K_WORKSPACE
  - Linux workspace: $OR1K_LINUX_WORKSPACE

Examples:
  $0 --build-qemu            # Build QEMU only
  $0 --get-tools --get-rootfs # Get toolchain and rootfs
  $0 --build-linux           # Build Linux kernel
  $0 --start-linux           # Start Linux kernel in QEMU
  $0 --clean-linux           # Clean Linux workspace

Note:
  This script requires git, wget, and basic build tools to be installed.
EOF
}

build_qemu() {
  info "Building QEMU for OpenRISC..."

  # Clone dependencies if they don't exist
  if [ ! -d "${OR1K_WORKSPACE}/or1k-utils" ]; then
    clone_url "$OR1K_UTILS_URL" "${OR1K_WORKSPACE}/or1k-utils" || {
      error "Failed to clone or1k-utils"
      return 1
    }
  fi

  if [ ! -d "${OR1K_WORKSPACE}/qemu" ]; then
    clone_url "$OR1K_QEMU_URL" "${OR1K_WORKSPACE}/qemu" || {
      error "Failed to clone QEMU"
      return 1
    }
  fi

  # Build QEMU
  pushd "${OR1K_WORKSPACE}/qemu" >/dev/null || {
    error "Failed to enter QEMU directory"
    return 1
  }

  info "Configuring QEMU..."
  mkdir -p build
  pushd build >/dev/null || {
    error "Failed to create/enter build directory"
    return 1
  }

  # Run configuration
  if ! "${OR1K_WORKSPACE}/or1k-utils/qemu/config.qemu"; then
    error "QEMU configuration failed"
    popd >/dev/null || true
    return 1
  fi

  info "Compiling QEMU (this may take a while)..."
  if ! make -j$(nproc); then
    error "QEMU compilation failed"
    popd >/dev/null || true
    return 1
  fi

  popd >/dev/null # build
  popd >/dev/null # qemu
  success "QEMU built successfully!"
}

build_linux() {
  info "Building Linux for OpenRISC..."

  # Clone dependencies if they don't exist
  if [ ! -d "${OR1K_WORKSPACE}/or1k-utils" ]; then
    clone_url "$OR1K_UTILS_URL" "${OR1K_WORKSPACE}/or1k-utils" || {
      error "Failed to clone or1k-utils"
      return 1
    }
  fi

  if [ ! -d "${OR1K_LINUX_WORKSPACE}/linux" ]; then
    clone_url "$OR1K_LINUX_URL" "${OR1K_LINUX_WORKSPACE}/linux" || {
      error "Failed to clone Linux"
      return 1
    }
  fi

  # Build Linux
  pushd "${OR1K_WORKSPACE}" >/dev/null || {
    error "Failed to enter workspace directory"
    return 1
  }

  info "Building Linux kernel..."
  pushd "${OR1K_LINUX_WORKSPACE}/linux" >/dev/null || {
    error "Failed to enter linux directory"
  }

  ARCH=openrisc CROSS_COMPILE=or1k-linux- make virt_defconfig

  popd >/dev/null
  if ! bear -- "${OR1K_WORKSPACE}/or1k-utils/scripts/make-or1k-linux"; then
    error "Linux kernel build failed"
    popd >/dev/null || true
    return 1
  fi

  popd >/dev/null
  success "Linux kernel built successfully!"
}

build_tools() {
  info "Building Or1k ToolChains"
  source "${GIT_REPO_PATH}/tool-stage/tools.config"

  if [ ! -d "${OR1K_TOOLCHAIN_WORKSPACE}/gcc" ]; then
    download_url "$OR1K_GCC_URL" "${OR1K_TOOLCHAIN_WORKSPACE}/gcc" || {
      error "Failed to download and extract gcc"
      return 1
    }
  fi
  if [ ! -d "${OR1K_TOOLCHAIN_WORKSPACE}/binutils" ]; then
    download_url "$OR1K_BINUTILS_URL" "${OR1K_TOOLCHAIN_WORKSPACE}/binutils" || {
      error "Failed to download and extract binutils"
      return 1
    }
  fi
  if [ ! -d "${OR1K_TOOLCHAIN_WORKSPACE}/gdb" ]; then
    download_url "$OR1K_GDB_URL" "${OR1K_TOOLCHAIN_WORKSPACE}/gdb" || {
      error "Failed to download and extract gdb"
      return 1
    }
  fi
  if [ ! -d "${OR1K_TOOLCHAIN_WORKSPACE}/gmp" ]; then
    download_url "$OR1K_GMP_URL" "${OR1K_TOOLCHAIN_WORKSPACE}/gmp" || {
      error "Failed to download and extract gmp"
      return 1
    }
  fi
  if [ ! -d "${OR1K_TOOLCHAIN_WORKSPACE}/newlib" ]; then
    download_url "$OR1K_NEWLIB_URL" "${OR1K_TOOLCHAIN_WORKSPACE}/newlib" || {
      error "Failed to download and extract newlib"
      rm -rf ${OR1K_TOOLCHAIN_WORKSPACE}/newlib
      return 1
    }
  fi
  
  if [ ! -x "${INSTALLDIR}/bin/${CROSS}-objdump" ]; then
    info "Building binutils"
    ${GIT_REPO_PATH}/tool-stage/tools.binutils || {
      error "Failed to build binutils"
      return 1
    }
    success "Build binutils at ${INSTALLDIR}"
  fi
  # if [ ! -x "${INSTALLDIR}/bin/${CROSS}-gcc" ]; then
    export PATH=$INSTALLDIR/bin:$PATH

    info "Building gcc-1"
    ${GIT_REPO_PATH}/tool-stage/tools.gcc1 >/dev/null || {
      error "Failed to build gcc-1"
      return 1
    }
    success "Build gcc-1 at ${INSTALLDIR}"


    info "Building newlib"
    ${GIT_REPO_PATH}/tool-stage/tools.newlib >/dev/null || {
      error "Failed to build newlib"
      return 1
    }
    success "Build newlib at ${INSTALLDIR}"


    info "Building gcc-2"
    ${GIT_REPO_PATH}/tool-stage/tools.gcc2 >/dev/null || {
      error "Failed to build gcc-2"
      return 1
    }
    success "Build gcc-2 at ${INSTALLDIR}"
  # fi
}

get_rootfs() {
  info "Getting OpenRISC root filesystem..."
  download_url "$OR1K_ROOTFS_URL" "${OR1K_WORKSPACE}/buildroot-rootfs" || {
    error "Failed to download and extract root filesystem"
    return 1
  }
  success "Root filesystem installed at ${OR1K_WORKSPACE}/buildroot-rootfs"
}

get_tools() {
  info "Getting OpenRISC toolchain..."
  download_url "$OR1K_TOOLCHAIN_URL" "${OR1K_WORKSPACE}/toolchain" || {
    error "Failed to download and extract toolchain"
    return 1
  }

  local toolchain_bin="${OR1K_WORKSPACE}/toolchain/bin"

  # Check if the path is already in PATH
  if [[ ":$PATH:" != *":${toolchain_bin}:"* ]]; then
    info "Adding toolchain to PATH..."

    # Add to PATH in the current session
    export PATH="${toolchain_bin}:$PATH"

    # Add to shell configuration files for future sessions
    for shell_file in "${HOME}/.bashrc" "${HOME}/.zshrc" "${HOME}/.profile"; do
      if [ -f "$shell_file" ]; then
        if ! grep -q "export PATH=\"${toolchain_bin}:\$PATH\"" "$shell_file"; then
          echo "export PATH=\"${toolchain_bin}:\$PATH\"" >>"$shell_file"
          info "Added to $shell_file"
        else
          info "Already exists in $shell_file"
        fi
      fi
    done

    success "Toolchain added to PATH"
  else
    info "Toolchain is already in PATH"
  fi

  success "Toolchain installed at ${OR1K_WORKSPACE}/toolchain"
  info "You may need to restart your shell or run 'source ~/.bashrc' for changes to take effect"
}

start_linux() {
  info "Starting Linux kernel..."
  pushd "${OR1K_WORKSPACE}" >/dev/null || {
    error "Failed to enter work directory"
    return 1
  }

  if ! "${OR1K_WORKSPACE}/or1k-utils/scripts/qemu-or1k-linux"; then
    error "Start Linux Kernel failed"
    popd >/dev/null || true
    return 1
  fi

  popd >/dev/null
}

debug_linux() {
  info "Debugging Linux kernel..."
  pushd "${OR1K_WORKSPACE}" >/dev/null || {
    error "Failed to enter work directory"
    return 1
  }

  if ! "${OR1K_WORKSPACE}/or1k-utils/scripts/qemu-or1k-linux" -S; then
    error "Debug Linux Kernel failed"
    popd >/dev/null || true
    return 1
  fi

  popd >/dev/null
}

clean_linux() {
  info "Cleaning Linux workspace..."
  pushd "${OR1K_LINUX_WORKSPACE}/linux" >/dev/null || {
    error "Failed to enter Linux workspace directory"
    return 1
  }

  make mrproper || {
    error "Failed to clean Linux workspace"
    popd >/dev/null || true
    return 1
  }

  popd >/dev/null
}

# Main option handling
if [[ $# -eq 0 ]]; then
  error "No options specified. Showing help."
  show_help
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
  --build-qemu)
    build_qemu
    ;;
  --build-linux)
    build_linux
    ;;
  --build-tools)
    build_tools
    ;;
  --get-rootfs)
    get_rootfs
    ;;
  --get-tools)
    get_tools
    ;;
  --start-linux)
    start_linux
    ;;
  --debug-linux)
    debug_linux
    ;;
  --clean-linux)
    clean_linux
    ;;
  --help | -h)
    show_help
    exit 0
    ;;
  *)
    error "Unknown option: $1"
    show_help
    exit 1
    ;;
  esac
  shift
done

info "Operation completed successfully."
