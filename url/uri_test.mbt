///|
test "can_parse returns true for valid absolute URL" {
  assert_eq(@url.can_parse("aaa:b", None), true)
}

///|
test "can_parse returns true for valid URL with path" {
  assert_eq(@url.can_parse("aaa:/b", None), true)
}

///|
test "can_parse returns false for URL with invalid port" {
  assert_eq(@url.can_parse("https://test:test", None), false)
}

///|
test "can_parse returns true for relative URL against valid base" {
  let base = @url.parse("https://b/")
  assert_eq(@url.can_parse("a", Some(base)), true)
}

///|
test "can_parse returns false when schemeless and no base" {
  assert_eq(@url.can_parse("//example.com", None), false)
}

///|
test "parse_maybe returns Some for valid absolute URL" {
  let result = @url.parse_maybe("https://example.com/", None)
  assert_true(result is Some(_))
}

///|
test "parse_maybe returns None for invalid URL" {
  let result = @url.parse_maybe("https://test:test", None)
  assert_true(result is None)
}

///|
test "parse_maybe returns Some with correct href" {
  let result = @url.parse_maybe("http://example.com/path", None)
  match result {
    Some(url) => assert_eq(url.href(), "http://example.com/path")
    None => fail("expected Some but got None")
  }
}

///|
test "parse_maybe with base resolves relative URL" {
  let base = @url.parse("https://example.com/")
  let result = @url.parse_maybe("path", Some(base))
  match result {
    Some(url) => assert_eq(url.href(), "https://example.com/path")
    None => fail("expected Some but got None")
  }
}

///|
test "to_json serializes URL as a JSON string value" {
  let url = @url.parse("https://example.com/")
  @debug.assert_eq(url.to_json(), Json::string("https://example.com/"))
}

///|
test "to_json JSON string value equals href for complex URL" {
  let url = @url.parse("http://user:pass@example.com:8080/path?query#hash")
  @debug.assert_eq(url.to_json(), Json::string(url.href()))
}

///|
test "search_params returns empty params when URL has no query" {
  let url = @url.parse("http://example.com/path")
  assert_eq(url.search_params().to_string(), "")
}

///|
test "search_params returns empty params for empty query" {
  let url = @url.parse("http://example.com/path?")
  assert_eq(url.search_params().to_string(), "")
}

///|
test "search_params parses key-value pairs from query" {
  let url = @url.parse("http://example.com/path?a=b&c=d")
  let params = url.search_params()
  assert_eq(params.to_string(), "a=b&c=d")
  @debug.assert_eq(params.get("a"), Some("b"))
  @debug.assert_eq(params.get("c"), Some("d"))
}

///|
test "search_params: query starting with ? encodes it (no stripping)" {
  let url = @url.parse_with_base(
    "??a=b&c=d",
    Some(@url.parse("http://example.org/foo/bar")),
  )
  assert_eq(url.search_params().to_string(), "%3Fa=b&c=d")
}

///|
test "search_params: key without value yields empty-string value" {
  let url = @url.parse("http://foo.bar/baz?qux")
  assert_eq(url.search_params().to_string(), "qux=")
}

///|
test "search_params returns independent copy (mutations do not affect URL)" {
  let url = @url.parse("http://example.com/?a=b")
  let params = url.search_params()
  params.append("x", "y")
  assert_eq(url.search(), "?a=b")
  assert_eq(url.search_params().to_string(), "a=b")
}

///|
test "Show for Url outputs href" {
  let url = @url.parse("https://example.com/path?q=1#hash")
  assert_eq("\{url}", "https://example.com/path?q=1#hash")
}

///|
test "Show for Url works for opaque-path URL" {
  let url = @url.parse("mailto:user@example.com")
  assert_eq("\{url}", "mailto:user@example.com")
}

// ===== Url::join =====

///|
test "join resolves relative path against base" {
  let base = @url.parse("https://example.com/a/b/c")
  assert_eq(base.join("../d").href(), "https://example.com/a/d")
}

///|
test "join resolves absolute path against base" {
  let base = @url.parse("https://example.com/a/b")
  assert_eq(base.join("/x/y").href(), "https://example.com/x/y")
}

///|
test "join with different scheme overrides base entirely" {
  let base = @url.parse("https://example.com/a")
  assert_eq(base.join("https://other.com/b").href(), "https://other.com/b")
}

///|
test "join with query-only input replaces query" {
  let base = @url.parse("https://example.com/path?old=1")
  assert_eq(base.join("?new=2").href(), "https://example.com/path?new=2")
}

