#!/bin/bash

# Global variables
BUILD_BINUTILS=false
BUILD_GCC=false
BUILD_GDB=false
BUILD_QEMU=false
BUILD_LINUX=false
BUILD_BUILDROOT=false
BUILD_OR1KSIM=false
BUILD_OPENOCD=false
USE_GMP=false
USE_MPFR=false
USE_MPC=false
CLEAN_CACHE=false
CLEAN_TARGET="all"

GIT_REPO_PATH=$(git rev-parse --show-toplevel 2>/dev/null)
source $GIT_REPO_PATH/scripts/logger.sh

# Function to setup build dependencies (Ubuntu/Debian only)
setup_dependency() {
  info "Installing required build dependencies for Ubuntu/Debian"

  # Check if we're on a Debian-based system
  if ! command -v apt-get >/dev/null 2>&1; then
    error "This script currently only supports Ubuntu/Debian for dependency installation"
    error "Please install the following packages manually:"
    error "gcc, g++, make, cmake, autogen, automake, autoconf, zlib1g-dev, texinfo, build-essential, flex, bison, git, wget, xz-utils"
    return 1
  fi

  # Update package lists
  sudo apt-get update || {
    error "Failed to update package lists"
    return 1
  }

  # Install required packages
  sudo apt-get install -y gcc g++ make cmake autogen automake autoconf zlib1g-dev \
    texinfo build-essential flex bison git wget xz-utils libtool libjim-dev || {
    error "Failed to install dependencies"
    return 1
  }

  success "Build dependencies installed successfully"
  return 0
}

# Function to check and create work directory
setup_work_dir() {
  if [ ! -d "$WORK_DIR" ]; then
    info "Creating work directory at $WORK_DIR"
    mkdir -p "$WORK_DIR" || {
      error "Failed to create work directory"
      exit 1
    }
  fi
}

# Function to set up prefix in PATH
setup_prefix() {
  local bashrc="$HOME/.bashrc"
  local path_line="export PATH=\$PATH:$OPENRISC_PREFIX/bin"

  if ! grep -q "$path_line" "$bashrc"; then
    info "Adding $OPENRISC_PREFIX/bin to PATH in $bashrc"
    echo "$path_line" >>"$bashrc" || {
      error "Failed to update $bashrc"
      exit 1
    }
    source "$bashrc"
  else
    source "$bashrc"
  fi
}

# setup_prefix() {
#   local profile_dir="/etc/profile.d"
#   local profile_file="${profile_dir}/or1k-toolchain.sh"

#   # Create the directory if it doesn't exist
#   if [ ! -d "$profile_dir" ]; then
#     info "Creating profile.d directory"
#     sudo mkdir -p "$profile_dir" || {
#       error "Failed to create profile.d directory"
#       return 1
#     }
#   fi

#   # Create or update the profile file
#   info "Setting up system-wide PATH in ${profile_file}"
#   echo "export PATH=\$PATH:${OPENRISC_PREFIX}/bin" | sudo tee "$profile_file" >/dev/null || {
#     error "Failed to create profile file"
#     return 1
#   }

#   # Set proper permissions
#   sudo chmod 644 "$profile_file" || {
#     error "Failed to set permissions on profile file"
#     return 1
#   }

#   # Load the new PATH in current session
#   if source "$profile_file"; then
#     # Also source for root if we're not already root
#     if [ "$(id -u)" -ne 0 ]; then
#       sudo -H bash -c "source '$profile_file'" || {
#         error "Failed to load new PATH configuration for root"
#         return 1
#       }
#     fi
#   else
#     error "Failed to load new PATH configuration"
#     return 1
#   fi

#   success "Toolchain PATH configured system-wide in ${profile_file}"
#   return 0
# }

# Function to clone repositories
clone_repos() {
  # Clone GCC if not exists
  if [ ! -d "gcc" ]; then
    info "Cloning GCC repository"
    git clone --depth 1 git://gcc.gnu.org/git/gcc.git gcc || {
      error "Failed to clone GCC"
      exit 1
    }
  fi

  # Clone binutils-gdb if not exists
  if [ ! -d "binutils-gdb" ]; then
    info "Cloning binutils-gdb repository"
    git clone --depth 1 git://sourceware.org/git/binutils-gdb.git binutils-gdb || {
      error "Failed to clone binutils-gdb"
      exit 1
    }
  fi

  # Clone newlib if not exists
  if [ ! -d "newlib" ]; then
    info "Cloning newlib repository"
    git clone --depth 1 git://sourceware.org/git/newlib-cygwin.git newlib || {
      error "Failed to clone newlib"
      exit 1
    }
  fi
}

