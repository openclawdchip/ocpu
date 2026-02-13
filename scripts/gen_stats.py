#!/usr/bin/env python3
"""
OCPU RTL Statistics Generator
Generates statistics about the RTL codebase
"""

import os
import sys
from pathlib import Path
from collections import defaultdict

def count_lines_in_file(filepath):
    """Count lines in a file"""
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            return len(f.readlines())
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
        return 0

def analyze_rtl(rtl_dir):
    """Analyze RTL directory"""
    stats = {
        'total_files': 0,
        'total_lines': 0,
        'modules': defaultdict(lambda: {'files': 0, 'lines': 0})
    }
    
    rtl_path = Path(rtl_dir)
    
    for sv_file in rtl_path.rglob("*.sv"):
        rel_path = sv_file.relative_to(rtl_path)
        module_name = rel_path.parts[0] if rel_path.parts else 'other'
        
        lines = count_lines_in_file(sv_file)
        
        stats['total_files'] += 1
        stats['total_lines'] += lines
        stats['modules'][module_name]['files'] += 1
        stats['modules'][module_name]['lines'] += lines
    
    return stats

def print_stats(stats):
    """Print statistics"""
    print("=" * 60)
    print("OCPU RTL Statistics")
    print("=" * 60)
    print()
    print(f"Total Files: {stats['total_files']}")
    print(f"Total Lines: {stats['total_lines']:,}")
    print()
    print("-" * 60)
    print(f"{'Module':<20} {'Files':>10} {'Lines':>15} {'%':>10}")
    print("-" * 60)
    
    # Sort modules by file count
    sorted_modules = sorted(stats['modules'].items(), 
                          key=lambda x: x[1]['files'], 
                          reverse=True)
    
    for module_name, module_stats in sorted_modules:
        files = module_stats['files']
        lines = module_stats['lines']
        percentage = (files / stats['total_files']) * 100
        
        print(f"{module_name:<20} {files:>10} {lines:>15,} {percentage:>9.1f}%")
    
    print("-" * 60)
    print()
    
    # Average lines per file
    avg_lines = stats['total_lines'] / stats['total_files'] if stats['total_files'] > 0 else 0
    print(f"Average lines per file: {avg_lines:.1f}")
    print()

def main():
    """Main function"""
    rtl_dir = "../rtl"
    
    if len(sys.argv) > 1:
        rtl_dir = sys.argv[1]
    
    if not os.path.exists(rtl_dir):
        print(f"Error: Directory '{rtl_dir}' not found")
        sys.exit(1)
    
    stats = analyze_rtl(rtl_dir)
    print_stats(stats)
    
    # Save to file
    with open("rtl_stats.txt", "w") as f:
        # Redirect stdout to file
        import io
        old_stdout = sys.stdout
        sys.stdout = io.StringIO()
        print_stats(stats)
        output = sys.stdout.getvalue()
        sys.stdout = old_stdout
        f.write(output)
    
    print("Statistics saved to rtl_stats.txt")

if __name__ == "__main__":
    main()
