///|
test "exact pathname match succeeds" {
  let p = try! @urlpattern.UrlPattern::from_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/foo/bar")),
  )
  let result = p.exec_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/foo/bar")),
  )
  assert_true(result is Some(_))
  guard result is Some(r) else { fail("expected match") }
  guard r.pathname() is Some(pr) else { fail("expected pathname result") }
  assert_eq(pr.input(), "/foo/bar")
  assert_eq(pr.groups().length(), 0)
}

///|
test "exact pathname match fails on different path" {
  let p = try! @urlpattern.UrlPattern::from_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/foo/bar")),
  )
  let result = p.exec_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/foo/ba")),
  )
  assert_true(result is None)
}

///|
test "wildcard pathname matches anything" {
  let p = try! @urlpattern.UrlPattern::from_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("*")),
  )
  let result = p.exec_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/foo/bar/baz")),
  )
  assert_true(result is Some(_))
  guard result is Some(r) else { fail("expected match") }
  guard r.pathname() is Some(pr) else { fail("expected pathname result") }
  assert_eq(pr.input(), "/foo/bar/baz")
  match pr.groups().get("0") {
    Some(Some(v)) => assert_eq(v, "/foo/bar/baz")
    _ => fail("expected group 0 = '/foo/bar/baz'")
  }
}

///|
test "named group :bar captures segment" {
  let p = try! @urlpattern.UrlPattern::from_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/foo/:bar")),
  )
  let result = p.exec_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/foo/hello")),
  )
  assert_true(result is Some(_))
  guard result is Some(r) else { fail("expected match") }
  guard r.pathname() is Some(pr) else { fail("expected pathname result") }
  assert_eq(pr.input(), "/foo/hello")
  match pr.groups().get("bar") {
    Some(Some(v)) => assert_eq(v, "hello")
    _ => fail("expected group bar = 'hello'")
  }
}

///|
test "group name may contain a CJK Unified Ideograph Extension B character" {
  let p = try! @urlpattern.UrlPattern::from_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/:\u{20000}")),
  )
  let result = p.exec_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/foo")),
  )
  guard result is Some(r) else { fail("expected match") }
  guard r.pathname() is Some(pr) else { fail("expected pathname result") }
  match pr.groups().get("\u{20000}") {
    Some(Some(v)) => assert_eq(v, "foo")
    _ => fail("expected group value 'foo'")
  }
}

///|
test "named group :bar does not match across slash" {
  let p = try! @urlpattern.UrlPattern::from_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/foo/:bar")),
  )
  let result = p.exec_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/foo/a/b")),
  )
  assert_true(result is None)
}

// ===== ignoreCase =====

///|
test "ignoreCase: exact pathname match succeeds case-insensitively" {
  let p = try! @urlpattern.UrlPattern::from_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/foo/bar")),
    ignore_case=true,
  )
  let result = p.exec_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/FOO/BAR")),
  )
  assert_true(result is Some(_))
}

///|
test "ignoreCase: exact pathname does not match when flag is false" {
  let p = try! @urlpattern.UrlPattern::from_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/foo/bar")),
  )
  let result = p.exec_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/FOO/BAR")),
  )
  assert_true(result is None)
}

///|
test "ignoreCase: named group captures uppercase input" {
  let p = try! @urlpattern.UrlPattern::from_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/foo/:name")),
    ignore_case=true,
  )
  let result = p.exec_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/FOO/HELLO")),
  )
  assert_true(result is Some(_))
  guard result is Some(r) else { fail("expected match") }
  guard r.pathname() is Some(pr) else { fail("expected pathname result") }
  match pr.groups().get("name") {
    Some(Some(v)) => assert_eq(v, "HELLO")
    _ => fail("expected group name = 'HELLO'")
  }
}

///|
test "ignoreCase: from_string matches uppercase input" {
  let p = try! @urlpattern.UrlPattern::from_string(
    "https://example.com/foo",
    None,
    ignore_case=true,
  )
  let result = p.exec_url("https://example.com/FOO")
  assert_true(result is Some(_))
}

///|
test "ignoreCase: from_string without flag does not match uppercase" {
  let p = try! @urlpattern.UrlPattern::from_string(
    "https://example.com/foo",
    None,
  )
  let result = p.exec_url("https://example.com/FOO")
  assert_true(result is None)
}

///|
test "custom regexp group (.*) captures greedily" {
  let p = try! @urlpattern.UrlPattern::from_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/foo/(.*)")),
  )
  let result = p.exec_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/foo/bar/baz")),
  )
  assert_true(result is Some(_))
  guard result is Some(r) else { fail("expected match") }
  guard r.pathname() is Some(pr) else { fail("expected pathname result") }
  match pr.groups().get("0") {
    Some(Some(v)) => assert_eq(v, "bar/baz")
    _ => fail("expected group 0 = 'bar/baz'")
  }
}

