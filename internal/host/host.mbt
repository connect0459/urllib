///|
let nonchar_low_start : Int32 = 0xFDD0

///|
let nonchar_low_end : Int32 = 0xFDEF

///|
let no_break_space : Int32 = 0x00A0

///|
let ideographic_space : Int32 = 0x3000

///|
let replacement_char : Int32 = 0xFFFD

///|
let nonchar_plane_sentinel_lower : Int32 = 0xFFFE

///|
let nonchar_plane_sentinel_upper : Int32 = 0xFFFF

///|
pub enum Host {
  Domain(String)
  Ipv4(UInt32)
  Ipv6(Array[UInt32])
  OpaqueHost(String)
} derive(Eq, Debug)

///|
pub extend Host with Eq::{not_equal, equal}

///|
pub extend Host with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub suberror HostParseError {
  HostParseError(String)
}

///|
pub impl Show for HostParseError with fn output(self, logger) {
  match self {
    HostParseError(msg) => logger.write_string("HostParseError: " + msg)
  }
}

///|
pub extend HostParseError with Show::{to_string, output}

///|
pub fn Host::empty_domain() -> Host {
  Domain("")
}

///|
pub fn serialize_host(host : Host) -> String {
  match host {
    Domain(s) => s
    Ipv4(addr) => serialize_ipv4(addr)
    Ipv6(pieces) => "[" + serialize_ipv6(pieces) + "]"
    OpaqueHost(s) => s
  }
}

///|
fn serialize_ipv4(addr : UInt32) -> String {
  let n1 = (addr >> 24) & 0xFFU
  let n2 = (addr >> 16) & 0xFFU
  let n3 = (addr >> 8) & 0xFFU
  let n4 = addr & 0xFFU
  "\{n1}.\{n2}.\{n3}.\{n4}"
}

///|
fn nibble_to_lower_hex(n : Int32) -> Char {
  if n < 10 {
    Int32::unsafe_to_char('0'.to_int() + n)
  } else {
    Int32::unsafe_to_char('a'.to_int() + n - 10)
  }
}

///|
fn uint_to_lower_hex(n : UInt32) -> String {
  if n == 0U {
    return "0"
  }
  let buf = StringBuilder()
  let mut shift = 28
  let mut leading = true
  while shift >= 0 {
    let nibble = (n >> shift).reinterpret_as_int() & 0xF
    if nibble != 0 || !leading {
      buf.write_char(nibble_to_lower_hex(nibble))
      leading = false
    }
    shift = shift - 4
  }
  buf.to_string()
}

///|
fn find_ipv6_compress(pieces : Array[UInt32]) -> Int32? {
  let mut best_start : Int32? = None
  let mut best_len = 1
  let mut cur_start : Int32? = None
  let mut cur_len = 0
  for i, piece in pieces {
    if piece == 0U {
      if cur_start is None {
        cur_start = Some(i)
        cur_len = 1
      } else {
        cur_len = cur_len + 1
      }
      if cur_len > best_len {
        best_len = cur_len
        best_start = cur_start
      }
    } else {
      cur_start = None
      cur_len = 0
    }
  }
  best_start
}

///|
fn serialize_ipv6(pieces : Array[UInt32]) -> String {
  let buf = StringBuilder()
  let compress = find_ipv6_compress(pieces)
  let last = pieces.length() - 1
  let mut ignore0 = false
  for i, piece in pieces {
    if ignore0 && piece == 0U {
      continue
    }
    if ignore0 {
      ignore0 = false
    }
    if compress == Some(i) {
      let sep = if i == 0 { "::" } else { ":" }
      buf.write_string(sep)
      ignore0 = true
      continue
    }
    buf.write_string(uint_to_lower_hex(piece))
    if i != last {
      buf.write_char(':')
    }
  }
  buf.to_string()
}

///|
pub fn parse_host(
  input : String,
  is_special : Bool,
) -> Host raise HostParseError {
  if input.is_empty() {
    if is_special {
      raise HostParseError("empty host for special URL")
    }
    return Host::Domain("")
  }
  if input.has_prefix("[") {
    if !input.has_suffix("]") {
      raise HostParseError("invalid IPv6: missing closing bracket")
    }
    let inner = input[1:input.length() - 1].to_owned()
    let pieces = parse_ipv6(inner)
    return Host::Ipv6(pieces)
  }
  if !is_special {
    return parse_opaque_host(input)
  }
  let domain = @pe.percent_decode(input)
  let ascii_domain = @idna.domain_to_ascii(domain) catch {
    @idna.IdnaParseError(msg) => raise HostParseError(msg)
  }
  if domain_has_forbidden_char(ascii_domain) {
    raise HostParseError("domain has forbidden host code point")
  }
  if ends_in_number(ascii_domain) {
    let addr = parse_ipv4(ascii_domain)
    return Host::Ipv4(addr)
  }
  Host::Domain(ascii_domain)
}

///|
fn parse_opaque_host(input : String) -> Host raise HostParseError {
  for c in input {
    let cp = c.to_int()
    if is_forbidden_host_cp(cp) && cp != '%'.to_int() {
      raise HostParseError("opaque host has forbidden code point")
    }
  }
  Host::OpaqueHost(@pe.percent_encode_c0(input))
}

