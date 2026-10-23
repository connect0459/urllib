///|
let utf16_bmp_max : Int32 = 0xFFFF

///|
let utf16_supplementary_offset : Int32 = 0x10000

///|
let utf16_high_surrogate_base : Int32 = 0xD800

///|
let utf16_low_surrogate_base : Int32 = 0xDC00

///|
let utf16_surrogate_mask : Int32 = 0x3FF

///|
/// A mutable list of name/value string pairs used to encode
/// `application/x-www-form-urlencoded` data.
pub struct UrlSearchParams {
  priv mut list : Array[(String, String)]
}

///|
/// Creates an empty `UrlSearchParams` with no pairs.
pub fn UrlSearchParams::new() -> UrlSearchParams {
  { list: [], }
}

///|
fn parse_urlencoded(s : String) -> UrlSearchParams {
  let list : Array[(String, String)] = []
  for seq in s.split("&") {
    if seq == "" {
      continue
    }
    let seq_str = seq.to_owned()
    let eq_pos = seq_str.find("=")
    let (raw_name, raw_value) = match eq_pos {
      Some(pos) => (seq_str[0:pos].to_owned(), seq_str[pos + 1:].to_owned())
      None => (seq_str, "")
    }
    let name = url_form_decode(raw_name)
    let value = url_form_decode(raw_value)
    list.push((name, value))
  }
  { list, }
}

///|
/// Parses an `application/x-www-form-urlencoded` string into `UrlSearchParams`;
/// strips a leading `"?"` if present.
///
/// ### Example
///
/// ```mbt check
/// test {
///   let sp = @url.UrlSearchParams::from_string("a=1&b=2")
///   inspect(sp.get("a") == Some("1"), content="true")
///   inspect(sp.get("b") == Some("2"), content="true")
/// }
/// ```
pub fn UrlSearchParams::from_string(s : String) -> UrlSearchParams {
  let input = if s.has_prefix("?") { s[1:].to_owned() } else { s }
  parse_urlencoded(input)
}

///|
/// Appends a new name/value pair at the end of the list.
pub fn UrlSearchParams::append(
  self : UrlSearchParams,
  name : String,
  value : String,
) -> Unit {
  self.list.push((name, value))
}

///|
/// Removes all pairs whose name equals `name`.
pub fn UrlSearchParams::delete(self : UrlSearchParams, name : String) -> Unit {
  self.list = self.list.filter(fn(pair) { pair.0 != name })
}

///|
/// Removes all pairs matching both `name` and `value` exactly.
pub fn UrlSearchParams::delete_entry(
  self : UrlSearchParams,
  name : String,
  value : String,
) -> Unit {
  self.list = self.list.filter(fn(pair) { pair.0 != name || pair.1 != value })
}

///|
/// Returns the first value whose name equals `name`, or `None` if not found.
pub fn UrlSearchParams::get(self : UrlSearchParams, name : String) -> String? {
  for pair in self.list {
    if pair.0 == name {
      return Some(pair.1)
    }
  }
  None
}

///|
/// Returns all values whose name equals `name` in list order.
pub fn UrlSearchParams::get_all(
  self : UrlSearchParams,
  name : String,
) -> Array[String] {
  self.list.filter_map(fn(pair) {
    if pair.0 == name {
      Some(pair.1)
    } else {
      None
    }
  })
}

///|
/// Returns `true` if any pair has the given `name`.
pub fn UrlSearchParams::has(self : UrlSearchParams, name : String) -> Bool {
  self.list.any(fn(pair) { pair.0 == name })
}

///|
/// Returns `true` if any pair matches both `name` and `value` exactly.
pub fn UrlSearchParams::has_entry(
  self : UrlSearchParams,
  name : String,
  value : String,
) -> Bool {
  self.list.any(fn(pair) { pair.0 == name && pair.1 == value })
}

///|
/// Sets the first pair with `name` to `value`, removing all other pairs with
/// the same name; appends a new pair if none exists.
pub fn UrlSearchParams::set(
  self : UrlSearchParams,
  name : String,
  value : String,
) -> Unit {
  let mut found = false
  let new_list : Array[(String, String)] = []
  for pair in self.list {
    if pair.0 == name {
      if !found {
        new_list.push((name, value))
        found = true
      }
    } else {
      new_list.push(pair)
    }
  }
  if !found {
    new_list.push((name, value))
  }
  self.list = new_list
}

///|
/// Sorts pairs in place by name using UTF-16 code-unit order (stable sort).
///
/// ### Example
///
/// ```mbt check
/// test {
///   let sp = @url.UrlSearchParams::from_string("b=2&a=1")
///   sp.sort()
///   inspect(sp.to_string(), content="a=1&b=2")
/// }
/// ```
pub fn UrlSearchParams::sort(self : UrlSearchParams) -> Unit {
  let keyed = self.list.map(fn(pair) { (string_to_utf16_units(pair.0), pair) })
  keyed.sort_by(fn(a, b) { compare_utf16_units(a.0, b.0) })
  self.list = keyed.map(fn(x) { x.1 })
}

///|
/// Returns the number of name/value pairs.
pub fn UrlSearchParams::size(self : UrlSearchParams) -> Int32 {
  self.list.length()
}