///|
test "join with fragment-only input replaces fragment" {
  let base = @url.parse("https://example.com/path#old")
  assert_eq(base.join("#new").href(), "https://example.com/path#new")
}

///|
test "join with empty string returns base href" {
  let base = @url.parse("https://example.com/path?q=1")
  assert_eq(base.join("").href(), "https://example.com/path?q=1")
}

///|
test "join raises for URL with invalid port" {
  let base = @url.parse("https://example.com/")
  let result : Result[@url.Url, @url.UrlParseError] = Ok(
    base.join("https://invalid:port"),
  ) catch {
    e => Err(e)
  }
  assert_true(result is Err(_))
}

// ===== Url::is_special =====

///|
test "is_special returns true for http URL" {
  assert_eq(@url.parse("http://example.com/").is_special(), true)
}

///|
test "is_special returns true for https URL" {
  assert_eq(@url.parse("https://example.com/").is_special(), true)
}

///|
test "is_special returns true for ftp URL" {
  assert_eq(@url.parse("ftp://example.com/").is_special(), true)
}

///|
test "is_special returns true for file URL" {
  assert_eq(@url.parse("file:///tmp/file").is_special(), true)
}

///|
test "is_special returns true for ws URL" {
  assert_eq(@url.parse("ws://example.com/").is_special(), true)
}

///|
test "is_special returns true for wss URL" {
  assert_eq(@url.parse("wss://example.com/").is_special(), true)
}

///|
test "is_special returns false for non-special scheme" {
  assert_eq(@url.parse("custom://example.com/").is_special(), false)
}

// ===== Url::has_credentials =====

///|
test "has_credentials returns false when no username or password" {
  assert_eq(@url.parse("https://example.com/").has_credentials(), false)
}

///|
test "has_credentials returns true when username is non-empty" {
  assert_eq(@url.parse("https://user@example.com/").has_credentials(), true)
}

///|
test "has_credentials returns true when both username and password are set" {
  assert_eq(
    @url.parse("https://user:pass@example.com/").has_credentials(),
    true,
  )
}

// ===== Url::has_opaque_path =====

///|
test "has_opaque_path returns false for hierarchical URL" {
  assert_eq(@url.parse("https://example.com/path").has_opaque_path(), false)
}

///|
test "has_opaque_path returns true for data URL" {
  assert_eq(@url.parse("data:text/html,Hello").has_opaque_path(), true)
}

///|
test "has_opaque_path returns true for mailto URL" {
  assert_eq(@url.parse("mailto:user@example.com").has_opaque_path(), true)
}

// ===== Url::scheme =====

///|
test "scheme returns scheme string without colon" {
  assert_eq(@url.parse("https://example.com/").scheme(), "https")
}

///|
test "scheme returns non-special scheme without colon" {
  assert_eq(@url.parse("custom://example.com/").scheme(), "custom")
}

///|
test "scheme returns file for file URL" {
  assert_eq(@url.parse("file:///tmp").scheme(), "file")
}

// ===== Url::username =====

///|
test "username returns empty string when no credentials" {
  assert_eq(@url.parse("https://example.com/").username(), "")
}

///|
test "username returns percent-encoded username" {
  assert_eq(@url.parse("https://user@example.com/").username(), "user")
}

///|
test "username returns username from user:pass URL" {
  assert_eq(@url.parse("https://user:pass@example.com/").username(), "user")
}

// ===== Url::password =====

///|
test "password returns empty string when no credentials" {
  assert_eq(@url.parse("https://example.com/").password(), "")
}

///|
test "password returns empty string for user-only credentials" {
  assert_eq(@url.parse("https://user@example.com/").password(), "")
}

///|
test "password returns password from user:pass URL" {
  assert_eq(@url.parse("https://user:pass@example.com/").password(), "pass")
}

// ===== Url::port =====

///|
test "port returns None for URL without explicit port" {
  let url = @url.parse("https://example.com/")
  assert_true(url.port() is None)
}

///|
test "port returns Some for URL with explicit port" {
  let url = @url.parse("https://example.com:8080/")
  assert_true(url.port() is Some(8080))
}

///|
test "port returns None when port matches default for scheme" {
  let url = @url.parse("https://example.com:443/")
  assert_true(url.port() is None)
}

///|
test "port returns Some for non-default port" {
  let url = @url.parse("http://example.com:8000/")
  assert_true(url.port() is Some(8000))
}

// ===== Url::path_segments =====

///|
fn collect_segments(url : @url.Url) -> Array[String]? {
  match url.path_segments() {
    None => None
    Some(iter) => {
      let arr : Array[String] = []
      for s in iter {
        arr.push(s)
      }
      Some(arr)
    }
  }
}

