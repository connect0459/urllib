# urllib

[![CI](https://github.com/connect0459/urllib/actions/workflows/ci.yml/badge.svg)](https://github.com/connect0459/urllib/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/connect0459/urllib/blob/main/LICENSE)
[![docs](https://img.shields.io/badge/docs-mooncakes.io-green)](https://mooncakes.io/docs/connect0459/urllib)

A WHATWG-compliant URL parsing library for [MoonBit](https://moonbitlang.com).

Implements the [URL Standard](https://url.spec.whatwg.org/) and [URL Pattern Standard](https://urlpattern.spec.whatwg.org/) with full WPT (Web Platform Tests) coverage.

## Packages

| Package | Description |
| :--- | :--- |
| `connect0459/urllib/url` | URL parsing, getters, setters, URLSearchParams, IDNA utilities |
| `connect0459/urllib/urlpattern` | URLPattern — route matching against URL components |

## Installation

```sh
moon add connect0459/urllib
```

Then declare the packages you need in your `moon.pkg`:

```mbt nocheck
///|
import {
  "connect0459/urllib/url",
  "connect0459/urllib/urlpattern",
}
```

## Usage

### URL Parsing

```mbt check
///|
test {
  let url = @url.parse("https://user:pass@example.com:8080/path?q=1#frag")
  assert_eq(url.href(), "https://user:pass@example.com:8080/path?q=1#frag")
  assert_eq(url.hostname(), "example.com")
  @debug.assert_eq(url.port(), Some(8080))
  assert_eq(url.pathname(), "/path")
  assert_eq(url.search(), "?q=1")
  assert_eq(url.origin(), "https://example.com:8080")

  // Infallible variant — returns None instead of raising
  let opt = @url.parse_maybe("not a url", None)
  @debug.assert_eq(opt, None)

  // Resolve a relative URL
  let base = @url.parse("https://example.com/a/b/c")
  let resolved = base.join("../d")
  assert_eq(resolved.href(), "https://example.com/a/d")
}
```

### URLSearchParams

```mbt check
///|
test {
  let params = @url.UrlSearchParams::from_string("a=1&b=2&a=3")
  @debug.assert_eq(params.get("a"), Some("1"))
  @debug.assert_eq(params.get_all("a"), ["1", "3"])

  params.append("c", "4")
  params.delete("b")
  params.set("a", "99")
  assert_eq(params.to_string(), "a=99&c=4")
}
```

### URLPattern

```mbt check
///|
test {
  let p = @urlpattern.UrlPattern::from_string(
    "https://example.com/books/:id",
    None,
  )
  assert_eq(p.test_url("https://example.com/books/42"), true)

  match p.exec_url("https://example.com/books/42") {
    Some(result) =>
      match result.pathname() {
        Some(pr) =>
          match pr.groups().get("id") {
            Some(Some(id)) => assert_eq(id, "42")
            _ => assert_true(false)
          }
        None => assert_true(false)
      }
    None => assert_true(false)
  }
}
```

### IDNA

```mbt check
///|
test {
  assert_eq(@url.domain_to_ascii("münchen.example"), "xn--mnchen-3ya.example")
  assert_eq(
    @url.domain_to_unicode("xn--mnchen-3ya.example"),
    "münchen.example",
  )
}
```

## Compliance

Full [Web Platform Tests (WPT)](https://github.com/web-platform-tests/wpt) coverage for the URL and URLPattern standards.

## Documentation

Each public package has a `README.mbt.md` with a key-types overview, usage examples, and a full API reference. Start with `url` for the main entry point.

- [ARCHITECTURE.md](https://github.com/connect0459/urllib/blob/main/docs/ARCHITECTURE.md) : Architecture overview

## Contributing

See [CONTRIBUTING.md](https://github.com/connect0459/urllib/blob/main/CONTRIBUTING.md).

## License

[Apache-2.0](https://github.com/connect0459/urllib/blob/main/LICENSE)
