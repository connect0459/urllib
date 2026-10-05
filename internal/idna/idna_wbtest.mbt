///|
test "try_nfc_compose: grave accent combinations (U+0300)" {
  assert_eq(try_nfc_compose(0x0041, 0x0300), 0x00C0) // A + ` → À
  assert_eq(try_nfc_compose(0x0061, 0x0300), 0x00E0) // a + ` → à
  assert_eq(try_nfc_compose(0x006F, 0x0300), 0x00F2) // o + ` → ò
}

///|
test "try_nfc_compose: diaeresis combinations (U+0308)" {
  assert_eq(try_nfc_compose(0x0041, 0x0308), 0x00C4) // A + ¨ → Ä
  assert_eq(try_nfc_compose(0x0061, 0x0308), 0x00E4) // a + ¨ → ä
  assert_eq(try_nfc_compose(0x004F, 0x0308), 0x00D6) // O + ¨ → Ö
  assert_eq(try_nfc_compose(0x006F, 0x0308), 0x00F6) // o + ¨ → ö
  assert_eq(try_nfc_compose(0x0055, 0x0308), 0x00DC) // U + ¨ → Ü
  assert_eq(try_nfc_compose(0x0075, 0x0308), 0x00FC) // u + ¨ → ü
}

///|
test "try_nfc_compose: circumflex combinations (U+0302)" {
  assert_eq(try_nfc_compose(0x0053, 0x0302), 0x015C) // S + ^ → Ŝ
  assert_eq(try_nfc_compose(0x0073, 0x0302), 0x015D) // s + ^ → ŝ
}

///|
test "try_nfc_compose: dot above combinations (U+0307)" {
  assert_eq(try_nfc_compose(0x0059, 0x0307), 0x1E8E) // Y + ˙ → Ẏ
  assert_eq(try_nfc_compose(0x0079, 0x0307), 0x1E8F) // y + ˙ → ẏ
}

///|
test "try_nfc_compose: acute accent combinations (U+0301)" {
  assert_eq(try_nfc_compose(0x039F, 0x0301), 0x038C) // Ο + ´ → Ό
  assert_eq(try_nfc_compose(0x03BF, 0x0301), 0x03CC) // ο + ´ → ό
  assert_eq(try_nfc_compose(0x006F, 0x0301), 0x00F3) // o + ´ → ó
  assert_eq(try_nfc_compose(0x006B, 0x0301), 0x1E31) // k + ´ → ḱ
}

///|
test "try_nfc_compose: no composition returns -1" {
  assert_eq(try_nfc_compose(0x0041, 0x0041), -1) // A + A → no composition
}

///|
test "domain_to_ascii: empty input raises IdnaParseError" {
  let caught = try {
    let _ = domain_to_ascii("")
    false
  } catch {
    IdnaParseError(_) => true
  }
  assert_eq(caught, true)
}

///|
test "domain_to_ascii: ASCII xn-- label with invalid Punycode is passed through" {
  assert_eq(domain_to_ascii("xn--a"), "xn--a")
  assert_eq(domain_to_ascii("xn--ls8h="), "xn--ls8h=")
  assert_eq(domain_to_ascii("xn--"), "xn--")
}

///|
test "domain_to_ascii: ASCII xn-- label whose decoding violates validity rules is passed through" {
  assert_eq(domain_to_ascii("xn--zn7c.com"), "xn--zn7c.com")
  assert_eq(domain_to_ascii("xn--1ug.example"), "xn--1ug.example")
}

///|
test "domain_to_ascii: non-ASCII label with xn-- prefix is rejected" {
  try domain_to_ascii("xn--te\u{0161}la") catch {
    IdnaParseError(_) => ()
  } noraise {
    _ => fail("expected IdnaParseError")
  }
}

///|
test "domain_to_ascii: invalid ASCII xn-- label is rejected when another label is non-ASCII" {
  try domain_to_ascii("xn--a.\u{DF}") catch {
    IdnaParseError(_) => ()
  } noraise {
    _ => fail("expected IdnaParseError")
  }
}

///|
test "is_combining_mark_table: marks assigned after Unicode 16 are recognized" {
  assert_true(is_combining_mark_table(0x05C8))
  assert_true(is_combining_mark_table(0x1ACF))
}

///|
test "is_combining_mark_table: base letters are not marks" {
  assert_false(is_combining_mark_table(0x0041))
  assert_false(is_combining_mark_table(0x05D0))
}
