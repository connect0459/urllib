///|
fn strip_tab_newline(s : String) -> String {
  let mut needs_strip = false
  for c in s {
    if c == '\t' || c == '\n' || c == '\r' {
      needs_strip = true
      break
    }
  }
  if !needs_strip {
    return s
  }
  let buf = StringBuilder()
  for c in s {
    if c != '\t' && c != '\n' && c != '\r' {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
fn apply_path_seg(
  segs : Array[String],
  seg : String,
  scheme : String,
  is_terminal : Bool,
) -> Unit {
  if is_dot_segment(seg) {
    shorten_path_segs(segs, scheme)
    if is_terminal {
      segs.push("")
    }
  } else if is_single_dot(seg) {
    if is_terminal {
      segs.push("")
    }
  } else {
    push_normalized_segment(segs, seg, scheme)
  }
}

///|
fn shorten_path_segs(segs : Array[String], scheme : String) -> Unit {
  if scheme == "file" && segs.length() == 1 && is_windows_drive_letter(segs[0]) {
    return
  }
  if segs.length() > 0 {
    let _ = segs.pop()
  }
}

///|
fn safe_parse_host(input : String, is_special : Bool) -> Host? {
  Some(@host.parse_host(input, is_special)) catch {
    _ => None
  }
}

///|
fn Url::can_have_credentials(self : Url) -> Bool {
  match self.host {
    None | Some(Host::Domain("")) => false
    _ => self.scheme != "file" && !self.has_opaque_path()
  }
}

///|
priv enum SetterPort {
  Unchanged
  Changed(Int32?)
}

///|
fn parse_setter_port(s : String, scheme : String) -> SetterPort {
  let mut val = 0
  let mut has_digits = false
  for c in s {
    if c >= '0' && c <= '9' {
      val = val * 10 + (c.to_int() - '0'.to_int())
      has_digits = true
      if val > max_port {
        return Unchanged
      }
    } else {
      break
    }
  }
  if !has_digits {
    return Unchanged
  }
  match special_scheme_default_port(scheme) {
    Some(dp) if dp == val => Changed(None)
    _ => Changed(Some(val))
  }
}

///|
fn truncate_host_value(s : String, is_special : Bool) -> String {
  let buf = StringBuilder()
  for c in s {
    if c == '/' || c == '?' || c == '#' || (is_special && c == '\\') {
      return buf.to_string()
    }
    buf.write_char(c)
  }
  s
}

///|
fn split_host_port(s : String) -> (String, String?) {
  if s.has_prefix("[") {
    match s.rev_find("]") {
      None => (s, None)
      Some(pos) => {
        let after = s[pos + 1:].to_owned()
        if after.has_prefix(":") {
          (s[0:pos + 1].to_owned(), Some(after[1:].to_owned()))
        } else {
          (s, None)
        }
      }
    }
  } else {
    match s.find(":") {
      None => (s, None)
      Some(i) => (s[0:i].to_owned(), Some(s[i + 1:].to_owned()))
    }
  }
}

///|
/// Re-parses `value` as an absolute URL; raises `UrlParseError` if invalid.
pub fn Url::set_href(_ : Url, value : String) -> Url raise UrlParseError {
  parse(value)
}

///|
/// Changes the URL scheme if the new scheme is valid and compatible with the
/// current scheme type; no-op otherwise.
pub fn Url::set_protocol(self : Url, value : String) -> Url {
  let stripped = strip_tab_newline(value)
  if stripped.is_empty() {
    return self
  }
  match stripped.get_char(0) {
    Some(c) if is_ascii_alpha(c) => ()
    _ => return self
  }
  let buf = StringBuilder()
  for c in stripped {
    if c == ':' {
      break
    }
    if is_ascii_alphanumeric(c) || c == '+' || c == '-' || c == '.' {
      buf.write_char(ascii_lowercase_char(c))
    } else {
      return self
    }
  }
  let new_scheme = buf.to_string()
  let old_special = self.is_special()
  let new_special = is_special_scheme(new_scheme)
  if old_special != new_special {
    return self
  }
  if new_scheme == "file" &&
    (self.username != "" || self.password != "" || self.port != None) {
    return self
  }
  if self.scheme == "file" &&
    new_scheme != "file" &&
    self.host is (None | Some(Host::Domain(""))) {
    return self
  }
  let new_port = match self.port {
    Some(p) if special_scheme_default_port(new_scheme) == Some(p) => None
    p => p
  }
  { ..self, scheme: new_scheme, port: new_port, }
}

///|
/// Sets the percent-encoded username; no-op when credentials are not allowed.
pub fn Url::set_username(self : Url, value : String) -> Url {
  if !self.can_have_credentials() {
    return self
  }
  { ..self, username: @pe.percent_encode_userinfo(value), }
}

///|
/// Sets the percent-encoded password; no-op when credentials are not allowed.
pub fn Url::set_password(self : Url, value : String) -> Url {
  if !self.can_have_credentials() {
    return self
  }
  { ..self, password: @pe.percent_encode_userinfo(value), }
}

///|
/// Sets the port; clears it when `value` is empty or matches the scheme default.
/// No-op for `file:` URLs and opaque-path URLs.
pub fn Url::set_port(self : Url, value : String) -> Url {
  if !self.can_have_credentials() {
    return self
  }
  if value.is_empty() {
    return { ..self, port: None, }
  }
  let stripped = strip_tab_newline(value)
  if stripped.is_empty() {
    return self
  }
  match parse_setter_port(stripped, self.scheme) {
    Unchanged => self
    Changed(new_port) => { ..self, port: new_port, }
  }
}

///|
/// Sets the fragment from `value`, stripping a leading `"#"`; clears the
/// fragment when `value` is empty.
pub fn Url::set_hash(self : Url, value : String) -> Url {
  let stripped = strip_tab_newline(value)
  if stripped.is_empty() {
    return { ..self, fragment: None, }
  }
  let input = @pe.strip_leading_char(stripped, '#')
  { ..self, fragment: Some(@pe.percent_encode_fragment(input)), }
}

///|
/// Sets the query from `value`, stripping a leading `"?"`; clears the query
/// when `value` is empty.
pub fn Url::set_search(self : Url, value : String) -> Url {
  let stripped = strip_tab_newline(value)
  if stripped.is_empty() {
    return { ..self, query: None, }
  }
  let input = @pe.strip_leading_char(stripped, '?')
  let encoded = @pe.percent_encode_query(input, self.is_special())
  { ..self, query: Some(encoded), }
}

///|
/// Sets the URL path from `value`; no-op for opaque-path URLs.
pub fn Url::set_pathname(self : Url, value : String) -> Url {
  if self.has_opaque_path() {
    return self
  }
  let is_special = self.is_special()
  let stripped = strip_tab_newline(value)
  if stripped.is_empty() {
    let new_path = if self.host != None {
      UrlPath::Segments([])
    } else {
      UrlPath::Segments([""])
    }
    return { ..self, path: new_path, }
  }
  let segs : Array[String] = []
  let seg_buf = StringBuilder()
  let path_input = match stripped.get_char(0) {
    Some(c) if c == '/' || (is_special && c == '\\') => stripped[1:]
    _ => stripped
  }
  for c in path_input {
    if c == '/' || (is_special && c == '\\') {
      apply_path_seg(segs, seg_buf.to_string(), self.scheme, false)
      seg_buf.reset()
    } else {
      seg_buf.write_char(c)
    }
  }
  apply_path_seg(segs, seg_buf.to_string(), self.scheme, true)
  { ..self, path: UrlPath::Segments(segs), }
}

///|
fn Url::normalize_and_guard_host(
  self : Url,
  parsed : Host,
  is_special : Bool,
) -> Host? {
  let h = if self.scheme == "file" {
    normalize_file_host(parsed)
  } else {
    parsed
  }
  match h {
    Host::Domain("") if !is_special &&
      (self.username != "" || self.password != "" || self.port != None) => None
    _ => Some(h)
  }
}

///|
fn Url::parse_and_normalize_host(
  self : Url,
  input : String,
  is_special : Bool,
) -> Host? {
  match safe_parse_host(input, is_special) {
    None => None
    Some(h) => self.normalize_and_guard_host(h, is_special)
  }
}

///|
/// Sets the host and optional port from a `"host"` or `"host:port"` string.
/// No-op for opaque-path URLs or on parse failure.
pub fn Url::set_host(self : Url, value : String) -> Url {
  if self.has_opaque_path() {
    return self
  }
  let is_special = self.is_special()
  let stripped = strip_tab_newline(value)
  let truncated = truncate_host_value(stripped, is_special)
  let (host_str, port_opt) = split_host_port(truncated)
  if self.scheme == "file" {
    match port_opt {
      Some(ps) if ps != "" => return self
      _ => ()
    }
    if host_str == "" {
      return { ..self, host: Some(@host.Host::empty_domain()), }
    }
  }
  if host_str == "" {
    match port_opt {
      Some(ps) if ps != "" => return self
      _ => ()
    }
  }
  let new_host = match self.parse_and_normalize_host(host_str, is_special) {
    None => return self
    Some(h) => h
  }
  let url_with_host = { ..self, host: Some(new_host), }
  match port_opt {
    None | Some("") => url_with_host
    Some(port_str) =>
      match parse_setter_port(port_str, self.scheme) {
        Unchanged => url_with_host
        Changed(new_port) => { ..url_with_host, port: new_port, }
      }
  }
}

///|
/// Sets the host from `value` without modifying the port.
/// No-op for opaque-path URLs or on parse failure.
pub fn Url::set_hostname(self : Url, value : String) -> Url {
  if self.has_opaque_path() {
    return self
  }
  let is_special = self.is_special()
  let stripped = strip_tab_newline(value)
  let truncated = truncate_host_value(stripped, is_special)
  if truncated.has_prefix("[") {
    match truncated.rev_find("]") {
      Some(pos) if pos + 1 < truncated.length() => return self
      _ => ()
    }
  } else {
    for c in truncated {
      if c == ':' {
        return self
      }
    }
  }
  if self.scheme == "file" && truncated == "" {
    return { ..self, host: Some(@host.Host::empty_domain()), }
  }
  let new_host = match self.parse_and_normalize_host(truncated, is_special) {
    None => return self
    Some(h) => h
  }
  { ..self, host: Some(new_host), }
}
