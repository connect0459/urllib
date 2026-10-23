///|
using @host {type Host}

///|
/// The path of a parsed URL: either an ordered list of decoded path segments
/// or an opaque string for cannot-be-a-base URLs.
enum UrlPath {
  Segments(Array[String])
  Opaque(String)
} derive(Debug)

///|
pub extend UrlPath with @moonbitlang/core/debug.Debug::{to_repr}

///|
impl Eq for UrlPath with fn equal(self : UrlPath, other : UrlPath) -> Bool {
  match (self, other) {
    (Segments(a), Segments(b)) => a == b
    (Opaque(a), Opaque(b)) => a == b
    _ => false
  }
}

///|
/// Error raised when a URL string fails to parse.
pub suberror UrlParseError {
  UrlParseError(String)
}

///|
pub impl Show for UrlParseError with fn output(self, logger) {
  match self {
    UrlParseError(msg) => logger.write_string("UrlParseError: " + msg)
  }
}

///|
pub extend UrlParseError with Show::{to_string, output}

///|
/// An immutable parsed URL. All setter methods return a new `Url` value
/// rather than modifying this one.
pub struct Url {
  priv scheme : String
  priv username : String
  priv password : String
  priv host : Host?
  priv port : Int32?
  priv path : UrlPath
  priv query : String?
  priv fragment : String?
} derive(Eq, Debug)

///|
pub extend Url with Eq::{not_equal, equal}

///|
pub extend Url with @moonbitlang/core/debug.Debug::{to_repr}

///|
priv struct UrlRecord {
  mut scheme : String
  mut username : String
  mut password : String
  mut host : Host?
  mut port : Int32?
  mut path : UrlPath
  mut query : String?
  mut fragment : String?
}

///|
fn UrlRecord::new() -> UrlRecord {
  {
    scheme: "",
    username: "",
    password: "",
    host: None,
    port: None,
    path: UrlPath::Segments([]),
    query: None,
    fragment: None,
  }
}

///|
fn UrlRecord::copy_path_from(self : UrlRecord, other : Url) -> Unit {
  self.path = match other.path {
    Segments(segs) => UrlPath::Segments(segs.copy())
    Opaque(s) => UrlPath::Opaque(s)
  }
}

///|
fn UrlRecord::path_segs(self : UrlRecord) -> Array[String] {
  match self.path {
    Segments(s) => s
    _ => panic()
  }
}

///|
fn UrlRecord::copy_authority_from(self : UrlRecord, other : Url) -> Unit {
  self.username = other.username
  self.password = other.password
  self.host = other.host
  self.port = other.port
}

///|
fn UrlRecord::copy_from(self : UrlRecord, other : Url) -> Unit {
  self.scheme = other.scheme
  self.copy_authority_from(other)
  self.copy_path_from(other)
  self.query = other.query
  self.fragment = other.fragment
}

///|
fn UrlRecord::to_url(self : UrlRecord) -> Url {
  let path = match self.path {
    Segments(s) => UrlPath::Segments(s.copy())
    Opaque(s) => UrlPath::Opaque(s)
  }
  {
    scheme: self.scheme,
    username: self.username,
    password: self.password,
    host: self.host,
    port: self.port,
    path,
    query: self.query,
    fragment: self.fragment,
  }
}

///|
fn UrlRecord::is_special(self : UrlRecord) -> Bool {
  is_special_scheme(self.scheme)
}

///|
fn is_special_scheme(scheme : String) -> Bool {
  match scheme {
    "ftp" | "file" | "http" | "https" | "ws" | "wss" => true
    _ => false
  }
}

///|
fn special_scheme_default_port(scheme : String) -> Int32? {
  match scheme {
    "ftp" => Some(21)
    "http" | "ws" => Some(80)
    "https" | "wss" => Some(443)
    _ => None
  }
}
