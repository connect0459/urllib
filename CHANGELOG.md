# Changelog

<!--
When cutting a new release, update THREE places in this file:

1. Rename [Unreleased] to [X.Y.Z] with today's date (above), and add a fresh empty [Unreleased] section above it.
2. Update the reference links at the very bottom of this file:
    - Change [Unreleased] to compare the new tag against HEAD.
    - Add [X.Y.Z] comparing the new tag against the previous tag.
3. Push the release tag:

    ```console
    git tag vX.Y.Z && git push origin vX.Y.Z
    ```

   Pushing the tag triggers `.github/workflows/publish.yml`, which extracts this file's `[X.Y.Z]` section and creates the GitHub Release from it automatically. Do not run `gh release create` manually; it would create the Release with hand-pasted notes instead of the CHANGELOG-derived ones.
-->

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2026-10-05

### Changed

#### IDNA

- `url`: pass ASCII `xn--` labels through unchanged when the whole domain is ASCII instead of rejecting them as invalid Punycode, following the updated URL Standard; a domain that also contains non-ASCII labels is still validated (#82)
- `url`: regenerate the IDNA mapping and status tables from Unicode 18.0.0 (previously 16.0.0), so code points assigned in Unicode 17 and 18 are no longer treated as disallowed, and drop a hand-written forbidden range (U+34000..U+3FFFF) that overrode the generated table (#82)
- `url`: recognize the 79 combining marks assigned in Unicode 17 and 18 in the leading-combining-mark check (V6), by generating its table from `DerivedGeneralCategory.txt` 18.0.0 instead of the local Python runtime's Unicode database (#83)

### Fixed

- `urlpattern`: accept CJK ideographs beyond U+1DFFF (e.g. U+20000) as group names (#82)

### Miscellaneous

- **repo**: rename repository from `urllib-mbt` to `urllib`, since the library is not a binding of a specific upstream repository (#81)
- **chore**: update the `wpt` submodule to the latest revision (#82)
- **test**: keep supplementary-plane characters intact when sanitizing WPT JSON fixtures before parsing (#82)
- **chore**: add the `just fetch-unicode-data` recipe to download the pinned Unicode data used by the table generators, and derive the Unicode version in generated headers from the source file (#82, #83)
- **chore**: add `.moonignore` so agent instructions, APM files, local tooling, and the `wpt` submodule are not published to mooncakes, and `.gitattributes` to mark the generated IDNA tables (#84)
- **chore**: bump the pinned `moonbitlang/skills` revision in `apm.yml` and regenerate `apm.lock.yaml` (#84)
- **chore**: bump `moonbitlang/x` from 0.4.50 to 0.5.5 (#88)
- **ci**: add a manually triggered publish dry run that verifies the mooncakes credentials without publishing, and publish only from version tags (#85, #86)
- **ci**: add Dependabot for GitHub Actions and pre-commit hooks, bump `markdownlint-cli2`, and drop the full-history checkout now that the repository is public (#87)
- **chore**: ignore the `target` directory in `.gitignore` (#87)

## [0.4.5] - 2026-09-20

### Fixed

#### MoonBit toolchain compatibility

- `url`, `urlpattern`: apply `moon fmt`'s newly-enforced trailing comma in single-line struct/record literals (#75)
- `url`: move the `moonbitlang/core/debug` import into the package's `for "test"` block, since it was only referenced from test files but declared in the main import block, flagged as an unused package by `moon check --deny-warn` (#79)
- `url`, `urlpattern`, `internal/host`: add explicit `pub extend T with Trait::{methods}` declarations for trait methods a `derive(Eq, Debug)` or `pub impl Trait for T` previously promoted implicitly, no longer accepted by the latest MoonBit toolchain (#79)
- all packages' test files: qualify bare references to the enclosing package's own public symbols as `@pkg.Symbol`, no longer implicitly self-imported by the latest MoonBit toolchain (#79)

### Miscellaneous

- **ci**: skip the `lint`/`test` jobs at the job level (rather than per-step) when no relevant files changed, so GitHub reports them as skipped instead of a misleadingly green success (#74)
- **chore**: refresh the pinned `markdownlint-cli2` pre-commit revision and regenerate `apm.lock.yaml` (#76)
- **chore**: bump the pinned `moonbitlang/skills` revision in `apm.yml` and regenerate `apm.lock.yaml` (#77)
- **ci**: pin workflow actions to their latest release hashes and enforce `shell: bash` on steps that lacked it (#78)

## [0.4.4] - 2026-08-25

### Fixed

#### MoonBit toolchain compatibility

- multiple packages: replace deprecated `StringBuilder::new()` calls with the bare `StringBuilder()` constructor, no longer accepted under `--deny-warn` by the latest MoonBit toolchain (#71)

#### moonbitlang/core compatibility

- test suites: sanitize unpaired surrogates before parsing WPT JSON fixtures, required by moonbitlang/core's stricter `@json.parse` (#68)

### Miscellaneous

- **ci**: promote CHANGELOG heading levels in extracted release notes (#59)
- **ci**: render the Full Changelog link as its own section and fix related label/formatting issues in extracted release notes (#60)
- **ci**: replace inline changelog extraction with the extract-changelog action, later repointed at its renamed repository (#61, #66)
- **docs**: unwrap hard-wrapped prose and list items across Markdown docs; drop the commit body 72-char wrap convention (#62, #63, #64)
- **chore**: bump moonbitlang/x to 0.4.50 (#65)
- **ci**: consolidate required checks into a single gate job (#67)
- **docs**: drop stale `src/` prefix from package paths, then link the License section to the LICENSE file (#69, #70)
- **chore**: flatten the PR template into a single file (#72)

## [0.4.3] - 2026-08-13

### Fixed

#### MoonBit toolchain compatibility

- `urlpattern`: spell out an empty `Map` literal in `match_component` as `Map([])` instead of the now-ambiguous bare `{}`, flagged as `ambiguous_braces` by the latest MoonBit toolchain (#49)
- test suites: replace deprecated bare `to_repr(x)` calls with `Repr(x)`, no longer implicitly promoted by the latest MoonBit toolchain; adjust the `mbt nocheck` import fence in README.mbt.md for the latest `moon fmt`; bump pinned `moonbitlang/x` from 0.4.45 to 0.4.49; regenerate `pkg.generated.mbti` for the latest `moon info` output (#55)

### Miscellaneous

- **docs**: add Contributor Covenant Code of Conduct v2.1 (#46)
- **docs**: add SECURITY.md security policy (#48)
- **docs**: add Type vs. Scope Precedence section (#50)
- **docs**: reorder README badges to put repo badges before external ones (#51)
- **docs**: list pre-commit in Prerequisites and auto-install via `just setup` (#54)
- **ci**: clarify lint/test responsibilities and use `--target all` (#45)
- **ci**: skip CI steps when no code-related files changed (#52)
- **ci**: create GitHub Release from CHANGELOG.md on tag push, and append a Full Changelog comparison link to the Release body (#56, #57)
- **chore**: nest PR template and add release template (#53)

## [0.4.2] - 2026-06-10

### Miscellaneous

- **docs**: fix broken relative package link in root `README.mbt.md` (#41)
- **ci**: unify test matrix into a single sequential job; deny warnings in check steps (#42)
- **test**: replace deprecated `try?` with `try/catch/noraise` (#43)

## [0.4.1] - 2026-06-08

### Miscellaneous

- **docs**: add mooncakes.io docs badge to README
- **docs**: add per-package `README.mbt.md` as the single documentation source for each public package
- **docs**: enable `README.mbt.md` doc-tests via root `moon.pkg`
- **docs**: fix mooncakes.io path resolution for doc rendering
- **chore**: update apm lock; reorder `import` block in `moon.mod`

## [0.4.0] - 2026-06-07

### Miscellaneous

- **repo**: rename repository from `urllib.mbt` to `urllib-mbt`
- **chore**: migrate module layout to flat package structure
- **chore**: expand `just verify` to all four CI backends (`js`, `wasm`, `wasm-gc`, `native`)
- **chore**: bump `moonbitlang/x` from 0.4.43 to 0.4.45
- **ci**: set `persist-credentials: false` on `actions/checkout`
- **docs**: update CONTRIBUTING.md and AGENTS.md to document pre-commit hooks and `just verify` gate

## [0.3.0] - 2026-05-27

### Changed

- **urlpattern**: `UrlPatternInit`, `UrlPatternComponentResult`, and `UrlPatternResult` fields are now private; use getter methods to access values (`input()`, `groups()`, `protocol()`, `pathname()`, etc.)

### Miscellaneous

- **urlpattern**: add benchmark suite covering pattern compilation (`from_string`, `from_init`) and URL matching (`exec_url`, `test_url`)

## [0.2.0] - 2026-05-24

### Changed

- **urlpattern**: `compare_component` / `generate` take a typed `UrlPatternComponent` enum (was `String`)
- **url**: `Url` implements `ToJson` trait instead of exposing a `to_json()` method

### Added

- **url**: `impl Show for UrlSearchParams`

### Removed

- Hide `percent_encoding`, `idna`, and `host` sub-packages under `internal/` (no longer importable)
- **url**: drop the `@url.Host` type re-export
- **url**: privatize fields of `Url` and `UrlSearchParams`
- **url**: privatize `UrlPath` enum constructors

### Performance

- **url**: eliminate O(N²) string concat in credentials parsing
- **url**: reduce allocations in `percent_decode`, `percent_encode`, `UrlSearchParams` sort / serialization
- **url**: add fast paths in `strip_tab_newline`, `is_dot_segment`, `is_single_dot`
- **host / idna**: reduce allocations in hex / numeric helpers and ASCII-only label processing

### Refactored

- **url / urlpattern**: replace C-style loops and mutation blocks with idiomatic MoonBit iteration
- **url / urlpattern**: extract shared utilities (`lower_ipv6_literal`, `strip_leading_char`, `encode_part_str`)
- **host**: eliminate `parse_ipv6` panic path (returns `None` instead)

### Miscellaneous

- **ci**: extend test matrix to `js`, `wasm`, `wasm-gc`, `native`
- **docs**: add GitHub issue and pull request templates

## [0.1.0] - 2026-05-23

### Added

#### URL parsing (`connect0459/urllib/url`)

- `parse(String)` — parses a URL string; raises `UrlParseError` on failure
- `parse_maybe(String, Url?)` — infallible variant; returns `None` on failure
- `parse_with_base(String, Url?)` — parses with an explicit base URL
- `can_parse(String, Url?)` — validity check without allocating a `Url`
- Full WHATWG URL Standard compliance with 100 % WPT pass rate

**Getters**: `href`, `protocol`, `scheme`, `username`, `password`, `hostname`, `host_str`, `port`, `port_str`, `pathname`, `search`, `hash`, `origin`, `to_json`

**Predicates**: `is_special`, `has_credentials`, `has_opaque_path`, `has_host`, `has_port`, `has_query`, `has_fragment`, `has_authority`

**Setters** (immutable — each returns a new `Url`): `set_href` (raises), `set_protocol`, `set_username`, `set_password`, `set_host`, `set_hostname`, `set_port`, `set_pathname`, `set_search`, `set_hash`

**Path utilities**: `path_segments` iterator; `join` for relative URL resolution

**File URL helpers**: `from_file_path`, `from_directory_path`, `to_file_path`

**Query helpers**: `search_params`, `query_pairs`, `parse_with_params`

**Authority helpers**: `authority`, `domain`, `make_relative`, `port_or_known_default`

#### URLSearchParams (`connect0459/urllib/url`)

- `UrlSearchParams::from_string(String)` — parses `application/x-www-form-urlencoded` data
- Operations: `get`, `get_all`, `has`, `size`, `append`, `delete`, `set`, `sort`
- Iterators: `iter` (name-value pairs), `keys`, `values`, `entries`

#### IDNA utilities (`connect0459/urllib/url`)

- `domain_to_ascii(String)` — UTS#46 Unicode-to-ACE conversion
- `domain_to_unicode(String)` — ACE-to-Unicode conversion
- Full WPT IdnaTestV2 coverage (2670 / 2670)

#### URLPattern (`connect0459/urllib/urlpattern`)

- `UrlPattern::from_string` — constructs a pattern from a URL pattern string
- `UrlPattern::from_init` — constructs from a `UrlPatternInit` object
- `ignore_case` option for case-insensitive matching
- `test_url` / `test_init` — boolean URL matching
- `exec_url` / `exec_init` — match with captured group extraction
- Compiled pattern accessors: `get_protocol`, `get_username`, `get_password`, `get_hostname`, `get_port`, `get_pathname`, `get_search`, `get_hash`
- `has_regexp_groups` — reports whether any component contains a custom regexp group
- `generate` — reconstructs a URL string from a pattern and captured group values
- `compare_component` — specificity ordering for route-priority comparisons

---

[Unreleased]: <https://github.com/connect0459/urllib/compare/v0.5.0...HEAD>
[0.5.0]: <https://github.com/connect0459/urllib/compare/v0.4.5...v0.5.0>
[0.4.5]: <https://github.com/connect0459/urllib/compare/v0.4.4...v0.4.5>
[0.4.4]: <https://github.com/connect0459/urllib/compare/v0.4.3...v0.4.4>
[0.4.3]: <https://github.com/connect0459/urllib/compare/v0.4.2...v0.4.3>
[0.4.2]: <https://github.com/connect0459/urllib/compare/v0.4.1...v0.4.2>
[0.4.1]: <https://github.com/connect0459/urllib/compare/v0.4.0...v0.4.1>
[0.4.0]: <https://github.com/connect0459/urllib/compare/v0.3.0...v0.4.0>
[0.3.0]: <https://github.com/connect0459/urllib/compare/v0.2.0...v0.3.0>
[0.2.0]: <https://github.com/connect0459/urllib/compare/v0.1.0...v0.2.0>
[0.1.0]: <https://github.com/connect0459/urllib/releases/tag/v0.1.0>
