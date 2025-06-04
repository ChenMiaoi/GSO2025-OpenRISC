# OpenRISC Toolchain Builder

This script automates the building and installation of the OpenRISC toolchain, including binutils, GCC, GDB, QEMU, and Linux kernel support.

- 🛠️ ​Toolchain Components: binutils, GCC, GDB
- 🖥️ ​Emulation: QEMU
- 🐧 ​Kernel: Linux kernel support

## 🚀Quick Start

### 🔧Build Options

| Command |	Description |
| --- | --- | 
|./scripts/build.sh --use-extra |	Build with math libraries (GMP/MPFR/MPC) |
| ./scripts/build.sh --build-binutils |	Build binutils |
| ./scripts/build.sh --build-gcc |	Build GCC compiler |
| ./scripts/build.sh --build-gdb |	Build GDB debugger |
| ./scripts/build.sh --build-qemu |	Build QEMU emulator |
| ./scripts/build.sh --build-linux |	Build Linux kernel |

``` bash
./scripts/build.sh --use-extra
```

``` bash
./scripts/build.sh --build-binutils
```

**NOTE: AFTER RUN THIS COMMAND, YOU SHOULD RUN `source ~/.bashrc`**

``` bash
./scripts/build.sh --build-gcc 
./scripts/build.sh --build-gdb
```

### Additional Components

``` bash
# Build QEMU emulator
./scripts/build.sh --build-qemu

# Build Linux kernel
./scripts/build.sh --build-linux

```

### 🧹Clean Options

| Command |	Description |
| --- | --- | 
| ./scripts/build.sh --clean or ./scripts/build.sh --clean=all |	Clean everything |
| ./scripts/build.sh --clean=extra |		Clean math libraries |
| ./scripts/build.sh --clean=toolchain |	Clean toolchain components |
| ./scripts/build.sh --clean=qemu |	Clean QEMU |
| ./scripts/build.sh --clean=linux |	Clean Linux kernel |

``` bash
# Clean everything
./scripts/build.sh --clean[=all]

# Clean specific components
./scripts/build.sh --clean=extra      # Clean extra only
./scripts/build.sh --clean=toolchain  # Clean toolchain only
./scripts/build.sh --clean=qemu       # Clean QEMU only
./scripts/build.sh --clean=linux      # Clean Linux only
```

### 💡Pro Tips

1. For a complete setup, run components in this order:

``` bash
./scripts/build.sh --use-extra 
./scripts/build.sh --build-binutils
source ~/.bashrc
./scripts/build.sh --build-gcc 
./scripts/build.sh --build-gdb
./scripts/build.sh --build-qemu
./scripts/build.sh --build-linux
```

2. For use those tools, you can run this command:

``` bash
source ./scripts/flush_env.sh
```

## Installation Locations

- OR1K-ELF: `$HOME/env/toolchain/or1k-elf/`

``` bash
tree $HOME/env/toolchain/or1k-elf/ -L 1
$HOME/env/toolchain/or1k-elf/
├── bin
├── include
├── lib
├── libexec
├── or1k-elf
└── share
```

- OR1K-TOOLS: `$HOME/env/toolchain/or1k-tools/`

``` bash
tree $HOME/env/toolchain/or1k-tools/ -L 1
$HOME/env/toolchain/or1k-tools/
├── gmp
├── mpc
├── mpfr
└── qemu
```
