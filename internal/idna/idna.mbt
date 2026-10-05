///|
let replacement_char : Int = 0xFFFD

///|
let nonchar_low_start : Int = 0xFDD0

///|
let nonchar_low_end : Int = 0xFDEF

///|
let nonchar_plane_sentinel_lower : Int = 0xFFFE

///|
let nonchar_plane_sentinel_upper : Int = 0xFFFF

///|
let no_break_space : Int = 0x00A0

///|
let ideographic_space : Int = 0x3000

///|
let surrogate_start : Int = 0xD800

///|
let surrogate_end : Int = 0xDFFF

///|
pub suberror IdnaParseError {
  IdnaParseError(String)
}

///|
fn is_virama(cp : Int) -> Bool {
  cp == 0x094D ||
  cp == 0x09CD ||
  cp == 0x0A4D ||
  cp == 0x0ACD ||
  cp == 0x0B4D ||
  cp == 0x0BCD ||
  cp == 0x0C4D ||
  cp == 0x0CCD ||
  cp == 0x0D3B ||
  cp == 0x0D3C ||
  cp == 0x0D4D ||
  cp == 0x0DCA ||
  cp == 0x0E3A ||
  cp == 0x0F84 ||
  cp == 0x1039 ||
  cp == 0x103A ||
  cp == 0x1714 ||
  cp == 0x1734 ||
  cp == 0x17D2 ||
  cp == 0x1A60 ||
  cp == 0x1BAA ||
  cp == 0x1BAB ||
  cp == 0x2D7F ||
  cp == 0xA806 ||
  cp == 0xA8C4 ||
  cp == 0xA953 ||
  cp == 0xA9C0 ||
  cp == 0xAAF6 ||
  cp == 0xABED ||
  cp == 0x10A3F ||
  cp == 0x11134 ||
  cp == 0x111C0 ||
  cp == 0x11235 ||
  cp == 0x112EA ||
  cp == 0x1134D ||
  cp == 0x11442 ||
  cp == 0x114C2 ||
  cp == 0x115BF ||
  cp == 0x1163F ||
  cp == 0x116B6 ||
  cp == 0x11C3F
}

///|
fn is_arabic_script(cp : Int) -> Bool {
  cp >= 0x0600 && cp <= 0x06FF
}

///|
fn is_arabic_right_joining(cp : Int) -> Bool {
  cp == 0x0622 ||
  cp == 0x0623 ||
  cp == 0x0624 ||
  cp == 0x0625 ||
  cp == 0x0627 ||
  cp == 0x0629 ||
  cp == 0x062F ||
  cp == 0x0630 ||
  cp == 0x0631 ||
  cp == 0x0632 ||
  cp == 0x0648 ||
  cp == 0x0671 ||
  cp == 0x0672 ||
  cp == 0x0673 ||
  cp == 0x0675 ||
  cp == 0x0676 ||
  cp == 0x0677 ||
  (cp >= 0x0688 && cp <= 0x0699) ||
  (cp >= 0x06C4 && cp <= 0x06CF) ||
  cp == 0x06D2 ||
  cp == 0x06D3 ||
  cp == 0x06EE ||
  cp == 0x06EF
}

///|
fn is_arabic_nonjoining(cp : Int) -> Bool {
  (cp >= 0x0610 && cp <= 0x061A) ||
  (cp >= 0x064B && cp <= 0x065F) ||
  cp == 0x0670 ||
  (cp >= 0x0660 && cp <= 0x0669) ||
  (cp >= 0x06F0 && cp <= 0x06F9) ||
  (cp >= 0x06D6 && cp <= 0x06DC) ||
  (cp >= 0x06DF && cp <= 0x06E4) ||
  cp == 0x06E7 ||
  cp == 0x06E8 ||
  (cp >= 0x06EA && cp <= 0x06ED)
}