///|
test "path_segments returns None for opaque-path URL" {
  assert_true(collect_segments(@url.parse("mailto:user@example.com")) is None)
}

///|
test "path_segments returns None for data URL" {
  assert_true(collect_segments(@url.parse("data:text/html,Hello")) is None)
}

///|
test "path_segments returns single empty segment for root path" {
  let url = @url.parse("https://example.com/")
  @debug.assert_eq(collect_segments(url), Some(([""] : Array[String])))
}

///|
test "path_segments returns segments for multi-segment path" {
  let url = @url.parse("https://example.com/a/b/c")
  @debug.assert_eq(
    collect_segments(url),
    Some((["a", "b", "c"] : Array[String])),
  )
}

///|
test "path_segments includes trailing empty segment for trailing slash" {
  let url = @url.parse("https://example.com/a/b/")
  @debug.assert_eq(
    collect_segments(url),
    Some((["a", "b", ""] : Array[String])),
  )
}

///|
test "path_segments returns empty iterator for non-special URL with no path" {
  let url = @url.parse("sc://example.com")
  @debug.assert_eq(collect_segments(url), Some(([] : Array[String])))
}

///|
test "path_segments returns percent-encoded segment values as-is" {
  let url = @url.parse("https://example.com/hello%20world")
  @debug.assert_eq(
    collect_segments(url),
    Some((["hello%20world"] : Array[String])),
  )
}

///|
test "path_segments returns Some for file URL" {
  let url = @url.parse("file:///usr/local/bin")
  @debug.assert_eq(
    collect_segments(url),
    Some((["usr", "local", "bin"] : Array[String])),
  )
}

// ===== domain_to_ascii =====

///|
test "domain_to_ascii: ASCII domain lowercased" {
  assert_eq(@url.domain_to_ascii("gOoGle.com"), "google.com")
}

///|
test "domain_to_ascii: Unicode domain encodes to Punycode" {
  assert_eq(@url.domain_to_ascii("ẞ.com"), "xn--zca.com")
}

///|
test "domain_to_ascii: already-ACE label unchanged" {
  assert_eq(@url.domain_to_ascii("xn--zca.com"), "xn--zca.com")
}

///|
test "domain_to_ascii: empty input returns empty string" {
  assert_eq(@url.domain_to_ascii(""), "")
}

///|
test "domain_to_ascii strict: label with a leading hyphen is rejected" {
  assert_eq(@url.domain_to_ascii("-a.com", strict=true), "")
  assert_eq(@url.domain_to_ascii("-a.com"), "-a.com")
}

///|
test "domain_to_ascii strict: label with a trailing hyphen is rejected" {
  assert_eq(@url.domain_to_ascii("a-.com", strict=true), "")
  assert_eq(@url.domain_to_ascii("a-.com"), "a-.com")
}

///|
test "domain_to_ascii strict: hyphens in the third and fourth positions are rejected" {
  assert_eq(@url.domain_to_ascii("ab--c.com", strict=true), "")
  assert_eq(@url.domain_to_ascii("ab--c.com"), "ab--c.com")
}

///|
test "domain_to_ascii strict: inner hyphen is accepted" {
  assert_eq(@url.domain_to_ascii("a-b.com", strict=true), "a-b.com")
}

///|
test "domain_to_ascii strict: label over 63 octets is rejected" {
  let label64 = "a".repeat(64)
  assert_eq(@url.domain_to_ascii(label64 + ".com", strict=true), "")
  assert_eq(@url.domain_to_ascii(label64 + ".com"), label64 + ".com")
}

///|
test "domain_to_ascii strict: label of exactly 63 octets is accepted" {
  let label63 = "a".repeat(63)
  assert_eq(
    @url.domain_to_ascii(label63 + ".com", strict=true),
    label63 + ".com",
  )
}

///|
test "domain_to_ascii strict: Punycode output over 63 octets is rejected" {
  let name = "é".repeat(60) + ".com"
  assert_eq(@url.domain_to_ascii(name, strict=true), "")
  assert_true(@url.domain_to_ascii(name) != "")
}

///|
test "domain_to_ascii strict: name over 253 octets is rejected" {
  let l63 = "a".repeat(63)
  let at_limit = l63 + "." + l63 + "." + l63 + "." + "a".repeat(61)
  let over_limit = l63 + "." + l63 + "." + l63 + "." + "a".repeat(62)
  assert_eq(@url.domain_to_ascii(at_limit, strict=true), at_limit)
  assert_eq(@url.domain_to_ascii(over_limit, strict=true), "")
  assert_eq(@url.domain_to_ascii(over_limit), over_limit)
}

