///|
priv enum CspState {
  CspInit
  CspProtocol
  CspAuthority
  CspUsername
  CspPassword
  CspHostname
  CspPort
  CspPathname
  CspSearch
  CspHash
  CspDone
} derive(Eq)

///|
priv struct Csp {
  input_chars : Array[Char]
  token_list : Array[Token]
  mut protocol : String?
  mut username : String?
  mut password : String?
  mut hostname : String?
  mut port : String?
  mut pathname : String?
  mut search : String?
  mut hash : String?
  mut component_start : Int32
  mut token_index : Int32
  mut token_increment : Int32
  mut group_depth : Int32
  mut hostname_ipv6_bracket_depth : Int32
  mut protocol_matches_special : Bool
  mut state : CspState
}

///|
fn Csp::new(input_chars : Array[Char], token_list : Array[Token]) -> Csp {
  {
    input_chars,
    token_list,
    protocol: None,
    username: None,
    password: None,
    hostname: None,
    port: None,
    pathname: None,
    search: None,
    hash: None,
    component_start: 0,
    token_index: 0,
    token_increment: 1,
    group_depth: 0,
    hostname_ipv6_bracket_depth: 0,
    protocol_matches_special: false,
    state: CspInit,
  }
}

///|
fn Csp::get_safe_token(self : Csp, index : Int32) -> Token {
  if index < self.token_list.length() {
    self.token_list[index]
  } else {
    self.token_list[self.token_list.length() - 1]
  }
}

///|
fn str_first_char_eq(s : String, c : Char) -> Bool {
  s.get_char(0) == Some(c)
}

///|
fn Csp::is_non_special_pattern_char(
  self : Csp,
  index : Int32,
  expected : Char,
) -> Bool {
  let token = self.get_safe_token(index)
  if token.value.length() == 0 || !str_first_char_eq(token.value, expected) {
    return false
  }
  match token.kind {
    Char | EscapedChar | InvalidChar => true
    _ => false
  }
}

///|
fn Csp::is_hash_prefix(self : Csp) -> Bool {
  self.is_non_special_pattern_char(self.token_index, '#')
}

///|
fn Csp::is_search_prefix(self : Csp) -> Bool {
  if self.is_non_special_pattern_char(self.token_index, '?') {
    return true
  }
  let tok = self.token_list[self.token_index]
  if tok.value != "?" {
    return false
  }
  if self.token_index == 0 {
    return true
  }
  let prev = self.get_safe_token(self.token_index - 1)
  match prev.kind {
    Name | Regexp | Close | Asterisk => false
    _ => true
  }
}

///|
fn Csp::is_protocol_suffix(self : Csp) -> Bool {
  self.is_non_special_pattern_char(self.token_index, ':')
}

///|
fn Csp::next_is_authority_slashes(self : Csp) -> Bool {
  self.is_non_special_pattern_char(self.token_index + 1, '/') &&
  self.is_non_special_pattern_char(self.token_index + 2, '/')
}

///|
fn Csp::is_group_open(self : Csp) -> Bool {
  self.token_list[self.token_index].kind == Open
}

///|
fn Csp::is_group_close(self : Csp) -> Bool {
  self.token_list[self.token_index].kind == Close
}

///|
fn Csp::is_an_identity_terminator(self : Csp) -> Bool {
  self.is_non_special_pattern_char(self.token_index, '@')
}

///|
fn Csp::is_pathname_start(self : Csp) -> Bool {
  self.is_non_special_pattern_char(self.token_index, '/')
}

///|
fn Csp::is_password_prefix(self : Csp) -> Bool {
  self.is_non_special_pattern_char(self.token_index, ':')
}

///|
fn Csp::is_an_ipv6_open(self : Csp) -> Bool {
  self.is_non_special_pattern_char(self.token_index, '[')
}

///|
fn Csp::is_an_ipv6_close(self : Csp) -> Bool {
  self.is_non_special_pattern_char(self.token_index, ']')
}

///|
fn Csp::is_port_prefix(self : Csp) -> Bool {
  self.is_non_special_pattern_char(self.token_index, ':')
}

///|
fn Csp::make_component_string(self : Csp) -> String {
  let end_char_index = self.token_list[self.token_index].index
  let start_char_index = self.get_safe_token(self.component_start).index
  let buf = StringBuilder()
  for c in self.input_chars[start_char_index:end_char_index] {
    buf.write_char(c)
  }
  buf.to_string()
}

///|
fn Csp::rewind(self : Csp) -> Unit {
  self.token_index = self.component_start
  self.token_increment = 0
}

///|
fn Csp::compute_protocol_matches_special(
  self : Csp,
) -> Unit raise UrlPatternError {
  let proto_str = self.make_component_string()
  let proto_component = compile_component(
    proto_str,
    default_options,
    Strict,
    Protocol,
  )
  let regex = proto_component.regex
  if regex.execute("http") is Some(_) ||
    regex.execute("https") is Some(_) ||
    regex.execute("ftp") is Some(_) ||
    regex.execute("ws") is Some(_) ||
    regex.execute("wss") is Some(_) ||
    regex.execute("file") is Some(_) {
    self.protocol_matches_special = true
  }
}