///|
fn validate_contextj(cps : Array[Int]) -> Unit raise IdnaParseError {
  for idx, cp in cps {
    if cp == 0x200D {
      if idx == 0 || !is_virama(cps[idx - 1]) {
        raise IdnaParseError("ZWJ requires preceding virama")
      }
    } else if cp == 0x200C {
      let allowed = if idx == 0 {
        false
      } else {
        let prev = cps[idx - 1]
        if is_virama(prev) {
          true
        } else {
          let mut back_idx = idx - 1
          while back_idx > 0 && is_arabic_nonjoining(cps[back_idx]) {
            back_idx = back_idx - 1
          }
          let back_cp = cps[back_idx]
          let prev_ok = is_arabic_script(back_cp) &&
            !is_arabic_right_joining(back_cp) &&
            !is_arabic_nonjoining(back_cp)
          if !prev_ok {
            false
          } else {
            let mut fwd_idx = idx + 1
            while fwd_idx < cps.length() && is_arabic_nonjoining(cps[fwd_idx]) {
              fwd_idx = fwd_idx + 1
            }
            fwd_idx < cps.length() &&
            is_arabic_script(cps[fwd_idx]) &&
            !is_arabic_nonjoining(cps[fwd_idx])
          }
        }
      }
      if !allowed {
        raise IdnaParseError("ZWNJ requires virama or joining context")
      }
    }
  }
}

///|
fn validate_bidi(cps : Array[Int]) -> Unit raise IdnaParseError {
  let mut has_rtl = false
  let mut has_ltr = false
  for cp in cps {
    if is_combining_mark_table(cp) {
      continue
    }
    if (cp >= 0x0590 && cp <= 0x05FF) || (cp >= 0x0700 && cp <= 0x074F) {
      has_rtl = true
    } else if is_arabic_script(cp) && !is_arabic_nonjoining(cp) {
      has_rtl = true
    } else if (cp >= 0x41 && cp <= 0x5A) ||
      (cp >= 0x61 && cp <= 0x7A) ||
      (cp >= 0x0370 && cp <= 0x03FF) ||
      (cp >= 0x0400 && cp <= 0x04FF) ||
      (cp >= 0x10A0 && cp <= 0x10FF) ||
      (cp >= 0x2D00 && cp <= 0x2D2F) ||
      (cp >= 0x3040 && cp <= 0x9FFF) ||
      (cp >= 0xAC00 && cp <= 0xD7A3) {
      has_ltr = true
    }
  }
  if has_rtl && has_ltr {
    raise IdnaParseError("BIDI violation: label mixes RTL and LTR scripts")
  }
}

///|
fn hangul_compose(l : Int, v : Int) -> Int {
  let s_base = 0xAC00
  let l_base = 0x1100
  let v_base = 0x1161
  let t_count = 28
  let n_count = 21 * t_count
  s_base + (l - l_base) * n_count + (v - v_base) * t_count
}

///|
fn try_nfc_compose(a : Int, b : Int) -> Int {
  if a >= 0x1100 && a <= 0x1112 && b >= 0x1161 && b <= 0x1175 {
    return hangul_compose(a, b)
  }
  if a >= 0xAC00 &&
    a <= 0xD7A3 &&
    (a - 0xAC00) % 28 == 0 &&
    b >= 0x11A8 &&
    b <= 0x11C2 {
    return a + (b - 0x11A7)
  }
  if b == 0x0300 {
    if a == 0x0041 {
      return 0x00C0
    }
    if a == 0x0061 {
      return 0x00E0
    }
    if a == 0x006F {
      return 0x00F2
    }
  }
  if b == 0x0308 {
    if a == 0x0041 {
      return 0x00C4
    }
    if a == 0x0061 {
      return 0x00E4
    }
    if a == 0x004F {
      return 0x00D6
    }
    if a == 0x006F {
      return 0x00F6
    }
    if a == 0x0055 {
      return 0x00DC
    }
    if a == 0x0075 {
      return 0x00FC
    }
  }
  if b == 0x0302 {
    if a == 0x0053 {
      return 0x015C
    }
    if a == 0x0073 {
      return 0x015D
    }
  }
  if b == 0x0307 {
    if a == 0x0059 {
      return 0x1E8E
    }
    if a == 0x0079 {
      return 0x1E8F
    }
  }
  if b == 0x0301 {
    if a == 0x039F {
      return 0x038C
    }
    if a == 0x03BF {
      return 0x03CC
    }
    if a == 0x006F {
      return 0x00F3
    }
    if a == 0x006B {
      return 0x1E31
    }
  }
  if a == 0x0648 && b == 0x0654 {
    return 0x0624
  }
  if a == 0x003D && b == 0x0338 {
    return 0x2260
  }
  if a == 0x003C && b == 0x0338 {
    return 0x226E
  }
  if a == 0x003E && b == 0x0338 {
    return 0x226F
  }
  -1
}

