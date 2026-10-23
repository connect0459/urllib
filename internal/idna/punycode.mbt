///|
let punycode_base : Int32 = 36

///|
let punycode_tmin : Int32 = 1

///|
let punycode_tmax : Int32 = 26

///|
let punycode_skew : Int32 = 38

///|
let punycode_damp : Int32 = 700

///|
let punycode_initial_bias : Int32 = 72

///|
let punycode_initial_n : Int32 = 128

///|
fn punycode_adapt(delta : Int32, numpoints : Int32, firsttime : Bool) -> Int32 {
  let mut d = if firsttime { delta / punycode_damp } else { delta >> 1 }
  d = d + d / numpoints
  let mut k = 0
  while d > (punycode_base - punycode_tmin) * punycode_tmax / 2 {
    d = d / (punycode_base - punycode_tmin)
    k = k + punycode_base
  }
  k + (punycode_base - punycode_tmin + 1) * d / (d + punycode_skew)
}

///|
fn punycode_digit_value(c : Char) -> Int32 raise IdnaParseError {
  if c >= 'a' && c <= 'z' {
    return c.to_int() - 'a'.to_int()
  }
  if c >= 'A' && c <= 'Z' {
    return c.to_int() - 'A'.to_int()
  }
  if c >= '0' && c <= '9' {
    return c.to_int() - '0'.to_int() + 26
  }
  raise IdnaParseError("invalid punycode digit")
}

///|
fn punycode_digit_to_char(d : Int32) -> Char {
  if d < 26 {
    Int32::unsafe_to_char('a'.to_int() + d)
  } else {
    Int32::unsafe_to_char('0'.to_int() + d - 26)
  }
}

///|
fn punycode_decode(input : String) -> Array[Int32] raise IdnaParseError {
  let chars = @pe.string_to_chars(input)
  let n_input = chars.length()
  if n_input == 0 {
    raise IdnaParseError("punycode: empty input")
  }
  let output : Array[Int32] = []
  let mut n = punycode_initial_n
  let mut i = 0
  let mut bias = punycode_initial_bias
  let mut basic_end = -1
  for idx, c in chars {
    if c == '-' {
      basic_end = idx
    }
  }
  let copy_end = if basic_end > 0 { basic_end } else { 0 }
  for c in chars[0:copy_end] {
    let cp = c.to_int()
    if cp > 0x7E {
      raise IdnaParseError("punycode: non-ASCII before delimiter")
    }
    output.push(cp)
  }
  let mut in_pos = if basic_end >= 0 { basic_end + 1 } else { 0 }
  while in_pos < n_input {
    let oldi = i
    let mut w = 1
    let mut k = punycode_base
    while true {
      if in_pos >= n_input {
        raise IdnaParseError("punycode: unexpected end")
      }
      let digit = punycode_digit_value(chars[in_pos])
      in_pos = in_pos + 1
      i = i + digit * w
      let t = if k <= bias + punycode_tmin {
        punycode_tmin
      } else if k >= bias + punycode_tmax {
        punycode_tmax
      } else {
        k - bias
      }
      if digit < t {
        break
      }
      w = w * (punycode_base - t)
      k = k + punycode_base
    }
    let out_plus1 = output.length() + 1
    bias = punycode_adapt(i - oldi, out_plus1, oldi == 0)
    let dn = i / out_plus1
    if n > 0x10FFFF - dn {
      raise IdnaParseError("punycode: code point overflow")
    }
    n = n + dn
    i = i % out_plus1
    if n >= 0xD800 && n <= 0xDFFF {
      raise IdnaParseError("punycode: surrogate code point")
    }
    output.insert(i, n)
    i = i + 1
  }
  output
}

///|
fn punycode_encode(input : Array[Int32]) -> String raise IdnaParseError {
  let total = input.length()
  if total == 0 {
    raise IdnaParseError("punycode: empty input")
  }
  let buf = StringBuilder()
  let mut n = punycode_initial_n
  let mut delta = 0
  let mut bias = punycode_initial_bias
  let mut basic_count = 0
  for cp in input {
    if cp < 0x80 {
      buf.write_char(Int32::unsafe_to_char(cp))
      basic_count = basic_count + 1
    }
  }
  let mut handled = basic_count
  if basic_count > 0 {
    buf.write_char('-')
  }
  while handled < total {
    let mut m = 0x110000
    for cp in input {
      if cp >= n && cp < m {
        m = cp
      }
    }
    delta = delta + (m - n) * (handled + 1)
    n = m
    for cp in input {
      if cp < n {
        delta = delta + 1
      }
      if cp == n {
        let mut q = delta
        let mut k = punycode_base
        while true {
          let t = if k <= bias + punycode_tmin {
            punycode_tmin
          } else if k >= bias + punycode_tmax {
            punycode_tmax
          } else {
            k - bias
          }
          if q < t {
            break
          }
          buf.write_char(
            punycode_digit_to_char(t + (q - t) % (punycode_base - t)),
          )
          q = (q - t) / (punycode_base - t)
          k = k + punycode_base
        }
        buf.write_char(punycode_digit_to_char(q))
        bias = punycode_adapt(delta, handled + 1, handled == basic_count)
        delta = 0
        handled = handled + 1
      }
    }
    delta = delta + 1
    n = n + 1
  }
  buf.to_string()
}