# Function to check if library is already built
is_library_built() {
  local lib_name="$1"
  local lib_path="$OPENRISC_TOOL_PREFIX/$lib_name"

  # Check if installation directory exists and contains files
  [ -d "$lib_path" ] && [ -n "$(ls -A "$lib_path")" ] &&
    # Check if library files exist
    [ -f "$lib_path/lib/lib$lib_name.a" ] || [ -f "$lib_path/lib/lib$lib_name.so" ]
}

# Function to setup GMP (extraction only)
setup_gmp() {
  if [ ! -d "gmp-6.1.0" ]; then
    info "Downloading and extracting GMP"
    wget https://gmplib.org/download/gmp/gmp-6.1.0.tar.xz || {
      error "Failed to download GMP"
      exit 1
    }
    tar -xf gmp-6.1.0.tar.xz || {
      error "Failed to extract GMP"
      exit 1
    }
    rm gmp-6.1.0.tar.xz
  fi

  if [ ! -L "gcc/gmp" ]; then
    ln -s ../gmp-6.1.0 gcc/gmp || {
      error "Failed to create symlink for GMP"
      exit 1
    }
  fi
}

# Function to setup MPFR (extraction only)
setup_mpfr() {
  if [ ! -d "mpfr-3.1.6" ]; then
    info "Downloading and extracting MPFR"
    wget https://www.mpfr.org/mpfr-3.1.6/mpfr-3.1.6.tar.xz || {
      error "Failed to download MPFR"
      exit 1
    }
    tar -xf mpfr-3.1.6.tar.xz || {
      error "Failed to extract MPFR"
      exit 1
    }
    rm mpfr-3.1.6.tar.xz
  fi

  if [ ! -L "gcc/mpfr" ]; then
    ln -s ../mpfr-3.1.6 gcc/mpfr || {
      error "Failed to create symlink for MPFR"
      exit 1
    }
  fi
}

# Function to setup MPC (extraction only)
setup_mpc() {
  if [ ! -d "mpc-1.0.3" ]; then
    info "Downloading and extracting MPC"
    wget ftp://ftp.gnu.org/gnu/mpc/mpc-1.0.3.tar.gz || {
      error "Failed to download MPC"
      exit 1
    }
    tar -xf mpc-1.0.3.tar.gz || {
      error "Failed to extract MPC"
      exit 1
    }
    rm mpc-1.0.3.tar.gz
  fi

  if [ ! -L "gcc/mpc" ]; then
    ln -s ../mpc-1.0.3 gcc/mpc || {
      error "Failed to create symlink for MPC"
      exit 1
    }
  fi
}

# Main build function for all extra libraries
build_extra() {
  # Build GMP if not already built
  if ! is_library_built "gmp"; then
    info "Building GMP..."
    pushd gmp-6.1.0 >/dev/null || {
      error "Failed to change to GMP build directory"
      return 1
    }

    ./configure --prefix="$OPENRISC_TOOL_PREFIX/gmp" || {
      error "Failed to configure GMP"
      return 1
    }

    make -j "$(nproc)" || {
      error "Failed to build GMP"
      return 1
    }

    make install || {
      error "Failed to install GMP"
      return 1
    }

    popd >/dev/null
    success "GMP built and installed successfully"
  else
    info "GMP already built, skipping..."
  fi

  # Build MPFR if not already built (depends on GMP)
  if ! is_library_built "mpfr"; then
    info "Building MPFR..."
    pushd mpfr-3.1.6 >/dev/null || {
      error "Failed to change to MPFR build directory"
      return 1
    }

    ./configure --prefix="$OPENRISC_TOOL_PREFIX/mpfr" \
      --with-gmp="$OPENRISC_TOOL_PREFIX/gmp" || {
      error "Failed to configure MPFR"
      return 1
    }

    make -j "$(nproc)" || {
      error "Failed to build MPFR"
      return 1
    }

    make install || {
      error "Failed to install MPFR"
      return 1
    }

    popd >/dev/null
    success "MPFR built and installed successfully"
  else
    info "MPFR already built, skipping..."
  fi

  # Build MPC if not already built (depends on MPFR and GMP)
  if ! is_library_built "mpc"; then
    info "Building MPC..."
    pushd mpc-1.0.3 >/dev/null || {
      error "Failed to change to MPC build directory"
      return 1
    }

    ./configure --prefix="$OPENRISC_TOOL_PREFIX/mpc" \
      --with-mpfr="$OPENRISC_TOOL_PREFIX/mpfr" \
      --with-gmp="$OPENRISC_TOOL_PREFIX/gmp" || {
      error "Failed to configure MPC"
      return 1
    }

    make -j "$(nproc)" || {
      error "Failed to build MPC"
      return 1
    }

    make install || {
      error "Failed to install MPC"
      return 1
    }

    popd >/dev/null
    success "MPC built and installed successfully"
  else
    info "MPC already built, skipping..."
  fi
}

