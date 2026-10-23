///|
let max_port : Int32 = 65535

///|
priv enum ComponentKind {
  Protocol
  Username
  Password
  Hostname
  Port
  Pathname
  OpaquePathname
  Search
  Hash
} derive(Eq)

///|
fn canonicalize_protocol_for_pattern(
  input : String,
) -> String raise UrlPatternError {
  if input == "" {
    return ""
  }
  let stripped = if input.has_suffix(":") {
    input[0:input.length() - 1].to_owned()
  } else {
    input
  }
  let parsed = @url.parse(stripped + "://dummy.test") catch {
    _ => raise UrlPatternError("invalid protocol: '\{input}'")
  }
  parsed.scheme()
}

///|
fn canonicalize_hostname_for_pattern(
  input : String,
) -> String raise UrlPatternError {
  if input == "" {
    return ""
  }
  // Strip C0 controls; truncate at #, /, \ (URL parsing would do the same)
  let buf = StringBuilder()
  for c in input {
    let cp = c.to_int()
    if cp <= 0x1F || cp == 0x7F {
      continue
    }
    if c == '#' || c == '/' || c == '\\' || c == '?' {
      break
    }
    buf.write_char(c)
  }
  let processed = buf.to_string()
  if processed == "" {
    return ""
  }
  let host = @host.parse_host(processed, true) catch {
    e => raise UrlPatternError("invalid hostname: \{e}")
  }
  @host.serialize_host(host)
}

///|
fn is_literal_port_out_of_range(s : String) -> Bool {
  if s == "" {
    return false
  }
  for c in s {
    if !(c >= '0' && c <= '9') {
      return false
    }
  }
  let mut n = 0
  for c in s {
    n = n * 10 + (c.to_int() - '0'.to_int())
    if n > max_port {
      return true
    }
  }
  false
}

///|
fn apply_encode_for_component(
  value : String,
  kind : ComponentKind,
) -> String raise UrlPatternError {
  match kind {
    Protocol => canonicalize_protocol_for_pattern(value)
    Username => canonicalize_userinfo(value)
    Password => canonicalize_password(value)
    Hostname => canonicalize_hostname_for_pattern(value)
    Port => canonicalize_port(value, "")
    Pathname => canonicalize_pathname(value)
    OpaquePathname => value
    Search => canonicalize_search(value)
    Hash => canonicalize_hash(value)
  }
}

///|
fn is_ipv6_literal_char(c : Char) -> Bool {
  (c >= '0' && c <= '9') ||
  (c >= 'a' && c <= 'f') ||
  (c >= 'A' && c <= 'F') ||
  c == ':' ||
  c == '.' ||
  c == '[' ||
  c == ']'
}

///|
fn lower_ipv6_literal(value : String) -> String raise UrlPatternError {
  for c in value {
    if !is_ipv6_literal_char(c) {
      raise UrlPatternError("invalid character '\{c}' in IPv6 address literal")
    }
  }
  let buf = StringBuilder()
  for c in value {
    buf.write_char(
      if c >= 'A' && c <= 'F' {
        (c.to_int() + 32).unsafe_to_char()
      } else {
        c
      },
    )
  }
  buf.to_string()
}

///|
fn encode_hostname_value(
  value : String,
  in_ipv6 : Bool,
) -> String raise UrlPatternError {
  if value == "" {
    return ""
  }
  if in_ipv6 || value.get_char(0) == Some('[') {
    return lower_ipv6_literal(value)
  }
  canonicalize_hostname_for_pattern(value)
}

///|
fn encode_part_str(
  s : String,
  kind : ComponentKind,
  ipv6_open : Bool,
) -> (String, Bool) raise UrlPatternError {
  if kind == Hostname {
    let encoded = encode_hostname_value(s, ipv6_open)
    let mut new_open = ipv6_open
    for c in s {
      if c == '[' {
        new_open = true
      } else if c == ']' {
        new_open = false
      }
    }
    (encoded, new_open)
  } else {
    (apply_encode_for_component(s, kind), ipv6_open)
  }
}