///|
fn nfc_compose(cps : Array[Int]) -> Array[Int] {
  if cps.length() <= 1 {
    return cps
  }
  let result : Array[Int] = []
  let mut i = 0
  while i < cps.length() {
    let mut cur = cps[i]
    let mut j = i + 1
    while j < cps.length() {
      let composed = try_nfc_compose(cur, cps[j])
      if composed >= 0 {
        cur = composed
        j = j + 1
      } else {
        break
      }
    }
    result.push(cur)
    i = j
  }
  result
}

///|
fn is_idna_forbidden_cp(cp : Int) -> Bool {
  cp == replacement_char ||
  (cp >= nonchar_low_start && cp <= nonchar_low_end) ||
  (cp & 0xFFFF) == nonchar_plane_sentinel_lower ||
  (cp & 0xFFFF) == nonchar_plane_sentinel_upper ||
  cp == no_break_space ||
  cp == ideographic_space ||
  cp == 0x1680 ||
  (cp >= 0x80 && cp <= 0x9F) ||
  (cp >= surrogate_start && cp <= surrogate_end) ||
  (cp >= 0x202A && cp <= 0x202E) ||
  (cp >= 0x2066 && cp <= 0x2069) ||
  cp == 0x06DD ||
  (cp >= 0xFFFA && cp <= 0xFFFC) ||
  (cp >= 0x2FF0 && cp <= 0x2FFB) ||
  (cp >= 0xE0000 && cp <= 0xE00FF) ||
  (cp >= 0xE01F0 && cp <= 0xE0FFF) ||
  (cp >= 0x2488 && cp <= 0x249B) ||
  (cp >= 0x10A0 && cp <= 0x10C5) ||
  cp == 0x1160 ||
  cp == 0x3164 ||
  cp == 0x3002 ||
  cp == 0xFF61 ||
  cp == 0xFE12 ||
  cp == 0xFE52 ||
  (cp >= 0x40000 && cp <= 0xDFFFF) ||
  (cp >= 0xE1000 && cp <= 0xEFFFF) ||
  (cp >= 0xE000 && cp <= 0xF8FF) ||
  cp >= 0xF0000 ||
  cp == 0x2025 ||
  cp == 0x2A74 ||
  cp == 0x05BE ||
  cp == 0x0378
}

