# todo - uri

Current state: **611/611 WPT success cases pass (100%)**  
URLPattern: **384/384 tests pass (0 failed, 3 skipped). 65/65 string pattern constructor cases pass.**  
WPT URLPattern hasRegExpGroups: **10/10 test assertions pass.**  
WPT URLPattern generate: **19/19 cases pass.**  
WPT URLPattern compareComponent: **100/100 assertions pass (25 entries × 4 assertions).**  
Coverage: **589 unit tests pass. 9 uncovered lines in 4 files (all verified unreachable).**

---

## Infrastructure

- [x] **`src/` layout migration** — added `"source": "src"` to `moon.mod.json`; moved all source files under `src/`. Public module name `connect0459/moon_uri`.
- [x] **Module rename `moon_uri` → `uri`** — renamed to `connect0459/uri`; updated all source file names, test aliases, and `.mbti` interface files.

---

## Package architecture

- [x] **Extract `src/idna/` sub-package** — IDNA tables, Punycode, and domain-to-ASCII helpers; no external deps.
- [x] **Extract `src/percent_encoding/` sub-package** — percent-encode/decode utilities; no external deps.
  - `percent_encoding_wpt_test.mbt` stays in `src/` to avoid circular dependency with `@uri.parse`
- [x] **Extract `src/host/` sub-package** — `Host` type, IPv4/IPv6 parsers, forbidden-char checks; deps: `@idna`, `@pe`.
  - `Host::empty_domain()` factory function added — MoonBit external enum constructors are pattern-match-only
  - `src/types.mbt` re-exports via `pub type Host = @host.Host`

```text
connect0459/uri/idna              — IDNA (no deps)
connect0459/uri/percent_encoding  — percent encode/decode (no deps)
connect0459/uri/host              — Host type + parsing/serialization (deps: @idna, @pe)
connect0459/uri                   — URL parser/API (deps: @host, @pe)
```

---

## Core URL parser

### Bug fixes

- [x] **`%2e%2e` trailing slash** — `https://example.com/aaa/bbb/%2e%2e?query` → `aaa/?query`
- [x] **IPv4 fallback on invalid hex** — `http://0x7f.0.0.0x7g` treated as domain (not error)
- [x] **Opaque path encoding** — C0 percent-encoding applied at `?`/`#` stops in `OpaquePath` state
- [x] **Multiple `@` in credentials** — `https://@@@example` → `%40%40@example/`
- [x] **`///` relative to non-special base** — `///` + `sc://x/` → `sc:///`
- [x] **Percent-encode set correctness** — `^` (U+005E) encoded as `%5E` in path
- [x] **Windows drive letter in file URLs** — detection in File/FileSlash/FileHost/Path states
- [x] **Non-special `//` path normalization** — `non-spec:/a/..//path` → `non-spec:/.//path`
- [x] **IDNA / Punycode** — full RFC 3492 Punycode; per-label ACE encoding; `xn--` label validation; full UTS#46 table-driven processing (87/87 WPT toascii)
- [x] **IPv4 overflow** — `UInt64` with saturation at 2^32; values ≥ 2^32 rejected
- [x] **Empty host with port for non-special schemes** — `sc://:/` now correctly rejected
- [x] **Forbidden chars in special URL domain hosts** — C0, DEL, `%`, U+FFFD, nonchars, IDNA-disallowed spaces
  - 6 remaining WPT failure cases (`xn--pokxncvks`) require full Punycode validation — out of scope

### URL Setters

- [x] **URL Setters: 278/278 WPT cases** — `set_href`, `set_protocol`, `set_username`, `set_password`, `set_host`, `set_hostname`, `set_port`, `set_pathname`, `set_search`, `set_hash`
  - `Url` remains immutable; all setters return a new `Url` value
  - `set_href` raises `UrlParseError` on invalid input; other setters are no-ops on invalid input
  - setters strip `\t`/`\n`/`\r` only (not leading/trailing C0 or space), matching WHATWG basic URL parse with state override

---

## WPT conformance

- [x] **Phase 1 — Static utilities** — `can_parse`, `parse_maybe`, `to_json`
- [x] **Phase 2 — URLSearchParams** — `UrlSearchParams` struct + 13 operation methods; `sort()` uses UTF-16 code-unit comparison
- [x] **Phase 3 — WPT URL getter tests: 611/611** — `protocol`, `username`, `password`, `hostname`, `host`, `port`, `pathname`, `search`, `hash`; `origin` 399/399; `blob:` URL origin fixed
- [x] **Phase 4 — WPT url-setters-stripping: 270/270** — C0-char stripping for all setters; implementation already compliant
- [x] **Phase 5 — `Url::search_params` getter: 9/9** — returns snapshot of URL query as `UrlSearchParams`
  - live URL↔URLSearchParams bidirectional sync not planned (requires mutable `Url`)