///|
test "domain_to_ascii strict: empty label is rejected" {
  assert_eq(@url.domain_to_ascii("a..com", strict=true), "")
  assert_eq(@url.domain_to_ascii(".com", strict=true), "")
  assert_eq(@url.domain_to_ascii("a..com"), "a..com")
}

///|
test "domain_to_ascii strict: trailing root dot is accepted" {
  assert_eq(@url.domain_to_ascii("example.com.", strict=true), "example.com.")
}

///|
test "domain_to_ascii strict: 253 octets followed by a root dot is accepted" {
  let l63 = "a".repeat(63)
  let name = l63 + "." + l63 + "." + l63 + "." + "a".repeat(61) + "."
  assert_eq(@url.domain_to_ascii(name, strict=true), name)
}

///|
test "domain_to_ascii strict: two trailing dots are rejected" {
  assert_eq(@url.domain_to_ascii("example.com..", strict=true), "")
  assert_eq(@url.domain_to_ascii("example.com.."), "example.com..")
}

///|
test "domain_to_ascii strict: a lone root dot is rejected" {
  assert_eq(@url.domain_to_ascii(".", strict=true), "")
  assert_eq(@url.domain_to_ascii("."), ".")
}

///|
test "domain_to_ascii strict: non-LDH ASCII character is rejected" {
  assert_eq(@url.domain_to_ascii("a_b.com", strict=true), "")
  assert_eq(@url.domain_to_ascii("a_b.com"), "a_b.com")
}

///|
test "domain_to_ascii strict: non-LDH character produced by mapping is rejected" {
  assert_eq(@url.domain_to_ascii("a\u{FF3F}b.com", strict=true), "")
}

///|
test "domain_to_ascii strict: invalid Punycode label is rejected" {
  assert_eq(@url.domain_to_ascii("xn--a.com", strict=true), "")
  assert_eq(@url.domain_to_ascii("xn--a.com"), "xn--a.com")
}

///|
test "domain_to_ascii strict: name valid in both modes gives the same result" {
  assert_eq(
    @url.domain_to_ascii("EXAMPLE.com", strict=true),
    @url.domain_to_ascii("EXAMPLE.com"),
  )
  assert_eq(
    @url.domain_to_ascii("münchen.example", strict=true),
    "xn--mnchen-3ya.example",
  )
  assert_eq(@url.domain_to_ascii("xn--zca.com", strict=true), "xn--zca.com")
}

///|
test "domain_to_ascii strict: explicit false behaves like the default" {
  assert_eq(@url.domain_to_ascii("a_b.com", strict=false), "a_b.com")
}

///|
test "domain_to_ascii strict: empty input returns empty string" {
  assert_eq(@url.domain_to_ascii("", strict=true), "")
}

// ===== domain_to_unicode =====

///|
test "domain_to_unicode: ACE label decodes to Unicode" {
  assert_eq(@url.domain_to_unicode("xn--zca.com"), "ß.com")
}

///|
test "domain_to_unicode: ASCII domain unchanged" {
  assert_eq(@url.domain_to_unicode("google.com"), "google.com")
}

///|
test "domain_to_unicode: roundtrip from Unicode input" {
  assert_eq(@url.domain_to_unicode("ẞ.com"), "ß.com")
}

///|
test "domain_to_unicode: empty input returns empty string" {
  assert_eq(@url.domain_to_unicode(""), "")
}

// ===== Url::has_authority =====

///|
test "has_authority returns true for hierarchical URL with host" {
  assert_eq(@url.parse("https://example.com/").has_authority(), true)
}

///|
test "has_authority returns true for ftp URL" {
  assert_eq(@url.parse("ftp://rms@example.com").has_authority(), true)
}

///|
test "has_authority returns true for file URL with empty host" {
  assert_eq(@url.parse("file:///tmp/foo").has_authority(), true)
}

///|
test "has_authority returns false for non-special URL without authority" {
  assert_eq(@url.parse("unix:/run/foo.socket").has_authority(), false)
}

///|
test "has_authority returns false for opaque-path URL" {
  assert_eq(@url.parse("data:text/plain,Stuff").has_authority(), false)
}

///|
test "has_authority returns false for mailto URL" {
  assert_eq(@url.parse("mailto:user@example.com").has_authority(), false)
}

// ===== Url::authority =====