///|
fn encode_parts(
  raw_parts : Array[Part],
  kind : ComponentKind,
) -> Array[Part] raise UrlPatternError {
  let result : Array[Part] = []
  let mut ipv6_open = false
  for part in raw_parts {
    match part.kind {
      FixedText => {
        let (enc, new_open) = encode_part_str(part.value, kind, ipv6_open)
        ipv6_open = new_open
        result.push({
          kind: FixedText,
          value: enc,
          modifier: part.modifier,
          name: part.name,
          prefix: part.prefix,
          suffix: part.suffix,
        })
      }
      Regexp | SegmentWildcard | FullWildcard => {
        match part.kind {
          Regexp =>
            for c in part.value {
              if c.to_int() > 0x7F {
                raise UrlPatternError(
                  "regexp value contains non-ASCII character '\{c}'",
                )
              }
            }
          _ => ()
        }
        let (enc_prefix, after_prefix) = encode_part_str(
          part.prefix,
          kind,
          ipv6_open,
        )
        ipv6_open = after_prefix
        let (enc_suffix, after_suffix) = encode_part_str(
          part.suffix,
          kind,
          ipv6_open,
        )
        ipv6_open = after_suffix
        result.push({
          kind: part.kind,
          value: part.value,
          modifier: part.modifier,
          name: part.name,
          prefix: enc_prefix,
          suffix: enc_suffix,
        })
      }
    }
  }
  result
}

///|
fn compile_component(
  pattern : String,
  options : CompileOptions,
  policy : TokenizePolicy,
  kind : ComponentKind,
  ignore_case~ : Bool = false,
) -> CompiledComponent raise UrlPatternError {
  let raw_parts = parse_pattern_to_parts(pattern, options, policy)
  let parts = encode_parts(raw_parts, kind)
  let has_regexp_groups = parts.any(fn(p) { p.kind == Regexp })
  let pat_str = generate_pattern_string(parts, options)
  let (regexp_str, group_names, group_strips) = generate_regexp(parts, options)
  let final_regexp_str = if ignore_case {
    "(?i:" + regexp_str + ")"
  } else {
    regexp_str
  }
  let regex = @string.Regex(final_regexp_str) catch {
    err =>
      raise UrlPatternError(
        "compile_component: invalid regex '\{final_regexp_str}': \{err}",
      )
  }
  {
    pattern: pat_str,
    regex,
    group_names,
    group_strips,
    parts,
    has_regexp_groups,
    kind,
  }
}

///|
/// Compiles a `UrlPattern` from a URL pattern string with an optional base URL.
///
/// - `pattern` : The URL pattern string (e.g. `"https://example.com/:path*"`).
/// - `base_url` : Optional base URL used to resolve relative patterns.
/// - `ignore_case` : When `true`, all component regexes match case-insensitively.
///
/// ### Example
///
/// ```mbt check
/// test {
///   let p = try! @urlpattern.UrlPattern::from_string(
///     "https://example.com/api/:id",
///     None,
///   )
///   inspect(p.test_url("https://example.com/api/42"), content="true")
///   inspect(p.test_url("https://other.com/api/42"), content="false")
/// }
/// ```
pub fn UrlPattern::from_string(
  pattern : String,
  base_url : String?,
  ignore_case~ : Bool = false,
) -> UrlPattern raise UrlPatternError {
  let init = parse_constructor_string(pattern)
  if init.protocol is None && base_url is None {
    raise UrlPatternError(
      "constructor string pattern requires a protocol or base URL",
    )
  }
  let init = match base_url {
    None => init
    Some(b) => { ..init, base_url: Some(b), }
  }
  UrlPattern::from_init(init, ignore_case~)
}