- [x] **Phase 6 — WPT urlencoded-parser: 35/35** — `utf8_bytes_to_string` continuation-byte validation fix (`(b & 0xC0) == 0x80`)
- [x] **Phase 7 — WPT percent-encoding: 14/14** — no implementation changes needed; non-UTF-8 encoding variants out of scope
- [x] **Phase 8 — WPT static methods + URLSearchParams operations** — `can_parse` 4/4, `parse_maybe` 4/4, `to_json` 1/1, all URLSearchParams operation suites 55/55
- [x] **Phase 9 — WPT IdnaTestV2: 2670/2670 (100%)** — full UTS#46 table-driven processing; NFC composition; CONTEXTJ ZWJ validation; BIDI RTL/Latin rejection
- [x] **Strict-mode oracle — Unicode `IdnaTestV2.txt` 18.0.0** — vendored under `testdata/unicode`; `domain_to_ascii(strict=true)` agrees on all cases except two documented groups
  - Known limitation: the RFC 5893 Bidi rule (B1–B6) is approximated by an RTL/LTR mixing check, so names the oracle rejects with a `B*` status are accepted; a faithful check needs the `Bidi_Class` table
  - Spec interpretation difference: a trailing root dot is accepted (UTS #46 §4.2 excludes the root label from the DNS length check) although `IdnaTestV2.txt` reports `A4_2`

---

## WHATWG API completeness

- [x] **Phase 10 — Method-style getters** — `scheme()`, `username()`, `password()`, `port() -> Int?`, `path_segments() -> Iter[String]?`
  - `path_segments()` returns `None` for opaque-path URLs (mirrors rust-url)

---

## URLPattern

- [x] **URL Pattern API** — `src/urlpattern/` sub-package; WPT runner: 384/384 (0 failed, 3 skipped); 65/65 string pattern constructor cases
  - optional groups with prefix/suffix use outer capturing `(prefix value suffix)?` and strip prefix/suffix in `match_component` — MoonBit regex does not backtrack inside `(?:prefix(.*)suffix)?`
  - default port stripping for special-scheme protocols in `from_init`
  - `None→""` in `exec_init`: all components always matched; fixed-value patterns reject absent inputs
  - path normalization via `normalize_path_dots` (not URL parser) to avoid `\` being treated as separator in HTTPS scheme
- [x] **Phase 11 — `ignoreCase` option** — wraps compiled regexes in `(?i:...)`
- [x] **Phase 12 — `hasRegExpGroups` + `generate`** — `SegmentWildcard`/`FullWildcard` do not count as regexp groups; `encode_value_for_generate` uses direct percent-encoding to avoid URL-parser C0 stripping
- [x] **Phase 13 — `compareComponent`** — pairwise specificity; merges consecutive `NoMod FixedText` parts; `compare_str_lex` for true code-unit lexicographic order (MoonBit's `String::compare` is length-first)
- [x] **Constructor edge cases** — `%25(` pathname raises via strict tokenizer; `from_init(UrlPatternInit::new())` defaults all components to wildcard

---

## API extensions

- [x] **API ergonomics** — `Show` for `Url`/`UrlSearchParams`; `join()`, `is_special()`, `has_credentials()`, `has_opaque_path()`, `percent_encode_c0()`; `has_authority()`, `authority()`, `domain()`, `make_relative()`
- [x] **UrlSearchParams iterators** — `keys()`, `values()`, `entries()` (WHATWG iterator surface complete)
- [x] **`port_or_known_default()`** — explicit port or scheme default (http/ws→80, https/wss→443, ftp→21)
- [x] **`parse_with_params()`** — parses URL and appends query parameters; preserves existing query
- [x] **`from_file_path()` / `to_file_path()`** — filesystem path ↔ `file://` URL; Unix and Windows drive-letter paths
- [x] **`from_directory_path()`** — wraps `from_file_path` with trailing `/`; usable as base URL for relative resolution
- [x] **`query_pairs()`** — delegates to `search_params().iter()`
- [x] **Raw getters + predicates** — `query()`, `fragment()`, `has_host()`, `has_port()`, `has_query()`, `has_fragment()`

---

## Documentation

- [x] **Doc comments for all public APIs** — `///` + `### Example` / `mbt check` blocks for every exported function, method, and type across `url` and `urlpattern` packages

---

## Out-of-scope WPT files

| File | Reason |
| :--- | :--- |
| `url-searchparams.any.js` | Live `Url ↔ UrlSearchParams` bidirectional sync; object-identity; JS readonly-property `TypeError` |
| `url-setters-a-area.window.js` | HTML `<a>` / `<area>` elements via DOM APIs |
| `historical.any.js` | JS-only: `location.searchParams`, `structuredClone`, coercion |
| `javascript-urls.window.js` | Browser navigation of `javascript:` URLs |
| `idlharness.any.js` | WebIDL interface tests; requires WebIDL harness |
