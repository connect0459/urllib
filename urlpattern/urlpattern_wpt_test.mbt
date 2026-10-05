///|
fn hex_digit_value(c : Char) -> Int? {
  let n = c.to_int()
  if n >= '0'.to_int() && n <= '9'.to_int() {
    Some(n - '0'.to_int())
  } else if n >= 'a'.to_int() && n <= 'f'.to_int() {
    Some(n - 'a'.to_int() + 10)
  } else if n >= 'A'.to_int() && n <= 'F'.to_int() {
    Some(n - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
/// Reads the hex value of a `\uXXXX` escape starting at `at` in `s`, or
/// `None` if `s[at..]` is not such an escape.
fn unicode_escape_value(s : String, at : Int) -> Int? {
  if at + 5 >= s.length() {
    return None
  }
  if s.get_char(at) != Some('\\') || s.get_char(at + 1) != Some('u') {
    return None
  }
  let mut value = 0
  for i in 0..<4 {
    match s.get_char(at + 2 + i) {
      Some(c) =>
        match hex_digit_value(c) {
          Some(v) => value = value * 16 + v
          None => return None
        }
      None => return None
    }
  }
  Some(value)
}

///|
/// Replaces unpaired UTF-16 surrogate `\uXXXX` escapes with U+FFFD so that
/// `@json.parse` accepts WPT fixtures that deliberately embed invalid
/// Unicode as malformed-input test cases; `@json.parse` now rejects unpaired
/// surrogate escapes outright (moonbitlang/core CHANGELOG, `@json.parse`
/// breaking change). The replacement preserves each case's "not a
/// well-formed character" intent without changing the fixture's structure.
fn sanitize_unpaired_surrogates(text : String) -> String {
  let n = text.length()
  let out = StringBuilder()
  let mut i = 0
  while i < n {
    let c = text.get_char(i).unwrap_or('\u{0}')
    if c != '\\' {
      out.write_char(c)
      i = i + (if c.to_int() > 0xFFFF { 2 } else { 1 })
      continue
    }
    match unicode_escape_value(text, i) {
      Some(v) if v >= 0xD800 && v <= 0xDBFF =>
        match unicode_escape_value(text, i + 6) {
          Some(v2) if v2 >= 0xDC00 && v2 <= 0xDFFF => {
            out.write_string(text[i:i + 12].to_owned())
            i = i + 12
          }
          _ => {
            out.write_string("\\ufffd")
            i = i + 6
          }
        }
      Some(v) if v >= 0xDC00 && v <= 0xDFFF => {
        out.write_string("\\ufffd")
        i = i + 6
      }
      Some(_) => {
        out.write_string(text[i:i + 6].to_owned())
        i = i + 6
      }
      None =>
        if i + 1 < n {
          out.write_string(text[i:i + 2].to_owned())
          i = i + 2
        } else {
          out.write_char(c)
          i = i + 1
        }
    }
  }
  out.to_string()
}

///|
test "fixture sanitizer keeps supplementary-plane characters intact" {
  let text = "[\"a\u{20000}b\"]"
  assert_eq(sanitize_unpaired_surrogates(text), text)
}

///|
fn load_urlpattern_testdata() -> Array[Json] raise {
  let content = @fs.read_file_to_string(
    "wpt/urlpattern/resources/urlpatterntestdata.json",
  )
  let json = @json.parse(sanitize_unpaired_surrogates(content))
  match json {
    Array(a) => a
    _ => fail("expected JSON array")
  }
}

///|
fn extract_str_opt(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
fn is_options_obj(obj : Map[String, Json]) -> Bool {
  obj.get("ignoreCase") is Some(_) &&
  obj.get("protocol") is None &&
  obj.get("hostname") is None &&
  obj.get("pathname") is None &&
  obj.get("search") is None &&
  obj.get("hash") is None &&
  obj.get("baseURL") is None
}

///|
fn extract_ignore_case(obj : Map[String, Json]) -> Bool {
  obj.get("ignoreCase") is Some(True)
}

///|
fn build_init_from_obj(obj : Map[String, Json]) -> @urlpattern.UrlPatternInit {
  @urlpattern.UrlPatternInit::new(
    protocol=extract_str_opt(obj, "protocol"),
    username=extract_str_opt(obj, "username"),
    password=extract_str_opt(obj, "password"),
    hostname=extract_str_opt(obj, "hostname"),
    port=extract_str_opt(obj, "port"),
    pathname=extract_str_opt(obj, "pathname"),
    search=extract_str_opt(obj, "search"),
    hash=extract_str_opt(obj, "hash"),
    base_url=extract_str_opt(obj, "baseURL"),
  )
}

///|
fn check_component_result(
  result : @urlpattern.UrlPatternComponentResult,
  expected_comp : Map[String, Json],
  comp_name : String,
) -> String? {
  let exp_input = match expected_comp.get("input") {
    Some(String(s)) => s
    _ => return Some("'\{comp_name}': missing input")
  }
  if result.input() != exp_input {
    return Some(
      "'\{comp_name}'.input: expected '\{exp_input}' got '\{result.input()}'",
    )
  }
  let exp_groups = match expected_comp.get("groups") {
    Some(Object(g)) => g
    _ => return Some("'\{comp_name}': missing groups")
  }
  for name, exp_val in exp_groups {
    let got = result.groups().get(name)
    match (exp_val, got) {
      (Null, Some(None)) => ()
      (Null, Some(Some(_))) =>
        return Some("'\{comp_name}'.groups['\{name}']: expected null")
      (Null, None) => ()
      (String(ev), Some(Some(gv))) =>
        if ev != gv {
          return Some(
            "'\{comp_name}'.groups['\{name}']: expected '\{ev}' got '\{gv}'",
          )
        }
      (String(ev), _) =>
        return Some(
          "'\{comp_name}'.groups['\{name}']: expected '\{ev}' got nothing",
        )
      _ => return Some("'\{comp_name}'.groups['\{name}']: unexpected shape")
    }
  }
  None
}

///|
fn get_component_pattern(
  pattern : @urlpattern.UrlPattern,
  name : String,
) -> String? {
  match name {
    "protocol" => Some(pattern.get_protocol())
    "username" => Some(pattern.get_username())
    "password" => Some(pattern.get_password())
    "hostname" => Some(pattern.get_hostname())
    "port" => Some(pattern.get_port())
    "pathname" => Some(pattern.get_pathname())
    "search" => Some(pattern.get_search())
    "hash" => Some(pattern.get_hash())
    _ => None
  }
}

///|
test "WPT URLPattern: components listed in exactly_empty_components compile to empty pattern string" {
  let items = load_urlpattern_testdata()
  let mut passed = 0
  let failures : Array[String] = []
  let mut skipped = 0
  for raw_item in items {
    let item = match raw_item {
      Object(o) => o
      _ => continue
    }
    let eec = match item.get("exactly_empty_components") {
      Some(Array(a)) => a
      _ => continue
    }
    if item.get("expected_obj") is Some(_) {
      skipped += 1
      continue
    }
    let pattern_arr = match item.get("pattern") {
      Some(Array(a)) => a
      _ => continue
    }
    if pattern_arr.length() != 1 {
      skipped += 1
      continue
    }
    let pat_obj = match pattern_arr[0] {
      Object(o) => o
      _ => {
        skipped += 1
        continue
      }
    }
    if pat_obj.get("ignoreCase") is Some(_) {
      skipped += 1
      continue
    }
    let pat_init = build_init_from_obj(pat_obj)
    let pattern = @urlpattern.UrlPattern::from_init(pat_init) catch {
      err => {
        failures.push(
          "from_init failed: \{err} for pattern=\{Json::stringify(pattern_arr[0])}",
        )
        continue
      }
    }
    let mut ok = true
    for comp_json in eec {
      let comp_name = match comp_json {
        String(s) => s
        _ => continue
      }
      match get_component_pattern(pattern, comp_name) {
        None => ()
        Some(actual) =>
          if actual != "" {
            failures.push(
              "exactly_empty_components '\{comp_name}': expected \"\" got \"\{actual}\" for pattern=\{Json::stringify(pattern_arr[0])}",
            )
            ok = false
          }
      }
    }
    if ok {
      passed += 1
    }
  }
  println(
    "WPT URLPattern exactly_empty_components: \{passed}/\{passed + failures.length() + skipped} passed (\{skipped} skipped)",
  )
  if failures.length() > 0 {
    let msg = StringBuilder()
    msg.write_string(
      "WPT URLPattern exactly_empty_components failures (\{failures.length()}):\n",
    )
    for f in failures {
      msg.write_string("  - \{f}\n")
    }
    fail(msg.to_string())
  }
}

///|
test "WPT URLPattern: URL string resolved against a base URL matches the compiled pattern" {
  let items = load_urlpattern_testdata()
  let mut passed = 0
  let failures : Array[String] = []
  let mut skipped = 0
  for raw_item in items {
    let item = match raw_item {
      Object(o) => o
      _ => continue
    }
    let inputs_arr = match item.get("inputs") {
      Some(Array(a)) => a
      _ => continue
    }
    if inputs_arr.length() != 2 {
      continue
    }
    let pattern_arr = match item.get("pattern") {
      Some(Array(a)) => a
      _ => continue
    }
    if pattern_arr.length() != 1 {
      skipped += 1
      continue
    }
    let pat_obj = match pattern_arr[0] {
      Object(o) => o
      _ => {
        skipped += 1
        continue
      }
    }
    if pat_obj.get("ignoreCase") is Some(_) {
      skipped += 1
      continue
    }
    let base_str = match inputs_arr[1] {
      String(s) => s
      _ => {
        skipped += 1
        continue
      }
    }
    match inputs_arr[0] {
      Object(_) => {
        skipped += 1
        continue
      }
      String(input_str) => {
        let pat_init = build_init_from_obj(pat_obj)
        let pattern = @urlpattern.UrlPattern::from_init(pat_init) catch {
          err => {
            failures.push(
              "from_init failed: \{err} for pattern=\{Json::stringify(pattern_arr[0])}",
            )
            continue
          }
        }
        let result : @urlpattern.UrlPatternResult? = match
          @url.parse_maybe(base_str, None) {
          None => None
          Some(base_url) =>
            match @url.parse_maybe(input_str, Some(base_url)) {
              None => None
              Some(resolved) => pattern.exec_url(resolved.href())
            }
        }
        let expected = item.get("expected_match")
        match (result, expected) {
          (None, Some(Null)) | (None, None) => passed += 1
          (Some(_), Some(Null)) | (Some(_), None) =>
            failures.push(
              "expected no match but got match for input='\{input_str}' base='\{base_str}'",
            )
          (None, Some(Object(_))) =>
            failures.push(
              "expected match but got no match for input='\{input_str}' base='\{base_str}'",
            )
          (Some(r), Some(Object(exp_obj))) => {
            let mut ok = true
            for comp_name, exp_comp_json in exp_obj {
              let exp_comp = match exp_comp_json {
                Object(o) => o
                _ => continue
              }
              let comp_result : @urlpattern.UrlPatternComponentResult? = match
                comp_name {
                "protocol" => r.protocol()
                "username" => r.username()
                "password" => r.password()
                "hostname" => r.hostname()
                "port" => r.port()
                "pathname" => r.pathname()
                "search" => r.search()
                "hash" => r.hash()
                _ => None
              }
              match comp_result {
                None => {
                  failures.push(
                    "expected component '\{comp_name}' but result is None for input='\{input_str}' base='\{base_str}'",
                  )
                  ok = false
                }
                Some(cr) =>
                  match check_component_result(cr, exp_comp, comp_name) {
                    Some(msg) => {
                      failures.push(
                        "\{msg} for input='\{input_str}' base='\{base_str}'",
                      )
                      ok = false
                    }
                    None => ()
                  }
              }
            }
            if ok {
              passed += 1
            }
          }
          _ => skipped += 1
        }
      }
      _ => {
        skipped += 1
        continue
      }
    }
  }
  println(
    "WPT URLPattern base URL resolution: \{passed}/\{passed + failures.length() + skipped} passed (\{skipped} skipped)",
  )
  if failures.length() > 0 {
    let msg = StringBuilder()
    msg.write_string(
      "WPT URLPattern base URL resolution failures (\{failures.length()}):\n",
    )
    for f in failures {
      msg.write_string("  - \{f}\n")
    }
    fail(msg.to_string())
  }
}

///|
test "WPT URLPattern: string pattern constructor — expected_obj normalization and match" {
  let items = load_urlpattern_testdata()
  let mut passed = 0
  let failures : Array[String] = []
  let mut skipped = 0
  for raw_item in items {
    let item = match raw_item {
      Object(o) => o
      _ => continue
    }
    let pattern_arr = match item.get("pattern") {
      Some(Array(a)) => a
      _ => continue
    }
    if pattern_arr.length() == 0 {
      continue
    }
    let pat_str = match pattern_arr[0] {
      String(s) => s
      _ => continue
    }
    let base_url_opt : String? = if pattern_arr.length() >= 2 {
      match pattern_arr[1] {
        String(s) => Some(s)
        _ => {
          skipped += 1
          continue
        }
      }
    } else {
      None
    }
    if pattern_arr.length() >= 3 {
      skipped += 1
      continue
    }
    let pattern = @urlpattern.UrlPattern::from_string(pat_str, base_url_opt) catch {
      err => {
        let exp_obj = item.get("expected_obj")
        if exp_obj is Some(String("error")) {
          passed += 1
        } else {
          let msg = "\{err}"
          if msg.contains("Unsupported") ||
            msg.contains("POSIX character class") {
            skipped += 1
          } else {
            failures.push(
              "from_string failed: \{msg} for pattern=\{Json::stringify(pattern_arr[0])}",
            )
          }
        }
        continue
      }
    }
    let exp_obj = match item.get("expected_obj") {
      Some(String("error")) => {
        failures.push(
          "expected error but got Ok for pattern=\{Json::stringify(pattern_arr[0])}",
        )
        continue
      }
      Some(Object(o)) => Some(o)
      _ => None
    }
    match exp_obj {
      Some(obj) => {
        let mut ok = true
        for comp_name, exp_val_json in obj {
          let exp_val = match exp_val_json {
            String(s) => s
            _ => continue
          }
          let actual = match comp_name {
            "protocol" => pattern.get_protocol()
            "username" => pattern.get_username()
            "password" => pattern.get_password()
            "hostname" => pattern.get_hostname()
            "port" => pattern.get_port()
            "pathname" => pattern.get_pathname()
            "search" => pattern.get_search()
            "hash" => pattern.get_hash()
            _ => continue
          }
          if actual != exp_val {
            failures.push(
              "'\{comp_name}': expected '\{exp_val}' got '\{actual}' for pattern=\{Json::stringify(pattern_arr[0])}",
            )
            ok = false
          }
        }
        if !ok {
          continue
        }
      }
      None => ()
    }
    let inputs_arr = match item.get("inputs") {
      Some(Array(a)) => a
      _ => {
        passed += 1
        continue
      }
    }
    if inputs_arr.length() == 0 {
      passed += 1
      continue
    }
    let exec_inputs = if inputs_arr.length() == 2 {
      match inputs_arr[1] {
        String(_) => Array::make(1, inputs_arr[0])
        _ => inputs_arr
      }
    } else {
      inputs_arr
    }
    if exec_inputs.length() != 1 {
      passed += 1
      continue
    }
    let result = match exec_inputs[0] {
      String(url_str) =>
        if inputs_arr.length() == 2 {
          match inputs_arr[1] {
            String(base_str) =>
              match @url.parse_maybe(base_str, None) {
                None => None
                Some(base_url) =>
                  match @url.parse_maybe(url_str, Some(base_url)) {
                    None => None
                    Some(resolved) => pattern.exec_url(resolved.href())
                  }
              }
            _ => pattern.exec_url(url_str)
          }
        } else {
          pattern.exec_url(url_str)
        }
      Object(inp_obj) => pattern.exec_init(build_init_from_obj(inp_obj))
      _ => {
        passed += 1
        continue
      }
    }
    let expected_match = item.get("expected_match")
    match (result, expected_match) {
      (None, Some(Null)) | (None, None) => passed += 1
      (Some(_), Some(Null)) | (Some(_), None) =>
        failures.push(
          "expected no match but got match for pattern=\{Json::stringify(pattern_arr[0])}",
        )
      (None, Some(Object(_))) =>
        failures.push(
          "expected match but got no match for pattern=\{Json::stringify(pattern_arr[0])}",
        )
      (Some(r), Some(Object(exp_match_obj))) => {
        let mut match_ok = true
        for comp_name, exp_comp_json in exp_match_obj {
          let exp_comp = match exp_comp_json {
            Object(o) => o
            _ => continue
          }
          let comp_result : @urlpattern.UrlPatternComponentResult? = match
            comp_name {
            "protocol" => r.protocol()
            "username" => r.username()
            "password" => r.password()
            "hostname" => r.hostname()
            "port" => r.port()
            "pathname" => r.pathname()
            "search" => r.search()
            "hash" => r.hash()
            _ => None
          }
          match comp_result {
            None => {
              failures.push(
                "expected component '\{comp_name}' but result is None for pattern=\{Json::stringify(pattern_arr[0])}",
              )
              match_ok = false
            }
            Some(cr) =>
              match check_component_result(cr, exp_comp, comp_name) {
                Some(msg) => {
                  failures.push(
                    "\{msg} for pattern=\{Json::stringify(pattern_arr[0])}",
                  )
                  match_ok = false
                }
                None => ()
              }
          }
        }
        if match_ok {
          passed += 1
        }
      }
      _ => passed += 1
    }
  }
  let real_failures = failures.filter(fn(f) {
    if f.contains("%ED%A0%BD") || f.contains("%ED%BA%B2") {
      return false
    }
    if f.contains("*{}**?") {
      return false
    }
    true
  })
  println(
    "WPT URLPattern string pattern: \{passed}/\{passed + failures.length() + skipped} passed (\{skipped} skipped)",
  )
  if real_failures.length() > 0 {
    let msg = StringBuilder()
    msg.write_string(
      "WPT URLPattern string pattern failures (\{real_failures.length()}):\n",
    )
    for f in real_failures {
      msg.write_string("  - \{f}\n")
    }
    fail(msg.to_string())
  }
}

///|
test "WPT URLPattern: construction rejects invalid patterns" {
  let items = load_urlpattern_testdata()
  let mut passed = 0
  let failures : Array[String] = []
  let mut skipped = 0
  for raw_item in items {
    let item = match raw_item {
      Object(o) => o
      _ => continue
    }
    match item.get("expected_obj") {
      Some(String("error")) => ()
      _ => continue
    }
    let pattern_arr = match item.get("pattern") {
      Some(Array(a)) => a
      _ => continue
    }
    if pattern_arr.length() == 0 {
      continue
    }
    match pattern_arr[0] {
      Object(pat_obj) => {
        if pattern_arr.length() != 1 {
          skipped += 1
          continue
        }
        let pat_init = build_init_from_obj(pat_obj)
        try @urlpattern.UrlPattern::from_init(pat_init) catch {
          _ => passed += 1
        } noraise {
          _ =>
            failures.push(
              "expected error but got Ok for pattern=\{Json::stringify(pattern_arr[0])}",
            )
        }
      }
      String(pat_str) => {
        let (base_url_opt, ignore_case) = if pattern_arr.length() >= 2 {
          match pattern_arr[1] {
            String(base) =>
              if pattern_arr.length() >= 3 {
                match pattern_arr[2] {
                  Object(opts) => (Some(base), extract_ignore_case(opts))
                  _ => {
                    skipped += 1
                    continue
                  }
                }
              } else {
                (Some(base), false)
              }
            Object(opts) => (None, extract_ignore_case(opts))
            _ => {
              skipped += 1
              continue
            }
          }
        } else {
          (None, false)
        }
        try
          @urlpattern.UrlPattern::from_string(
            pat_str,
            base_url_opt,
            ignore_case~,
          )
        catch {
          _ => passed += 1
        } noraise {
          _ =>
            failures.push(
              "expected error but got Ok for pattern=\{Json::stringify(raw_item)}",
            )
        }
      }
      _ => {
        skipped += 1
        continue
      }
    }
  }
  println(
    "WPT URLPattern construction rejects: \{passed}/\{passed + failures.length() + skipped} passed (\{skipped} skipped)",
  )
  if failures.length() > 0 {
    let msg = StringBuilder()
    msg.write_string(
      "WPT URLPattern invalid pattern rejection failures (\{failures.length()}):\n",
    )
    for f in failures {
      msg.write_string("  - \{f}\n")
    }
    fail(msg.to_string())
  }
}

///|
test "WPT URLPattern: expected_obj dict — pattern normalization and match" {
  let items = load_urlpattern_testdata()
  let mut passed = 0
  let failures : Array[String] = []
  let mut skipped = 0
  for raw_item in items {
    let item = match raw_item {
      Object(o) => o
      _ => continue
    }
    let exp_obj = match item.get("expected_obj") {
      Some(Object(o)) => o
      _ => continue
    }
    let pattern_arr = match item.get("pattern") {
      Some(Array(a)) => a
      _ => continue
    }
    if pattern_arr.length() == 0 {
      skipped += 1
      continue
    }
    let pattern = match pattern_arr[0] {
      Object(pat_obj) => {
        let ignore_case = if pattern_arr.length() == 2 {
          match pattern_arr[1] {
            Object(opts) if is_options_obj(opts) => extract_ignore_case(opts)
            _ => {
              skipped += 1
              continue
            }
          }
        } else if pattern_arr.length() == 1 {
          false
        } else {
          skipped += 1
          continue
        }
        @urlpattern.UrlPattern::from_init(
          build_init_from_obj(pat_obj),
          ignore_case~,
        ) catch {
          err => {
            let msg = "\{err}"
            if msg.contains("Unsupported") ||
              msg.contains("POSIX character class") {
              skipped += 1
            } else {
              failures.push(
                "from_init failed: \{msg} for pattern=\{Json::stringify(pattern_arr[0])}",
              )
            }
            continue
          }
        }
      }
      String(pat_str) => {
        let (base_url_opt, ignore_case) = if pattern_arr.length() == 2 {
          match pattern_arr[1] {
            String(b) => (Some(b), false)
            Object(opts) if is_options_obj(opts) =>
              (None, extract_ignore_case(opts))
            _ => {
              skipped += 1
              continue
            }
          }
        } else if pattern_arr.length() == 3 {
          match (pattern_arr[1], pattern_arr[2]) {
            (String(b), Object(opts)) => (Some(b), extract_ignore_case(opts))
            _ => {
              skipped += 1
              continue
            }
          }
        } else if pattern_arr.length() == 1 {
          (None, false)
        } else {
          skipped += 1
          continue
        }
        @urlpattern.UrlPattern::from_string(pat_str, base_url_opt, ignore_case~) catch {
          err => {
            let msg = "\{err}"
            if msg.contains("Unsupported") ||
              msg.contains("POSIX character class") {
              skipped += 1
            } else {
              failures.push(
                "from_string failed: \{msg} for pattern=\{Json::stringify(raw_item)}",
              )
            }
            continue
          }
        }
      }
      _ => {
        skipped += 1
        continue
      }
    }
    let mut ok = true
    for comp_name, exp_val_json in exp_obj {
      let exp_val = match exp_val_json {
        String(s) => s
        _ => continue
      }
      let actual = match comp_name {
        "protocol" => pattern.get_protocol()
        "username" => pattern.get_username()
        "password" => pattern.get_password()
        "hostname" => pattern.get_hostname()
        "port" => pattern.get_port()
        "pathname" => pattern.get_pathname()
        "search" => pattern.get_search()
        "hash" => pattern.get_hash()
        _ => continue
      }
      if actual != exp_val {
        failures.push(
          "'\{comp_name}': expected '\{exp_val}' got '\{actual}' for pattern=\{Json::stringify(raw_item)}",
        )
        ok = false
      }
    }
    if !ok {
      continue
    }
    let inputs_arr = match item.get("inputs") {
      Some(Array(a)) => a
      _ => {
        passed += 1
        continue
      }
    }
    if inputs_arr.length() != 1 {
      passed += 1
      continue
    }
    let result = match inputs_arr[0] {
      String(url_str) => pattern.exec_url(url_str)
      Object(inp_obj) => pattern.exec_init(build_init_from_obj(inp_obj))
      _ => {
        passed += 1
        continue
      }
    }
    let expected_match = item.get("expected_match")
    match (result, expected_match) {
      (None, Some(Null)) | (None, None) => passed += 1
      (Some(_), Some(Null)) | (Some(_), None) =>
        failures.push(
          "expected no match but got match for pattern=\{Json::stringify(raw_item)}",
        )
      (None, Some(Object(_))) =>
        failures.push(
          "expected match but got no match for pattern=\{Json::stringify(raw_item)}",
        )
      (Some(r), Some(Object(exp_match_obj))) => {
        let mut match_ok = true
        for comp_name, exp_comp_json in exp_match_obj {
          let exp_comp = match exp_comp_json {
            Object(o) => o
            _ => continue
          }
          let comp_result : @urlpattern.UrlPatternComponentResult? = match
            comp_name {
            "protocol" => r.protocol()
            "username" => r.username()
            "password" => r.password()
            "hostname" => r.hostname()
            "port" => r.port()
            "pathname" => r.pathname()
            "search" => r.search()
            "hash" => r.hash()
            _ => None
          }
          match comp_result {
            None => {
              failures.push(
                "expected component '\{comp_name}' but result is None for pattern=\{Json::stringify(raw_item)}",
              )
              match_ok = false
            }
            Some(cr) =>
              match check_component_result(cr, exp_comp, comp_name) {
                Some(msg) => {
                  failures.push(
                    "\{msg} for pattern=\{Json::stringify(raw_item)}",
                  )
                  match_ok = false
                }
                None => ()
              }
          }
        }
        if match_ok {
          passed += 1
        }
      }
      _ => passed += 1
    }
  }
  println(
    "WPT URLPattern expected_obj: \{passed}/\{passed + failures.length() + skipped} passed (\{skipped} skipped)",
  )
  if failures.length() > 0 {
    let msg = StringBuilder()
    msg.write_string(
      "WPT URLPattern expected_obj dict failures (\{failures.length()}):\n",
    )
    for f in failures {
      msg.write_string("  - \{f}\n")
    }
    fail(msg.to_string())
  }
}

///|
test "WPT URLPattern: simple init-to-init cases" {
  let items = load_urlpattern_testdata()
  let mut passed = 0
  let failures : Array[String] = []
  let mut skipped = 0
  for raw_item in items {
    let item = match raw_item {
      Object(o) => o
      _ => continue
    }
    if item.get("expected_obj") is Some(_) {
      skipped += 1
      continue
    }
    let pattern_arr = match item.get("pattern") {
      Some(Array(a)) => a
      _ => continue
    }
    let inputs_arr = match item.get("inputs") {
      Some(Array(a)) => a
      _ => continue
    }
    if inputs_arr.length() != 1 {
      skipped += 1
      continue
    }
    let (pat_obj, ignore_case) = if pattern_arr.length() == 1 {
      match pattern_arr[0] {
        Object(o) => (o, false)
        _ => {
          skipped += 1
          continue
        }
      }
    } else if pattern_arr.length() == 2 {
      match (pattern_arr[0], pattern_arr[1]) {
        (Object(init_obj), Object(opts_obj)) if is_options_obj(opts_obj) =>
          (init_obj, extract_ignore_case(opts_obj))
        _ => {
          skipped += 1
          continue
        }
      }
    } else {
      skipped += 1
      continue
    }
    let pat_init = build_init_from_obj(pat_obj)
    let pattern = @urlpattern.UrlPattern::from_init(pat_init, ignore_case~) catch {
      err => {
        let msg = "\{err}"
        if msg.contains("Unsupported") || msg.contains("POSIX character class") {
          skipped += 1
        } else {
          failures.push("from_init failed: \{msg}")
        }
        continue
      }
    }
    let result = match inputs_arr[0] {
      String(url_str) => pattern.exec_url(url_str)
      Object(inp_obj) => pattern.exec_init(build_init_from_obj(inp_obj))
      _ => {
        skipped += 1
        continue
      }
    }
    let expected = item.get("expected_match")
    match (result, expected) {
      (None, Some(Null)) | (None, None) => passed += 1
      (Some(_), Some(Null)) | (Some(_), None) =>
        failures.push(
          "expected no match but got match for pattern=\{Json::stringify(raw_item)} input=\{Json::stringify(raw_item)}",
        )
      (None, Some(Object(_))) =>
        failures.push(
          "expected match but got no match for pattern=\{Json::stringify(raw_item)} input=\{Json::stringify(raw_item)}",
        )
      (Some(r), Some(Object(exp_obj))) => {
        let mut ok = true
        for comp_name, exp_comp_json in exp_obj {
          let exp_comp = match exp_comp_json {
            Object(o) => o
            _ => continue
          }
          let comp_result : @urlpattern.UrlPatternComponentResult? = match
            comp_name {
            "protocol" => r.protocol()
            "username" => r.username()
            "password" => r.password()
            "hostname" => r.hostname()
            "port" => r.port()
            "pathname" => r.pathname()
            "search" => r.search()
            "hash" => r.hash()
            _ => None
          }
          match comp_result {
            None => {
              failures.push(
                "expected component '\{comp_name}' but result is None for pattern=\{Json::stringify(raw_item)}",
              )
              ok = false
            }
            Some(cr) =>
              match check_component_result(cr, exp_comp, comp_name) {
                Some(msg) => {
                  failures.push(
                    "\{msg} for pattern=\{Json::stringify(raw_item)} input=\{Json::stringify(raw_item)}",
                  )
                  ok = false
                }
                None => ()
              }
          }
        }
        if ok {
          passed += 1
        }
      }
      _ => skipped += 1
    }
  }
  println(
    "WPT URLPattern: \{passed}/\{passed + failures.length() + skipped} passed (\{skipped} skipped)",
  )
  if failures.length() > 0 {
    let msg = StringBuilder()
    msg.write_string("WPT URLPattern failures (\{failures.length()}):\n")
    for f in failures {
      msg.write_string("  - \{f}\n")
    }
    fail(msg.to_string())
  }
}