///|
/// Compiles a `UrlPattern` from per-component pattern strings in `init`.
///
/// - `init` : Per-component pattern strings; `None` fields match any value.
/// - `ignore_case` : When `true`, all component regexes match case-insensitively.
pub fn UrlPattern::from_init(
  init : UrlPatternInit,
  ignore_case~ : Bool = false,
) -> UrlPattern raise UrlPatternError {
  let init = apply_base_url(init, true)
  let proto_raw = init.protocol.unwrap_or("*")
  let proto_val = if proto_raw.length() > 0 &&
    proto_raw[proto_raw.length() - 1] == ':' {
    proto_raw[0:proto_raw.length() - 1].to_owned()
  } else {
    proto_raw
  }
  let port_raw = init.port.unwrap_or("*")
  if is_literal_port_out_of_range(port_raw) {
    raise UrlPatternError("port out of range: '\{port_raw}'")
  }
  let port_val = match (proto_val, port_raw) {
    ("http" | "ws", "80") => ""
    ("https" | "wss", "443") => ""
    ("ftp", "21") => ""
    (_, v) => v
  }
  let protocol = compile_component(
    proto_val,
    default_options,
    Strict,
    Protocol,
    ignore_case~,
  )
  let username = compile_component(
    init.username.unwrap_or("*"),
    default_options,
    Strict,
    Username,
    ignore_case~,
  )
  let password = compile_component(
    init.password.unwrap_or("*"),
    default_options,
    Strict,
    Password,
    ignore_case~,
  )
  let hostname = compile_component(
    init.hostname.unwrap_or("*"),
    hostname_options,
    Strict,
    Hostname,
    ignore_case~,
  )
  let port = compile_component(
    port_val,
    default_options,
    Strict,
    Port,
    ignore_case~,
  )
  let can_match_special_proto = protocol.regex.execute("ftp") is Some(_) ||
    protocol.regex.execute("file") is Some(_) ||
    protocol.regex.execute("http") is Some(_) ||
    protocol.regex.execute("https") is Some(_) ||
    protocol.regex.execute("ws") is Some(_) ||
    protocol.regex.execute("wss") is Some(_)
  let pathname_kind = if !can_match_special_proto {
    OpaquePathname
  } else {
    Pathname
  }
  let pathname_compile_opts = if pathname_kind == OpaquePathname {
    default_options
  } else {
    pathname_options
  }
  let pathname = compile_component(
    init.pathname.unwrap_or("*"),
    pathname_compile_opts,
    Strict,
    pathname_kind,
    ignore_case~,
  )
  let search_raw = init.search.unwrap_or("*")
  let search_val = if search_raw.length() > 0 && search_raw[0] == '?' {
    search_raw[1:].to_owned()
  } else {
    search_raw
  }
  let search = compile_component(
    search_val,
    default_options,
    Strict,
    Search,
    ignore_case~,
  )
  let hash_raw = init.hash.unwrap_or("*")
  let hash_val = if hash_raw.length() > 0 && hash_raw[0] == '#' {
    hash_raw[1:].to_owned()
  } else {
    hash_raw
  }
  let hash = compile_component(
    hash_val,
    default_options,
    Strict,
    Hash,
    ignore_case~,
  )
  { protocol, username, password, hostname, port, pathname, search, hash, }
}

///|
fn match_component(
  component : CompiledComponent,
  input : String,
) -> UrlPatternComponentResult? {
  match component.regex.execute(input) {
    None => None
    Some(m) => {
      let groups : Map[String, String?] = Map([])
      for idx, name in component.group_names {
        let val = match m.group(idx + 1) {
          None => None
          Some(sv) => {
            let raw = sv.to_owned()
            let (pre, suf) = component.group_strips[idx]
            let stripped = if pre.length() > 0 || suf.length() > 0 {
              let start = pre.length()
              let end = raw.length() - suf.length()
              if start <= end {
                raw[start:end].to_owned()
              } else {
                raw
              }
            } else {
              raw
            }
            Some(stripped)
          }
        }
        groups[name] = val
      }
      Some({ input, groups, })
    }
  }
}