# Function to build binutils
build_binutils() {
  info "Building binutils"
  mkdir -p binutils-gdb/build-binutils || {
    error "Failed to create build directory for binutils"
    exit 1
  }

  pushd binutils-gdb/build-binutils >/dev/null || {
    error "Failed to change to binutils build directory"
    exit 1
  }

  ../configure --target=or1k-elf --prefix="$OPENRISC_PREFIX" \
    --disable-itcl \
    --disable-tk \
    --disable-tcl \
    --disable-winsup \
    --disable-gdbtk \
    --disable-libgui \
    --disable-rda \
    --disable-sid \
    --disable-sim \
    --disable-gdb \
    --with-sysroot \
    --disable-newlib \
    --disable-libgloss \
    --with-system-zlib || {
    error "Failed to configure binutils"
    exit 1
  }

  make -j "$(nproc)" || {
    error "Failed to build binutils"
    exit 1
  }

  make install || {
    error "Failed to install binutils"
    exit 1
  }

  popd >/dev/null
  success "Binutils built and installed successfully"
}

# Function to build GCC stage1
build_gcc_stage1() {
  info "Building GCC stage1"
  mkdir -p gcc/build-gcc-stage1 || {
    error "Failed to create build directory for GCC stage1"
    exit 1
  }

  pushd gcc/build-gcc-stage1 >/dev/null || {
    error "Failed to change to GCC stage1 build directory"
    exit 1
  }

  ../configure --target=or1k-elf \
    --prefix="$OPENRISC_PREFIX" \
    --enable-languages=c \
    --disable-shared \
    --disable-libssp || {
    error "Failed to configure GCC stage1"
    exit 1
  }

  make -j "$(nproc)" || {
    error "Failed to build GCC stage1"
    exit 1
  }

  make install || {
    error "Failed to install GCC stage1"
    exit 1
  }

  popd >/dev/null
  success "GCC stage1 built and installed successfully"
}

# Function to build newlib
build_newlib() {
  info "Building newlib"
  mkdir -p newlib/build-newlib || {
    error "Failed to create build directory for newlib"
    exit 1
  }

  pushd newlib/build-newlib >/dev/null || {
    error "Failed to change to newlib build directory"
    exit 1
  }

  ../configure --target=or1k-elf --prefix="$OPENRISC_PREFIX" || {
    error "Failed to configure newlib"
    exit 1
  }

  make -j "$(nproc)" || {
    error "Failed to build newlib"
    exit 1
  }

  make install || {
    error "Failed to install newlib"
    exit 1
  }

  popd >/dev/null
  success "Newlib built and installed successfully"
}

# Function to build GCC stage2
build_gcc_stage2() {
  info "Building GCC stage2"
  mkdir -p gcc/build-gcc-stage2 || {
    error "Failed to create build directory for GCC stage2"
    exit 1
  }

  pushd gcc/build-gcc-stage2 >/dev/null || {
    error "Failed to change to GCC stage2 build directory"
    exit 1
  }

  ../configure --target=or1k-elf \
    --prefix="$OPENRISC_PREFIX" \
    --enable-languages=c,c++ \
    --disable-shared \
    --disable-libssp \
    --with-newlib || {
    error "Failed to configure GCC stage2"
    exit 1
  }

  make -j "$(nproc)" || {
    error "Failed to build GCC stage2"
    exit 1
  }

  make install || {
    error "Failed to install GCC stage2"
    exit 1
  }

  popd >/dev/null
  success "GCC stage2 built and installed successfully"
}

