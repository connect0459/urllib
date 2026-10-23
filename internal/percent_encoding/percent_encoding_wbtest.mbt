///|
test "percent_encode_opaque_path_at_stop: empty input returns empty string" {
  assert_eq(percent_encode_opaque_path_at_stop(""), "")
}

// ===== percent_encode_c0 =====

///|
test "percent_encode_c0: printable ASCII is unchanged" {
  assert_eq(percent_encode_c0("hello-world_123"), "hello-world_123")
}

///|
test "percent_encode_c0: null byte is encoded" {
  assert_eq(percent_encode_c0("\u{00}"), "%00")
}

///|
test "percent_encode_c0: C0 control char is encoded" {
  assert_eq(percent_encode_c0("\u{1F}"), "%1F")
}

///|
test "percent_encode_c0: non-ASCII char is UTF-8 percent-encoded" {
  assert_eq(percent_encode_c0("café"), "caf%C3%A9")
}

///|
test "percent_encode_c0: emoji is encoded as four-byte UTF-8 sequence" {
  assert_eq(percent_encode_c0("🌈"), "%F0%9F%8C%88")
}

///|
test "percent_encode_c0: lone high surrogate is replaced with U+FFFD" {
  let s = String::from_array([Int32::unsafe_to_char(0xD83D)])
  assert_eq(percent_encode_c0(s), "%EF%BF%BD")
}

///|
test "percent_encode_c0: lone low surrogate is replaced with U+FFFD" {
  let s = String::from_array([Int32::unsafe_to_char(0xDEB2)])
  assert_eq(percent_encode_c0(s), "%EF%BF%BD")
}

///|
test "percent_encode_path_seg: lone surrogates split by space yield two U+FFFD" {
  let s = String::from_array([
    Int32::unsafe_to_char(0xD83D),
    Int32::unsafe_to_char(0x20),
    Int32::unsafe_to_char(0xDEB2),
  ])
  assert_eq(percent_encode_path_seg(s), "%EF%BF%BD%20%EF%BF%BD")
}

///|
test "char_to_utf8_bytes: lone surrogate produces U+FFFD bytes" {
  let hi = char_to_utf8_bytes(Int32::unsafe_to_char(0xD83D))
  let lo = char_to_utf8_bytes(Int32::unsafe_to_char(0xDEB2))
  let expected = [0xEF, 0xBF, 0xBD]
  assert_true(hi.length() == expected.length())
  assert_true(lo.length() == expected.length())
  for i in 0..<expected.length() {
    assert_true(hi[i] == expected[i])
    assert_true(lo[i] == expected[i])
  }
}

// ===== percent_decode =====

///|
test "percent_decode: already-decoded string is unchanged" {
  assert_eq(percent_decode("hello"), "hello")
}

///|
test "percent_decode: %20 decodes to space" {
  assert_eq(percent_decode("hello%20world"), "hello world")
}

///|
test "percent_decode: %25 decodes to literal percent" {
  assert_eq(percent_decode("100%25"), "100%")
}

///|
test "percent_decode: multi-byte UTF-8 sequence decodes to char" {
  assert_eq(percent_decode("%C3%A9"), "é")
}

///|
test "percent_decode: lone percent sign is passed through" {
  assert_eq(percent_decode("%"), "%")
}

///|
test "percent_decode: invalid percent sequence is passed through" {
  assert_eq(percent_decode("%GG"), "%GG")
}

// ===== percent_encode_path_seg =====

///|
test "percent_encode_path_seg: space is encoded" {
  assert_eq(percent_encode_path_seg("a b"), "a%20b")
}

///|
test "percent_encode_path_seg: curly braces are encoded" {
  assert_eq(percent_encode_path_seg("a{b}"), "a%7Bb%7D")
}

///|
test "percent_encode_path_seg: question mark is encoded" {
  assert_eq(percent_encode_path_seg("a?b"), "a%3Fb")
}

///|
test "percent_encode_path_seg: unreserved chars are unchanged" {
  assert_eq(percent_encode_path_seg("abc-._~"), "abc-._~")
}

// ===== percent_encode_query =====

///|
test "percent_encode_query: space is encoded for non-special URL" {
  assert_eq(percent_encode_query("hello world", false), "hello%20world")
}

///|
test "percent_encode_query: single quote is not encoded for non-special URL" {
  assert_eq(percent_encode_query("it's", false), "it's")
}

///|
test "percent_encode_query: single quote is encoded for special URL" {
  assert_eq(percent_encode_query("it's", true), "it%27s")
}

///|
test "percent_encode_query: hash is encoded" {
  assert_eq(percent_encode_query("a#b", false), "a%23b")
}

// ===== percent_encode_fragment =====

///|
test "percent_encode_fragment: space is encoded" {
  assert_eq(percent_encode_fragment("hello world"), "hello%20world")
}

///|
test "percent_encode_fragment: backtick is encoded" {
  assert_eq(percent_encode_fragment("a`b"), "a%60b")
}

///|
test "percent_encode_fragment: angle brackets are encoded" {
  assert_eq(percent_encode_fragment("a<b>c"), "a%3Cb%3Ec")
}

// ===== percent_encode_userinfo =====

///|
test "percent_encode_userinfo: colon is encoded" {
  assert_eq(percent_encode_userinfo("user:pass"), "user%3Apass")
}

///|
test "percent_encode_userinfo: at-sign is encoded" {
  assert_eq(percent_encode_userinfo("user@host"), "user%40host")
}

///|
test "percent_encode_userinfo: slash is encoded" {
  assert_eq(percent_encode_userinfo("a/b"), "a%2Fb")
}

// ===== hex_digit_value =====

///|
test "hex_digit_value: decimal digits map to 0-9" {
  assert_true(hex_digit_value('0') == Some(0))
  assert_true(hex_digit_value('9') == Some(9))
}

///|
test "hex_digit_value: uppercase hex letters map to 10-15" {
  assert_true(hex_digit_value('A') == Some(10))
  assert_true(hex_digit_value('F') == Some(15))
}

///|
test "hex_digit_value: lowercase hex letters map to 10-15" {
  assert_true(hex_digit_value('a') == Some(10))
  assert_true(hex_digit_value('f') == Some(15))
}

///|
test "hex_digit_value: non-hex char returns None" {
  assert_true(hex_digit_value('G') is None)
  assert_true(hex_digit_value('z') is None)
}

// ===== percent_encode_byte =====

///|
test "percent_encode_byte: space is %20" {
  assert_eq(percent_encode_byte(0x20), "%20")
}

///|
test "percent_encode_byte: null byte is %00" {
  assert_eq(percent_encode_byte(0x00), "%00")
}

///|
test "percent_encode_byte: high byte is uppercase hex" {
  assert_eq(percent_encode_byte(0xFF), "%FF")
}