///|
test "authority returns host string for simple URL" {
  assert_eq(@url.parse("https://example.com/").authority(), "example.com")
}

///|
test "authority includes username" {
  assert_eq(@url.parse("ftp://rms@example.com").authority(), "rms@example.com")
}

///|
test "authority includes username and password" {
  assert_eq(
    @url.parse("https://user:pass@example.com/").authority(),
    "user:pass@example.com",
  )
}

///|
test "authority includes port" {
  assert_eq(
    @url.parse("https://example.com:8080/").authority(),
    "example.com:8080",
  )
}

///|
test "authority includes all parts" {
  assert_eq(
    @url.parse("https://user@example.com:8080/").authority(),
    "user@example.com:8080",
  )
}

///|
test "authority returns empty string for file URL with empty host" {
  assert_eq(@url.parse("file:///tmp/foo").authority(), "")
}

///|
test "authority returns empty string for URL without authority" {
  assert_eq(@url.parse("unix:/run/foo.socket").authority(), "")
}

///|
test "authority returns empty string for opaque-path URL" {
  assert_eq(@url.parse("data:text/plain,Hello").authority(), "")
}

// ===== Url::domain =====

///|
test "domain returns Some for domain host" {
  @debug.assert_eq(
    @url.parse("https://example.com/").domain(),
    Some("example.com"),
  )
}

///|
test "domain returns None for IPv4 host" {
  assert_true(@url.parse("https://127.0.0.1/").domain() is None)
}

///|
test "domain returns None for IPv6 host" {
  assert_true(@url.parse("https://[::1]/").domain() is None)
}

///|
test "domain returns None when no host" {
  assert_true(@url.parse("unix:/run/foo.socket").domain() is None)
}

///|
test "domain returns Some empty string for file URL with empty host" {
  @debug.assert_eq(@url.parse("file:///tmp/").domain(), Some(""))
}

///|
test "domain returns None for non-special URL (opaque host, not Domain)" {
  assert_true(@url.parse("sc://foo.bar/path").domain() is None)
}

// ===== Url::make_relative =====

///|
test "make_relative: same URL returns empty string" {
  let base = @url.parse("https://example.net/a/b.html")
  let url = @url.parse("https://example.net/a/b.html")
  @debug.assert_eq(base.make_relative(url), Some(""))
}

///|
test "make_relative: different filename same directory" {
  let base = @url.parse("https://example.net/a/b/")
  let url = @url.parse("https://example.net/a/b/c.png")
  @debug.assert_eq(base.make_relative(url), Some("c.png"))
}

///|
test "make_relative: file in sibling directory" {
  let base = @url.parse("https://example.net/a/b/")
  let url = @url.parse("https://example.net/a/d/c.png")
  @debug.assert_eq(base.make_relative(url), Some("../d/c.png"))
}

///|
test "make_relative: different query only" {
  let base = @url.parse("https://example.net/a/b.html?c=d")
  let url = @url.parse("https://example.net/a/b.html?e=f")
  @debug.assert_eq(base.make_relative(url), Some("?e=f"))
}

///|
test "make_relative: different fragment only" {
  let base = @url.parse("https://example.com/path#old")
  let url = @url.parse("https://example.com/path#new")
  @debug.assert_eq(base.make_relative(url), Some("#new"))
}

///|
test "make_relative: different scheme returns None" {
  let base = @url.parse("https://example.com/path")
  let url = @url.parse("http://example.com/path")
  assert_true(base.make_relative(url) is None)
}

///|
test "make_relative: different host returns None" {
  let base = @url.parse("https://example.com/path")
  let url = @url.parse("https://other.com/path")
  assert_true(base.make_relative(url) is None)
}

///|
test "make_relative: different port returns None" {
  let base = @url.parse("https://example.com:8080/path")
  let url = @url.parse("https://example.com:9090/path")
  assert_true(base.make_relative(url) is None)
}

///|
test "make_relative: opaque-path base returns None" {
  let base = @url.parse("data:text/html,Hello")
  let url = @url.parse("data:text/html,World")
  assert_true(base.make_relative(url) is None)
}

///|
test "make_relative: opaque-path other returns None" {
  let base = @url.parse("https://example.com/path")
  let url = @url.parse("data:text/html,Hello")
  assert_true(base.make_relative(url) is None)
}

///|
test "make_relative: opaque-path other with matching non-special scheme returns None" {
  let base = @url.parse("sc:/x")
  let url = @url.parse("sc:opaque")
  assert_true(base.make_relative(url) is None)
}