# Function to build GDB
build_gdb() {
  info "Building GDB"
  mkdir -p binutils-gdb/build-gdb || {
    error "Failed to create build directory for GDB"
    exit 1
  }

  build_extra

  pushd binutils-gdb/build-gdb >/dev/null || {
    error "Failed to change to GDB build directory"
    exit 1
  }

  ../configure --target=or1k-elf \
    --prefix="$OPENRISC_PREFIX" \
    --with-gmp="$OPENRISC_TOOL_PREFIX/gmp" \
    --with-mpfr="$OPENRISC_TOOL_PREFIX/mpfr" \
    --disable-itcl \
    --disable-tk \
    --disable-tcl \
    --disable-winsup \
    --disable-gdbtk \
    --disable-libgui \
    --disable-rda \
    --disable-sid \
    --with-sysroot \
    --disable-newlib \
    --disable-libgloss \
    --disable-gas \
    --disable-ld \
    --disable-binutils \
    --disable-gprof \
    --with-system-zlib || {
    error "Failed to configure GDB"
    exit 1
  }

  make -j "$(nproc)" || {
    error "Failed to build GDB"
    exit 1
  }

  make install || {
    error "Failed to install GDB"
    exit 1
  }

  popd >/dev/null
  success "GDB built and installed successfully"
}

# Add QEMU build function
build_qemu() {
  local qemu_version="9.2.3"
  local qemu_dir="qemu-${qemu_version}"
  local qemu_archive="${qemu_dir}.tar.xz"
  local qemu_url="https://download.qemu.org/${qemu_archive}"

  info "Building QEMU ${qemu_version}"

  # Download QEMU if not exists
  if [ ! -f "${WORK_DIR}/${qemu_archive}" ]; then
    info "Downloading QEMU"
    wget "${qemu_url}" || {
      error "Failed to download QEMU"
      return 1
    }
  fi

  # Extract QEMU
  if [ ! -d "${WORK_DIR}/${qemu_dir}" ]; then
    info "Extracting QEMU"
    tar -xJf "${WORK_DIR}/${qemu_archive}" || {
      error "Failed to extract QEMU"
      return 1
    }
  fi

  sudo apt-get install -y libglib2.0-dev pkgconf ninja-build python3-venv python3-pip python3-full || {
    error "Failed to install dependencies"
    return 1
  }

  # python3 -m pip install -i https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple --upgrade pip || {
  #   error "cannot set pypi tsinghua mirror"
  #   return 1
  # }

  # python3 -m pip install --upgrade pip || {
  #   error "cannot upgrade pip"
  #   return 1
  # }

  # pip config set global.index-url https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple || {
  #   error "cannot set pypi tsinghua mirror"
  #   return 1
  # }

  # Build QEMU
  pushd "${WORK_DIR}/${qemu_dir}" >/dev/null || {
    error "Failed to enter QEMU directory"
    return 1
  }

  info "Configuring QEMU"
  ./configure --prefix="$OPENRISC_TOOL_PREFIX/qemu" \
    --target-list=or1k-softmmu,or1k-linux-user || {
    error "QEMU configuration failed"
    popd >/dev/null
    return 1
  }

  info "Building QEMU"
  make -j$(nproc) || {
    error "QEMU build failed"
    popd >/dev/null
    return 1
  }

  info "Installing QEMU"
  make install || {
    error "QEMU installation failed"
    popd >/dev/null
    return 1
  }

  popd >/dev/null

  # Add QEMU to PATH in .bashrc
  local bashrc="$HOME/.bashrc"
  local qemu_path_line="export PATH=\$PATH:${OPENRISC_TOOL_PREFIX}/qemu/bin"

  if ! grep -q "${qemu_path_line}" "$bashrc"; then
    info "Adding QEMU to PATH in ${bashrc}"
    echo "${qemu_path_line}" >>"$bashrc" || {
      error "Failed to update ${bashrc}"
      return 1
    }
    # Source the updated .bashrc
    source "$bashrc"
  else
    source "$bashrc"
  fi

  success "QEMU ${qemu_version} built and installed successfully"
  return 0
}

