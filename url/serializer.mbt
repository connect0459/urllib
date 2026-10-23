///|
fn write_credentials(buf : StringBuilder, url : Url) -> Unit {
  if url.username != "" || url.password != "" {
    buf.write_string(url.username)
    if url.password != "" {
      buf.write_char(':')
      buf.write_string(url.password)
    }
    buf.write_char('@')
  }
}

///|
fn write_query(buf : StringBuilder, query : String?) -> Unit {
  match query {
    Some(q) => {
      buf.write_char('?')
      buf.write_string(q)
    }
    None => ()
  }
}

///|
fn write_fragment(buf : StringBuilder, fragment : String?) -> Unit {
  match fragment {
    Some(f) => {
      buf.write_char('#')
      buf.write_string(f)
    }
    None => ()
  }
}

///|
fn write_port(buf : StringBuilder, port : Int32?) -> Unit {
  match port {
    Some(p) => {
      buf.write_char(':')
      buf.write_string(p.to_string())
    }
    None => ()
  }
}

///|
fn write_authority_components(buf : StringBuilder, url : Url, h : Host) -> Unit {
  write_credentials(buf, url)
  buf.write_string(@host.serialize_host(h))
  write_port(buf, url.port)
}

///|
/// Returns the full serialized URL string.
pub fn Url::href(self : Url) -> String {
  let buf = StringBuilder()
  buf.write_string(self.scheme)
  buf.write_char(':')
  match self.host {
    None => ()
    Some(h) => {
      buf.write_string("//")
      write_authority_components(buf, self, h)
    }
  }
  match self.path {
    Opaque(s) => buf.write_string(s)
    Segments(segs) =>
      if segs.is_empty() {
        if self.host != None && is_special_scheme(self.scheme) {
          buf.write_char('/')
        }
      } else {
        if self.host == None && segs.length() > 1 && segs[0] == "" {
          buf.write_string("/.")
        }
        for seg in segs {
          buf.write_char('/')
          buf.write_string(seg)
        }
      }
  }
  write_query(buf, self.query)
  write_fragment(buf, self.fragment)
  buf.to_string()
}

///|
/// Returns the serialized origin of this URL, or `"null"` for opaque origins.
pub fn Url::origin(self : Url) -> String {
  if is_special_scheme(self.scheme) && self.scheme != "file" {
    let buf = StringBuilder()
    buf.write_string(self.scheme)
    buf.write_string("://")
    match self.host {
      Some(h) => buf.write_string(@host.serialize_host(h))
      None => ()
    }
    write_port(buf, self.port)
    buf.to_string()
  } else if self.scheme == "blob" {
    let inner = parse_with_base(self.pathname(), None) catch {
      _ => return "null"
    }
    if inner.scheme != "http" && inner.scheme != "https" {
      "null"
    } else {
      inner.origin()
    }
  } else {
    "null"
  }
}

///|
/// Returns the scheme followed by a colon (e.g. `"https:"`).
pub fn Url::protocol(self : Url) -> String {
  self.scheme + ":"
}

///|
/// Returns the serialized host without port; IPv6 addresses are bracketed.
pub fn Url::hostname(self : Url) -> String {
  match self.host {
    Some(h) => @host.serialize_host(h)
    None => ""
  }
}

///|
/// Returns the serialized host with port if present (e.g. `"example.com:8080"`).
pub fn Url::host_str(self : Url) -> String {
  match self.host {
    None => ""
    Some(h) => {
      let serialized = @host.serialize_host(h)
      match self.port {
        None => serialized
        Some(p) => serialized + ":" + p.to_string()
      }
    }
  }
}

///|
/// Returns the port as a decimal string, or `""` when absent.
pub fn Url::port_str(self : Url) -> String {
  match self.port {
    None => ""
    Some(p) => p.to_string()
  }
}

///|
/// Returns the serialized path (e.g. `"/path/to/resource"`).
pub fn Url::pathname(self : Url) -> String {
  match self.path {
    Opaque(s) => s
    Segments(segs) =>
      if segs.is_empty() {
        if is_special_scheme(self.scheme) {
          "/"
        } else {
          ""
        }
      } else {
        let buf = StringBuilder()
        for seg in segs {
          buf.write_char('/')
          buf.write_string(seg)
        }
        buf.to_string()
      }
  }
}

///|
/// Returns the query string prefixed with `"?"`, or `""` when absent or empty.
pub fn Url::search(self : Url) -> String {
  match self.query {
    None | Some("") => ""
    Some(q) => "?" + q
  }
}

///|
/// Returns the fragment prefixed with `"#"`, or `""` when absent or empty.
pub fn Url::hash(self : Url) -> String {
  match self.fragment {
    None | Some("") => ""
    Some(f) => "#" + f
  }
}

///|
pub impl Show for Url with fn output(self, logger) {
  logger.write_string(self.href())
}

///|
pub extend Url with Show::{to_string, output}
