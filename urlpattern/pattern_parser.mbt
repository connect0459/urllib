///|
let unicode_id_non_ascii_start : Int = 0x80

///|
let unicode_id_bmp_max : Int = 0xD7FF

///|
let unicode_id_supplementary_start : Int = 0x10000

///|
let unicode_id_supplementary_end : Int = 0x1DFFF

///|
let unicode_id_ideograph_start : Int = 0x20000

///|
let unicode_id_ideograph_end : Int = 0x323AF

///|
let unicode_variation_selector_start : Int = 0xE0100

///|
let unicode_variation_selector_end : Int = 0xE01EF

///|
priv enum PartType {
  FixedText
  Regexp
  SegmentWildcard
  FullWildcard
} derive(Eq)

///|
priv enum PartModifier {
  NoMod
  Optional
  ZeroOrMore
  OneOrMore
} derive(Eq)

///|
priv struct Part {
  kind : PartType
  value : String
  modifier : PartModifier
  name : String
  prefix : String
  suffix : String
}

///|
priv struct CompileOptions {
  delimiter : Char?
  prefix_char : Char?
}

///|
let default_options : CompileOptions = { delimiter: None, prefix_char: None, }

///|
let hostname_options : CompileOptions = {
  delimiter: Some('.'),
  prefix_char: None,
}

///|
let pathname_options : CompileOptions = {
  delimiter: Some('/'),
  prefix_char: Some('/'),
}

///|
priv struct ParserCtx {
  tokens : Array[Token]
  mut i : Int
  parts : Array[Part]
  mut pending_fixed : String
  mut pending_escaped : Bool
  mut next_numeric_name : Int
  options : CompileOptions
}

///|
fn ParserCtx::new(tokens : Array[Token], options : CompileOptions) -> ParserCtx {
  {
    tokens,
    i: 0,
    parts: [],
    pending_fixed: "",
    pending_escaped: false,
    next_numeric_name: 0,
    options,
  }
}

///|
fn ParserCtx::peek(self : ParserCtx) -> TokenType {
  if self.i < self.tokens.length() {
    self.tokens[self.i].kind
  } else {
    End
  }
}

///|
fn ParserCtx::try_consume(self : ParserCtx, kind : TokenType) -> Token? {
  if self.i < self.tokens.length() && self.tokens[self.i].kind == kind {
    let t = self.tokens[self.i]
    self.i += 1
    Some(t)
  } else {
    None
  }
}

///|
fn ParserCtx::try_consume_modifier(self : ParserCtx) -> Token? {
  if self.i < self.tokens.length() {
    match self.tokens[self.i].kind {
      OtherModifier | Asterisk => {
        let t = self.tokens[self.i]
        self.i += 1
        Some(t)
      }
      _ => None
    }
  } else {
    None
  }
}

///|
fn ParserCtx::consume_text(self : ParserCtx) -> String {
  let buf = StringBuilder()
  while self.i < self.tokens.length() {
    match self.tokens[self.i].kind {
      Char | EscapedChar => {
        buf.write_string(self.tokens[self.i].value)
        self.i += 1
      }
      _ => break
    }
  }
  buf.to_string()
}

///|
fn ParserCtx::flush_pending(self : ParserCtx) -> Unit {
  let val = self.pending_fixed
  if val.length() > 0 {
    self.parts.push({
      kind: FixedText,
      value: val,
      modifier: NoMod,
      name: "",
      prefix: "",
      suffix: "",
    })
    self.pending_fixed = ""
    self.pending_escaped = false
  }
}

///|
fn ParserCtx::alloc_name(self : ParserCtx) -> String {
  let n = self.next_numeric_name.to_string()
  self.next_numeric_name += 1
  n
}

///|
fn ParserCtx::segment_wildcard_regexp(self : ParserCtx) -> String {
  match self.options.delimiter {
    None => "[^]+?"
    Some(d) => "[^" + escape_regexp_char(d) + "]+?"
  }
}