///|
fn is_forbidden_host_cp(cp : Int32) -> Bool {
  cp == 0x00 ||
  cp == 0x09 ||
  cp == 0x0A ||
  cp == 0x0D ||
  cp == 0x20 ||
  cp == '#'.to_int() ||
  cp == '/'.to_int() ||
  cp == ':'.to_int() ||
  cp == '<'.to_int() ||
  cp == '>'.to_int() ||
  cp == '?'.to_int() ||
  cp == '@'.to_int() ||
  cp == '['.to_int() ||
  cp == '\\'.to_int() ||
  cp == ']'.to_int() ||
  cp == '^'.to_int() ||
  cp == '|'.to_int()
}

///|
fn is_unicode_nonchar(cp : Int32) -> Bool {
  (cp >= nonchar_low_start && cp <= nonchar_low_end) ||
  (cp & 0xFFFF) == nonchar_plane_sentinel_lower ||
  (cp & 0xFFFF) == nonchar_plane_sentinel_upper
}

///|
fn domain_has_forbidden_char(domain : String) -> Bool {
  for c in domain {
    let cp = c.to_int()
    if cp <= 0x1F ||
      cp == 0x7F ||
      is_forbidden_host_cp(cp) ||
      cp == '%'.to_int() ||
      cp == replacement_char ||
      is_unicode_nonchar(cp) ||
      cp == no_break_space ||
      cp == ideographic_space {
      return true
    }
  }
  false
}

