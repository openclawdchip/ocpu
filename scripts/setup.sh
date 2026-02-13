#!/bin/bash
# Setup script for OCPU development environment

set -e

echo "========================================"
echo "OCPU Development Environment Setup"
echo "========================================"
echo ""

# Check OS
OS=""
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi

echo "Detected OS: $OS"

# Install dependencies
echo ""
echo "Installing dependencies..."

if [ "$OS" == "linux" ]; then
    sudo apt-get update
    sudo apt-get install -y \
        build-essential \
        git \
        python3 \
        python3-pip \
        verilator \
        gtkwave \
        cmake
elif [ "$OS" == "macos" ]; then
    if ! command -v brew &> /dev/null; then
        echo "Homebrew not found. Please install Homebrew first."
        exit 1
    fi
    brew install \
        verilator \
        gtkwave \
        python3 \
        cmake
fi

# Install Python dependencies
echo ""
echo "Installing Python dependencies..."
pip3 install -r ../requirements.txt

# Create directories
echo ""
echo "Creating directories..."
mkdir -p ../sim/build
mkdir -p ../sim/logs
mkdir -p ../sim/waves
mkdir -p ../fpga/build
mkdir -p ../fpga/reports

# Make scripts executable
echo ""
echo "Setting up scripts..."
chmod +x *.sh *.py

echo ""
echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "  1. cd ../sim"
echo "  2. make build"
echo "  3. make test"
echo ""
