///|
/// Returns `true` if `url` (optionally resolved against `base`) parses without error.
///
/// ### Example
///
/// ```mbt check
/// test {
///   inspect(@url.can_parse("https://example.com", None), content="true")
///   inspect(@url.can_parse("not a url", None), content="false")
/// }
/// ```
pub fn can_parse(url : String, base : Url?) -> Bool {
  (parse_with_base(url, base) catch { _ => return false }) |> ignore
  true
}

///|
/// Parses `url` (optionally against `base`), returning `None` on failure instead of raising.
///
/// ### Example
///
/// ```mbt check
/// test {
///   inspect(
///     @url.parse_maybe("https://example.com", None) is Some(_),
///     content="true",
///   )
///   inspect(@url.parse_maybe("not a url", None) is None, content="true")
/// }
/// ```
pub fn parse_maybe(url : String, base : Url?) -> Url? {
  Some(parse_with_base(url, base)) catch {
    _ => None
  }
}

///|
/// Serializes the URL as a JSON string value (equivalent to `href()`).
pub impl ToJson for Url with fn to_json(self : Url) -> Json {
  Json::string(self.href())
}

///|
pub extend Url with ToJson::{to_json}

///|
/// Returns `true` when the scheme is one of the WHATWG special schemes
/// (`ftp`, `file`, `http`, `https`, `ws`, `wss`).
pub fn Url::is_special(self : Url) -> Bool {
  is_special_scheme(self.scheme)
}

///|
/// Returns `true` when the URL has a non-empty username or password.
pub fn Url::has_credentials(self : Url) -> Bool {
  self.username != "" || self.password != ""
}

///|
/// Returns `true` when the URL has an opaque path (cannot-be-a-base URL).
pub fn Url::has_opaque_path(self : Url) -> Bool {
  self.path is UrlPath::Opaque(_)
}

///|
/// Resolves `url` relative to this URL; raises `UrlParseError` on failure.
///
/// ### Example
///
/// ```mbt check
/// test {
///   let base = try! @url.parse("https://example.com/a/b/")
///   inspect((try! base.join("../c")).href(), content="https://example.com/a/c")
/// }
/// ```
pub fn Url::join(self : Url, url : String) -> Url raise UrlParseError {
  parse_with_base(url, Some(self))
}

///|
/// Returns the URL query string parsed as `UrlSearchParams`; an absent or empty
/// query produces an empty `UrlSearchParams`.
///
/// ### Example
///
/// ```mbt check
/// test {
///   let url = try! @url.parse("https://example.com/?a=1&b=2")
///   inspect(url.search_params().get("a") == Some("1"), content="true")
/// }
/// ```
pub fn Url::search_params(self : Url) -> UrlSearchParams {
  match self.query {
    None | Some("") => UrlSearchParams::new()
    Some(q) => parse_urlencoded(q)
  }
}

///|
/// Returns the URL scheme without the trailing colon (e.g. `"https"`).
pub fn Url::scheme(self : Url) -> String {
  self.scheme
}

///|
/// Returns the percent-encoded username, or `""` when absent.
pub fn Url::username(self : Url) -> String {
  self.username
}

///|
/// Returns the percent-encoded password, or `""` when absent.
pub fn Url::password(self : Url) -> String {
  self.password
}

///|
/// Returns the port number, or `None` when absent or equal to the scheme default.
pub fn Url::port(self : Url) -> Int32? {
  self.port
}

///|
/// Returns an iterator over percent-encoded path segments, or `None` for opaque-path URLs.
pub fn Url::path_segments(self : Url) -> Iter[String]? {
  match self.path {
    UrlPath::Opaque(_) => None
    UrlPath::Segments(segs) => Some(segs.iter())
  }
}

///|
/// Converts a domain name to its ACE/Punycode form per UTS#46;
/// returns `""` on error.
///
/// ### Example
///
/// ```mbt check
/// test {
///   inspect(@url.domain_to_ascii("例え.jp"), content="xn--r8jz45g.jp")
///   inspect(@url.domain_to_ascii("EXAMPLE.COM"), content="example.com")
/// }
/// ```
pub fn domain_to_ascii(domain : String) -> String {
  @idna.domain_to_ascii(domain) catch {
    _ => ""
  }
}

