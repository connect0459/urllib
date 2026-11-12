# `urlpattern` package

URLPattern route matching for [MoonBit](https://moonbitlang.com). Implements the [URL Pattern Standard](https://urlpattern.spec.whatwg.org/) with full WPT (Web Platform Tests) coverage.

## Key types

| Type | Description |
| :--- | :--- |
| `UrlPattern` | A compiled URL pattern that matches against URL components |
| `UrlPatternInit` | Named-field constructor for per-component pattern strings |
| `UrlPatternResult` | Per-component match result returned by `exec_url` / `exec_init` |
| `UrlPatternComponentResult` | Input string and capture-group map for one component |
| `UrlPatternComponent` | Enum selecting a single URL component |
| `UrlPatternError` | Raised when a pattern string is invalid |

## Quick start

Basic matching:

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

Constructing from an init object:

```mbt check
///|
test {
  let p = @urlpattern.UrlPattern::from_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/books/:id")),
  )
  assert_eq(p.test_url("https://example.com/books/42"), true)
}
```

Case-insensitive matching:

```mbt check
///|
test {
  let p = @urlpattern.UrlPattern::from_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/Books/:id")),
    ignore_case=true,
  )
  assert_eq(p.test_url("https://example.com/books/42"), true)
}
```

---

## API reference

### `UrlPattern` type

```mbt nocheck
pub struct UrlPattern { /* private fields */ }
```

#### UrlPattern constructors

| Method | Signature | Description |
| :--- | :--- | :--- |
| `from_string` | `(String, String?, ignore_case?: Bool) -> Self raise UrlPatternError` | Construct from a URL pattern string and optional base URL |
| `from_init` | `(UrlPatternInit, ignore_case?: Bool) -> Self raise UrlPatternError` | Construct from an init object |

```mbt check
///|
test {
  // From a pattern string
  let p1 = @urlpattern.UrlPattern::from_string(
    "https://example.com/books/:id",
    None,
  )
  ignore(p1)

  // From an init object
  let p2 = @urlpattern.UrlPattern::from_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/books/:id")),
  )
  ignore(p2)

  // Case-insensitive
  let p3 = @urlpattern.UrlPattern::from_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/Books/:id")),
    ignore_case=true,
  )
  ignore(p3)
}
```

#### Testing and executing

| Method | Signature | Description |
| :--- | :--- | :--- |
| `test_url` | `(String, base_url? : String) -> Bool` | Returns `true` if the URL (resolved against the optional base) matches the pattern |
| `test_init` | `(UrlPatternInit) -> Bool` | Returns `true` if the init object matches |
| `exec_url` | `(String, base_url? : String) -> UrlPatternResult?` | Match with captured group extraction; an invalid base yields `None` |
| `exec_init` | `(UrlPatternInit) -> UrlPatternResult?` | Match init with captured group extraction |

```mbt check
///|
test {
  let p = @urlpattern.UrlPattern::from_string(
    "https://example.com/books/:id",
    None,
  )
  assert_eq(p.test_url("https://example.com/books/42"), true)
  assert_eq(p.test_url("https://other.com/books/42"), false)

  match p.exec_url("https://example.com/books/42") {
    None => assert_true(false)
    Some(result) =>
      match result.pathname() {
        Some(pr) =>
          match pr.groups().get("id") {
            Some(Some(v)) => assert_eq(v, "42")
            _ => assert_true(false)
          }
        None => assert_true(false)
      }
  }
}
```

#### Compiled pattern accessors

| Method | Returns | Description |
| :--- | :--- | :--- |
| `get_protocol()` | `String` | Compiled protocol pattern |
| `get_username()` | `String` | Compiled username pattern |
| `get_password()` | `String` | Compiled password pattern |
| `get_hostname()` | `String` | Compiled hostname pattern |
| `get_port()` | `String` | Compiled port pattern |
| `get_pathname()` | `String` | Compiled pathname pattern |
| `get_search()` | `String` | Compiled search pattern |
| `get_hash()` | `String` | Compiled hash pattern |

#### Advanced

| Method | Signature | Description |
| :--- | :--- | :--- |
| `has_regexp_groups()` | `Bool` | Whether any component contains a custom regexp group |
| `generate` | `(UrlPatternComponent, Map[String, String]) -> String?` | Reconstruct a URL component string from captured group values |
| `compare_component` | `(UrlPatternComponent, UrlPattern, UrlPattern) -> Int` | Specificity ordering for route-priority comparisons |

```mbt check
///|
test {
  let p = @urlpattern.UrlPattern::from_string(
    "https://example.com/books/:id",
    None,
  )
  assert_eq(p.has_regexp_groups(), false)

  // Generate a URL component from captured values
  let groups : Map[String, String] = { "id": "42" }
  match p.generate(@urlpattern.UrlPatternComponent::Pathname, groups) {
    Some(s) => assert_eq(s, "/books/42")
    None => assert_true(false)
  }

  // Specificity comparison: named segment is less specific than a literal
  let p1 = @urlpattern.UrlPattern::from_string(
    "/books/:id",
    Some("https://example.com"),
  )
  let p2 = @urlpattern.UrlPattern::from_string(
    "/books/42",
    Some("https://example.com"),
  )
  let cmp = @urlpattern.UrlPattern::compare_component(
    @urlpattern.UrlPatternComponent::Pathname,
    p1,
    p2,
  )
  assert_true(cmp < 0)
}
```

---

### `UrlPatternInit` type

```mbt nocheck
pub struct UrlPatternInit { /* private fields */ }
pub fn UrlPatternInit::new(
  protocol? : String?,
  username? : String?,
  password? : String?,
  hostname? : String?,
  port?     : String?,
  pathname? : String?,
  search?   : String?,
  hash?     : String?,
  base_url? : String?,
) -> Self
```

All fields default to `None` (wildcard) when omitted.

---

### `UrlPatternComponent` enum

```mbt nocheck
///|
#derive(Eq, @debug.Debug)
pub(all) enum UrlPatternComponent {
  Protocol
  Username
  Password
  Hostname
  Port
  Pathname
  Search
  Hash
}
```

Used as the component selector in `compare_component` and `generate`.

---

### `UrlPatternResult` type

```mbt nocheck
pub struct UrlPatternResult { /* private fields */ }
```

Returned by `exec_url` and `exec_init`.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `inputs()` | `Array[UrlPatternInput]` | The inputs passed to the match call |
| `protocol()` | `UrlPatternComponentResult?` | Protocol component match result |
| `username()` | `UrlPatternComponentResult?` | Username component match result |
| `password()` | `UrlPatternComponentResult?` | Password component match result |
| `hostname()` | `UrlPatternComponentResult?` | Hostname component match result |
| `port()` | `UrlPatternComponentResult?` | Port component match result |
| `pathname()` | `UrlPatternComponentResult?` | Pathname component match result |
| `search()` | `UrlPatternComponentResult?` | Search component match result |
| `hash()` | `UrlPatternComponentResult?` | Hash component match result |

When the call returns `Some(result)`, every component getter returns `Some(...)` — `exec_init` matches and guards each component before constructing the result, so a mismatch on any single component aborts the whole call with `None`. The `Option` wrapper on each getter exists only to keep room for forward-compatible component additions.

---

### `UrlPatternComponentResult` type

```mbt nocheck
pub struct UrlPatternComponentResult { /* private fields */ }
```

| Method | Returns | Description |
| :--- | :--- | :--- |
| `input()` | `String` | The input string for this component |
| `groups()` | `Map[String, String?]` | Capture-group name-to-value map |

`groups()` maps capture-group names to their matched values. Reading via `groups().get(name)`, a `Some(None)` result means the named group did not participate in the match (mirrors WPT's expected `null`); a `Some(Some(""))` result means the group participated and captured an empty string.

---

### `UrlPatternInput` type

```mbt nocheck
///|
pub enum UrlPatternInput {
  Str(String)
  Init(UrlPatternInit)
}
```

Records which form of input was passed to `exec_url` or `exec_init`.

---

### `UrlPatternError` type

```mbt nocheck
///|
pub suberror UrlPatternError {
  UrlPatternError(String)
}

///|
pub impl Show for UrlPatternError
```

Raised by `from_string` and `from_init` when the pattern is invalid.