# Add Linux kernel build function
build_linux() {
  info "Building Linux kernel for OpenRISC"

  # Clone Linux repository if not exists
  if [ ! -d "linux" ]; then
    info "Cloning Linux repository"
    git clone --depth 1 https://github.com/openrisc/linux.git linux || {
      error "Failed to clone Linux repository"
      return 1
    }
  fi

  pushd linux >/dev/null || {
    error "Failed to enter Linux directory"
    return 1
  }

  # Set up environment for cross-compilation
  export ARCH=openrisc
  export CROSS_COMPILE=or1k-elf-

  # Check if toolchain is in PATH
  if ! command -v ${CROSS_COMPILE}gcc >/dev/null 2>&1; then
    error "OpenRISC toolchain not found in PATH. Please build toolchain first or add to PATH."
    popd >/dev/null
    return 1
  fi

  info "Configuring Linux kernel"
  cp $OPENRISC_KERNEL_CFG/.config .config || {
    error "Failed to copy config"
    popd >/dev/null
    return 1
  }

  local initramfs_source=$OPENRISC_KERNEL_CFG/rootfs.cpio
  if grep -q "^CONFIG_INITRAMFS_SOURCE=" .config; then
    sed -i "s|^CONFIG_INITRAMFS_SOURCE=.*|CONFIG_INITRAMFS_SOURCE=\"${initramfs_source}\"|" .config || {
      error "Failed to set config CONFIG_INITRAMFS_SOURCE"
      popd >/dev/null
      return 1
    }
  else
    warning "config CONFIG_INITRAMFS_SOURCE not exists, appending to the tail"
    info "CONFIG_INITRAMFS_SOURCE=${initramfs_source}" >>.config
  fi

  # make defconfig || {
  #   error "Failed to configure Linux kernel"
  #   popd >/dev/null
  #   return 1
  # }

  info "Building Linux kernel"
  make -j$(nproc) || {
    error "Failed to build Linux kernel"
    popd >/dev/null
    return 1
  }

  popd >/dev/null
  success "Linux kernel built successfully"
  return 0
}

build_or1ksim() {
  info "Building or1ksim for OpenRISC"

  # Clone Linux repository if not exists
  if [ ! -d "or1ksim" ]; then
    info "Cloning or1ksim repository"
    git clone --depth 1 https://github.com/openrisc/or1ksim.git or1ksim || {
      error "Failed to clone or1ksim repository"
      return 1
    }
  fi

  pushd or1ksim >/dev/null || {
    error "Failed to enter or1ksim directory"
    return 1
  }

  # Check if toolchain is in PATH
  if ! command -v ${CROSS_COMPILE}gcc >/dev/null 2>&1; then
    error "OpenRISC toolchain not found in PATH. Please build toolchain first or add to PATH."
    popd >/dev/null
    return 1
  fi

  mkdir -p build_or1ksim
  pushd build_or1ksim >/dev/null || {
    error "Failed to enter build_or1ksim directory"
    return 1
  }

  info "Configuring or1ksim"
  ../configure --prefix="$OPENRISC_TOOL_PREFIX/or1ksim" || {
    error "Failed to configure or1ksim"
    popd >/dev/null
    popd >/dev/null

    return 1
  }

  info "Building or1ksim"
  make -j$(nproc) || {
    error "Failed to build or1ksim"
    popd >/dev/null
    popd >/dev/null

    return 1
  }

  info "Installing or1ksim"
  make install || {
    error "or1ksim installation failed"
    popd >/dev/null
    popd >/dev/null

    return 1
  }

  popd >/dev/null
  popd >/dev/null

  # Add QEMU to PATH in .bashrc
  local bashrc="$HOME/.bashrc"
  local or1ksim_path_line="export PATH=\$PATH:${OPENRISC_TOOL_PREFIX}/or1ksim/bin"

  if ! grep -q "${or1ksim_path_line}" "$bashrc"; then
    info "Adding or1ksim to PATH in ${bashrc}"
    echo "${or1ksim_path_line}" >>"$bashrc" || {
      error "Failed to update ${bashrc}"
      return 1
    }
    # Source the updated .bashrc
    source "$bashrc"
  else
    source "$bashrc"
  fi

  success "or1ksim kernel built successfully"
  return 0
}