///|
/// Converts an ACE-encoded domain to its Unicode form per UTS#46;
/// returns `""` on error.
///
/// ### Example
///
/// ```mbt check
/// test {
///   inspect(@url.domain_to_unicode("xn--r8jz45g.jp"), content="例え.jp")
///   inspect(@url.domain_to_unicode("example.com"), content="example.com")
/// }
/// ```
pub fn domain_to_unicode(domain : String) -> String {
  @idna.domain_to_unicode(domain) catch {
    _ => ""
  }
}

///|
/// Returns `true` when this URL has an authority component (i.e. a `://`
/// separator is present and a host is stored).
///
/// ### Example
///
/// ```mbt check
/// test {
///   inspect(@url.parse("https://example.com/").has_authority(), content="true")
///   inspect(@url.parse("data:text/plain,Hello").has_authority(), content="false")
/// }
/// ```
pub fn Url::has_authority(self : Url) -> Bool {
  self.host != None
}

///|
/// Returns the authority component (`[user[:pass]@]host[:port]`), or `""`
/// when no authority is present.
///
/// ### Example
///
/// ```mbt check
/// test {
///   inspect(
///     @url.parse("https://user:pass@example.com:8080/").authority(),
///     content="user:pass@example.com:8080",
///   )
///   inspect(@url.parse("data:text/plain,Hello").authority(), content="")
/// }
/// ```
pub fn Url::authority(self : Url) -> String {
  match self.host {
    None => ""
    Some(h) => {
      let buf = StringBuilder()
      write_authority_components(buf, self, h)
      buf.to_string()
    }
  }
}

///|
/// Returns the domain string when the host is a domain name, or `None` for
/// IP addresses and URLs without a host.
///
/// ### Example
///
/// ```mbt check
/// test {
///   inspect(
///     @url.parse("https://example.com/").domain() == Some("example.com"),
///     content="true",
///   )
///   inspect(@url.parse("https://127.0.0.1/").domain() is None, content="true")
/// }
/// ```
pub fn Url::domain(self : Url) -> String? {
  match self.host {
    Some(Host::Domain(s)) => Some(s)
    _ => None
  }
}

///|
/// Returns a relative URL string that, when resolved against `self`, yields
/// `other`. Returns `None` when a relative URL cannot be computed (different
/// scheme, host, or port; or when `self` has an opaque path).
///
/// ### Example
///
/// ```mbt check
/// test {
///   let base = @url.parse("https://example.net/a/b/")
///   let url = @url.parse("https://example.net/a/d/c.png")
///   inspect(base.make_relative(url) == Some("../d/c.png"), content="true")
/// }
/// ```
pub fn Url::make_relative(self : Url, other : Url) -> String? {
  if self.scheme != other.scheme ||
    self.host != other.host ||
    self.port != other.port {
    return None
  }
  let base_segs = match self.path {
    UrlPath::Opaque(_) => return None
    UrlPath::Segments(s) => s
  }
  let url_segs = match other.path {
    UrlPath::Opaque(_) => return None
    UrlPath::Segments(s) => s
  }
  let (base_dir, base_filename) = dir_and_filename(base_segs)
  let (url_dir, url_filename) = dir_and_filename(url_segs)
  let common_len = for n = 0 {
    if n >= base_dir.length() ||
      n >= url_dir.length() ||
      base_dir[n] != url_dir[n] {
      break n
    }
    continue n + 1
  }
  let path_parts : Array[String] = []
  for seg in base_dir[common_len:] {
    if seg != "" {
      path_parts.push("..")
    }
  }
  for seg in url_dir[common_len:] {
    path_parts.push(seg)
  }
  let buf = StringBuilder()
  if path_parts.length() > 0 || base_filename != url_filename {
    if url_filename == "" {
      if path_parts.length() > 0 {
        buf.write_string(path_parts.join("/") + "/")
      } else {
        buf.write_string("./")
      }
    } else {
      if path_parts.length() > 0 {
        buf.write_string(path_parts.join("/") + "/")
      }
      buf.write_string(url_filename)
    }
  }
  write_query(buf, other.query)
  write_fragment(buf, other.fragment)
  Some(buf.to_string())
}