///|
pub fn domain_to_ascii(domain : String) -> String raise IdnaParseError {
  if domain.is_empty() {
    raise IdnaParseError("empty domain")
  }
  let buf = StringBuilder()
  for c in domain {
    let cp = c.to_int()
    let st = idna_status_code(cp)
    if st == 1 {
      continue
    }
    if st == 4 {
      raise IdnaParseError("domain has IDNA-disallowed code point")
    }
    if st == 2 || st == 6 {
      match idna_mapping_lookup(cp) {
        Some(targets) =>
          for t in targets {
            buf.write_char(Int::unsafe_to_char(t))
          }
        None => panic()
      }
      continue
    }
    buf.write_char(Int::unsafe_to_char(cp))
  }
  let mapped = buf.to_string()
  if mapped.is_empty() {
    raise IdnaParseError("empty domain")
  }
  let labels = @pe.split_on_char(mapped, '.')
  let domain_is_ascii = mapped.iter().all(fn(c) { c.to_int() <= 0x7F })
  let out = StringBuilder()
  for i, label in labels {
    if i > 0 {
      out.write_char('.')
    }
    if label.is_empty() {
      continue
    }
    let mut has_non_ascii = false
    for c in label {
      if c.to_int() > 0x7F {
        has_non_ascii = true
        break
      }
    }
    if has_non_ascii {
      let cps : Array[Int] = []
      for c in label {
        cps.push(c.to_int())
      }
      let cps = nfc_compose(cps)
      if label.has_prefix("xn--") {
        raise IdnaParseError("invalid ACE label: non-ASCII in xn-- label")
      }
      if cps.length() > 0 && is_combining_mark_table(cps[0]) {
        raise IdnaParseError("label starts with combining mark (V6)")
      }
      for cp in cps {
        if is_idna_forbidden_cp(cp) {
          raise IdnaParseError("domain has IDNA-forbidden code point")
        }
      }
      validate_contextj(cps)
      validate_bidi(cps)
      let encoded = punycode_encode(cps)
      out.write_string("xn--")
      out.write_string(encoded)
    } else {
      if label.has_prefix("xn--") && !domain_is_ascii {
        let suffix = label[4:].to_owned()
        if suffix.is_empty() {
          raise IdnaParseError("invalid ACE label: empty xn-- extension")
        }
        let decoded = punycode_decode(suffix)
        if decoded.length() == 0 {
          raise IdnaParseError("decoded ACE label is empty (P4)")
        }
        if !decoded.any(fn(cp) { cp > 0x7F }) {
          raise IdnaParseError("decoded ACE label contains no non-ASCII (P4)")
        }
        let nfc_decoded = nfc_compose(decoded)
        if nfc_decoded.length() != decoded.length() {
          raise IdnaParseError("decoded ACE label is not in NFC form (V2)")
        }
        if decoded.length() >= 4 &&
          decoded[0] == 'x' &&
          decoded[1] == 'n' &&
          decoded[2] == '-' &&
          decoded[3] == '-' {
          raise IdnaParseError("decoded ACE label starts with xn-- (V4)")
        }
        if decoded.length() > 0 && is_combining_mark_table(decoded[0]) {
          raise IdnaParseError(
            "decoded ACE label starts with combining mark (V6)",
          )
        }
        for cp in decoded {
          if is_idna_forbidden_cp(cp) {
            raise IdnaParseError("decoded ACE label has forbidden code point")
          }
          let st = idna_status_code(cp)
          if st != 0 && st != 3 && st != 5 {
            raise IdnaParseError(
              "decoded ACE label has IDNA-disallowed code point (V7)",
            )
          }
        }
        validate_contextj(decoded)
        validate_bidi(decoded)
      }
      out.write_string(label)
    }
  }
  let result = out.to_string()
  if result.is_empty() {
    raise IdnaParseError("empty domain")
  }
  result
}

///|
pub fn domain_to_unicode(domain : String) -> String raise IdnaParseError {
  let ascii = domain_to_ascii(domain)
  let labels = @pe.split_on_char(ascii, '.')
  let out = StringBuilder()
  for i, label in labels {
    if i > 0 {
      out.write_char('.')
    }
    if label.has_prefix("xn--") {
      let suffix = label[4:].to_owned()
      let cps = punycode_decode(suffix)
      for cp in cps {
        out.write_char(Int::unsafe_to_char(cp))
      }
    } else {
      out.write_string(label)
    }
  }
  let result = out.to_string()
  if result.is_empty() {
    raise IdnaParseError("empty domain")
  }
  result
}
