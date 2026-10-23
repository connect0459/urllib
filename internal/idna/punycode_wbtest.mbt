///|
fn str_to_cps(s : String) -> Array[Int32] {
  let cps : Array[Int32] = []
  for c in s {
    cps.push(c.to_int())
  }
  cps
}

///|
fn cps_to_str(cps : Array[Int32]) -> String {
  let buf = StringBuilder()
  for cp in cps {
    buf.write_char(Int32::unsafe_to_char(cp))
  }
  buf.to_string()
}

///|
test "punycode encode: RFC 3492 section 7.1 test vectors" {
  let cases : Array[(String, String)] = [
    // Arabic (Egyptian)
    ("ليهمابتكلموشعربي؟", "egbpdaj6bu4bxfgehfvwxn"),
    // Chinese (simplified)
    ("他们为什么不说中文", "ihqwcrb4cv8a8dqg056pqjye"),
    // Chinese (traditional)
    ("他們爲什麽不說中文", "ihqwctvzc91f659drss3x8bo0yb"),
    // Czech
    ("Pročprostěnemluvíčesky", "Proprostnemluvesky-uyb24dma41a"),
    // Hebrew
    (
      "למההםפשוטלאמדבריםעברית", "4dbcagdahymbxekheh6e0a7fei0b",
    ),
    // Hindi (Devanagari)
    (
      "यहलोगहिन्दीक्योंनहींबोलसकतेहैं",
      "i1baa7eci9glrd9b2ae1bj0hfcgg6iyaf8o0a1dig0cd",
    ),
    // Japanese (kanji and hiragana)
    (
      "なぜみんな日本語を話してくれないのか", "n8jok5ay5dzabd5bym9f0cm5685rrjetr6pdxa",
    ),
    // Korean (Hangul syllables)
    (
      "세계의모든사람들이한국어를이해한다면얼마나좋을까",
      "989aomsvi5e83db1d2a355cv1e0vak1dwrv93d5xbh15a0dt30a5jpsd879ccm6fea98c",
    ),
    // Russian (Cyrillic)
    (
      "почемужеонинеговорятпорусски", "b1abfaaepdrnnbgefbadotcwatmq2g4l",
    ),
    // Spanish
    (
      "PorquénopuedensimplementehablarenEspañol", "PorqunopuedensimplementehablarenEspaol-fmd56a",
    ),
    // Vietnamese
    (
      "TạisaohọkhôngthểchỉnóitiếngViệt", "TisaohkhngthchnitingVit-kjcr8268qyxafd2f1b9g",
    ),
    // Mixed script
    ("3年B組金八先生", "3B-ww4c5e180e575a65lsy2b"),
    (
      "安室奈美恵-with-SUPER-MONKEYS", "-with-SUPER-MONKEYS-pc58ag80a8qai00g7n9n",
    ),
    (
      "Hello-Another-Way-それぞれの場所", "Hello-Another-Way--fc4qua05auwb3674vfr0b",
    ),
    ("ひとつ屋根の下2", "2-u9tlzr9756bt3uc0v"),
    ("MajiでKoiする5秒前", "MajiKoi5-783gue6qz075azm5e"),
    ("パフィーdeルンバ", "de-jg4avhby1noc0d"),
    ("そのスピードで", "d9juau41awczczp"),
    ("-> $1.00 <-", "-> $1.00 <--"),
  ]
  for item in cases {
    let (raw, expected) = item
    let got = punycode_encode(str_to_cps(raw))
    assert_eq(got, expected)
  }
}

///|
test "punycode_digit_value: uppercase letters are valid digits" {
  assert_eq(punycode_digit_value('A'), 0)
  assert_eq(punycode_digit_value('Z'), 25)
}

///|
test "punycode_decode: empty input raises IdnaParseError" {
  let caught = try {
    let _ = punycode_decode("")
    false
  } catch {
    IdnaParseError(_) => true
  }
  assert_eq(caught, true)
}