///|
/// Returns the port if explicitly set, otherwise the default port for the
/// scheme (`http`/`ws`→80, `https`/`wss`→443, `ftp`→21). Returns `None`
/// when neither is available.
///
/// ### Example
///
/// ```mbt check
/// test {
///   inspect(
///     @url.parse("https://example.com/").port_or_known_default() == Some(443),
///     content="true",
///   )
///   inspect(
///     @url.parse("https://example.com:8080/").port_or_known_default() ==
///     Some(8080),
///     content="true",
///   )
///   inspect(
///     @url.parse("custom://example.com/").port_or_known_default() is None,
///     content="true",
///   )
/// }
/// ```
pub fn Url::port_or_known_default(self : Url) -> Int32? {
  match self.port {
    Some(_) as p => p
    None => special_scheme_default_port(self.scheme)
  }
}

///|
/// Returns the raw query string without the leading `?`, or `None` when the
/// URL has no query component.
///
/// ### Example
///
/// ```mbt check
/// test {
///   inspect(
///     @url.parse("https://example.com/?a=1").query() == Some("a=1"),
///     content="true",
///   )
///   inspect(@url.parse("https://example.com/").query() is None, content="true")
/// }
/// ```
pub fn Url::query(self : Url) -> String? {
  self.query
}

///|
/// Returns the raw fragment string without the leading `#`, or `None` when the
/// URL has no fragment component.
///
/// ### Example
///
/// ```mbt check
/// test {
///   inspect(
///     @url.parse("https://example.com/#section").fragment() == Some("section"),
///     content="true",
///   )
///   inspect(@url.parse("https://example.com/").fragment() is None, content="true")
/// }
/// ```
pub fn Url::fragment(self : Url) -> String? {
  self.fragment
}

///|
/// Returns `true` when the URL has a host component (i.e. the host is non-`None`).
pub fn Url::has_host(self : Url) -> Bool {
  self.has_authority()
}

///|
/// Returns `true` when the URL has an explicitly set port number.
pub fn Url::has_port(self : Url) -> Bool {
  self.port is Some(_)
}

///|
/// Returns `true` when the URL has a query component (even if empty).
pub fn Url::has_query(self : Url) -> Bool {
  self.query is Some(_)
}

///|
/// Returns `true` when the URL has a fragment component (even if empty).
pub fn Url::has_fragment(self : Url) -> Bool {
  self.fragment is Some(_)
}

///|
/// Parses `url` and appends `params` as query parameters.
/// Existing query parameters are preserved; new ones are appended with `&`.
/// Raises `UrlParseError` if `url` cannot be parsed.
///
/// ### Example
///
/// ```mbt check
/// test {
///   let url = try! @url.parse_with_params("https://example.net?k=v", [
///     ("lang", "rust"),
///   ])
///   inspect(url.href(), content="https://example.net/?k=v&lang=rust")
/// }
/// ```
pub fn parse_with_params(
  url : String,
  params : Array[(String, String)],
) -> Url raise UrlParseError {
  let u = parse(url)
  if params.is_empty() {
    return u
  }
  let new_sp = UrlSearchParams::new()
  for kv in params {
    new_sp.append(kv.0, kv.1)
  }
  let appended = new_sp.to_string()
  let query_str = match u.query {
    Some(q) if q != "" => q + "&" + appended
    _ => appended
  }
  u.set_search(query_str)
}