///|
/// Serializes pairs to an `application/x-www-form-urlencoded` string.
///
/// ### Example
///
/// ```mbt check
/// test {
///   let sp = @url.UrlSearchParams::from_string("a=hello world&b=ok")
///   inspect(sp.to_string(), content="a=hello+world&b=ok")
/// }
/// ```
pub fn UrlSearchParams::to_string(self : UrlSearchParams) -> String {
  let buf = StringBuilder()
  let mut first = true
  for pair in self.list {
    if !first {
      buf.write_char('&')
    }
    first = false
    buf.write_string(url_form_encode(pair.0))
    buf.write_char('=')
    buf.write_string(url_form_encode(pair.1))
  }
  buf.to_string()
}

///|
pub impl Show for UrlSearchParams with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
pub extend UrlSearchParams with Show::{output}

///|
/// Returns an iterator over name/value pairs in list order.
pub fn UrlSearchParams::iter(self : UrlSearchParams) -> Iter[(String, String)] {
  self.list.iter()
}

///|
/// Returns an iterator over name/value pairs in list order.
/// Equivalent to `iter()`; provided as the WHATWG `URLSearchParams.entries()` alias.
///
/// ### Example
///
/// ```mbt check
/// test {
///   let sp = @url.UrlSearchParams::from_string("a=1&b=2")
///   let pairs : Array[(String, String)] = []
///   for pair in sp.entries() {
///     pairs.push(pair)
///   }
///   inspect(pairs == [("a", "1"), ("b", "2")], content="true")
/// }
/// ```
pub fn UrlSearchParams::entries(
  self : UrlSearchParams,
) -> Iter[(String, String)] {
  self.list.iter()
}

///|
/// Returns an iterator over names (keys) in list order.
///
/// ### Example
///
/// ```mbt check
/// test {
///   let sp = @url.UrlSearchParams::from_string("a=1&b=2&a=3")
///   let names : Array[String] = []
///   for k in sp.keys() {
///     names.push(k)
///   }
///   inspect(names == ["a", "b", "a"], content="true")
/// }
/// ```
pub fn UrlSearchParams::keys(self : UrlSearchParams) -> Iter[String] {
  self.list.iter().map(fn(pair) { pair.0 })
}

///|
/// Returns an iterator over values in list order.
///
/// ### Example
///
/// ```mbt check
/// test {
///   let sp = @url.UrlSearchParams::from_string("a=1&b=2&c=3")
///   let vals : Array[String] = []
///   for v in sp.values() {
///     vals.push(v)
///   }
///   inspect(vals == ["1", "2", "3"], content="true")
/// }
/// ```
pub fn UrlSearchParams::values(self : UrlSearchParams) -> Iter[String] {
  self.list.iter().map(fn(pair) { pair.1 })
}

///|
/// Calls `f` with each name/value pair in list order.
pub fn UrlSearchParams::for_each(
  self : UrlSearchParams,
  f : (String, String) -> Unit,
) -> Unit {
  for pair in self.list {
    f(pair.0, pair.1)
  }
}

///|
fn url_form_decode(s : String) -> String {
  let chars : Array[Char] = []
  for c in s {
    chars.push(c)
  }
  let n = chars.length()
  let bytes : Array[Int32] = []
  let mut i = 0
  while i < n {
    let c = chars[i]
    if c == '+' {
      bytes.push(0x20)
      i = i + 1
    } else if c == '%' && i + 2 < n {
      match
        (@pe.hex_digit_value(chars[i + 1]), @pe.hex_digit_value(chars[i + 2])) {
        (Some(hi), Some(lo)) => {
          bytes.push(hi * 16 + lo)
          i = i + 3
        }
        _ => {
          for byte in @pe.char_to_utf8_bytes(c) {
            bytes.push(byte)
          }
          i = i + 1
        }
      }
    } else {
      for byte in @pe.char_to_utf8_bytes(c) {
        bytes.push(byte)
      }
      i = i + 1
    }
  }
  @pe.utf8_bytes_to_string(bytes)
}

///|
fn url_form_encode(s : String) -> String {
  let buf = StringBuilder()
  for c in s {
    let cp = c.to_int()
    if cp == 0x20 {
      buf.write_char('+')
    } else if is_url_form_safe(cp) {
      buf.write_char(c)
    } else {
      for byte in @pe.char_to_utf8_bytes(c) {
        buf.write_string(@pe.percent_encode_byte(byte))
      }
    }
  }
  buf.to_string()
}

///|
fn is_url_form_safe(cp : Int32) -> Bool {
  (cp >= 0x30 && cp <= 0x39) ||
  (cp >= 0x41 && cp <= 0x5A) ||
  (cp >= 0x61 && cp <= 0x7A) ||
  cp == 0x2A ||
  cp == 0x2D ||
  cp == 0x2E ||
  cp == 0x5F
}

///|
fn char_to_utf16(c : Char) -> Array[Int32] {
  let cp = c.to_int()
  if cp <= utf16_bmp_max {
    [cp]
  } else {
    let adj = cp - utf16_supplementary_offset
    let high = utf16_high_surrogate_base + (adj >> 10)
    let low = utf16_low_surrogate_base + (adj & utf16_surrogate_mask)
    [high, low]
  }
}

///|
fn string_to_utf16_units(s : String) -> Array[Int32] {
  let result : Array[Int32] = []
  for c in s {
    for unit in char_to_utf16(c) {
      result.push(unit)
    }
  }
  result
}

///|
fn compare_utf16_units(ua : Array[Int32], ub : Array[Int32]) -> Int32 {
  let la = ua.length()
  let lb = ub.length()
  let min_len = if la < lb { la } else { lb }
  for i in 0..<min_len {
    let diff = ua[i] - ub[i]
    if diff != 0 {
      return diff
    }
  }
  la - lb
}