build_openocd() {
  info "Building openocd for OpenRISC"

  # Clone Linux repository if not exists
  if [ ! -d "openocd" ]; then
    info "Cloning openocd repository"
    git clone --depth 1 https://github.com/openocd-org/openocd.git openocd || {
      error "Failed to clone openocd repository"
      return 1
    }
  fi

  pushd openocd >/dev/null || {
    error "Failed to enter openocd directory"
    return 1
  }

  # Check if toolchain is in PATH
  # if ! command -v ${CROSS_COMPILE}gcc >/dev/null 2>&1; then
  #   error "OpenRISC toolchain not found in PATH. Please build toolchain first or add to PATH."
  #   popd >/dev/null
  #   return 1
  # fi

  info "Bootstrap openocd"
  ./bootstrap || {
    error "Failed to bootstrap openocd"
    popd >/dev/null

    return 1
  }

  info "Configuring openocd"
  ./configure --prefix="$OPENRISC_TOOL_PREFIX/openocd" || {
    error "Failed to configure openocd"
    popd >/dev/null

    return 1
  }

  info "Building openocd"
  make -j$(nproc) || {
    error "Failed to build openocd"
    popd >/dev/null

    return 1
  }

  info "Installing openocd"
  make install || {
    error "openocd installation failed"
    popd >/dev/null

    return 1
  }

  popd >/dev/null

  # Add QEMU to PATH in .bashrc
  local bashrc="$HOME/.bashrc"
  local openocd_path_line="export PATH=\$PATH:${OPENRISC_TOOL_PREFIX}/openocd/bin"

  if ! grep -q "${openocd_path_line}" "$bashrc"; then
    info "Adding openocd to PATH in ${bashrc}"
    echo "${openocd_path_line}" >>"$bashrc" || {
      error "Failed to update ${bashrc}"
      return 1
    }
    # Source the updated .bashrc
    source "$bashrc"
  else
    source "$bashrc"
  fi

  success "openocd kernel built successfully"
  return 0
}

clean_toolchain() {
  # Remove build directories
  local build_dirs=(
    "binutils-gdb/build-binutils"
    "binutils-gdb/build-gdb"
    "gcc/build-gcc-stage1"
    "gcc/build-gcc-stage2"
    "newlib/build-newlib"
  )

  for dir in "${build_dirs[@]}"; do
    if [ -d "$WORK_DIR/$dir" ]; then
      info "Make Clean $dir"
      make -C "${WORK_DIR:?}/$dir" distclean || {
        error "Failed to Make distclean $dir"
        return 1
      }

      info "Removing $dir"
      rm -rf "${WORK_DIR:?}/$dir" || {
        error "Failed to remove $dir"
        return 1
      }
    fi
  done

  if [ -d "$OPENRISC_PREFIX" ]; then
    info "Removing installed toolchain from $OPENRISC_PREFIX"

    # Safety check - verify this looks like a toolchain directory
    if [ -x "$OPENRISC_PREFIX/bin/or1k-elf-"* ] || [ -d "$OPENRISC_PREFIX/lib" ]; then
      sudo rm -rf "${OPENRISC_PREFIX:?}" || {
        error "Failed to remove installed toolchain"
        return 1
      }

      # Also remove the profile file if it exists
      # local profile_file="/etc/profile.d/or1k-toolchain.sh"
      # if [ -f "$profile_file" ]; then
      #   info "Removing profile file: $profile_file"
      #   sudo rm -f "$profile_file" || {
      #     error "Failed to remove profile file"
      #     return 1
      #   }
      # fi
    else
      warning "$OPENRISC_PREFIX doesn't appear to contain or1k toolchain - skipping removal"
    fi
  else
    info "No installed toolchain found at $OPENRISC_PREFIX"
  fi

  local bashrc="$HOME/.bashrc"
  local path_line="export PATH=\$PATH:$OPENRISC_PREFIX/bin"

  remove_path_entry "$bashrc" "$path_line"
}

clean_extra() {
  # Remove extracted source directories (but keep symlinks in gcc/)
  local source_dirs=(
    "gmp-6.1.0"
    "mpfr-3.1.6"
    "mpc-1.0.3"
  )

  local install_paths=(
    "$OPENRISC_TOOL_PREFIX/gmp"
    "$OPENRISC_TOOL_PREFIX/mpfr"
    "$OPENRISC_TOOL_PREFIX/mpc"
  )

  for dir in "${source_dirs[@]}"; do
    if [ -d "$WORK_DIR/$dir" ]; then
      info "Make Clean $dir"
      make -C "${WORK_DIR:?}/$dir" distclean || {
        error "Failed to Make distclean $dir"
        return 1
      }

      # info "Removing $dir"
      # rm -rf "${WORK_DIR:?}/$dir" || {
      #   error "Failed to remove $dir"
      #   return 1
      # }
    fi
  done

  for path in "${install_paths[@]}"; do
    if [ -d "$path" ]; then
      info "Removing installed files: $path"
      rm -rf "${path:?}" || {
        error "Failed to remove installed files at $path"
        return 1
      }
    fi
  done
}

