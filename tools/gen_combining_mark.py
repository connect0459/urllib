#!/usr/bin/env python3
"""Generate a sorted-range table of Unicode Mark code points (Mn, Mc, Me)
for use by the V6 leading-combining-mark check in IDNA validation.

Usage: python3 tools/gen_combining_mark.py [path/to/DerivedGeneralCategory.txt]
"""
import re
import sys


def output_path() -> str:
    return 'internal/idna/combining_mark.mbt'


MARK_CATEGORIES = ('Mn', 'Mc', 'Me')

path = sys.argv[1] if len(sys.argv) > 1 else '/tmp/DerivedGeneralCategory.txt'
version = None
marks = []
with open(path) as f:
    for line in f:
        if version is None:
            m = re.match(r'#\s*DerivedGeneralCategory-(\S+)\.txt', line)
            if m:
                version = m.group(1)
        if '#' in line:
            line = line[:line.index('#')]
        line = line.strip()
        if not line:
            continue
        cp_range, category = (x.strip() for x in line.split(';'))
        if category not in MARK_CATEGORIES:
            continue
        lo, _, hi = cp_range.partition('..')
        marks.append((int(lo, 16), int(hi or lo, 16)))
if version is None:
    sys.exit('error: version header not found in ' + path)

marks.sort()
ranges = []
for s, e in marks:
    if ranges and s == ranges[-1][1] + 1:
        ranges[-1] = (ranges[-1][0], e)
    else:
        ranges.append((s, e))

with open(output_path(), 'w') as f:
    f.write('// AUTO-GENERATED FILE — do not edit by hand.\n')
    f.write(f'// Source: DerivedGeneralCategory.txt (Unicode {version}): Mark (Mn|Mc|Me) ranges.\n')
    f.write('\n')
    f.write('///|\n')
    f.write('let combining_mark_ranges : Array[(Int, Int)] = [\n')
    for s, e in ranges:
        f.write(f'  ({s}, {e}),\n')
    f.write(']\n')
    f.write('\n')
    f.write('///|\n')
    f.write('fn is_combining_mark_table(cp : Int) -> Bool {\n')
    f.write('  let arr = combining_mark_ranges\n')
    f.write('  let mut lo = 0\n')
    f.write('  let mut hi = arr.length()\n')
    f.write('  while lo < hi {\n')
    f.write('    let mid = (lo + hi) / 2\n')
    f.write('    let (s, e) = arr[mid]\n')
    f.write('    if cp < s {\n')
    f.write('      hi = mid\n')
    f.write('    } else if cp > e {\n')
    f.write('      lo = mid + 1\n')
    f.write('    } else {\n')
    f.write('      return true\n')
    f.write('    }\n')
    f.write('  }\n')
    f.write('  false\n')
    f.write('}\n')
