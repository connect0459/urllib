///|
fn to_repr_idna(s : String?) -> String {
  match s {
    None => "None"
    Some(v) => "Some(\{v})"
  }
}

///|
fn hex_digit_value(c : Char) -> Int? {
  let n = c.to_int()
  if n >= '0'.to_int() && n <= '9'.to_int() {
    Some(n - '0'.to_int())
  } else if n >= 'a'.to_int() && n <= 'f'.to_int() {
    Some(n - 'a'.to_int() + 10)
  } else if n >= 'A'.to_int() && n <= 'F'.to_int() {
    Some(n - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
/// Reads the hex value of a `\uXXXX` escape starting at `at` in `s`, or
/// `None` if `s[at..]` is not such an escape.
fn unicode_escape_value(s : String, at : Int) -> Int? {
  if at + 5 >= s.length() {
    return None
  }
  if s.get_char(at) != Some('\\') || s.get_char(at + 1) != Some('u') {
    return None
  }
  let mut value = 0
  for i in 0..<4 {
    match s.get_char(at + 2 + i) {
      Some(c) =>
        match hex_digit_value(c) {
          Some(v) => value = value * 16 + v
          None => return None
        }
      None => return None
    }
  }
  Some(value)
}

///|
/// Replaces unpaired UTF-16 surrogate `\uXXXX` escapes with U+FFFD so that
/// `@json.parse` accepts WPT fixtures that deliberately embed invalid
/// Unicode as malformed-input test cases; `@json.parse` now rejects unpaired
/// surrogate escapes outright (moonbitlang/core CHANGELOG, `@json.parse`
/// breaking change). The replacement preserves each case's "not a
/// well-formed character" intent without changing the fixture's structure.
fn sanitize_unpaired_surrogates(text : String) -> String {
  let n = text.length()
  let out = StringBuilder()
  let mut i = 0
  while i < n {
    let c = text.get_char(i).unwrap_or('\u{0}')
    if c != '\\' {
      out.write_char(c)
      i = i + (if c.to_int() > 0xFFFF { 2 } else { 1 })
      continue
    }
    match unicode_escape_value(text, i) {
      Some(v) if v >= 0xD800 && v <= 0xDBFF =>
        match unicode_escape_value(text, i + 6) {
          Some(v2) if v2 >= 0xDC00 && v2 <= 0xDFFF => {
            out.write_string(text[i:i + 12].to_owned())
            i = i + 12
          }
          _ => {
            out.write_string("\\ufffd")
            i = i + 6
          }
        }
      Some(v) if v >= 0xDC00 && v <= 0xDFFF => {
        out.write_string("\\ufffd")
        i = i + 6
      }
      Some(_) => {
        out.write_string(text[i:i + 6].to_owned())
        i = i + 6
      }
      None =>
        if i + 1 < n {
          out.write_string(text[i:i + 2].to_owned())
          i = i + 2
        } else {
          out.write_char(c)
          i = i + 1
        }
    }
  }
  out.to_string()
}

///|
test "fixture sanitizer keeps supplementary-plane characters intact" {
  let text = "[\"a\u{20000}b\"]"
  assert_eq(sanitize_unpaired_surrogates(text), text)
}

///|
test "WPT IdnaTestV2: domain-to-ascii cases" {
  let content = @fs.read_file_to_string("wpt/url/resources/IdnaTestV2.json")
  let json = @json.parse(sanitize_unpaired_surrogates(content))
  let items = match json {
    Array(a) => a
    _ => fail("expected JSON array")
  }
  let cases : Array[(String, String?)] = []
  for item in items {
    match item {
      Object(obj) => {
        let input = match obj.get("input") {
          Some(String(s)) => s
          _ => fail("missing or non-string 'input' field")
        }
        if input == "" {
          continue
        }
        let expected : String? = match obj.get("output") {
          Some(String(s)) => Some(s)
          Some(Null) => None
          _ => fail("unexpected 'output' field type")
        }
        cases.push((input, expected))
      }
      _ => ()
    }
  }
  let failures : Array[String] = []
  for item in cases {
    let (input, expected) = item
    let url_str = "https://" + input + "/x"
    let result = @url.parse_maybe(url_str, None)
    let actual = match result {
      None => None
      Some(url) => Some(url.hostname())
    }
    if actual != expected {
      failures.push(
        "FAIL: input=\{input}\n  expected=\{to_repr_idna(expected)}\n  actual=\{to_repr_idna(actual)}",
      )
    }
  }
  let total = cases.length()
  let passed = total - failures.length()
  let n = if failures.length() < 10 { failures.length() } else { 10 }
  for i in 0..<n {
    println(failures[i])
  }
  println("WPT IdnaTestV2: \{passed}/\{total} passed")
  assert_eq(failures.length(), 0)
}