///|
/// Converts an absolute filesystem path to a `file://` URL.
/// Raises `UrlParseError` when the path is empty or not absolute.
///
/// On Windows, paths starting with a drive letter (`C:\` or `C:/`) are
/// accepted; backslashes are treated as path separators.
///
/// ### Example
///
/// ```mbt check
/// test {
///   let url = try! @url.from_file_path("/usr/local/bin")
///   inspect(url.href(), content="file:///usr/local/bin")
/// }
/// ```
pub fn from_file_path(path : String) -> Url raise UrlParseError {
  if path.is_empty() {
    raise UrlParseError("path is empty")
  }
  let is_win = is_windows_drive_letter(path)
  if !is_win && path.get_char(0).unwrap_or(' ') != '/' {
    raise UrlParseError("path is not absolute")
  }
  let raw_segs : Array[String] = []
  let seg_buf = StringBuilder()
  for c in path {
    if c == '/' || c == '\\' {
      raw_segs.push(seg_buf.to_string())
      seg_buf.reset()
    } else {
      seg_buf.write_char(c)
    }
  }
  raw_segs.push(seg_buf.to_string())
  let url_buf = StringBuilder()
  url_buf.write_string("file:///")
  let start = if is_win { 0 } else { 1 }
  for i, seg in raw_segs[start:] {
    if i > 0 {
      url_buf.write_char('/')
    }
    if is_win && i == 0 {
      url_buf.write_string(seg)
    } else {
      url_buf.write_string(@pe.percent_encode_path_seg(seg))
    }
  }
  parse(url_buf.to_string())
}

///|
/// Returns the filesystem path for a `file://` URL, decoding any
/// percent-encoded characters.
/// Raises `UrlParseError` when the URL is not a `file:` URL, has a
/// non-local host, or has an opaque path.
///
/// ### Example
///
/// ```mbt check
/// test {
///   let url = try! @url.parse("file:///usr/local/bin")
///   inspect(try! url.to_file_path(), content="/usr/local/bin")
/// }
/// ```
pub fn Url::to_file_path(self : Url) -> String raise UrlParseError {
  if self.scheme != "file" {
    raise UrlParseError("URL scheme is not file")
  }
  match self.host {
    None | Some(Host::Domain("")) => ()
    Some(_) => raise UrlParseError("file URL has non-local host")
  }
  match self.path {
    UrlPath::Opaque(_) => raise UrlParseError("file URL has opaque path")
    UrlPath::Segments(segs) => {
      if segs.is_empty() {
        return "/"
      }
      let first_decoded = @pe.percent_decode(segs[0])
      let c0 = first_decoded.get_char(0).unwrap_or(' ')
      let c1 = first_decoded.get_char(1).unwrap_or(' ')
      let is_win_drive = first_decoded.length() == 2 &&
        is_ascii_alpha(c0) &&
        c1 == ':'
      let buf = StringBuilder()
      if !is_win_drive {
        buf.write_char('/')
      }
      for i, seg in segs {
        if i > 0 {
          buf.write_char('/')
        }
        buf.write_string(@pe.percent_decode(seg))
      }
      buf.to_string()
    }
  }
}

///|
/// Converts an absolute filesystem directory path to a `file://` URL,
/// ensuring the URL ends with a `/` so it can serve as a base URL for
/// resolving relative references.
///
/// Behaves like `from_file_path` but guarantees the trailing `/`.
/// Raises `UrlParseError` when the path is empty or not absolute.
///
/// ### Example
///
/// ```mbt check
/// test {
///   let dir = try! @url.from_directory_path("/var/www")
///   inspect(dir.href(), content="file:///var/www/")
///   let page = try! dir.join("index.html")
///   inspect(page.href(), content="file:///var/www/index.html")
/// }
/// ```
pub fn from_directory_path(path : String) -> Url raise UrlParseError {
  let url = from_file_path(path)
  let p = url.pathname()
  if p.has_suffix("/") {
    url
  } else {
    url.set_pathname(p + "/")
  }
}

///|
/// Returns an iterator over the URL query string parsed as
/// `application/x-www-form-urlencoded` key-value pairs.
///
/// Equivalent to `search_params().iter()`. Returns an empty iterator
/// when the URL has no query component.
///
/// ### Example
///
/// ```mbt check
/// test {
///   let url = try! @url.parse("https://example.com/?a=1&b=2")
///   let pairs = url.query_pairs().to_array()
///   inspect(pairs.length(), content="2")
/// }
/// ```
pub fn Url::query_pairs(self : Url) -> Iter[(String, String)] {
  self.search_params().iter()
}

///|
fn dir_and_filename(segs : Array[String]) -> (Array[String], String) {
  match segs {
    [] => ([], "")
    [.. dir, last] => (dir.to_owned(), last)
  }
}