clean_qemu() {
  local qemu_version="9.2.3"
  local qemu_files="qemu-${qemu_version}"
  local qemu_install_dir="${OPENRISC_TOOL_PREFIX}/qemu"

  if [ -d "${qemu_files}" ]; then
    info "Clean Qemu Build Cache"
    make -C "$WORK_DIR/$qemu_files" distclean || {
      error "Failed to clean Qemu Build Cache"
      return 1
    }
  fi

  if [ -d "${qemu_install_dir}" ]; then
    info "Removing installed QEMU from ${qemu_install_dir}"
    rm -rf "${qemu_install_dir}" || {
      error "Failed to remove QEMU installation"
      return 1
    }
  fi

  # Remove QEMU PATH from .bashrc
  local bashrc="$HOME/.bashrc"
  local qemu_path_line="export PATH=\$PATH:${qemu_install_dir}/bin"

  remove_path_entry "$bashrc" "$qemu_path_line"
}

clean_linux() {
  info "Clean Linux Build Cache"
  if [ -d "${WORK_DIR}/linux" ]; then
    make -C "${WORK_DIR}/linux" mrproper || {
      error "Failed to clean Linux Build Cache"
      return 1
    }
  fi
}

clean_or1ksim() {
  local or1ksim_files="or1ksim/build_or1ksim"
  local or1ksim_install_dir="${OPENRISC_TOOL_PREFIX}/or1ksim"

  if [ -d "$WORK_DIR/${or1ksim_files}" ]; then
    info "Clean or1ksim Build Cache"
    make -C "$WORK_DIR/$or1ksim_files" distclean || {
      error "Failed to clean or1ksim Build Cache"
      return 1
    }
  fi

  if [ -d "${or1ksim_install_dir}" ]; then
    info "Removing installed or1ksim from ${or1ksim_install_dir}"
    rm -rf "${or1ksim_install_dir}" || {
      error "Failed to remove or1ksim installation"
      return 1
    }
  fi

  # Remove or1ksim PATH from .bashrc
  local bashrc="$HOME/.bashrc"
  local or1ksim_path_line="export PATH=\$PATH:${or1ksim_install_dir}/bin"

  remove_path_entry "$bashrc" "$or1ksim_path_line"
}

clean_openocd() {
  local openocd_files="openocd"
  local openocd_install_dir="${OPENRISC_TOOL_PREFIX}/openocd"

  if [ -d "$WORK_DIR/${openocd_files}" ]; then
    info "Clean openocd Build Cache"
    make -C "$WORK_DIR/$openocd_files" distclean || {
      error "Failed to clean openocd Build Cache"
      return 1
    }
  fi

  if [ -d "${openocd_install_dir}" ]; then
    info "Removing installed openocd from ${openocd_install_dir}"
    rm -rf "${openocd_install_dir}" || {
      error "Failed to remove openocd installation"
      return 1
    }
  fi

  # Remove openocd PATH from .bashrc
  local bashrc="$HOME/.bashrc"
  local openocd_path_line="export PATH=\$PATH:${openocd_install_dir}/bin"

  remove_path_entry "$bashrc" "$openocd_path_line"
}

remove_path_entry() {
  local file="$1"
  local pattern="$2"

  if [ -f "$file" ] && grep -q "$pattern" "$file"; then
    info "Removing PATH entry from ${file}"
    sed -i "\|${pattern}|d" "$file" || {
      error "Failed to modify ${file}"
      return 1
    }

    # Also remove from current environment
    export PATH=$(echo "$PATH" | sed "s|:${pattern#*=}||")
  fi
}

clean_cache() {
  local target="${1:-all}" # Default to clean all if no target specified
  info "Starting clean operation for target: $target"

  case "$target" in
  qemu)
    clean_qemu || return $?
    ;;
  linux)
    clean_linux || return $?
    ;;
  buildroot)
    clean_buildroot || return $?
    ;;
  # or1ksim)
  #   clean_or1ksim || return $?
  #   ;;
  # openocd)
  #   clean_openocd || return $?
  #   ;;
  toolchain)
    clean_toolchain || return $?
    ;;
  extra)
    clean_extra || return $?
    ;;
  all)
    clean_qemu || return $?
    clean_linux || return $?
    clean_buildroot || return $?
    # clean_or1ksim || return $?
    # clean_openocd || return $?
    clean_extra || return $?
    clean_toolchain || return $?
    ;;
  *)
    error "Invalid clean target: $target. Valid targets are: binutils, gcc, newlib, qemu, linux, toolchain, all"
    return 1
    ;;
  esac

  success "Clean operation completed for target: $target"
  return 0
}

