#!/bin/bash

GIT_REPO_PATH=$(git rev-parse --show-toplevel 2>/dev/null)
# OPENRISC_PREFIX="/opt/toolchain/or1k-elf"
OPENRISC_PREFIX="$HOME/env/toolchain/or1k-elf"
OPENRISC_TOOL_PREFIX="$HOME/env/toolchain/or1k-tools"
WORK_DIR="$HOME/work/openrisc"
OPENRISC_CFGS="$GIT_REPO_PATH/cfgs"
OPENRISC_KERNEL_CFG="$OPENRISC_CFGS/kernel"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to print error messages
error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Function to print success messages
success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to print info messages
info() {
  echo -e "${YELLOW}[INFO]${NC} $1"
}
