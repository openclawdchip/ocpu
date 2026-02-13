#!/bin/bash
# Lint check script for OCPU RTL

set -e

RTL_DIR="../rtl"
INCDIR="../rtl/include"
LOG_FILE="lint_report.log"

echo "========================================"
echo "OCPU RTL Lint Check"
echo "========================================"
echo ""

# Check for verilator
if ! command -v verilator &> /dev/null; then
    echo "Error: Verilator not found"
    exit 1
fi

# Find all SystemVerilog files
echo "Finding RTL files..."
SV_FILES=$(find $RTL_DIR -name "*.sv" | sort)
FILE_COUNT=$(echo "$SV_FILES" | wc -l)
echo "Found $FILE_COUNT SystemVerilog files"
echo ""

# Run verilator lint
echo "Running Verilator lint..."
verilator --lint-only \
    -Wall \
    -Wno-fatal \
    -I$INCDIR \
    $SV_FILES \
    2>&1 | tee $LOG_FILE || true

# Check for errors and warnings
echo ""
echo "========================================"
echo "Lint Summary"
echo "========================================"

ERRORS=$(grep -c "%Error:" $LOG_FILE || true)
WARNINGS=$(grep -c "%Warning:" $LOG_FILE || true)

echo "Errors:   $ERRORS"
echo "Warnings: $WARNINGS"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "Status:   PASS ✅"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "Status:   WARNING ⚠️"
    exit 0
else
    echo "Status:   FAIL ❌"
    exit 1
fi
