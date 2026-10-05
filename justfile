# Initialize WPT submodule (run once after clone)
setup:
    bash tools/setup_wpt.sh
    moon update
    pre-commit install

# Regenerate combining mark table from DerivedGeneralCategory.txt
# Usage: just gen-combining-mark                         (reads /tmp/DerivedGeneralCategory.txt)
#        just gen-combining-mark /path/to/DerivedGeneralCategory.txt
gen-combining-mark input='/tmp/DerivedGeneralCategory.txt':
    python3 tools/gen_combining_mark.py {{input}}

# Regenerate IDNA mapping tables from IdnaMappingTable.txt
# Usage: just gen-idna                         (reads /tmp/IdnaMappingTable.txt)
#        just gen-idna /path/to/IdnaMappingTable.txt
gen-idna input='/tmp/IdnaMappingTable.txt':
    python3 tools/gen_idna_mapping.py {{input}}

# Run tests for a single target (e.g. `just test-target wasm-gc`)
test-target target:
    moon check --deny-warn --target {{target}}
    moon test --target {{target}}

# Verify code quality and all targets (matches CI)
verify:
    moon fmt --check
    for t in js wasm wasm-gc native; do \
        just test-target $t; \
    done
