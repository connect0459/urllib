///|
priv enum TokenType {
  InvalidChar
  Open
  Close
  Regexp
  Name
  Char
  EscapedChar
  OtherModifier
  Asterisk
  End
} derive(Eq)

///|
priv enum TokenizePolicy {
  Strict
  Lenient
} derive(Eq)

///|
priv struct Token {
  kind : TokenType
  value : String
  index : Int32
}

///|
fn tokenize(
  input : String,
  policy : TokenizePolicy,
) -> Array[Token] raise UrlPatternError {
  let tokens : Array[Token] = []
  let chars = @pe.string_to_chars(input)
  let n = chars.length()
  let mut i = 0
  while i < n {
    let c = chars[i]
    let tok_index = i
    if c == '*' {
      tokens.push({ kind: Asterisk, value: "*", index: tok_index, })
      i += 1
      continue
    }
    if c == '+' || c == '?' {
      tokens.push({
        kind: OtherModifier,
        value: c.to_string(),
        index: tok_index,
      })
      i += 1
      continue
    }
    if c == '\\' {
      if i == n - 1 {
        if policy == Strict {
          raise UrlPatternError("tokenize: trailing backslash")
        }
        i += 1
        continue
      }
      i += 1
      let escaped = chars[i]
      tokens.push({
        kind: EscapedChar,
        value: escaped.to_string(),
        index: tok_index,
      })
      i += 1
      continue
    }
    if c == '{' {
      tokens.push({ kind: Open, value: "{", index: tok_index, })
      i += 1
      continue
    }
    if c == '}' {
      tokens.push({ kind: Close, value: "}", index: tok_index, })
      i += 1
      continue
    }
    if c == ':' {
      i += 1
      let name_start = i
      while i < n && is_name_char(chars[i], i == name_start) {
        i += 1
      }
      if i <= name_start {
        if policy == Strict {
          raise UrlPatternError("tokenize: empty name after ':'")
        }
        tokens.push({ kind: InvalidChar, value: ":", index: tok_index, })
        continue
      }
      let buf = StringBuilder()
      for ch in chars[name_start:i] {
        buf.write_char(ch)
      }
      tokens.push({ kind: Name, value: buf.to_string(), index: tok_index, })
      continue
    }
    if c == '(' {
      let regexp_start = i + 1
      let mut depth = 1
      let mut j = regexp_start
      let mut error = false
      while j < n {
        let rc = chars[j]
        if rc == '(' {
          depth += 1
          if j + 1 >= n || chars[j + 1] != '?' {
            error = true
            break
          }
        } else if rc == ')' {
          depth -= 1
          if depth == 0 {
            j += 1
            break
          }
        } else if rc == '\\' {
          if j == n - 1 {
            error = true
            break
          }
          j += 1
        }
        j += 1
      }
      if error || depth != 0 {
        if policy == Strict {
          raise UrlPatternError("tokenize: unclosed regexp group")
        }
        tokens.push({ kind: InvalidChar, value: "(", index: tok_index, })
        i += 1
        continue
      }
      let buf = StringBuilder()
      for ch in chars[regexp_start:j - 1] {
        buf.write_char(ch)
      }
      tokens.push({ kind: Regexp, value: buf.to_string(), index: tok_index, })
      i = j
      continue
    }
    tokens.push({ kind: Char, value: c.to_string(), index: tok_index, })
    i += 1
  }
  tokens.push({ kind: End, value: "", index: n, })
  tokens
}

///|
fn is_name_char(c : Char, first : Bool) -> Bool {
  if first {
    (c >= 'a' && c <= 'z') ||
    (c >= 'A' && c <= 'Z') ||
    c == '_' ||
    c.to_int() > 0x7F
  } else {
    (c >= 'a' && c <= 'z') ||
    (c >= 'A' && c <= 'Z') ||
    (c >= '0' && c <= '9') ||
    c == '_' ||
    c == '-' ||
    c.to_int() > 0x7F
  }
}