///|
fn Csp::change_state(self : Csp, new_state : CspState, skip : Int32) -> Unit {
  if self.state != CspInit &&
    self.state != CspAuthority &&
    self.state != CspDone {
    let value = self.make_component_string()
    match self.state {
      CspProtocol => self.protocol = Some(value)
      CspUsername => self.username = Some(value)
      CspPassword => self.password = Some(value)
      CspHostname => self.hostname = Some(value)
      CspPort => self.port = Some(value)
      CspPathname => self.pathname = Some(value)
      CspSearch => self.search = Some(value)
      CspHash => self.hash = Some(value)
      _ => ()
    }
  }
  if self.state != CspInit && new_state != CspDone {
    if (
        self.state == CspProtocol ||
        self.state == CspAuthority ||
        self.state == CspUsername ||
        self.state == CspPassword
      ) &&
      (
        new_state == CspPort ||
        new_state == CspPathname ||
        new_state == CspSearch ||
        new_state == CspHash
      ) &&
      self.hostname is None {
      self.hostname = Some("")
    }
  }
  if (
      self.state == CspProtocol ||
      self.state == CspAuthority ||
      self.state == CspUsername ||
      self.state == CspPassword ||
      self.state == CspHostname ||
      self.state == CspPort
    ) &&
    (new_state == CspSearch || new_state == CspHash) &&
    self.pathname is None {
    self.pathname = if self.protocol_matches_special {
      Some("/")
    } else {
      Some("")
    }
  }
  if (
      self.state == CspProtocol ||
      self.state == CspAuthority ||
      self.state == CspUsername ||
      self.state == CspPassword ||
      self.state == CspHostname ||
      self.state == CspPort ||
      self.state == CspPathname
    ) &&
    new_state == CspHash &&
    self.search is None {
    self.search = Some("")
  }
  self.state = new_state
  self.token_index += skip
  self.component_start = self.token_index
  self.token_increment = 0
}

///|
fn parse_constructor_string(
  input : String,
) -> UrlPatternInit raise UrlPatternError {
  let chars = @pe.string_to_chars(input)
  let tokens = tokenize(input, Lenient)
  let csp = Csp::new(chars, tokens)
  while csp.token_index < csp.token_list.length() {
    csp.token_increment = 1
    if csp.token_list[csp.token_index].kind == End {
      if csp.state == CspInit {
        csp.rewind()
        if csp.is_hash_prefix() {
          csp.change_state(CspHash, 1)
        } else if csp.is_search_prefix() {
          csp.change_state(CspSearch, 1)
        } else {
          csp.change_state(CspPathname, 0)
        }
        csp.token_index += csp.token_increment
        continue
      }
      if csp.state == CspAuthority {
        csp.rewind()
        csp.change_state(CspHostname, 0)
        csp.token_index += csp.token_increment
        continue
      }
      csp.change_state(CspDone, 0)
      break
    }
    if csp.is_group_open() {
      csp.group_depth += 1
      csp.token_index += csp.token_increment
      continue
    }
    if csp.group_depth > 0 {
      if csp.is_group_close() {
        csp.group_depth -= 1
      } else {
        csp.token_index += csp.token_increment
        continue
      }
    }
    match csp.state {
      CspInit =>
        if csp.is_protocol_suffix() {
          csp.rewind()
          csp.change_state(CspProtocol, 0)
        }
      CspProtocol =>
        if csp.is_protocol_suffix() {
          csp.compute_protocol_matches_special()
          let next_state = if csp.next_is_authority_slashes() {
            CspAuthority
          } else if csp.protocol_matches_special {
            CspAuthority
          } else {
            CspPathname
          }
          let skip = if csp.next_is_authority_slashes() { 3 } else { 1 }
          csp.change_state(next_state, skip)
        }
      CspAuthority =>
        if csp.is_an_identity_terminator() {
          csp.rewind()
          csp.change_state(CspUsername, 0)
        } else if csp.is_pathname_start() ||
          csp.is_search_prefix() ||
          csp.is_hash_prefix() {
          csp.rewind()
          csp.change_state(CspHostname, 0)
        }
      CspUsername =>
        if csp.is_password_prefix() {
          csp.change_state(CspPassword, 1)
        } else if csp.is_an_identity_terminator() {
          csp.change_state(CspHostname, 1)
        }
      CspPassword =>
        if csp.is_an_identity_terminator() {
          csp.change_state(CspHostname, 1)
        }
      CspHostname =>
        if csp.is_an_ipv6_open() {
          csp.hostname_ipv6_bracket_depth += 1
        } else if csp.is_an_ipv6_close() {
          csp.hostname_ipv6_bracket_depth -= 1
        } else if csp.is_port_prefix() && csp.hostname_ipv6_bracket_depth == 0 {
          csp.change_state(CspPort, 1)
        } else if csp.is_pathname_start() {
          csp.change_state(CspPathname, 0)
        } else if csp.is_search_prefix() {
          csp.change_state(CspSearch, 1)
        } else if csp.is_hash_prefix() {
          csp.change_state(CspHash, 1)
        }
      CspPort =>
        if csp.is_pathname_start() {
          csp.change_state(CspPathname, 0)
        } else if csp.is_search_prefix() {
          csp.change_state(CspSearch, 1)
        } else if csp.is_hash_prefix() {
          csp.change_state(CspHash, 1)
        }
      CspPathname =>
        if csp.is_search_prefix() {
          csp.change_state(CspSearch, 1)
        } else if csp.is_hash_prefix() {
          csp.change_state(CspHash, 1)
        }
      CspSearch => if csp.is_hash_prefix() { csp.change_state(CspHash, 1) }
      CspHash => ()
      CspDone => ()
    }
    csp.token_index += csp.token_increment
  }
  if csp.hostname is Some(_) && csp.port is None {
    csp.port = Some("")
  }
  {
    protocol: csp.protocol,
    username: csp.username,
    password: csp.password,
    hostname: csp.hostname,
    port: csp.port,
    pathname: csp.pathname,
    search: csp.search,
    hash: csp.hash,
    base_url: None,
  }
}