///|
test "punycode_decode: non-ASCII char before delimiter raises error" {
  let caught = try {
    let _ = punycode_decode("\u{0080}-")
    false
  } catch {
    IdnaParseError(_) => true
  }
  assert_eq(caught, true)
}

///|
test "punycode_decode: code point overflow raises error" {
  // "en32g" encodes delta=1,113,984 which pushes n past U+10FFFF
  let caught = try {
    let _ = punycode_decode("en32g")
    false
  } catch {
    IdnaParseError(_) => true
  }
  assert_eq(caught, true)
}

///|
test "punycode_decode: surrogate code point raises error" {
  // "ib9b" encodes delta=55,168 which decodes to U+D800 (surrogate)
  let caught = try {
    let _ = punycode_decode("ib9b")
    false
  } catch {
    IdnaParseError(_) => true
  }
  assert_eq(caught, true)
}

///|
test "punycode_encode: empty input raises IdnaParseError" {
  let caught = try {
    let _ = punycode_encode([])
    false
  } catch {
    IdnaParseError(_) => true
  }
  assert_eq(caught, true)
}

///|
test "punycode decode: RFC 3492 section 7.1 test vectors" {
  let cases : Array[(String, String)] = [
    // Arabic (Egyptian)
    ("egbpdaj6bu4bxfgehfvwxn", "ليهمابتكلموشعربي؟"),
    // Chinese (simplified)
    ("ihqwcrb4cv8a8dqg056pqjye", "他们为什么不说中文"),
    // Chinese (traditional)
    ("ihqwctvzc91f659drss3x8bo0yb", "他們爲什麽不說中文"),
    // Czech
    ("Proprostnemluvesky-uyb24dma41a", "Pročprostěnemluvíčesky"),
    // Hebrew
    (
      "4dbcagdahymbxekheh6e0a7fei0b", "למההםפשוטלאמדבריםעברית",
    ),
    // Hindi (Devanagari)
    (
      "i1baa7eci9glrd9b2ae1bj0hfcgg6iyaf8o0a1dig0cd", "यहलोगहिन्दीक्योंनहींबोलसकतेहैं",
    ),
    // Japanese (kanji and hiragana)
    (
      "n8jok5ay5dzabd5bym9f0cm5685rrjetr6pdxa", "なぜみんな日本語を話してくれないのか",
    ),
    // Korean (Hangul syllables)
    (
      "989aomsvi5e83db1d2a355cv1e0vak1dwrv93d5xbh15a0dt30a5jpsd879ccm6fea98c", "세계의모든사람들이한국어를이해한다면얼마나좋을까",
    ),
    // Russian (Cyrillic)
    (
      "b1abfaaepdrnnbgefbadotcwatmq2g4l", "почемужеонинеговорятпорусски",
    ),
    // Spanish
    (
      "PorqunopuedensimplementehablarenEspaol-fmd56a", "PorquénopuedensimplementehablarenEspañol",
    ),
    // Vietnamese
    (
      "TisaohkhngthchnitingVit-kjcr8268qyxafd2f1b9g", "TạisaohọkhôngthểchỉnóitiếngViệt",
    ),
    // Mixed script
    ("3B-ww4c5e180e575a65lsy2b", "3年B組金八先生"),
    (
      "-with-SUPER-MONKEYS-pc58ag80a8qai00g7n9n", "安室奈美恵-with-SUPER-MONKEYS",
    ),
    (
      "Hello-Another-Way--fc4qua05auwb3674vfr0b", "Hello-Another-Way-それぞれの場所",
    ),
    ("2-u9tlzr9756bt3uc0v", "ひとつ屋根の下2"),
    ("MajiKoi5-783gue6qz075azm5e", "MajiでKoiする5秒前"),
    ("de-jg4avhby1noc0d", "パフィーdeルンバ"),
    ("d9juau41awczczp", "そのスピードで"),
    ("-> $1.00 <--", "-> $1.00 <-"),
  ]
  for item in cases {
    let (encoded, expected) = item
    let got = cps_to_str(punycode_decode(encoded))
    assert_eq(got, expected)
  }
}
