#!/bin/bash

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