///|
fn ParserCtx::extract_prefix_from_pending(self : ParserCtx) -> String {
  match self.options.prefix_char {
    None => ""
    Some(pc) => {
      if self.pending_escaped {
        return ""
      }
      let pf = self.pending_fixed
      match str_last_char(pf) {
        Some(last) if last == pc => {
          self.pending_fixed = pf[0:pf.length() - 1].to_owned()
          self.pending_escaped = false
          pc.to_string()
        }
        _ => ""
      }
    }
  }
}

///|
fn modifier_from_token(t : Token?) -> PartModifier {
  match t {
    None => NoMod
    Some({ kind: OtherModifier, value: "?", .. }) => Optional
    Some({ kind: OtherModifier, value: "+", .. }) => OneOrMore
    Some({ kind: Asterisk, .. }) => ZeroOrMore
    _ => NoMod
  }
}

///|
fn is_supplementary_id_char(cp : Int) -> Bool {
  (cp >= unicode_id_supplementary_start && cp <= unicode_id_supplementary_end) ||
  (cp >= unicode_id_ideograph_start && cp <= unicode_id_ideograph_end)
}

///|
fn is_valid_id_start(c : Char) -> Bool {
  let cp = c.to_int()
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  c == '_' ||
  (cp >= unicode_id_non_ascii_start && cp <= unicode_id_bmp_max) ||
  is_supplementary_id_char(cp)
}

///|
fn is_valid_id_continue(c : Char) -> Bool {
  let cp = c.to_int()
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '_' ||
  (cp >= unicode_id_non_ascii_start && cp <= unicode_id_bmp_max) ||
  is_supplementary_id_char(cp) ||
  (
    cp >= unicode_variation_selector_start &&
    cp <= unicode_variation_selector_end
  )
}

///|
fn is_valid_identifier(name : String) -> Bool {
  let it = name.iter()
  match it.next() {
    None => false
    Some(first) => is_valid_id_start(first) && it.all(is_valid_id_continue)
  }
}