///|
/// Tests a `UrlPatternInit` against this pattern and returns match details,
/// or `None` when the input does not match.
pub fn UrlPattern::exec_init(
  self : UrlPattern,
  init : UrlPatternInit,
) -> UrlPatternResult? {
  let init = apply_base_url(init, false) catch { _ => return None }
  let proto_raw = init.protocol.unwrap_or("")
  let proto_input = canonicalize_protocol_for_pattern(proto_raw) catch {
    _ => return None
  }
  let proto_str = proto_input
  let protocol = match_component(self.protocol, proto_input)
  guard protocol is Some(_) else { return None }
  let username_input = canonicalize_userinfo(init.username.unwrap_or(""))
  let username = match_component(self.username, username_input)
  guard username is Some(_) else { return None }
  let password_input = canonicalize_password(init.password.unwrap_or(""))
  let password = match_component(self.password, password_input)
  guard password is Some(_) else { return None }
  let hostname_input = canonicalize_hostname(init.hostname.unwrap_or(""))
  let hostname = match_component(self.hostname, hostname_input)
  guard hostname is Some(_) else { return None }
  let raw_port = init.port.unwrap_or("")
  let port_input = if raw_port != "" {
    let p = canonicalize_port(raw_port, proto_str)
    for c in p {
      if c < '0' || c > '9' {
        return None
      }
    }
    p
  } else {
    ""
  }
  let port = match_component(self.port, port_input)
  guard port is Some(_) else { return None }
  let raw_pathname = init.pathname.unwrap_or("")
  let pathname_input = if proto_str == "" ||
    proto_str == "http" ||
    proto_str == "https" ||
    proto_str == "ws" ||
    proto_str == "wss" ||
    proto_str == "ftp" ||
    proto_str == "file" {
    canonicalize_pathname(raw_pathname)
  } else {
    raw_pathname
  }
  let pathname = match_component(self.pathname, pathname_input)
  guard pathname is Some(_) else { return None }
  let search_input = canonicalize_search(init.search.unwrap_or(""))
  let search = match_component(self.search, search_input)
  guard search is Some(_) else { return None }
  let hash_input = canonicalize_hash(init.hash.unwrap_or(""))
  let hash = match_component(self.hash, hash_input)
  guard hash is Some(_) else { return None }

  Some({
    inputs: [Init(init)],
    protocol,
    username,
    password,
    hostname,
    port,
    pathname,
    search,
    hash,
  })
}

///|
fn canonicalize_hostname(input : String) -> String {
  if input == "" {
    return ""
  }
  let u = @url.parse("https://dummy.test") catch { _ => return input }
  u.set_hostname(input).hostname()
}

///|
fn canonicalize_userinfo(input : String) -> String {
  if input == "" {
    return ""
  }
  let u = @url.parse("https://x/") catch { _ => return input }
  u.set_username(input).username()
}

///|
fn canonicalize_password(input : String) -> String {
  if input == "" {
    return ""
  }
  let u = @url.parse("https://x/") catch { _ => return input }
  u.set_password(input).password()
}

///|
fn canonicalize_pathname(input : String) -> String {
  if input == "" {
    return ""
  }
  let leading_slash = input.get_char(0) == Some('/')
  let full = if leading_slash {
    "https://x" + input
  } else {
    "https://x/-" + input
  }
  let url = @url.parse(full) catch { _ => return input }
  let p = url.pathname()
  if leading_slash {
    p
  } else if p.length() < 2 {
    input
  } else {
    p[2:].to_owned()
  }
}

///|
fn canonicalize_search(input : String) -> String {
  if input == "" {
    return ""
  }
  let stripped = @pe.strip_leading_char(input, '?')
  if stripped == "" {
    return ""
  }
  let url = @url.parse("https://x/?" + stripped) catch { _ => return stripped }
  @pe.strip_leading_char(url.search(), '?')
}

///|
fn canonicalize_hash(input : String) -> String {
  if input == "" {
    return ""
  }
  let stripped = @pe.strip_leading_char(input, '#')
  if stripped == "" {
    return ""
  }
  let url = @url.parse("https://x/#" + stripped) catch { _ => return stripped }
  @pe.strip_leading_char(url.hash(), '#')
}

