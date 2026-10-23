///|
/// Per-component pattern strings used to construct a `UrlPattern`.
/// Each field is a pattern string for the corresponding URL component;
/// `None` means "use the wildcard default".
pub struct UrlPatternInit {
  priv protocol : String?
  priv username : String?
  priv password : String?
  priv hostname : String?
  priv port : String?
  priv pathname : String?
  priv search : String?
  priv hash : String?
  priv base_url : String?
} derive(Debug)

///|
pub extend UrlPatternInit with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Creates a `UrlPatternInit` with per-component pattern strings; all fields
/// default to `None` (wildcard) when omitted.
pub fn UrlPatternInit::new(
  protocol~ : String? = None,
  username~ : String? = None,
  password~ : String? = None,
  hostname~ : String? = None,
  port~ : String? = None,
  pathname~ : String? = None,
  search~ : String? = None,
  hash~ : String? = None,
  base_url~ : String? = None,
) -> UrlPatternInit {
  {
    protocol,
    username,
    password,
    hostname,
    port,
    pathname,
    search,
    hash,
    base_url,
  }
}

///|
/// Input accepted by `exec` and `test` methods: either a URL string or a
/// per-component `UrlPatternInit`.
pub enum UrlPatternInput {
  Str(String)
  Init(UrlPatternInit)
} derive(Debug)

///|
pub extend UrlPatternInput with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Match result for a single URL component: the matched input string and a
/// map of named capture group names to their matched values.
pub struct UrlPatternComponentResult {
  priv input : String
  priv groups : Map[String, String?]
} derive(Debug)

///|
pub extend UrlPatternComponentResult with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
/// Returns the input string that was matched against this component's pattern.
pub fn UrlPatternComponentResult::input(
  self : UrlPatternComponentResult,
) -> String {
  self.input
}

///|
/// Returns the map of named capture group names to their matched values.
pub fn UrlPatternComponentResult::groups(
  self : UrlPatternComponentResult,
) -> Map[String, String?] {
  self.groups
}

///|
/// Aggregate match result returned by `exec_url` and `exec_init`, containing
/// per-component results for every URL component.
pub struct UrlPatternResult {
  priv inputs : Array[UrlPatternInput]
  priv protocol : UrlPatternComponentResult?
  priv username : UrlPatternComponentResult?
  priv password : UrlPatternComponentResult?
  priv hostname : UrlPatternComponentResult?
  priv port : UrlPatternComponentResult?
  priv pathname : UrlPatternComponentResult?
  priv search : UrlPatternComponentResult?
  priv hash : UrlPatternComponentResult?
} derive(Debug)

///|
pub extend UrlPatternResult with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Returns the inputs array that was matched against this pattern.
pub fn UrlPatternResult::inputs(
  self : UrlPatternResult,
) -> Array[UrlPatternInput] {
  self.inputs
}

///|
/// Returns the match result for the `protocol` component, or `None`.
pub fn UrlPatternResult::protocol(
  self : UrlPatternResult,
) -> UrlPatternComponentResult? {
  self.protocol
}

///|
/// Returns the match result for the `username` component, or `None`.
pub fn UrlPatternResult::username(
  self : UrlPatternResult,
) -> UrlPatternComponentResult? {
  self.username
}

///|
/// Returns the match result for the `password` component, or `None`.
pub fn UrlPatternResult::password(
  self : UrlPatternResult,
) -> UrlPatternComponentResult? {
  self.password
}

///|
/// Returns the match result for the `hostname` component, or `None`.
pub fn UrlPatternResult::hostname(
  self : UrlPatternResult,
) -> UrlPatternComponentResult? {
  self.hostname
}

///|
/// Returns the match result for the `port` component, or `None`.
pub fn UrlPatternResult::port(
  self : UrlPatternResult,
) -> UrlPatternComponentResult? {
  self.port
}

///|
/// Returns the match result for the `pathname` component, or `None`.
pub fn UrlPatternResult::pathname(
  self : UrlPatternResult,
) -> UrlPatternComponentResult? {
  self.pathname
}

///|
/// Returns the match result for the `search` component, or `None`.
pub fn UrlPatternResult::search(
  self : UrlPatternResult,
) -> UrlPatternComponentResult? {
  self.search
}

///|
/// Returns the match result for the `hash` component, or `None`.
pub fn UrlPatternResult::hash(
  self : UrlPatternResult,
) -> UrlPatternComponentResult? {
  self.hash
}

///|
/// Error raised when a `UrlPattern` cannot be constructed due to an invalid pattern.
pub suberror UrlPatternError {
  UrlPatternError(String)
}

///|
pub impl Show for UrlPatternError with fn output(self, logger) {
  match self {
    UrlPatternError(msg) => logger.write_string("UrlPatternError: " + msg)
  }
}

///|
pub extend UrlPatternError with Show::{to_string, output}

///|
/// Identifies one of the eight URL components a `UrlPattern` operates on.
/// Used by `UrlPattern::compare_component` and `UrlPattern::generate` to
/// select which part of the pattern to act on.
pub(all) enum UrlPatternComponent {
  Protocol
  Username
  Password
  Hostname
  Port
  Pathname
  Search
  Hash
} derive(Eq, Debug)

///|
pub extend UrlPatternComponent with Eq::{not_equal, equal}

///|
pub extend UrlPatternComponent with @moonbitlang/core/debug.Debug::{to_repr}

///|
priv struct CompiledComponent {
  pattern : String
  regex : @string.Regex
  group_names : Array[String]
  group_strips : Array[(String, String)]
  parts : Array[Part]
  has_regexp_groups : Bool
  kind : ComponentKind
}

///|
/// A compiled WHATWG URL pattern that matches and extracts named groups from URLs.
pub struct UrlPattern {
  priv protocol : CompiledComponent
  priv username : CompiledComponent
  priv password : CompiledComponent
  priv hostname : CompiledComponent
  priv port : CompiledComponent
  priv pathname : CompiledComponent
  priv search : CompiledComponent
  priv hash : CompiledComponent
}
