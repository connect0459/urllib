#!/usr/bin/env python3
"""Generate IDNA UTS46 mapping data from IdnaMappingTable.txt.

Strategy: only emit non-valid status ranges to keep the table small. Default
status (when a cp is not in any range) is treated as `disallowed` (which is
what IdnaMappingTable does for unassigned codepoints anyway).

Adjacent ranges with the same status code AND no individual mapping (i.e.
ignored, disallowed, disallowed_STD3_valid) are merged. Mapped/deviation/
disallowed_STD3_mapped ranges are kept per individual cp because each may
have a distinct mapping target.
"""
import sys


def status_output_path() -> str:
    return 'internal/idna/idna_status.mbt'


def mapping_output_path() -> str:
    return 'internal/idna/idna_mapping.mbt'


STATUS = {
    'valid': 0,
    'ignored': 1,
    'mapped': 2,
    'deviation': 3,
    'disallowed': 4,
    'disallowed_STD3_valid': 5,
    'disallowed_STD3_mapped': 6,
}

path = sys.argv[1] if len(sys.argv) > 1 else '/tmp/IdnaMappingTable.txt'
raw = []
version = None
with open(path) as f:
    for line in f:
        if version is None and line.startswith('# Version:'):
            version = line.split(':', 1)[1].strip()
        if '#' in line:
            line = line[:line.index('#')]
        line = line.strip()
        if not line:
            continue
        parts = [p.strip() for p in line.split(';')]
        rng = parts[0]
        status = parts[1]
        mapping = parts[2] if len(parts) > 2 else ''
        if '..' in rng:
            a, b = rng.split('..')
            start = int(a, 16); end = int(b, 16)
        else:
            start = int(rng, 16); end = start
        code = STATUS[status]
        m = None
        if status in ('mapped', 'deviation', 'disallowed_STD3_mapped'):
            if mapping:
                m = [int(x, 16) for x in mapping.split()]
            else:
                m = []
        raw.append((start, end, code, m))

# Build status ranges, excluding `valid` (0). Coalesce adjacent same-status with no mapping.
status_entries = []  # (start, end, code)
for s, e, c, _m in raw:
    if c == 0:  # skip explicit valid
        continue
    if status_entries:
        ps, pe, pc = status_entries[-1]
        if pc == c and s == pe + 1:
            status_entries[-1] = (ps, e, c)
            continue
    status_entries.append((s, e, c))

# Mapping entries: per-codepoint
mapped = []
for s, e, c, m in raw:
    if m is None:
        continue
    for cp in range(s, e + 1):
        mapped.append((cp, m, c))
mapped.sort()

# Write status table
with open(status_output_path(), 'w') as f:
    f.write('// AUTO-GENERATED FILE — do not edit by hand.\n')
    f.write(f'// Source: IdnaMappingTable.txt (Unicode {version})\n')
    f.write('// Status codes: 0=valid 1=ignored 2=mapped 3=deviation 4=disallowed 5=disallowed_STD3_valid 6=disallowed_STD3_mapped\n')
    f.write('// Codepoints not listed default to valid (0).\n')
    f.write('// (Unassigned code points are explicitly disallowed by the IdnaMappingTable.)\n\n')
    f.write('///|\n')
    f.write('let idna_status_table : Array[(Int, Int, Int)] = [\n')
    for s, e, c in status_entries:
        f.write(f'  ({s}, {e}, {c}),\n')
    f.write(']\n\n')
    f.write('///|\n')
    f.write('fn idna_status_code(cp : Int) -> Int {\n')
    f.write('  let arr = idna_status_table\n')
    f.write('  let mut lo = 0\n')
    f.write('  let mut hi = arr.length()\n')
    f.write('  while lo < hi {\n')
    f.write('    let mid = (lo + hi) / 2\n')
    f.write('    let (s, e, c) = arr[mid]\n')
    f.write('    if cp < s {\n')
    f.write('      hi = mid\n')
    f.write('    } else if cp > e {\n')
    f.write('      lo = mid + 1\n')
    f.write('    } else {\n')
    f.write('      return c\n')
    f.write('    }\n')
    f.write('  }\n')
    f.write('  0 // default: valid\n')
    f.write('}\n')

# Write mapping table
with open(mapping_output_path(), 'w') as f:
    f.write('// AUTO-GENERATED FILE — do not edit by hand.\n')
    f.write(f'// Source: IdnaMappingTable.txt (Unicode {version})\n\n')
    f.write('///|\n')
    f.write('let idna_mapping_keys : Array[Int] = [\n')
    for cp, _m, _c in mapped:
        f.write(f'  {cp},\n')
    f.write(']\n\n')
    f.write('///|\n')
    f.write('let idna_mapping_values : Array[Array[Int]] = [\n')
    for _cp, m, _c in mapped:
        f.write('  [' + ', '.join(str(x) for x in m) + '],\n')
    f.write(']\n\n')
    f.write('///|\n')
    f.write('fn idna_mapping_lookup(cp : Int) -> Array[Int]? {\n')
    f.write('  let keys = idna_mapping_keys\n')
    f.write('  let mut lo = 0\n')
    f.write('  let mut hi = keys.length()\n')
    f.write('  while lo < hi {\n')
    f.write('    let mid = (lo + hi) / 2\n')
    f.write('    let k = keys[mid]\n')
    f.write('    if cp < k {\n')
    f.write('      hi = mid\n')
    f.write('    } else if cp > k {\n')
    f.write('      lo = mid + 1\n')
    f.write('    } else {\n')
    f.write('      return Some(idna_mapping_values[mid])\n')
    f.write('    }\n')
    f.write('  }\n')
    f.write('  None\n')
    f.write('}\n')

print(f'Status entries (non-valid coalesced): {len(status_entries)}', file=sys.stderr)
print(f'Mapping entries: {len(mapped)}', file=sys.stderr)