///|
fn canonicalize_port(port : String, protocol : String) -> String {
  if port == "" {
    return ""
  }
  let buf = StringBuilder()
  for c in port {
    if c != '\t' && c != '\n' && c != '\r' && c.to_int() != 12 {
      buf.write_char(c)
    }
  }
  let trimmed = buf.to_string()
  if trimmed == "" {
    return ""
  }
  let digit_buf = StringBuilder()
  for c in trimmed {
    if c >= '0' && c <= '9' {
      digit_buf.write_char(c)
    } else {
      break
    }
  }
  let digits = digit_buf.to_string()
  if digits == "" {
    return port
  }
  let mut n = 0
  for c in digits {
    n = n * 10 + (c.to_int() - '0'.to_int())
  }
  if n > max_port {
    return port
  }
  let normalized = n.to_string()
  match protocol {
    "http" | "ws" => if normalized == "80" { "" } else { normalized }
    "https" | "wss" => if normalized == "443" { "" } else { normalized }
    "ftp" => if normalized == "21" { "" } else { normalized }
    _ => normalized
  }
}

///|
fn normalize_path_dots(path : String) -> String {
  let segments : Array[String] = []
  for seg in path.split("/") {
    let s = seg.to_owned()
    if s == "" || s == "." {
      ()
    } else if s == ".." {
      if segments.length() > 0 {
        segments.pop() |> ignore
      }
    } else {
      segments.push(s)
    }
  }
  "/" + segments.join("/")
}

///|
fn get_base_dir(pathname : String) -> String {
  match pathname.rev_find("/") {
    None => ""
    Some(pos) => pathname[0:pos + 1].to_owned()
  }
}

///|
fn apply_base_url(
  init : UrlPatternInit,
  for_pattern : Bool,
) -> UrlPatternInit raise UrlPatternError {
  let base_str = match init.base_url {
    None => return init
    Some(s) => s
  }
  let base = @url.parse(base_str) catch {
    _ => raise UrlPatternError("invalid baseURL: \{base_str}")
  }
  let base_search_raw = @pe.strip_leading_char(base.search(), '?')
  let base_hash_raw = @pe.strip_leading_char(base.hash(), '#')
  let base_port = base.port_str()
  let esc : (String) -> String = if for_pattern {
    escape_pattern_string
  } else {
    fn(s) { s }
  }
  let has_protocol = init.protocol is Some(_)
  let has_username = init.username is Some(_)
  let has_password = init.password is Some(_)
  let has_hostname = init.hostname is Some(_)
  let has_port = init.port is Some(_)
  let has_pathname = init.pathname is Some(_)
  let has_search = init.search is Some(_)
  let protocol = if has_protocol {
    init.protocol
  } else {
    Some(esc(base.scheme()))
  }
  let username = if !for_pattern &&
    !has_protocol &&
    !has_hostname &&
    !has_port &&
    !has_username {
    Some(base.username())
  } else {
    init.username
  }
  let password = if !for_pattern &&
    !has_protocol &&
    !has_hostname &&
    !has_port &&
    !has_username &&
    !has_password {
    Some(base.password())
  } else {
    init.password
  }
  let hostname = if !has_protocol && !has_hostname {
    Some(esc(base.hostname()))
  } else {
    init.hostname
  }
  let port = if !has_protocol && !has_hostname && !has_port {
    Some(esc(base_port))
  } else {
    init.port
  }
  let pathname = if !has_protocol && !has_hostname && !has_port && !has_pathname {
    Some(esc(base.pathname()))
  } else if !has_protocol && !has_hostname && !has_port && has_pathname {
    let pn = init.pathname.unwrap_or("")
    let first_slash : Bool = match pn.get_char(0) {
      Some('/') => true
      Some('{') | Some('\\') => pn.get_char(1) == Some('/')
      _ => false
    }
    if first_slash {
      init.pathname
    } else {
      let resolved = get_base_dir(base.pathname()) + pn
      if for_pattern {
        Some(normalize_path_dots(resolved))
      } else {
        Some(resolved)
      }
    }
  } else {
    init.pathname
  }
  let search = if !has_protocol &&
    !has_hostname &&
    !has_port &&
    !has_pathname &&
    !has_search {
    Some(esc(base_search_raw))
  } else {
    init.search
  }
  let hash = if !has_protocol &&
    !has_hostname &&
    !has_port &&
    !has_pathname &&
    !has_search &&
    init.hash is None {
    Some(esc(base_hash_raw))
  } else {
    init.hash
  }
  {
    protocol,
    username,
    password,
    hostname,
    port,
    pathname,
    search,
    hash,
    base_url: None,
  }
}