///|
fn all_hex_from_str(s : String, from : Int32) -> Bool {
  let n = s.length()
  let mut i = from
  while i < n {
    if @pe.hex_digit_value(s.get_char(i).unwrap_or('\u{0}')) is None {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn strip_trailing_dot(s : String) -> String {
  if s.has_suffix(".") {
    s[0:s.length() - 1].to_owned()
  } else {
    s
  }
}

///|
fn ends_in_number(input : String) -> Bool {
  let effective = strip_trailing_dot(input)
  let last_label = match effective.rev_find(".") {
    Some(pos) => effective[pos + 1:].to_owned()
    None => effective
  }
  if last_label.is_empty() {
    return false
  }
  let n = last_label.length()
  let mut all_decimal = n > 0
  for c in last_label {
    if c < '0' || c > '9' {
      all_decimal = false
      break
    }
  }
  if all_decimal {
    return true
  }
  let c0 = last_label.get_char(0).unwrap_or('\u{0}')
  let c1 = last_label.get_char(1).unwrap_or('\u{0}')
  if n >= 2 && c0 == '0' && (c1 == 'x' || c1 == 'X') {
    return all_hex_from_str(last_label, 2)
  }
  false
}

///|
fn parse_ipv4(input : String) -> UInt32 raise HostParseError {
  let effective = strip_trailing_dot(input)
  let parts = @pe.split_on_char(effective, '.')
  let n_parts = parts.length()
  if n_parts == 0 || n_parts > 4 {
    raise HostParseError("invalid IPv4: bad number of parts")
  }
  let numbers : Array[UInt32] = []
  for part in parts {
    if part.is_empty() {
      raise HostParseError("invalid IPv4: empty part")
    }
    let n = parse_ipv4_number(part)
    numbers.push(n)
  }
  if n_parts == 4 {
    for num in numbers {
      if num > 255U {
        raise HostParseError("invalid IPv4: octet > 255")
      }
    }
    return (numbers[0] << 24) |
      (numbers[1] << 16) |
      (numbers[2] << 8) |
      numbers[3]
  }
  let last = numbers[n_parts - 1]
  let max_last : UInt32 = if n_parts == 1 {
    0xFFFFFFFFU
  } else if n_parts == 2 {
    0xFFFFFFU
  } else {
    0xFFFFU
  }
  if last > max_last {
    raise HostParseError("invalid IPv4: last part too large")
  }
  let mut addr = last
  for i, octet in numbers[0:n_parts - 1] {
    if octet > 255U {
      raise HostParseError("invalid IPv4: octet > 255")
    }
    let shift = (3 - i) * 8
    addr = addr | (octet << shift)
  }
  addr
}

///|
fn parse_ipv4_number(input : String) -> UInt32 raise HostParseError {
  let n = input.length()
  let val : UInt64 = if n >= 2 {
    let c0 = input.get_char(0)
    let c1 = input.get_char(1)
    if c0 == Some('0') && (c1 == Some('x') || c1 == Some('X')) {
      let hex_str = input[2:].to_owned()
      if hex_str.is_empty() {
        0UL
      } else {
        parse_hex_u64(hex_str)
      }
    } else if c0 == Some('0') {
      parse_octal_u64(input[1:].to_owned())
    } else {
      parse_decimal_u64(input)
    }
  } else {
    parse_decimal_u64(input)
  }
  if val >= 0x1_0000_0000UL {
    raise HostParseError("IPv4 number >= 2^32")
  }
  val.to_uint()
}

///|
fn parse_decimal_u64(input : String) -> UInt64 raise HostParseError {
  let mut result = 0UL
  let cap = 0x1_0000_0000UL
  for c in input {
    if c < '0' || c > '9' {
      raise HostParseError("invalid decimal digit")
    }
    let digit = (c.to_int() - '0'.to_int()).to_uint64()
    if result <= cap {
      let next = result * 10UL + digit
      result = if next > cap { cap + 1UL } else { next }
    }
  }
  result
}

///|
fn parse_hex_u64(input : String) -> UInt64 raise HostParseError {
  let mut result = 0UL
  let cap = 0x1_0000_0000UL
  for c in input {
    match @pe.hex_digit_value(c) {
      Some(v) =>
        if result <= cap {
          let next = (result << 4) | v.to_uint64()
          result = if next > cap { cap + 1UL } else { next }
        }
      None => raise HostParseError("invalid hex digit")
    }
  }
  result
}

///|
fn parse_octal_u64(input : String) -> UInt64 raise HostParseError {
  let mut result = 0UL
  let cap = 0x1_0000_0000UL
  for c in input {
    if c < '0' || c > '7' {
      raise HostParseError("invalid octal digit")
    }
    let digit = (c.to_int() - '0'.to_int()).to_uint64()
    if result <= cap {
      let next = result * 8UL + digit
      result = if next > cap { cap + 1UL } else { next }
    }
  }
  result
}

///|
fn parse_ipv6(input : String) -> Array[UInt32] raise HostParseError {
  let pieces : Array[UInt32] = [0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U]
  let mut piece_index = 0
  let mut compress : Int32? = None
  let n = input.length()
  let gc = fn(i : Int32) -> Char { input.get_char(i).unwrap_or('\u{0}') }
  let mut pointer = 0
  if pointer < n && gc(pointer) == ':' {
    if pointer + 1 >= n || gc(pointer + 1) != ':' {
      raise HostParseError("invalid IPv6: single leading colon")
    }
    pointer = pointer + 2
    piece_index = piece_index + 1
    compress = Some(piece_index)
  }
  while pointer < n {
    if piece_index == 8 {
      raise HostParseError("invalid IPv6: too many pieces")
    }
    if gc(pointer) == ':' {
      if compress != None {
        raise HostParseError("invalid IPv6: multiple compressions")
      }
      pointer = pointer + 1
      piece_index = piece_index + 1
      compress = Some(piece_index)
      continue
    }
    let mut value = 0U
    let mut length = 0
    while length < 4 && pointer < n {
      match @pe.hex_digit_value(gc(pointer)) {
        Some(v) => {
          value = (value << 4) | v.reinterpret_as_uint()
          pointer = pointer + 1
          length = length + 1
        }
        None => break
      }
    }
    if pointer < n && gc(pointer) == '.' {
      if length == 0 {
        raise HostParseError("invalid IPv6: bad IPv4 in IPv6")
      }
      pointer = pointer - length
      if piece_index > 6 {
        raise HostParseError("invalid IPv6: IPv4 part overflows")
      }
      let mut numbers_seen = 0
      while pointer < n {
        if numbers_seen > 0 {
          if gc(pointer) != '.' {
            raise HostParseError("invalid IPv6: expected dot in IPv4")
          }
          pointer = pointer + 1
        }
        if pointer >= n || gc(pointer) < '0' || gc(pointer) > '9' {
          raise HostParseError("invalid IPv6: expected digit in IPv4")
        }
        let mut ipv4_val : UInt32 = 0U
        let mut first_digit = true
        while pointer < n && gc(pointer) >= '0' && gc(pointer) <= '9' {
          let digit = (gc(pointer).to_int() - '0'.to_int()).reinterpret_as_uint()
          if !first_digit && ipv4_val == 0U {
            raise HostParseError("invalid IPv6: leading zero in IPv4")
          }
          let new_val = ipv4_val * 10U + digit
          if new_val > 255U {
            raise HostParseError("invalid IPv6: IPv4 octet > 255")
          }
          ipv4_val = new_val
          first_digit = false
          pointer = pointer + 1
        }
        pieces[piece_index] = pieces[piece_index] * 0x100U + ipv4_val
        numbers_seen = numbers_seen + 1
        if numbers_seen == 2 || numbers_seen == 4 {
          piece_index = piece_index + 1
        }
      }
      if numbers_seen != 4 {
        raise HostParseError("invalid IPv6: IPv4 must have 4 parts")
      }
      break
    }
    pieces[piece_index] = value
    piece_index = piece_index + 1
    if pointer < n {
      if gc(pointer) != ':' {
        raise HostParseError("invalid IPv6: expected colon")
      }
      pointer = pointer + 1
    }
  }
  match compress {
    Some(c) => {
      let mut swaps = piece_index - c
      let mut pi = 7
      while pi != 0 && swaps > 0 {
        let tmp = pieces[pi]
        pieces[pi] = pieces[c + swaps - 1]
        pieces[c + swaps - 1] = tmp
        pi = pi - 1
        swaps = swaps - 1
      }
    }
    None =>
      if piece_index != 8 {
        raise HostParseError("invalid IPv6: too few pieces")
      }
  }
  pieces
}