///|
test "lone surrogates in pathname pattern encode as U+FFFD" {
  let s = String::from_array([
    Int::unsafe_to_char(0xD83D),
    Int::unsafe_to_char(0x20),
    Int::unsafe_to_char(0xDEB2),
  ])
  let p = try! @urlpattern.UrlPattern::from_init(
    @urlpattern.UrlPatternInit::new(pathname=Some(s)),
  )
  assert_eq(p.get_pathname(), "%EF%BF%BD%20%EF%BF%BD")
}

// ===== constructor edge cases (urlpattern-constructor.any.js) =====

///|
test "from_init rejects pathname where percent-encoded percent yields unclosed paren" {
  try
    @urlpattern.UrlPattern::from_init(
      @urlpattern.UrlPatternInit::new(
        protocol=Some("https"),
        hostname=Some("example.org"),
        pathname=Some("/%25("),
      ),
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("expected error")
  }
}

///|
test "from_init rejects pathname with two consecutive unclosed parens after encoded percent" {
  try
    @urlpattern.UrlPattern::from_init(
      @urlpattern.UrlPatternInit::new(
        protocol=Some("https"),
        hostname=Some("example.org"),
        pathname=Some("/%25(("),
      ),
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("expected error")
  }
}

///|
test "from_string raises when pattern string has no protocol and no base URL" {
  try @urlpattern.UrlPattern::from_string("(\\", None) catch {
    _ => ()
  } noraise {
    _ => fail("expected error")
  }
}

///|
test "from_init with all fields absent succeeds with wildcard defaults" {
  try
    @urlpattern.UrlPattern::from_init(@urlpattern.UrlPatternInit::new())
  catch {
    e => fail("expected Ok, got \{e}")
  } noraise {
    _ => ()
  }
}

///|
test "optional FullWildcard tail group is None when input fully consumed" {
  let p = try! @urlpattern.UrlPattern::from_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("*{}**?")),
  )
  assert_eq(p.get_pathname(), "*(.*)?")
  let result = p.exec_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("foobar")),
  )
  guard result is Some(r) else { fail("expected match") }
  guard r.pathname() is Some(pr) else { fail("expected pathname result") }
  match pr.groups().get("0") {
    Some(Some(v)) => assert_eq(v, "foobar")
    _ => fail("expected group 0 = 'foobar'")
  }
  match pr.groups().get("1") {
    Some(None) => ()
    Some(Some(v)) => fail("expected group 1 = None, got Some('\{v}')")
    None => fail("expected group 1 key to be present")
  }
}

// ===== tokenizer and pattern parser error paths =====

///|
test "from_init raises for pattern with trailing backslash" {
  try
    @urlpattern.UrlPattern::from_init(
      @urlpattern.UrlPatternInit::new(pathname=Some("foo\\")),
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("expected error")
  }
}

///|
test "from_init raises for pattern with bare colon" {
  try
    @urlpattern.UrlPattern::from_init(
      @urlpattern.UrlPatternInit::new(pathname=Some(":")),
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("expected error")
  }
}

///|
test "from_init raises for named group with hyphen in name" {
  try
    @urlpattern.UrlPattern::from_init(
      @urlpattern.UrlPatternInit::new(pathname=Some("/:foo-bar")),
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("expected error")
  }
}

///|
test "from_init raises for duplicate named group" {
  try
    @urlpattern.UrlPattern::from_init(
      @urlpattern.UrlPatternInit::new(pathname=Some("/:name/:name")),
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("expected error")
  }
}

// ===== port normalization and exec_init edge cases =====

///|
test "wss port 443 is normalized to empty pattern in constructor" {
  let p = try! @urlpattern.UrlPattern::from_init(
    @urlpattern.UrlPatternInit::new(protocol=Some("wss"), port=Some("443")),
  )
  assert_eq(p.get_port(), "")
}

///|
test "exec_init with port above 65535 passes through without normalization" {
  let p = try! @urlpattern.UrlPattern::from_init(
    @urlpattern.UrlPatternInit::new(),
  )
  assert_true(
    p.exec_init(@urlpattern.UrlPatternInit::new(port=Some("65536"))) is Some(_),
  )
}

///|
test "from_init resolves dotdot in relative pathname against base URL" {
  let p = try! @urlpattern.UrlPattern::from_init(
    @urlpattern.UrlPatternInit::new(
      base_url=Some("https://example.com/a/b/c"),
      pathname=Some("../d"),
    ),
  )
  assert_eq(p.get_pathname(), "/a/d")
}

///|
test "test_init returns true for matching UrlPatternInit" {
  let p = try! @urlpattern.UrlPattern::from_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/foo/:bar")),
  )
  assert_true(
    p.test_init(@urlpattern.UrlPatternInit::new(pathname=Some("/foo/hello"))),
  )
}

///|
test "test_init returns false for non-matching UrlPatternInit" {
  let p = try! @urlpattern.UrlPattern::from_init(
    @urlpattern.UrlPatternInit::new(pathname=Some("/foo/:bar")),
  )
  assert_true(
    p.test_init(@urlpattern.UrlPatternInit::new(pathname=Some("/other"))) ==
    false,
  )
}
