///|
struct IdnaTestCase {
  line : Int32
  source : String
  to_ascii : String
  has_error : Bool
  status : String
}

///|
fn parse_idna_escapes(s : String) -> String? {
  let chars = s.to_array()
  let out = StringBuilder()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c != '\\' {
      out.write_char(c)
      i += 1
      continue
    }
    let (digits_start, terminator, skip) = if chars[i + 1] == 'u' {
      (i + 2, None, 4)
    } else {
      (i + 3, Some('}'), -1)
    }
    let mut value = 0
    let mut j = digits_start
    while j < chars.length() && Some(chars[j]) != terminator {
      if skip >= 0 && j - digits_start == skip {
        break
      }
      value = value * 16 + hex_digit_value(chars[j]).unwrap()
      j += 1
    }
    if value >= 0xD800 && value <= 0xDFFF {
      return None
    }
    out.write_char(value.unsafe_to_char())
    i = if terminator is Some(_) { j + 1 } else { j }
  }
  Some(out.to_string())
}

///|
fn trim_field(s : String) -> String {
  s.trim(chars=" \t").to_owned()
}

///|
fn resolve_field(raw : String, fallback : String) -> String {
  let t = trim_field(raw)
  if t == "" {
    fallback
  } else if t == "\"\"" {
    ""
  } else {
    t
  }
}

///|
fn resolve_status(raw : String, fallback : String) -> String {
  let t = trim_field(raw)
  if t == "" {
    fallback
  } else {
    t
  }
}

///|
fn load_idna_test_v2_cases() -> (Array[IdnaTestCase], Int32) raise {
  let content = @fs.read_file_to_string("testdata/unicode/IdnaTestV2.txt")
  let cases : Array[IdnaTestCase] = []
  let mut skipped = 0
  let mut line_no = 0
  for line in content.split("\n") {
    line_no += 1
    let line = line.to_owned()
    if line.trim(chars=" \t").to_owned() == "" || line.has_prefix("#") {
      continue
    }
    let body = match line.find("#") {
      Some(i) => line[0:i].to_owned()
      None => line
    }
    let cols = body.split(";").map(fn(c) { c.to_owned() }).collect()
    let source_raw = resolve_field(cols[0], "")
    let to_unicode = resolve_field(cols[1], source_raw)
    let to_unicode_status = resolve_status(cols[2], "[]")
    let to_ascii_n = resolve_field(cols[3], to_unicode)
    let to_ascii_n_status = resolve_status(cols[4], to_unicode_status)
    match (parse_idna_escapes(source_raw), parse_idna_escapes(to_ascii_n)) {
      (Some(source), Some(to_ascii)) =>
        cases.push({
          line: line_no,
          source,
          to_ascii,
          has_error: to_ascii_n_status != "[]",
          status: to_ascii_n_status,
        })
      _ => skipped += 1
    }
  }
  (cases, skipped)
}

///|
test "IdnaTestV2 loader reads the vendored Unicode 18.0.0 file" {
  let (cases, skipped) = load_idna_test_v2_cases()
  assert_true(cases.length() > 6000)
  assert_eq(skipped, 2)
}

///|
enum IdnaDisagreement {
  BidiRuleNotImplemented
  TrailingRootDotAccepted
  Unexplained
}

///|
fn idna_status_codes(status : String) -> Array[String] {
  let inner = status.trim(chars="[]").to_owned()
  let codes : Array[String] = []
  for part in inner.split(",") {
    let code = part.trim(chars=" ").to_owned()
    if code != "" {
      codes.push(code)
    }
  }
  codes
}

///|
fn accepts_single_trailing_root_dot(actual : String) -> Bool {
  actual.has_suffix(".") && !actual[:actual.length() - 1].has_suffix(".")
}

///|
fn classify_idna_disagreement(
  status : String,
  actual : String,
) -> IdnaDisagreement {
  let codes = idna_status_codes(status)
  let mut bidi = false
  let mut root_dot = false
  for code in codes {
    if code.has_prefix("B") {
      bidi = true
    } else if code == "A4_2" && accepts_single_trailing_root_dot(actual) {
      root_dot = true
    } else {
      return Unexplained
    }
  }
  if bidi {
    BidiRuleNotImplemented
  } else if root_dot {
    TrailingRootDotAccepted
  } else {
    Unexplained
  }
}

///|
test "a disagreement is explained only when every status code is a documented difference" {
  assert_true(
    classify_idna_disagreement("[B1, B6]", "a.b") is BidiRuleNotImplemented,
  )
  assert_true(
    classify_idna_disagreement("[A4_2]", "a.b.") is TrailingRootDotAccepted,
  )
  assert_true(
    classify_idna_disagreement("[B1, A4_2]", "a.b.") is BidiRuleNotImplemented,
  )
  assert_true(classify_idna_disagreement("[B1, V3]", "a.b") is Unexplained)
  assert_true(classify_idna_disagreement("[A4_2]", "a.b") is Unexplained)
  assert_true(classify_idna_disagreement("[A4_2]", "a.b..") is Unexplained)
  assert_true(classify_idna_disagreement("[]", "a.b") is Unexplained)
}

///|
test "strict domain_to_ascii agrees with IdnaTestV2 except for documented differences" {
  let (cases, _) = load_idna_test_v2_cases()
  let unexplained : Array[String] = []
  let mut bidi = 0
  let mut root_dot = 0
  for c in cases {
    let actual = @url.domain_to_ascii(c.source, strict=true)
    let agrees = if c.has_error { actual == "" } else { actual == c.to_ascii }
    if agrees {
      continue
    }
    match classify_idna_disagreement(c.status, actual) {
      BidiRuleNotImplemented => bidi += 1
      TrailingRootDotAccepted => root_dot += 1
      Unexplained =>
        unexplained.push(
          "\{c.status} line \{c.line}: \{c.source.escape()} expected=\{if c.has_error { "error" } else { c.to_ascii }} actual=\{actual}",
        )
    }
  }
  for line in unexplained {
    println(line)
  }
  assert_eq(unexplained.length(), 0)
  assert_true(bidi > 0)
  assert_true(root_dot > 0)
}
