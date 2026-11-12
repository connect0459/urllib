# `url` package

WHATWG URL parsing, mutation, and URLSearchParams for [MoonBit](https://moonbitlang.com). Implements the [URL Standard](https://url.spec.whatwg.org/) with full WPT (Web Platform Tests) coverage.

## Key types

| Type | Description |
| :--- | :--- |
| `Url` | A parsed, validated URL; immutable — all setters return a new `Url` |
| `UrlSearchParams` | Mutable key-value store for the query component |
| `UrlParseError` | Raised on invalid input by `parse`, `join`, and the setter `set_href` |

## Quick start

Parsing and inspecting a URL:

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

URLSearchParams:

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

IDNA:

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

---

## API reference

### Constructors

| Function | Signature | Description |
| :--- | :--- | :--- |
| `parse` | `(String) -> Url raise UrlParseError` | Parse a URL string; raises on failure |
| `parse_maybe` | `(String, Url?) -> Url?` | Infallible variant; returns `None` on failure |
| `parse_with_base` | `(String, Url?) -> Url raise UrlParseError` | Parse with an explicit base URL |
| `can_parse` | `(String, Url?) -> Bool` | Returns `true` if the URL parses successfully |
| `parse_with_params` | `(String, Array[(String, String)]) -> Url raise UrlParseError` | Parse and append query parameters |
| `from_file_path` | `(String) -> Url raise UrlParseError` | Convert a filesystem path to a `file://` URL |
| `from_directory_path` | `(String) -> Url raise UrlParseError` | Like `from_file_path` with a trailing `/`; usable as a base URL |

```mbt check
///|
test {
  let url = @url.parse("https://user:pass@example.com:8080/path?q=1#frag")
  ignore(url)

  // Infallible — returns None instead of raising
  let opt = @url.parse_maybe("not a url", None)
  @debug.assert_eq(opt, None)

  // Validity check
  assert_eq(@url.can_parse("https://example.com", None), true)

  // Parse with base
  let base = @url.parse("https://example.com/dir/")
  let url2 = @url.parse_with_base("/page", Some(base))
  ignore(url2)

  // Parse with query parameters appended
  let url3 = @url.parse_with_params("https://example.com/search", [
    ("q", "moon"),
    ("lang", "en"),
  ])
  ignore(url3)
}
```

### File URL helpers

```mbt check
///|
test {
  // Filesystem path → file:// URL
  let url = @url.from_file_path("/home/user/file.txt")
  assert_eq(url.href(), "file:///home/user/file.txt")

  // Directory path (trailing /)
  let base = @url.from_directory_path("/home/user/")
  let rel = base.join("file.txt")
  assert_eq(rel.href(), "file:///home/user/file.txt")

  // file:// URL → filesystem path
  let path = url.to_file_path()
  assert_eq(path, "/home/user/file.txt")
}
```

---

### `Url` type

```mbt nocheck
pub struct Url { /* private fields */ } derive(Eq, @debug.Debug)
pub impl Show  for Url  // href()
pub impl ToJson for Url // href()
```

#### Getters

| Method | Returns | Description |
| :--- | :--- | :--- |
| `href()` | `String` | Full serialized URL |
| `protocol()` | `String` | Scheme with trailing colon (`"https:"`) |
| `scheme()` | `String` | Scheme without colon (`"https"`) |
| `username()` | `String` | Username (empty string if absent) |
| `password()` | `String` | Password (empty string if absent) |
| `hostname()` | `String` | Host without port |
| `host_str()` | `String` | Host with port if non-default |
| `port()` | `Int?` | Typed port; `None` if absent or default |
| `port_str()` | `String` | Port as string; empty string if absent |
| `port_or_known_default()` | `Int?` | Explicit port or scheme default (80/443/21) |
| `pathname()` | `String` | Path component |
| `search()` | `String` | Query string with leading `?`; empty if absent |
| `query()` | `String?` | Raw query without leading `?`; `None` if absent |
| `hash()` | `String` | Fragment with leading `#`; empty if absent |
| `fragment()` | `String?` | Raw fragment without leading `#`; `None` if absent |
| `origin()` | `String` | Serialized origin |
| `authority()` | `String` | `username:password@host:port` component |

#### Predicates

| Method | Returns | Description |
| :--- | :--- | :--- |
| `is_special()` | `Bool` | `true` for `http`, `https`, `ftp`, `file`, `ws`, `wss` |
| `has_credentials()` | `Bool` | `true` when username or password is non-empty |
| `has_opaque_path()` | `Bool` | `true` for non-hierarchical URLs (e.g. `data:…`) |
| `has_authority()` | `Bool` | `true` when the URL has an authority component |
| `has_host()` | `Bool` | `true` when the URL has a host |
| `has_port()` | `Bool` | `true` when an explicit port is present |
| `has_query()` | `Bool` | `true` when a query string is present |
| `has_fragment()` | `Bool` | `true` when a fragment is present |

#### Authority helpers

| Method | Returns | Description |
| :--- | :--- | :--- |
| `domain()` | `String?` | Registered domain name; `None` for IPs and opaque hosts |
| `make_relative(other: Url)` | `String?` | Relative path from `self` to `other`; `None` if different origins |

```mbt check
///|
test {
  let base = @url.parse("https://example.com/a/b/")
  let other = @url.parse("https://example.com/a/c/d")
  @debug.assert_eq(base.make_relative(other), Some("../c/d"))
}
```

#### Path utilities

| Method | Returns | Description |
| :--- | :--- | :--- |
| `path_segments()` | `Iter[String]?` | Iterator over decoded path segments; `None` for opaque-path URLs |
| `join(relative: String)` | `Url raise UrlParseError` | Resolve a relative URL against this URL |

```mbt check
///|
test {
  let url = @url.parse("https://example.com/a/b/c")
  let segs : Array[String] = []
  match url.path_segments() {
    Some(iter) =>
      for seg in iter {
        segs.push(seg)
      }
    None => ()
  }
  @debug.assert_eq(segs, ["a", "b", "c"])

  let base = @url.parse("https://example.com/a/b/c")
  let resolved = base.join("../d")
  assert_eq(resolved.href(), "https://example.com/a/d")
}
```

#### Query helpers

| Method | Returns | Description |
| :--- | :--- | :--- |
| `search_params()` | `UrlSearchParams` | Snapshot of the query string as `UrlSearchParams` |
| `query_pairs()` | `Iter[(String, String)]` | Iterator over decoded name-value pairs |

#### File URL helper

| Method | Returns | Description |
| :--- | :--- | :--- |
| `to_file_path()` | `String raise UrlParseError` | Convert a `file://` URL back to a filesystem path |

#### Setters

All setters return a **new** `Url` — the original is unchanged.

| Method | Signature | Notes |
| :--- | :--- | :--- |
| `set_href` | `(String) -> Url raise UrlParseError` | Raises on invalid input |
| `set_protocol` | `(String) -> Url` | No-op on invalid input |
| `set_username` | `(String) -> Url` | No-op on invalid input |
| `set_password` | `(String) -> Url` | No-op on invalid input |
| `set_host` | `(String) -> Url` | Sets host and port together |
| `set_hostname` | `(String) -> Url` | Sets host only |
| `set_port` | `(String) -> Url` | No-op on invalid input |
| `set_pathname` | `(String) -> Url` | No-op on invalid input |
| `set_search` | `(String) -> Url` | No-op on invalid input |
| `set_hash` | `(String) -> Url` | No-op on invalid input |

```mbt check
///|
test {
  let url = @url.parse("https://example.com/old")
  let url2 = url.set_pathname("/new").set_search("q=hello")
  assert_eq(url.href(), "https://example.com/old")
  assert_eq(url2.href(), "https://example.com/new?q=hello")
}
```

---

### `UrlParseError` type

```mbt nocheck
///|
pub suberror UrlParseError {
  UrlParseError(String)
}

///|
pub impl Show for UrlParseError
```

Raised by `parse`, `parse_with_base`, `parse_with_params`, `from_file_path`, `from_directory_path`, `set_href`, `join`, and `to_file_path` on invalid input.

---

### `UrlSearchParams` type

```mbt nocheck
pub struct UrlSearchParams { /* private fields */ }
pub impl Show for UrlSearchParams
```

#### UrlSearchParams constructors

| Method | Description |
| :--- | :--- |
| `UrlSearchParams::new()` | Empty params |
| `UrlSearchParams::from_string(String)` | Parse `application/x-www-form-urlencoded` data |
| `UrlSearchParams::from_pairs(Array[(String, String)])` | Build from name/value pairs, keeping order and duplicates; lone surrogates become U+FFFD |
| `UrlSearchParams::from_record(Map[String, String])` | Build from a record in insertion order; lone surrogates become U+FFFD |

#### Read operations

| Method | Signature | Description |
| :--- | :--- | :--- |
| `get` | `(String) -> String?` | First value for the given name |
| `get_all` | `(String) -> Array[String]` | All values for the given name |
| `has` | `(String) -> Bool` | Whether any entry with the given name exists |
| `has_entry` | `(String, String) -> Bool` | Whether a specific name-value pair exists |
| `size` | `() -> Int` | Total number of entries |

#### Write operations

| Method | Signature | Description |
| :--- | :--- | :--- |
| `append` | `(String, String) -> Unit` | Add a new entry |
| `delete` | `(String) -> Unit` | Remove all entries with the given name |
| `delete_entry` | `(String, String) -> Unit` | Remove a specific name-value pair |
| `set` | `(String, String) -> Unit` | Replace all entries for the name with one value |
| `sort` | `() -> Unit` | Sort entries by name (Unicode code-unit order) |

#### Iteration

| Method | Returns | Description |
| :--- | :--- | :--- |
| `iter()` | `Iter[(String, String)]` | All name-value pairs |
| `entries()` | `Iter[(String, String)]` | Alias for `iter()` |
| `keys()` | `Iter[String]` | Names only |
| `values()` | `Iter[String]` | Values only |
| `for_each((String, String) -> Unit)` | `Unit` | Apply a function to each pair |

#### Output

| Method | Returns | Description |
| :--- | :--- | :--- |
| `to_string()` | `String` | Serialize to `application/x-www-form-urlencoded` format |

```mbt check
///|
test {
  let params = @url.UrlSearchParams::from_string("a=1&b=2&a=3")
  @debug.assert_eq(params.get("a"), Some("1"))
  @debug.assert_eq(params.get_all("a"), ["1", "3"])
  assert_eq(params.has("b"), true)
  assert_eq(params.has_entry("a", "1"), true)
  assert_eq(params.size(), 3)

  params.append("c", "4")
  params.delete("b")
  params.set("a", "99")
  assert_eq(params.to_string(), "a=99&c=4")

  for name, value in params.iter() {
    ignore((name, value))
  }

  params.sort()
}
```

---

### IDNA utilities

| Function | Signature | Description |
| :--- | :--- | :--- |
| `domain_to_ascii` | `(String) -> String` | UTS#46 Unicode-to-ACE; returns `""` on failure |
| `domain_to_unicode` | `(String) -> String` | ACE-to-Unicode; returns `""` on failure |

```mbt check
///|
test {
  assert_eq(@url.domain_to_ascii("münchen.example"), "xn--mnchen-3ya.example")
  assert_eq(@url.domain_to_ascii("EXAMPLE.COM"), "example.com")
  assert_eq(
    @url.domain_to_unicode("xn--mnchen-3ya.example"),
    "münchen.example",
  )
}
```