///|
test "make_relative: navigating up to parent directory produces trailing slash" {
  let base = @url.parse("https://e.com/a/b/c.html")
  let url = @url.parse("https://e.com/a/")
  @debug.assert_eq(base.make_relative(url), Some("../"))
}

///|
test "make_relative: base with no path segments produces relative path to target" {
  let base = @url.parse("http://example.com/").set_pathname("")
  let url = @url.parse("http://example.com/foo")
  @debug.assert_eq(base.make_relative(url), Some("foo"))
}

///|
test "make_relative: navigate to parent directory" {
  let base = @url.parse("https://example.net/a/b.html")
  let url = @url.parse("https://example.net/a/")
  @debug.assert_eq(base.make_relative(url), Some("./"))
}

///|
test "make_relative: result round-trips via join" {
  let base = @url.parse("https://example.net/a/b/")
  let url = @url.parse("https://example.net/a/d/c.png")
  let rel = base.make_relative(url)
  match rel {
    Some(r) => assert_eq(base.join(r).href(), url.href())
    None => fail("expected Some but got None")
  }
}

// ===== parse_with_params =====

///|
test "parse_with_params: adds params to URL with no existing query" {
  let url = @url.parse_with_params("https://example.com/", [("lang", "rust")])
  assert_eq(url.href(), "https://example.com/?lang=rust")
}

///|
test "parse_with_params: appends to existing query without clobbering" {
  let url = @url.parse_with_params("https://example.net?dont=clobberme", [
    ("lang", "rust"),
    ("browser", "servo"),
  ])
  assert_eq(
    url.href(),
    "https://example.net/?dont=clobberme&lang=rust&browser=servo",
  )
}

///|
test "parse_with_params: empty params returns URL with no query change" {
  let url = @url.parse_with_params(
    "https://example.com/?a=1",
    ([] : Array[(String, String)]),
  )
  assert_eq(url.href(), "https://example.com/?a=1")
}

///|
test "parse_with_params: empty params with no existing query preserves no query" {
  let url = @url.parse_with_params(
    "https://example.com/",
    ([] : Array[(String, String)]),
  )
  assert_eq(url.href(), "https://example.com/")
}

///|
test "parse_with_params: invalid URL raises UrlParseError" {
  try @url.parse_with_params("https://test:test", [("k", "v")]) catch {
    _ => ()
  } noraise {
    _ => fail("expected UrlParseError")
  }
}

// ===== Url::port_or_known_default =====

///|
test "port_or_known_default returns Some(80) for http with no explicit port" {
  assert_true(
    @url.parse("http://example.com/").port_or_known_default() == Some(80),
  )
}

///|
test "port_or_known_default returns Some(443) for https with no explicit port" {
  assert_true(
    @url.parse("https://example.com/").port_or_known_default() == Some(443),
  )
}

///|
test "port_or_known_default returns Some(21) for ftp with no explicit port" {
  assert_true(
    @url.parse("ftp://example.com/").port_or_known_default() == Some(21),
  )
}

///|
test "port_or_known_default returns Some(80) for ws with no explicit port" {
  assert_true(
    @url.parse("ws://example.com/").port_or_known_default() == Some(80),
  )
}

///|
test "port_or_known_default returns Some(443) for wss with no explicit port" {
  assert_true(
    @url.parse("wss://example.com/").port_or_known_default() == Some(443),
  )
}

///|
test "port_or_known_default returns explicit port when set" {
  assert_true(
    @url.parse("https://example.com:8080/").port_or_known_default() ==
    Some(8080),
  )
}

///|
test "port_or_known_default returns None for non-special scheme" {
  assert_true(
    @url.parse("custom://example.com/").port_or_known_default() is None,
  )
}

///|
test "port_or_known_default returns None for file scheme" {
  assert_true(@url.parse("file:///tmp/").port_or_known_default() is None)
}

// ===== Url::query =====

///|
test "query returns None when URL has no query" {
  assert_true(@url.parse("https://example.com/").query() is None)
}

///|
test "query returns Some empty string for empty query" {
  @debug.assert_eq(@url.parse("https://example.com/?").query(), Some(""))
}

///|
test "query returns Some with query content" {
  @debug.assert_eq(
    @url.parse("https://example.com/?q=foo").query(),
    Some("q=foo"),
  )
}

///|
test "query returns Some with multiple params" {
  @debug.assert_eq(
    @url.parse("https://example.com/?a=1&b=2").query(),
    Some("a=1&b=2"),
  )
}

// ===== Url::fragment =====

///|
test "fragment returns None when URL has no fragment" {
  assert_true(@url.parse("https://example.com/").fragment() is None)
}

