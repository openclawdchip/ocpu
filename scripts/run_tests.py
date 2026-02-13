#!/usr/bin/env python3
"""
OCPU Test Runner
Runs simulation tests and generates reports
"""

import argparse
import subprocess
import sys
import os
from pathlib import Path

TEST_DIR = Path(__file__).parent.parent / "sim"
TEST_LIST = {
    "basic": "Basic functionality test",
    "rv64i": "RV64I instruction tests",
    "rv64m": "RV64M multiply/divide tests",
    "rv64f": "RV64F floating-point tests",
    "rv64d": "RV64D double-precision tests",
    "rv64v": "RV64V vector tests",
    "compliance": "RISC-V compliance tests",
    "integration": "Integration tests"
}

def run_test(test_name, simulator="verilator", verbose=False):
    """Run a specific test"""
    print(f"\n{'='*60}")
    print(f"Running test: {test_name}")
    print(f"{'='*60}\n")
    
    cmd = ["make", "-C", str(TEST_DIR), "run", 
           f"SIMULATOR={simulator}", f"TESTNAME={test_name}"]
    
    if verbose:
        cmd.append("VERBOSE=1")
    
    result = subprocess.run(cmd, capture_output=not verbose)
    
    if result.returncode == 0:
        print(f"✅ Test '{test_name}' PASSED")
        return True
    else:
        print(f"❌ Test '{test_name}' FAILED")
        return False

def run_all_tests(simulator="verilator"):
    """Run all tests"""
    print(f"\n{'='*60}")
    print(f"Running all tests with {simulator}")
    print(f"{'='*60}\n")
    
    results = {}
    for test_name in TEST_LIST:
        results[test_name] = run_test(test_name, simulator)
    
    # Summary
    print(f"\n{'='*60}")
    print("Test Summary")
    print(f"{'='*60}")
    passed = sum(results.values())
    total = len(results)
    print(f"Passed: {passed}/{total}")
    
    for test_name, result in results.items():
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"  {test_name}: {status}")
    
    return passed == total

def main():
    parser = argparse.ArgumentParser(description="OCPU Test Runner")
    parser.add_argument("test", nargs="?", help="Test name to run")
    parser.add_argument("-s", "--simulator", default="verilator",
                       choices=["verilator", "vcs", "modelsim"],
                       help="Simulator to use")
    parser.add_argument("-a", "--all", action="store_true",
                       help="Run all tests")
    parser.add_argument("-v", "--verbose", action="store_true",
                       help="Verbose output")
    parser.add_argument("-l", "--list", action="store_true",
                       help="List available tests")
    
    args = parser.parse_args()
    
    if args.list:
        print("Available tests:")
        for name, desc in TEST_LIST.items():
            print(f"  {name:<15} - {desc}")
        return 0
    
    if args.all:
        success = run_all_tests(args.simulator)
    elif args.test:
        if args.test not in TEST_LIST:
            print(f"Error: Unknown test '{args.test}'")
            print(f"Use -l to list available tests")
            return 1
        success = run_test(args.test, args.simulator, args.verbose)
    else:
        parser.print_help()
        return 1
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