///|
fn parse_pattern_to_parts(
  input : String,
  options : CompileOptions,
  policy : TokenizePolicy,
) -> Array[Part] raise UrlPatternError {
  let tokens = tokenize(input, policy)
  let ctx = ParserCtx::new(tokens, options)
  let seen_names : Array[String] = []

  while ctx.i < ctx.tokens.length() {
    match ctx.peek() {
      End => break
      Open => {
        ctx.i += 1
        let prefix_text = ctx.consume_text()
        let name_tok = ctx.try_consume(Name)
        let rw_tok = match ctx.try_consume(Regexp) {
          Some(t) => Some(t)
          None => ctx.try_consume(Asterisk)
        }
        let suffix_text = ctx.consume_text()
        if ctx.try_consume(Close) is None {
          raise UrlPatternError("unclosed group '{' in pattern")
        }
        let mod_tok = ctx.try_consume_modifier()
        ctx.flush_pending()
        let name = match name_tok {
          Some(nt) => {
            if !is_valid_identifier(nt.value) {
              raise UrlPatternError("invalid group name: '\{nt.value}'")
            }
            nt.value
          }
          None =>
            if rw_tok is Some(_) {
              ctx.alloc_name()
            } else {
              let modifier = modifier_from_token(mod_tok)
              if modifier == NoMod {
                ctx.pending_fixed = ctx.pending_fixed +
                  prefix_text +
                  suffix_text
              } else {
                ctx.parts.push({
                  kind: FixedText,
                  value: prefix_text + suffix_text,
                  modifier,
                  name: "",
                  prefix: "",
                  suffix: "",
                })
              }
              continue
            }
        }
        for n in seen_names {
          if n == name {
            raise UrlPatternError("duplicate group name: '\{name}'")
          }
        }
        seen_names.push(name)
        let seg_wc = ctx.segment_wildcard_regexp()
        let (pk, pv) = match rw_tok {
          Some({ kind: Regexp, value: rv, .. }) =>
            if rv == ".*" {
              (FullWildcard, ".*")
            } else if rv == seg_wc {
              (SegmentWildcard, seg_wc)
            } else {
              (PartType::Regexp, rv)
            }
          Some({ kind: Asterisk, .. }) => (FullWildcard, ".*")
          _ => (SegmentWildcard, seg_wc)
        }
        ctx.parts.push({
          kind: pk,
          value: pv,
          modifier: modifier_from_token(mod_tok),
          name,
          prefix: prefix_text,
          suffix: suffix_text,
        })
      }
      Name => {
        let name_tok = ctx.tokens[ctx.i]
        ctx.i += 1
        if !is_valid_identifier(name_tok.value) {
          raise UrlPatternError("invalid group name: '\{name_tok.value}'")
        }
        let prefix = ctx.extract_prefix_from_pending()
        ctx.flush_pending()
        let rw_tok = ctx.try_consume(Regexp)
        let mod_tok = ctx.try_consume_modifier()
        let seg_wc = ctx.segment_wildcard_regexp()
        let (pk, pv) = match rw_tok {
          Some({ kind: Regexp, value: rv, .. }) =>
            if rv == ".*" {
              (FullWildcard, ".*")
            } else if rv == seg_wc {
              (SegmentWildcard, seg_wc)
            } else {
              (PartType::Regexp, rv)
            }
          _ => (SegmentWildcard, seg_wc)
        }
        let name = name_tok.value
        for n in seen_names {
          if n == name {
            raise UrlPatternError("duplicate group name: '\{name}'")
          }
        }
        seen_names.push(name)
        ctx.parts.push({
          kind: pk,
          value: pv,
          modifier: modifier_from_token(mod_tok),
          name,
          prefix,
          suffix: "",
        })
      }
      Regexp => {
        let rw_tok = ctx.tokens[ctx.i]
        ctx.i += 1
        let prefix = ctx.extract_prefix_from_pending()
        ctx.flush_pending()
        let mod_tok = ctx.try_consume_modifier()
        let name = ctx.alloc_name()
        seen_names.push(name)
        let seg_wc = ctx.segment_wildcard_regexp()
        let rv = rw_tok.value
        let (pk, pv) = if rv == ".*" {
          (FullWildcard, ".*")
        } else if rv == seg_wc {
          (SegmentWildcard, seg_wc)
        } else {
          (PartType::Regexp, rv)
        }
        ctx.parts.push({
          kind: pk,
          value: pv,
          modifier: modifier_from_token(mod_tok),
          name,
          prefix,
          suffix: "",
        })
      }
      Asterisk => {
        ctx.i += 1
        let prefix = ctx.extract_prefix_from_pending()
        ctx.flush_pending()
        let mod_tok = ctx.try_consume_modifier()
        let name = ctx.alloc_name()
        seen_names.push(name)
        ctx.parts.push({
          kind: FullWildcard,
          value: ".*",
          modifier: modifier_from_token(mod_tok),
          name,
          prefix,
          suffix: "",
        })
      }
      Char => {
        ctx.pending_fixed = ctx.pending_fixed + ctx.tokens[ctx.i].value
        ctx.pending_escaped = false
        ctx.i += 1
      }
      EscapedChar => {
        ctx.pending_fixed = ctx.pending_fixed + ctx.tokens[ctx.i].value
        ctx.pending_escaped = true
        ctx.i += 1
      }
      OtherModifier =>
        raise UrlPatternError(
          "invalid modifier '\{ctx.tokens[ctx.i].value}' without preceding group",
        )
      _ => ctx.i += 1
    }
  }
  ctx.flush_pending()
  ctx.parts
}

///|
fn str_first_char(s : String) -> Char? {
  s.get_char(0)
}

///|
fn str_last_char(s : String) -> Char? {
  s.get_char(s.length() - 1)
}

///|
fn segment_wildcard_regexp_str(options : CompileOptions) -> String {
  match options.delimiter {
    None => "[^]+?"
    Some(d) => "[^" + escape_regexp_char(d) + "]+?"
  }
}

///|
fn is_empty_fixed_text(part : Part) -> Bool {
  part.kind == FixedText &&
  part.value == "" &&
  part.prefix == "" &&
  part.suffix == ""
}