///|
/// Tests a URL string against this pattern and returns match details,
/// or `None` when the URL does not parse or does not match.
///
/// ### Example
///
/// ```mbt check
/// test {
///   let p = try! @urlpattern.UrlPattern::from_string(
///     "https://example.com/users/:id",
///     None,
///   )
///   let result = p.exec_url("https://example.com/users/42")
///   inspect(result is Some(_), content="true")
///   guard result is Some(r) else { fail("no match") }
///   guard r.pathname() is Some(pr) else { fail("no pathname") }
///   inspect(pr.groups()["id"] == Some("42"), content="true")
/// }
/// ```
pub fn UrlPattern::exec_url(
  self : UrlPattern,
  url_str : String,
) -> UrlPatternResult? {
  let url = @url.parse(url_str) catch { _ => return None }
  let scheme = url.scheme()
  let search_raw = url.search()
  let hash_raw = url.hash()
  let init = {
    protocol: Some(scheme),
    username: Some(url.username()),
    password: Some(url.password()),
    hostname: Some(url.hostname()),
    port: Some(url.port_str()),
    pathname: Some(url.pathname()),
    search: Some(@pe.strip_leading_char(search_raw, '?')),
    hash: Some(@pe.strip_leading_char(hash_raw, '#')),
    base_url: None,
  }
  match self.exec_init(init) {
    None => None
    Some(r) =>
      Some({
        inputs: [Str(url_str)],
        protocol: r.protocol,
        username: r.username,
        password: r.password,
        hostname: r.hostname,
        port: r.port,
        pathname: r.pathname,
        search: r.search,
        hash: r.hash,
      })
  }
}

///|
/// Returns `true` if the given `UrlPatternInit` matches this pattern.
pub fn UrlPattern::test_init(self : UrlPattern, init : UrlPatternInit) -> Bool {
  self.exec_init(init) is Some(_)
}

///|
/// Returns `true` if the URL string matches this pattern.
pub fn UrlPattern::test_url(self : UrlPattern, url : String) -> Bool {
  self.exec_url(url) is Some(_)
}

///|
/// Returns the compiled pattern string for the `protocol` component.
pub fn UrlPattern::get_protocol(self : UrlPattern) -> String {
  self.protocol.pattern
}

///|
/// Returns the compiled pattern string for the `username` component.
pub fn UrlPattern::get_username(self : UrlPattern) -> String {
  self.username.pattern
}

///|
/// Returns the compiled pattern string for the `password` component.
pub fn UrlPattern::get_password(self : UrlPattern) -> String {
  self.password.pattern
}

///|
/// Returns the compiled pattern string for the `hostname` component.
pub fn UrlPattern::get_hostname(self : UrlPattern) -> String {
  self.hostname.pattern
}

///|
/// Returns the compiled pattern string for the `port` component.
pub fn UrlPattern::get_port(self : UrlPattern) -> String {
  self.port.pattern
}

///|
/// Returns the compiled pattern string for the `pathname` component.
pub fn UrlPattern::get_pathname(self : UrlPattern) -> String {
  self.pathname.pattern
}

///|
/// Returns the compiled pattern string for the `search` component.
pub fn UrlPattern::get_search(self : UrlPattern) -> String {
  self.search.pattern
}

///|
/// Returns the compiled pattern string for the `hash` component.
pub fn UrlPattern::get_hash(self : UrlPattern) -> String {
  self.hash.pattern
}