///|
test "fragment returns Some empty string for empty fragment" {
  @debug.assert_eq(@url.parse("https://example.com/#").fragment(), Some(""))
}

///|
test "fragment returns Some with fragment content" {
  @debug.assert_eq(
    @url.parse("https://example.com/#section").fragment(),
    Some("section"),
  )
}

// ===== Url::has_host =====

///|
test "has_host returns true for URL with domain host" {
  assert_eq(@url.parse("https://example.com/").has_host(), true)
}

///|
test "has_host returns true for file URL with empty host" {
  assert_eq(@url.parse("file:///tmp/foo").has_host(), true)
}

///|
test "has_host returns false for URL without authority" {
  assert_eq(@url.parse("unix:/run/foo.socket").has_host(), false)
}

///|
test "has_host returns false for opaque-path URL" {
  assert_eq(@url.parse("data:text/html,Hello").has_host(), false)
}

// ===== Url::has_port =====

///|
test "has_port returns false when no port is present" {
  assert_eq(@url.parse("https://example.com/").has_port(), false)
}

///|
test "has_port returns true when explicit non-default port is present" {
  assert_eq(@url.parse("https://example.com:8080/").has_port(), true)
}

///|
test "has_port returns false when default port is stripped by parser" {
  assert_eq(@url.parse("https://example.com:443/").has_port(), false)
}

// ===== Url::has_query =====

///|
test "has_query returns false when URL has no query" {
  assert_eq(@url.parse("https://example.com/").has_query(), false)
}

///|
test "has_query returns true for empty query string" {
  assert_eq(@url.parse("https://example.com/?").has_query(), true)
}

///|
test "has_query returns true when query has content" {
  assert_eq(@url.parse("https://example.com/?q=1").has_query(), true)
}

// ===== Url::has_fragment =====

///|
test "has_fragment returns false when URL has no fragment" {
  assert_eq(@url.parse("https://example.com/").has_fragment(), false)
}

///|
test "has_fragment returns true for empty fragment" {
  assert_eq(@url.parse("https://example.com/#").has_fragment(), true)
}

///|
test "has_fragment returns true when fragment has content" {
  assert_eq(@url.parse("https://example.com/#section").has_fragment(), true)
}

// ===== from_file_path =====

///|
test "from_file_path produces file URL for absolute Unix path" {
  let url = @url.from_file_path("/usr/local/bin")
  assert_eq(url.href(), "file:///usr/local/bin")
}

///|
test "from_file_path encodes space in path segments" {
  let url = @url.from_file_path("/path with spaces/file.txt")
  assert_eq(url.href(), "file:///path%20with%20spaces/file.txt")
}

///|
test "from_file_path preserves trailing slash" {
  let url = @url.from_file_path("/path/to/dir/")
  assert_eq(url.href(), "file:///path/to/dir/")
}

///|
test "from_file_path produces file URL for root path" {
  let url = @url.from_file_path("/")
  assert_eq(url.href(), "file:///")
}

///|
test "from_file_path raises for relative path" {
  try @url.from_file_path("relative/path") catch {
    _ => ()
  } noraise {
    _ => fail("expected error")
  }
}

///|
test "from_file_path raises for empty path" {
  try @url.from_file_path("") catch {
    _ => ()
  } noraise {
    _ => fail("expected error")
  }
}

///|
test "from_file_path handles Windows path with backslashes" {
  let url = @url.from_file_path("C:\\Windows\\System32")
  assert_eq(url.href(), "file:///C:/Windows/System32")
}

///|
test "from_file_path handles Windows path with forward slashes and encodes spaces" {
  let url = @url.from_file_path("C:/Program Files/App")
  assert_eq(url.href(), "file:///C:/Program%20Files/App")
}

// ===== Url::to_file_path =====

///|
test "to_file_path returns Unix path for simple file URL" {
  let url = @url.parse("file:///etc/passwd")
  assert_eq(url.to_file_path(), "/etc/passwd")
}

///|
test "to_file_path raises for non-file scheme" {
  let url = @url.parse("https://example.com/path")
  try url.to_file_path() catch {
    _ => ()
  } noraise {
    _ => fail("expected error")
  }
}

///|
test "to_file_path raises for file URL with non-local host" {
  let url = @url.parse("file://example.com/path")
  try url.to_file_path() catch {
    _ => ()
  } noraise {
    _ => fail("expected error")
  }
}

///|
test "to_file_path returns root slash for root file URL" {
  let url = @url.parse("file:///")
  assert_eq(url.to_file_path(), "/")
}