show_help() {
  cat <<EOF
Usage: $0 [options]

Build and clean OpenRISC toolchain components.

Options:
  --prefix=<dir>        Set installation directory (default: current dir)
  --use-gmp             Use GMP library
  --use-mpfr            Use MPFR library
  --use-mpc             Use MPC library
  --use-extra           Use all extra math libraries (GMP, MPFR, MPC)
  
Build options:
  --build-binutils      Build binutils
  --build-gcc           Build GCC
  --build-gdb           Build GDB
  --build-qemu          Build QEMU
  --build-linux         Build Linux kernel
  --build-buildroot     Build buildroot
  #--build-or1ksim      Build OR1KSim (currently disabled)
  #--build-openocd      Build OpenOCD (currently disabled)

Clean options:
  --clean               Clean all build artifacts
  --clean=<target>      Clean specific target:
                        qemu      - Clean QEMU build
                        linux     - Clean Linux build
                        buildroot - Clean buildroot build
                        toolchain - Clean toolchain components
                        extra     - Clean extra libraries
                        all       - Clean everything (default)

Examples:
  $0 --prefix=/opt/openrisc --build-toolchain
  $0 --clean=qemu
  $0 --use-extra --build-gcc --build-qemu

EOF
  exit 0
}

# Function to parse arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --help)
      show_help
      ;;
    --prefix=*)
      OPENRISC_PREFIX="${1#*=}"
      shift
      ;;
    --use-gmp)
      USE_GMP=true
      shift
      ;;
    --use-mpfr)
      USE_MPFR=true
      shift
      ;;
    --use-mpc)
      USE_MPC=true
      shift
      ;;
    --use-extra)
      USE_GMP=true
      USE_MPFR=true
      USE_MPC=true
      shift
      ;;
    --build-binutils)
      BUILD_BINUTILS=true
      shift
      ;;
    --build-gcc)
      BUILD_GCC=true
      shift
      ;;
    --build-gdb)
      BUILD_GDB=true
      shift
      ;;
    --build-qemu)
      BUILD_QEMU=true
      shift
      ;;
    --build-linux)
      BUILD_LINUX=true
      shift
      ;;
      --build-linux)
      BUILD_BUILDROOT=true
      shift
      ;;
    # --build-or1ksim)
    #   BUILD_OR1KSIM=true
    #   shift
    #   ;;
    # --build-openocd)
    #   BUILD_OPENOCD=true
    #   shift
    #   ;;
    --clean=*)
      CLEAN_CACHE=true
      CLEAN_TARGET="${1#*=}"
      shift
      ;;
    --clean)
      CLEAN_CACHE=true
      CLEAN_TARGET="all" # Default to clean all
      shift
      ;;
    *)
      error "Unknown option: $1"
      exit 1
      ;;
    esac
  done
}

# Main function
main() {
  setup_work_dir

  pushd $WORK_DIR >/dev/null || {
    error "Failed to change to work directory"
    exit 1
  }
  parse_arguments "$@"

  if [ "$CLEAN_CACHE" = true ]; then
    clean_cache "$CLEAN_TARGET"
    exit $?
  fi

  setup_dependency
  if $BUILD_QEMU; then
    build_qemu
    exit $?
  fi

  if $BUILD_LINUX; then
    build_linux
    exit $?
  fi

  if $BUILD_BUILDROOT; then
    build_buildroot
    exit $?
  fi

  if $BUILD_OR1KSIM; then
    build_or1ksim
    exit $?
  fi

  if $BUILD_OPENOCD; then
    build_openocd
    exit $?
  fi

  info "Starting OpenRISC toolchain build process"
  info "Toolchain prefix: $OPENRISC_PREFIX"

  setup_prefix
  clone_repos

  # Setup extra libraries if needed
  if $USE_GMP; then setup_gmp; fi
  if $USE_MPFR; then setup_mpfr; fi
  if $USE_MPC; then setup_mpc; fi

  # Build components as requested
  if $BUILD_BINUTILS; then build_binutils; fi

  setup_prefix

  if $BUILD_GCC; then
    build_gcc_stage1
    build_newlib
    build_gcc_stage2
  fi

  if $BUILD_GDB; then build_gdb; fi

  success "OpenRISC toolchain build process completed successfully"

  popd >/dev/null || {
    error "Failed to change to work directory"
    exit 1
  }
}

# Execute main function
main "$@"