///|
/// Returns `true` if any component contains at least one regexp capturing group.
///
/// ### Example
///
/// ```mbt check
/// test {
///   let with_group = try! @urlpattern.UrlPattern::from_string(
///     "https://example.com/(hi)",
///     None,
///   )
///   inspect(with_group.has_regexp_groups(), content="true")
///   let wildcard = try! @urlpattern.UrlPattern::from_string(
///     "https://example.com/*",
///     None,
///   )
///   inspect(wildcard.has_regexp_groups(), content="false")
/// }
/// ```
pub fn UrlPattern::has_regexp_groups(self : UrlPattern) -> Bool {
  self.protocol.has_regexp_groups ||
  self.username.has_regexp_groups ||
  self.password.has_regexp_groups ||
  self.hostname.has_regexp_groups ||
  self.port.has_regexp_groups ||
  self.pathname.has_regexp_groups ||
  self.search.has_regexp_groups ||
  self.hash.has_regexp_groups
}

///|
fn delimiter_for_kind(kind : ComponentKind) -> Char? {
  match kind {
    Pathname => Some('/')
    Hostname => Some('.')
    _ => None
  }
}

///|
fn encode_value_for_generate(v : String, kind : ComponentKind) -> String {
  match kind {
    Pathname => @pe.percent_encode_path_seg(v)
    OpaquePathname => v
    Hostname => canonicalize_hostname_for_pattern(v) catch { _ => v }
    Username => @pe.percent_encode_userinfo(v)
    Password => @pe.percent_encode_userinfo(v)
    Search => @pe.percent_encode_query(v, false)
    Hash => @pe.percent_encode_fragment(v)
    Protocol => canonicalize_protocol_for_pattern(v) catch { _ => v }
    Port => canonicalize_port(v, "")
  }
}

///|
fn generate_component_string(
  parts : Array[Part],
  kind : ComponentKind,
  groups : Map[String, String],
) -> String? {
  let buf = StringBuilder()
  let delim = delimiter_for_kind(kind)
  for part in parts {
    match part.kind {
      FixedText => {
        if part.modifier != NoMod {
          return None
        }
        buf.write_string(part.value)
      }
      _ =>
        match groups.get(part.name) {
          None =>
            match part.modifier {
              Optional | ZeroOrMore => ()
              _ => return None
            }
          Some(v) => {
            if part.kind == SegmentWildcard {
              match delim {
                Some(d) =>
                  for c in v {
                    if c == d {
                      return None
                    }
                  }
                None => ()
              }
            }
            let encoded = encode_value_for_generate(v, kind)
            buf.write_string(part.prefix)
            buf.write_string(encoded)
            buf.write_string(part.suffix)
          }
        }
    }
  }
  Some(buf.to_string())
}

///|
/// Reconstructs a URL component string by substituting named group values from
/// `groups` into the compiled pattern; returns `None` when a required group is
/// absent or a wildcard value contains a delimiter character.
///
/// - `component` : Which URL component to generate.
/// - `groups` : Map of named group names to their string values.
///
/// ### Example
///
/// ```mbt check
/// test {
///   let p = try! @urlpattern.UrlPattern::from_string(
///     "https://example.com/users/:id",
///     None,
///   )
///   let groups : Map[String, String] = { "id": "42" }
///   inspect(p.generate(Pathname, groups) == Some("/users/42"), content="true")
/// }
/// ```
pub fn UrlPattern::generate(
  self : UrlPattern,
  component : UrlPatternComponent,
  groups : Map[String, String],
) -> String? {
  let comp = get_urlpattern_component(self, component)
  generate_component_string(comp.parts, comp.kind, groups)
}

///|
fn compare_str_lex(a : String, b : String) -> Int32 {
  let la = a.length()
  let lb = b.length()
  let n = if la < lb { la } else { lb }
  for i in 0..<n {
    let ca = a.unsafe_get(i).to_int()
    let cb = b.unsafe_get(i).to_int()
    if ca != cb {
      return if ca < cb { -1 } else { 1 }
    }
  }
  if la < lb {
    -1
  } else if la > lb {
    1
  } else {
    0
  }
}

