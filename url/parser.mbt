///|
let max_port : Int32 = 65535

///|
priv enum State {
  SchemeStart
  Scheme
  NoScheme
  SpecialRelativeOrAuthority
  PathOrAuthority
  Relative
  RelativeSlash
  SpecialAuthoritySlashes
  SpecialAuthorityIgnoreSlashes
  Authority
  File
  FileSlash
  FileHost
  PathStart
  Path
  OpaquePath
  Query
  Fragment
}

///|
fn is_ascii_alpha(c : Char) -> Bool {
  (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
}

///|
fn is_ascii_alphanumeric(c : Char) -> Bool {
  is_ascii_alpha(c) || (c >= '0' && c <= '9')
}

///|
fn ascii_lowercase_char(c : Char) -> Char {
  if c >= 'A' && c <= 'Z' {
    Int32::unsafe_to_char(c.to_int() + 32)
  } else {
    c
  }
}

///|
fn is_windows_drive_letter(s : String) -> Bool {
  let n = s.length()
  if n < 2 {
    return false
  }
  let c0 = s.get_char(0).unwrap_or(' ')
  let c1 = s.get_char(1).unwrap_or(' ')
  if !is_ascii_alpha(c0) {
    return false
  }
  if c1 == ':' || c1 == '|' {
    if n == 2 {
      return true
    }
    if n >= 3 {
      let c2 = s.get_char(2).unwrap_or(' ')
      return c2 == '/' || c2 == '\\' || c2 == '?' || c2 == '#'
    }
  }
  false
}

///|
fn chars_start_with_wdl(chars : Array[Char], from : Int32, n : Int32) -> Bool {
  if from + 1 >= n {
    return false
  }
  let c0 = chars[from]
  let c1 = chars[from + 1]
  if !is_ascii_alpha(c0) {
    return false
  }
  if c1 != ':' && c1 != '|' {
    return false
  }
  if from + 2 >= n {
    return true
  }
  let c2 = chars[from + 2]
  c2 == '/' || c2 == '\\' || c2 == '?' || c2 == '#'
}

///|
fn push_normalized_segment(
  segs : Array[String],
  seg : String,
  scheme : String,
) -> Unit {
  if scheme == "file" && segs.is_empty() && is_windows_drive_letter(seg) {
    let c0 = seg.get_char(0).unwrap_or('C').to_string()
    let rest = seg[2:].to_owned()
    segs.push(c0 + ":" + rest)
  } else {
    segs.push(@pe.percent_encode_path_seg(seg))
  }
}

///|
fn preprocess_url_input(input : String) -> String {
  let n = input.length()
  let mut start = 0
  let mut end = n
  while start < end {
    match input.get_char(start) {
      Some(c) if c.to_int() <= 0x20 => start = start + 1
      _ => break
    }
  }
  while end > start {
    match input.get_char(end - 1) {
      Some(c) if c.to_int() <= 0x20 => end = end - 1
      _ => break
    }
  }
  let buf = StringBuilder()
  for c in input[start:end] {
    let cp = c.to_int()
    if cp != 0x09 && cp != 0x0A && cp != 0x0D {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
fn is_2e_at(s : String, at : Int32) -> Bool {
  if s.get_char(at).unwrap_or('\u{0}') != '%' {
    return false
  }
  if s.get_char(at + 1).unwrap_or('\u{0}') != '2' {
    return false
  }
  let c2 = s.get_char(at + 2).unwrap_or('\u{0}')
  c2 == 'e' || c2 == 'E'
}

///|
fn is_dot_segment(s : String) -> Bool {
  let n = s.length()
  if n == 2 {
    s.get_char(0).unwrap_or('\u{0}') == '.' &&
    s.get_char(1).unwrap_or('\u{0}') == '.'
  } else if n == 4 {
    let c0 = s.get_char(0).unwrap_or('\u{0}')
    if c0 == '.' {
      is_2e_at(s, 1)
    } else if c0 == '%' {
      is_2e_at(s, 0) && s.get_char(3).unwrap_or('\u{0}') == '.'
    } else {
      false
    }
  } else if n == 6 {
    is_2e_at(s, 0) && is_2e_at(s, 3)
  } else {
    false
  }
}

///|
fn is_single_dot(s : String) -> Bool {
  let n = s.length()
  if n == 1 {
    s.get_char(0).unwrap_or('\u{0}') == '.'
  } else if n == 3 {
    is_2e_at(s, 0)
  } else {
    false
  }
}

///|
/// Parses `input` as an absolute URL string; raises `UrlParseError` if invalid.
///
/// ### Example
///
/// ```mbt check
/// test {
///   inspect(
///     (try! @url.parse("https://example.com/path")).href(),
///     content="https://example.com/path",
///   )
/// }
/// ```
pub fn parse(input : String) -> Url raise UrlParseError {
  parse_with_base(input, None)
}

///|
/// Parses `input` resolved against `base`; raises `UrlParseError` on failure.
///
/// ### Example
///
/// ```mbt check
/// test {
///   let base = try! @url.parse("https://example.com/a/b")
///   inspect(
///     (try! @url.parse_with_base("../c", Some(base))).href(),
///     content="https://example.com/c",
///   )
/// }
/// ```
pub fn parse_with_base(input : String, base : Url?) -> Url raise UrlParseError {
  let stripped = preprocess_url_input(input)
  let url = UrlRecord::new()
  let chars = @pe.string_to_chars(stripped)
  let n = chars.length()
  let mut state = State::SchemeStart
  let buf = StringBuilder()
  let mut pointer = 0
  let mut at_sign_seen = false
  let mut password_token_seen = false

  while pointer <= n {
    let c : Char? = if pointer < n { Some(chars[pointer]) } else { None }
    let mut advance = true

    match state {
      SchemeStart =>
        match c {
          Some(ch) if is_ascii_alpha(ch) => {
            buf.write_char(ascii_lowercase_char(ch))
            state = State::Scheme
          }
          _ => {
            state = State::NoScheme
            advance = false
          }
        }
      Scheme =>
        match c {
          Some(ch) if is_ascii_alphanumeric(ch) ||
            ch == '+' ||
            ch == '-' ||
            ch == '.' => buf.write_char(ascii_lowercase_char(ch))
          Some(':') => {
            url.scheme = buf.to_string()
            buf.reset()
            if url.scheme == "file" {
              state = State::File
            } else {
              let base_same_scheme = match base {
                Some(b) => b.scheme == url.scheme
                None => false
              }
              if url.is_special() && base != None && base_same_scheme {
                state = State::SpecialRelativeOrAuthority
              } else if url.is_special() {
                state = State::SpecialAuthoritySlashes
              } else if pointer + 1 < n && chars[pointer + 1] == '/' {
                state = State::PathOrAuthority
                pointer = pointer + 1
              } else {
                url.path = UrlPath::Opaque("")
                state = State::OpaquePath
              }
            }
          }
          _ => {
            buf.reset()
            state = State::NoScheme
            pointer = 0
            advance = false
          }
        }
      NoScheme =>
        match base {
          None => raise UrlParseError("no scheme and no base URL")
          Some(b) =>
            if b.path is Opaque(_) {
              match c {
                Some('#') => {
                  url.scheme = b.scheme
                  url.copy_from(b)
                  url.fragment = Some("")
                  state = State::Fragment
                }
                _ => raise UrlParseError("no scheme and base has opaque path")
              }
            } else if b.scheme != "file" {
              state = State::Relative
              advance = false
            } else {
              state = State::File
              advance = false
            }
        }
      SpecialRelativeOrAuthority => {
        let next_is_slash = pointer + 1 < n && chars[pointer + 1] == '/'
        if c == Some('/') && next_is_slash {
          state = State::SpecialAuthorityIgnoreSlashes
          pointer = pointer + 1
        } else {
          state = State::Relative
          advance = false
        }
      }
      PathOrAuthority =>
        if c == Some('/') {
          state = State::Authority
        } else {
          state = State::Path
          advance = false
        }
      Relative =>
        match base {
          None => panic()
          Some(b) => {
            url.scheme = b.scheme
            match c {
              None => url.copy_from(b)
              Some('/') => state = State::RelativeSlash
              Some('\\') if url.is_special() => state = State::RelativeSlash
              Some('?') => {
                url.copy_authority_from(b)
                url.copy_path_from(b)
                url.query = Some("")
                state = State::Query
              }
              Some('#') => {
                url.copy_authority_from(b)
                url.copy_path_from(b)
                url.query = b.query
                url.fragment = Some("")
                state = State::Fragment
              }
              _ => {
                url.copy_authority_from(b)
                url.copy_path_from(b)
                shorten_path_segs(url.path_segs(), url.scheme)
                state = State::Path
                advance = false
              }
            }
          }
        }
      RelativeSlash => {
        let is_special = url.is_special()
        if is_special && (c == Some('/') || c == Some('\\')) {
          state = State::SpecialAuthorityIgnoreSlashes
        } else if c == Some('/') {
          state = State::Authority
        } else {
          if base is Some(b) {
            url.copy_authority_from(b)
          }
          state = State::Path
          advance = false
        }
      }
      SpecialAuthoritySlashes => {
        let next_is_slash = pointer + 1 < n && chars[pointer + 1] == '/'
        if c == Some('/') && next_is_slash {
          state = State::SpecialAuthorityIgnoreSlashes
          pointer = pointer + 1
        } else {
          state = State::SpecialAuthorityIgnoreSlashes
          advance = false
        }
      }
      SpecialAuthorityIgnoreSlashes =>
        if c != Some('/') && c != Some('\\') {
          state = State::Authority
          advance = false
        }
      Authority => {
        let c = if url.is_special() && c == Some('\\') { Some('/') } else { c }
        match c {
          Some('@') => {
            let raw_creds = buf.to_string()
            buf.reset()
            let creds = if at_sign_seen { "%40" + raw_creds } else { raw_creds }
            at_sign_seen = true
            let username_buf = StringBuilder()
            let password_buf = StringBuilder()
            username_buf.write_string(url.username)
            password_buf.write_string(url.password)
            for ch in creds {
              if ch == ':' && !password_token_seen {
                password_token_seen = true
                continue
              }
              let enc = @pe.percent_encode_userinfo(ch.to_string())
              if password_token_seen {
                password_buf.write_string(enc)
              } else {
                username_buf.write_string(enc)
              }
            }
            url.username = username_buf.to_string()
            url.password = password_buf.to_string()
          }
          None | Some('/') | Some('?') | Some('#') => {
            let host_str = buf.to_string()
            buf.reset()
            if at_sign_seen && host_str.is_empty() {
              raise UrlParseError("empty host after @")
            }
            if url.is_special() && host_str.is_empty() {
              raise UrlParseError("empty host for special URL")
            }
            let (h, p) = parse_host_and_port(host_str, url.is_special())
            url.host = Some(h)
            match p {
              Some(pn) =>
                match special_scheme_default_port(url.scheme) {
                  Some(dp) if pn == dp => url.port = None
                  _ => url.port = Some(pn)
                }
              None => ()
            }
            match c {
              Some('?') => {
                url.query = Some("")
                state = State::Query
              }
              Some('#') => {
                url.fragment = Some("")
                state = State::Fragment
              }
              Some('/') | Some('\\') => {
                state = State::PathStart
                advance = false
              }
              _ => state = State::PathStart
            }
          }
          Some('[') => buf.write_char('[')
          Some(ch) => buf.write_char(ch)
        }
      }
      File => {
        url.scheme = "file"
        url.host = Some(@host.Host::empty_domain())
        match c {
          Some('/') | Some('\\') => state = State::FileSlash
          _ =>
            match base {
              Some(b) if b.scheme == "file" => {
                url.host = b.host
                url.copy_path_from(b)
                url.query = b.query
                match c {
                  Some('?') => {
                    url.query = Some("")
                    state = State::Query
                  }
                  Some('#') => {
                    url.fragment = Some("")
                    state = State::Fragment
                  }
                  None => ()
                  _ => {
                    url.query = None
                    if chars_start_with_wdl(chars, pointer, n) {
                      url.path = UrlPath::Segments([])
                    } else {
                      shorten_path_segs(url.path_segs(), url.scheme)
                    }
                    state = State::Path
                    advance = false
                  }
                }
              }
              _ => {
                state = State::Path
                advance = false
              }
            }
        }
      }
      FileSlash =>
        match c {
          Some('/') | Some('\\') => state = State::FileHost
          _ => {
            match base {
              Some(b) if b.scheme == "file" => {
                url.host = b.host
                if !chars_start_with_wdl(chars, pointer, n) {
                  let first_seg = match b.path {
                    Segments(segs) if segs.length() > 0 => segs[0]
                    _ => ""
                  }
                  if is_windows_drive_letter(first_seg) {
                    url.path_segs().push(first_seg)
                  }
                }
              }
              _ => ()
            }
            state = State::Path
            advance = false
          }
        }
      FileHost =>
        match c {
          None | Some('/') | Some('\\') | Some('?') | Some('#') => {
            let host_str = buf.to_string()
            if is_windows_drive_letter(host_str) {
              state = State::Path
            } else {
              buf.reset()
              if host_str.is_empty() {
                url.host = Some(@host.Host::empty_domain())
                state = State::PathStart
              } else {
                let h = host_parse(host_str, true)
                url.host = Some(normalize_file_host(h))
                state = State::PathStart
              }
            }
            advance = false
          }
          Some(ch) => buf.write_char(ch)
        }
      PathStart => {
        state = State::Path
        if c != Some('/') && !(c == Some('\\') && url.is_special()) {
          advance = false
        }
      }
      Path => {
        let is_sep = c == Some('/') ||
          (c == Some('\\') && url.is_special()) ||
          c == None
        let is_query = c == Some('?')
        let is_frag = c == Some('#')
        if is_sep || is_query || is_frag {
          let seg = buf.to_string()
          buf.reset()
          apply_path_seg(
            url.path_segs(),
            seg,
            url.scheme,
            c == None || is_query || is_frag,
          )
          if is_query {
            url.query = Some("")
            state = State::Query
          } else if is_frag {
            url.fragment = Some("")
            state = State::Fragment
          }
        } else if c is Some(ch) {
          buf.write_char(ch)
        }
      }
      OpaquePath =>
        match c {
          Some('?') => {
            url.path = UrlPath::Opaque(
              @pe.percent_encode_opaque_path_at_stop(buf.to_string()),
            )
            buf.reset()
            url.query = Some("")
            state = State::Query
          }
          Some('#') => {
            url.path = UrlPath::Opaque(
              @pe.percent_encode_opaque_path_at_stop(buf.to_string()),
            )
            buf.reset()
            url.fragment = Some("")
            state = State::Fragment
          }
          None =>
            url.path = UrlPath::Opaque(@pe.percent_encode_c0(buf.to_string()))
          Some(ch) => buf.write_char(ch)
        }
      Query =>
        match c {
          Some('#') => {
            let q = buf.to_string()
            buf.reset()
            url.query = Some(@pe.percent_encode_query(q, url.is_special()))
            url.fragment = Some("")
            state = State::Fragment
          }
          None =>
            url.query = Some(
              @pe.percent_encode_query(buf.to_string(), url.is_special()),
            )
          Some(ch) => buf.write_char(ch)
        }
      Fragment =>
        match c {
          None =>
            url.fragment = Some(@pe.percent_encode_fragment(buf.to_string()))
          Some(ch) => buf.write_char(ch)
        }
    }

    if advance {
      pointer = pointer + 1
    }
  }

  url.to_url()
}

///|
fn parse_host_and_port(
  input : String,
  is_special : Bool,
) -> (Host, Int32?) raise UrlParseError {
  if input.has_prefix("[") {
    match input.rev_find("]") {
      Some(bracket_pos) => {
        let host_part = input[0:bracket_pos + 1].to_owned()
        let after = input[bracket_pos + 1:].to_owned()
        let h = host_parse(host_part, is_special)
        let p = if after.has_prefix(":") {
          let port_str = after[1:].to_owned()
          if port_str.is_empty() {
            None
          } else {
            Some(parse_port_number(port_str))
          }
        } else if after.is_empty() {
          None
        } else {
          raise UrlParseError("invalid character after IPv6 address")
        }
        (h, p)
      }
      None => raise UrlParseError("invalid IPv6: no closing bracket")
    }
  } else {
    match input.rev_find(":") {
      Some(colon_pos) => {
        let host_part = input[0:colon_pos].to_owned()
        let port_str = input[colon_pos + 1:].to_owned()
        if !is_special && host_part.is_empty() {
          raise UrlParseError("empty host with port for non-special URL")
        }
        let h = host_parse(host_part, is_special)
        let p = if port_str.is_empty() {
          None
        } else {
          Some(parse_port_number(port_str))
        }
        (h, p)
      }
      None => (host_parse(input, is_special), None)
    }
  }
}

///|
fn parse_port_number(s : String) -> Int32 raise UrlParseError {
  let mut result = 0
  for c in s {
    if c < '0' || c > '9' {
      raise UrlParseError("invalid port character")
    }
    result = result * 10 + (c.to_int() - '0'.to_int())
    if result > max_port {
      raise UrlParseError("port out of range")
    }
  }
  result
}

///|
fn normalize_file_host(h : Host) -> Host {
  match h {
    Host::Domain("localhost") => @host.Host::empty_domain()
    _ => h
  }
}

///|
fn host_parse(input : String, is_special : Bool) -> Host raise UrlParseError {
  @host.parse_host(input, is_special) catch {
    @host.HostParseError(msg) => raise UrlParseError(msg)
  }
}