///|
fn generate_pattern_string(
  parts : Array[Part],
  options : CompileOptions,
) -> String {
  let buf = StringBuilder()
  let seg_wc = segment_wildcard_regexp_str(options)
  for i, part in parts {
    let prev : Part? = if i > 0 { Some(parts[i - 1]) } else { None }
    match part.kind {
      FixedText => {
        // Drop empty-value FixedText with modifier — they are semantic no-ops
        if part.value == "" && part.modifier != NoMod {
          continue
        }
        if part.modifier == NoMod {
          buf.write_string(escape_pattern_string(part.value))
        } else {
          buf.write_string("{")
          buf.write_string(escape_pattern_string(part.value))
          buf.write_string("}")
          buf.write_string(modifier_to_string(part.modifier))
        }
        continue
      }
      _ => ()
    }
    let next_real = parts[i + 1:]
      .iter()
      .find_first(fn(p) { !is_empty_fixed_text(p) })
    let custom_name = match str_first_char(part.name) {
      None => false
      Some(c) => !(c >= '0' && c <= '9')
    }
    let prefix_needs_group = part.prefix.length() > 0 &&
      (match options.prefix_char {
        None => true
        Some(pc) =>
          match str_first_char(part.prefix) {
            None => false
            Some(c) => c != pc
          }
      })
    let mut needs_grouping = part.suffix.length() > 0 || prefix_needs_group
    if !needs_grouping &&
      custom_name &&
      part.kind == SegmentWildcard &&
      part.modifier == NoMod {
      match next_real {
        None => ()
        Some(np) =>
          if np.prefix.length() == 0 && np.suffix.length() == 0 {
            match np.kind {
              FixedText =>
                match str_first_char(np.value) {
                  Some(c) =>
                    if is_valid_id_continue(c) {
                      needs_grouping = true
                    }
                  None => ()
                }
              _ =>
                match str_first_char(np.name) {
                  Some(c) => if c >= '0' && c <= '9' { needs_grouping = true }
                  None => ()
                }
            }
          }
      }
    }
    if !needs_grouping && part.prefix.length() == 0 {
      match prev {
        None => ()
        Some(pp) =>
          if pp.kind == FixedText {
            match (str_last_char(pp.value), options.prefix_char) {
              (Some(lc), Some(pc)) => if lc == pc { needs_grouping = true }
              _ => ()
            }
          }
      }
    }
    let effective_prev = parts[0:i]
      .rev_iter()
      .find_first(fn(p) { !is_empty_fixed_text(p) })
    if needs_grouping {
      buf.write_string("{")
    }
    buf.write_string(escape_pattern_string(part.prefix))
    if custom_name {
      buf.write_char(':')
      buf.write_string(part.name)
    }
    match part.kind {
      Regexp => {
        buf.write_char('(')
        buf.write_string(part.value)
        buf.write_char(')')
      }
      SegmentWildcard =>
        if !custom_name {
          buf.write_char('(')
          buf.write_string(seg_wc)
          buf.write_char(')')
        }
      FullWildcard => {
        let use_star = !custom_name &&
          (
            effective_prev is None ||
            (match effective_prev {
              None => false
              Some(pp) =>
                pp.kind == FixedText || pp.modifier != NoMod || needs_grouping
            }) ||
            part.prefix.length() > 0
          )
        if use_star {
          buf.write_char('*')
        } else {
          buf.write_string("(.*)")
        }
      }
      FixedText => ()
    }
    if part.kind == SegmentWildcard && custom_name {
      match str_first_char(part.suffix) {
        Some(c) => if is_valid_id_continue(c) { buf.write_char('\\') }
        None => ()
      }
    }
    buf.write_string(escape_pattern_string(part.suffix))
    if needs_grouping {
      buf.write_string("}")
    }
    buf.write_string(modifier_to_string(part.modifier))
  }
  buf.to_string()
}