///|
fn effective_part_kind(part : Part) -> PartType {
  if part.kind == FixedText && part.modifier != NoMod {
    Regexp
  } else {
    part.kind
  }
}

///|
fn merge_fixed_text_parts(parts : Array[Part]) -> Array[Part] {
  let result : Array[Part] = []
  for part in parts {
    let n = result.length()
    if n > 0 {
      let last = result[n - 1]
      if last.kind == FixedText &&
        last.modifier == NoMod &&
        part.kind == FixedText &&
        part.modifier == NoMod {
        result[n - 1] = {
          kind: FixedText,
          value: last.value + part.value,
          modifier: NoMod,
          name: "",
          prefix: "",
          suffix: "",
        }
        continue
      }
    }
    result.push(part)
  }
  result
}

///|
fn compare_pattern_parts(left : Part, right : Part) -> Int32 {
  let lkind = effective_part_kind(left)
  let rkind = effective_part_kind(right)
  if lkind == FixedText && rkind == FixedText {
    return compare_str_lex(left.value, right.value)
  }
  if lkind == FixedText {
    return 1
  }
  if rkind == FixedText {
    return -1
  }
  let r = compare_str_lex(
    left.prefix + left.suffix,
    right.prefix + right.suffix,
  )
  if r != 0 {
    return r
  }
  if left.modifier == right.modifier {
    if lkind == Regexp && rkind == Regexp {
      let lv = if left.kind == FixedText {
        escape_regexp_string(left.value)
      } else {
        left.value
      }
      let rv = if right.kind == FixedText {
        escape_regexp_string(right.value)
      } else {
        right.value
      }
      return compare_str_lex(lv, rv)
    }
    if lkind == Regexp {
      return 1
    }
    if rkind == Regexp {
      return -1
    }
    if lkind == SegmentWildcard && rkind != SegmentWildcard {
      return 1
    }
    if rkind == SegmentWildcard && lkind != SegmentWildcard {
      return -1
    }
    return 0
  }
  if left.modifier == NoMod {
    return 1
  }
  if right.modifier == NoMod {
    return -1
  }
  if left.modifier == OneOrMore {
    return 1
  }
  if right.modifier == OneOrMore {
    return -1
  }
  if left.modifier == Optional {
    return 1
  }
  if right.modifier == Optional {
    return -1
  }
  0
}

///|
fn compare_pattern_part_lists(left : Array[Part], right : Array[Part]) -> Int32 {
  let lm = merge_fixed_text_parts(left)
  let rm = merge_fixed_text_parts(right)
  let n = if lm.length() < rm.length() { lm.length() } else { rm.length() }
  for i in 0..<n {
    let r = compare_pattern_parts(lm[i], rm[i])
    if r != 0 {
      return r
    }
  }
  if lm.length() > rm.length() {
    1
  } else if lm.length() < rm.length() {
    -1
  } else {
    0
  }
}

///|
fn get_urlpattern_component(
  pattern : UrlPattern,
  component : UrlPatternComponent,
) -> CompiledComponent {
  match component {
    Protocol => pattern.protocol
    Username => pattern.username
    Password => pattern.password
    Hostname => pattern.hostname
    Port => pattern.port
    Pathname => pattern.pathname
    Search => pattern.search
    Hash => pattern.hash
  }
}

///|
/// Compares the specificity of two patterns for a given `component`.
/// Returns `1` if `left` is more specific, `-1` if `right` is more specific,
/// and `0` if they are equally specific.
pub fn UrlPattern::compare_component(
  component : UrlPatternComponent,
  left : UrlPattern,
  right : UrlPattern,
) -> Int32 {
  let lc = get_urlpattern_component(left, component)
  let rc = get_urlpattern_component(right, component)
  compare_pattern_part_lists(lc.parts, rc.parts)
}