///|
test "to_file_path decodes percent-encoded spaces" {
  let url = @url.parse("file:///path%20with%20spaces/file.txt")
  assert_eq(url.to_file_path(), "/path with spaces/file.txt")
}

///|
test "to_file_path returns Windows-style path for drive letter URL" {
  let url = @url.parse("file:///C:/Windows/System32")
  assert_eq(url.to_file_path(), "C:/Windows/System32")
}

///|
test "to_file_path preserves trailing slash" {
  let url = @url.parse("file:///path/to/dir/")
  assert_eq(url.to_file_path(), "/path/to/dir/")
}

///|
test "to_file_path returns root slash for file URL with empty path segment list" {
  let url = @url.parse("file:///").set_pathname("")
  assert_eq(url.to_file_path(), "/")
}

///|
test "from_file_path and to_file_path round-trip for Unix path" {
  let path = "/usr/local/bin/app"
  assert_eq(@url.from_file_path(path).to_file_path(), path)
}

// ===== from_directory_path =====

///|
test "from_directory_path adds trailing slash for path without slash" {
  assert_eq(@url.from_directory_path("/var/www").href(), "file:///var/www/")
}

///|
test "from_directory_path preserves existing trailing slash" {
  assert_eq(@url.from_directory_path("/var/www/").href(), "file:///var/www/")
}

///|
test "from_directory_path root path produces file:///" {
  assert_eq(@url.from_directory_path("/").href(), "file:///")
}

///|
test "from_directory_path raises for relative path" {
  try @url.from_directory_path("relative") catch {
    _ => ()
  } noraise {
    _ => fail("expected error")
  }
}

///|
test "from_directory_path raises for empty path" {
  try @url.from_directory_path("") catch {
    _ => ()
  } noraise {
    _ => fail("expected error")
  }
}

///|
test "from_directory_path handles Windows path with backslashes" {
  assert_eq(@url.from_directory_path("C:\\Users").href(), "file:///C:/Users/")
}

///|
test "from_directory_path result serves as base for relative URL resolution" {
  let dir = @url.from_directory_path("/var/www")
  let url = @url.parse_with_base("index.html", Some(dir))
  assert_eq(url.href(), "file:///var/www/index.html")
}

// ===== Url::query_pairs =====

///|
test "query_pairs returns empty iterator for URL with no query" {
  let url = @url.parse("https://example.com/")
  assert_true(url.query_pairs().to_array().is_empty())
}

///|
test "query_pairs returns key-value pairs from query string" {
  let url = @url.parse("https://example.com/?a=1&b=2")
  @debug.assert_eq(
    url.query_pairs().to_array(),
    ([("a", "1"), ("b", "2")] : Array[(String, String)]),
  )
}

///|
test "query_pairs decodes percent-encoded key and value" {
  let url = @url.parse("https://example.com/?hello%20world=foo%20bar")
  @debug.assert_eq(
    url.query_pairs().to_array(),
    ([("hello world", "foo bar")] : Array[(String, String)]),
  )
}

///|
test "query_pairs decodes plus sign as space" {
  let url = @url.parse("https://example.com/?a=hello+world")
  @debug.assert_eq(
    url.query_pairs().to_array(),
    ([("a", "hello world")] : Array[(String, String)]),
  )
}

///|
test "query_pairs returns empty for empty query string" {
  let url = @url.parse("https://example.com/?")
  assert_true(url.query_pairs().to_array().is_empty())
}

///|
test "query_pairs returns pair with empty value for key-only param" {
  let url = @url.parse("https://example.com/?key")
  @debug.assert_eq(
    url.query_pairs().to_array(),
    ([("key", "")] : Array[(String, String)]),
  )
}

///|
test "domain_to_ascii strict: negated relation signs are valid IDNA characters" {
  assert_eq(@url.domain_to_ascii("\u{2260}.com", strict=true), "xn--1ch.com")
  assert_eq(@url.domain_to_ascii("\u{226E}.com", strict=true), "xn--gdh.com")
  assert_eq(@url.domain_to_ascii("\u{226F}.com", strict=true), "xn--hdh.com")
  assert_eq(@url.domain_to_ascii("xn--1ch.com", strict=true), "xn--1ch.com")
}

///|
test "domain_to_ascii strict: STD3 rules apply after normalization" {
  assert_eq(@url.domain_to_ascii("=\u{338}.com", strict=true), "xn--1ch.com")
  assert_eq(@url.domain_to_ascii("a=b.com", strict=true), "")
  assert_eq(@url.domain_to_ascii("\u{FF1D}.com", strict=true), "")
}