///|
fn generate_regexp(
  parts : Array[Part],
  options : CompileOptions,
) -> (String, Array[String], Array[(String, String)]) {
  let buf = StringBuilder()
  let names : Array[String] = []
  let strips : Array[(String, String)] = []
  buf.write_string("^")
  for part in parts {
    match part.kind {
      FixedText =>
        if part.modifier == NoMod {
          buf.write_string(escape_regexp_string(part.value))
        } else {
          buf.write_string("(?:")
          buf.write_string(escape_regexp_string(part.value))
          buf.write_string(")")
          buf.write_string(modifier_to_string(part.modifier))
        }
      _ => {
        names.push(part.name)
        let regexp_value = match part.kind {
          SegmentWildcard =>
            match options.delimiter {
              None => "[^]+?"
              Some(d) => "[^" + escape_regexp_char(d) + "]+?"
            }
          FullWildcard => ".*"
          Regexp => part.value
          FixedText => ""
        }
        let esc_prefix = escape_regexp_string(part.prefix)
        let esc_suffix = escape_regexp_string(part.suffix)
        if part.prefix.length() == 0 && part.suffix.length() == 0 {
          strips.push(("", ""))
          if part.modifier == NoMod || part.modifier == Optional {
            let emit_value = if part.modifier == Optional &&
              part.kind == FullWildcard {
              ".+"
            } else {
              regexp_value
            }
            buf.write_string("(")
            buf.write_string(emit_value)
            buf.write_string(")")
            buf.write_string(modifier_to_string(part.modifier))
          } else {
            buf.write_string("((?:")
            buf.write_string(regexp_value)
            buf.write_string(")")
            buf.write_string(modifier_to_string(part.modifier))
            buf.write_string(")")
          }
        } else if part.modifier == Optional {
          strips.push((part.prefix, part.suffix))
          buf.write_string("(")
          buf.write_string(esc_prefix)
          buf.write_string(regexp_value)
          buf.write_string(esc_suffix)
          buf.write_string(")?")
        } else if part.modifier == NoMod {
          strips.push(("", ""))
          buf.write_string("(?:")
          buf.write_string(esc_prefix)
          buf.write_string("(")
          buf.write_string(regexp_value)
          buf.write_string(")")
          buf.write_string(esc_suffix)
          buf.write_string(")")
        } else {
          strips.push(("", ""))
          buf.write_string("(?:")
          buf.write_string(esc_prefix)
          buf.write_string("((?:")
          buf.write_string(regexp_value)
          buf.write_string(")(?:")
          buf.write_string(esc_suffix)
          buf.write_string(esc_prefix)
          buf.write_string("(?:")
          buf.write_string(regexp_value)
          buf.write_string("))*)")
          buf.write_string(esc_suffix)
          buf.write_string(")")
          if part.modifier == ZeroOrMore {
            buf.write_string("?")
          }
        }
      }
    }
  }
  buf.write_string("$")
  (buf.to_string(), names, strips)
}

///|
fn modifier_to_string(m : PartModifier) -> String {
  match m {
    NoMod => ""
    Optional => "?"
    ZeroOrMore => "*"
    OneOrMore => "+"
  }
}

///|
fn escape_regexp_string(s : String) -> String {
  let buf = StringBuilder()
  for c in s {
    if needs_regexp_escape(c) {
      buf.write_string("\\")
    }
    buf.write_char(c)
  }
  buf.to_string()
}

///|
fn escape_regexp_char(c : Char) -> String {
  if needs_regexp_escape(c) {
    "\\" + c.to_string()
  } else {
    c.to_string()
  }
}

///|
fn needs_regexp_escape(c : Char) -> Bool {
  match c {
    '.'
    | '+'
    | '*'
    | '?'
    | '^'
    | '$'
    | '{'
    | '}'
    | '('
    | ')'
    | '['
    | ']'
    | '|'
    | '\\'
    | '/' => true
    _ => false
  }
}

///|
fn escape_pattern_string(s : String) -> String {
  let buf = StringBuilder()
  for c in s {
    match c {
      '+' | '*' | '?' | ':' | '{' | '}' | '(' | ')' | '\\' => {
        buf.write_string("\\")
        buf.write_char(c)
      }
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}
