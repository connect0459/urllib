///|
fn load_setter_cases(
  prop : String,
) -> Array[(String, String, Array[(String, String)])] raise {
  let content = @fs.read_file_to_string("wpt/url/resources/setters_tests.json")
  let json = @json.parse(content)
  let root = match json {
    Object(o) => o
    _ => fail("expected JSON object")
  }
  let arr = match root.get(prop) {
    Some(Array(a)) => a
    _ => fail("missing or non-array '\{prop}'")
  }
  let cases : Array[(String, String, Array[(String, String)])] = []
  for item in arr {
    match item {
      Object(obj) => {
        let href = extract_str(obj, "href")
        let new_value = extract_str(obj, "new_value")
        let expected : Array[(String, String)] = []
        match obj.get("expected") {
          Some(Object(e)) =>
            for entry in e.iter() {
              let (k, v) = entry
              match v {
                String(s) => expected.push((k, s))
                _ => fail("expected string in 'expected' fields")
              }
            }
          _ => fail("missing or non-object 'expected'")
        }
        cases.push((href, new_value, expected))
      }
      _ => ()
    }
  }
  cases
}

///|
fn url_field(url : @url.Url, field : String) -> String {
  match field {
    "href" => url.href()
    "protocol" => url.protocol()
    "username" => url.username()
    "password" => url.password()
    "host" => url.host_str()
    "hostname" => url.hostname()
    "port" => url.port_str()
    "pathname" => url.pathname()
    "search" => url.search()
    "hash" => url.hash()
    _ => ""
  }
}

///|
fn check_setter_fields(
  label : String,
  href : String,
  new_value : String,
  result : @url.Url,
  expected_fields : Array[(String, String)],
  passed : Ref[Int32],
  failed : Ref[Int32],
) -> Unit {
  for efld in expected_fields {
    let (field, expected_val) = efld
    let actual = url_field(result, field)
    if actual != expected_val {
      if failed.val < 10 {
        println(
          "FAIL \{label}: href=\{href} new=\{new_value} field=\{field} expected=\{expected_val} got=\{actual}",
        )
      }
      failed.val = failed.val + 1
    } else {
      passed.val = passed.val + 1
    }
  }
}

///|
test "WPT setter cases: protocol" {
  let cases = load_setter_cases("protocol")
  let passed = Ref::Ref(0)
  let failed = Ref::Ref(0)
  for item in cases {
    let (href, new_value, expected_fields) = item
    let url = @url.parse(href) catch { _ => continue }
    let result = url.set_protocol(new_value)
    check_setter_fields(
      "set_protocol", href, new_value, result, expected_fields, passed, failed,
    )
  }
  println(
    "WPT setter protocol: \{passed.val}/\{passed.val + failed.val} passed",
  )
  if failed.val > 0 {
    println("WARN: \{failed.val} protocol setter cases failed")
    assert_eq(failed.val, 0)
  }
}

///|
test "WPT setter cases: username" {
  let cases = load_setter_cases("username")
  let passed = Ref::Ref(0)
  let failed = Ref::Ref(0)
  for item in cases {
    let (href, new_value, expected_fields) = item
    let url = @url.parse(href) catch { _ => continue }
    let result = url.set_username(new_value)
    check_setter_fields(
      "set_username", href, new_value, result, expected_fields, passed, failed,
    )
  }
  println(
    "WPT setter username: \{passed.val}/\{passed.val + failed.val} passed",
  )
  if failed.val > 0 {
    println("WARN: \{failed.val} username setter cases failed")
    assert_eq(failed.val, 0)
  }
}

///|
test "WPT setter cases: password" {
  let cases = load_setter_cases("password")
  let passed = Ref::Ref(0)
  let failed = Ref::Ref(0)
  for item in cases {
    let (href, new_value, expected_fields) = item
    let url = @url.parse(href) catch { _ => continue }
    let result = url.set_password(new_value)
    check_setter_fields(
      "set_password", href, new_value, result, expected_fields, passed, failed,
    )
  }
  println(
    "WPT setter password: \{passed.val}/\{passed.val + failed.val} passed",
  )
  if failed.val > 0 {
    println("WARN: \{failed.val} password setter cases failed")
    assert_eq(failed.val, 0)
  }
}

///|
test "WPT setter cases: host" {
  let cases = load_setter_cases("host")
  let passed = Ref::Ref(0)
  let failed = Ref::Ref(0)
  for item in cases {
    let (href, new_value, expected_fields) = item
    let url = @url.parse(href) catch { _ => continue }
    let result = url.set_host(new_value)
    check_setter_fields(
      "set_host", href, new_value, result, expected_fields, passed, failed,
    )
  }
  println("WPT setter host: \{passed.val}/\{passed.val + failed.val} passed")
  if failed.val > 0 {
    println("WARN: \{failed.val} host setter cases failed")
    assert_eq(failed.val, 0)
  }
}

///|
test "WPT setter cases: hostname" {
  let cases = load_setter_cases("hostname")
  let passed = Ref::Ref(0)
  let failed = Ref::Ref(0)
  for item in cases {
    let (href, new_value, expected_fields) = item
    let url = @url.parse(href) catch { _ => continue }
    let result = url.set_hostname(new_value)
    check_setter_fields(
      "set_hostname", href, new_value, result, expected_fields, passed, failed,
    )
  }
  println(
    "WPT setter hostname: \{passed.val}/\{passed.val + failed.val} passed",
  )
  if failed.val > 0 {
    println("WARN: \{failed.val} hostname setter cases failed")
    assert_eq(failed.val, 0)
  }
}

///|
test "WPT setter cases: port" {
  let cases = load_setter_cases("port")
  let passed = Ref::Ref(0)
  let failed = Ref::Ref(0)
  for item in cases {
    let (href, new_value, expected_fields) = item
    let url = @url.parse(href) catch { _ => continue }
    let result = url.set_port(new_value)
    check_setter_fields(
      "set_port", href, new_value, result, expected_fields, passed, failed,
    )
  }
  println("WPT setter port: \{passed.val}/\{passed.val + failed.val} passed")
  if failed.val > 0 {
    println("WARN: \{failed.val} port setter cases failed")
    assert_eq(failed.val, 0)
  }
}

///|
test "WPT setter cases: pathname" {
  let cases = load_setter_cases("pathname")
  let passed = Ref::Ref(0)
  let failed = Ref::Ref(0)
  for item in cases {
    let (href, new_value, expected_fields) = item
    let url = @url.parse(href) catch { _ => continue }
    let result = url.set_pathname(new_value)
    check_setter_fields(
      "set_pathname", href, new_value, result, expected_fields, passed, failed,
    )
  }
  println(
    "WPT setter pathname: \{passed.val}/\{passed.val + failed.val} passed",
  )
  if failed.val > 0 {
    println("WARN: \{failed.val} pathname setter cases failed")
    assert_eq(failed.val, 0)
  }
}

///|
test "WPT setter cases: search" {
  let cases = load_setter_cases("search")
  let passed = Ref::Ref(0)
  let failed = Ref::Ref(0)
  for item in cases {
    let (href, new_value, expected_fields) = item
    let url = @url.parse(href) catch { _ => continue }
    let result = url.set_search(new_value)
    check_setter_fields(
      "set_search", href, new_value, result, expected_fields, passed, failed,
    )
  }
  println("WPT setter search: \{passed.val}/\{passed.val + failed.val} passed")
  if failed.val > 0 {
    println("WARN: \{failed.val} search setter cases failed")
    assert_eq(failed.val, 0)
  }
}

///|
test "WPT setter cases: hash" {
  let cases = load_setter_cases("hash")
  let passed = Ref::Ref(0)
  let failed = Ref::Ref(0)
  for item in cases {
    let (href, new_value, expected_fields) = item
    let url = @url.parse(href) catch { _ => continue }
    let result = url.set_hash(new_value)
    check_setter_fields(
      "set_hash", href, new_value, result, expected_fields, passed, failed,
    )
  }
  println("WPT setter hash: \{passed.val}/\{passed.val + failed.val} passed")
  if failed.val > 0 {
    println("WARN: \{failed.val} hash setter cases failed")
    assert_eq(failed.val, 0)
  }
}

///|
test "WPT setter cases: href" {
  let cases = load_setter_cases("href")
  let passed = Ref::Ref(0)
  let failed = Ref::Ref(0)
  for item in cases {
    let (href, new_value, expected_fields) = item
    let url = @url.parse(href) catch { _ => continue }
    let result = url.set_href(new_value) catch { _ => continue }
    check_setter_fields(
      "set_href", href, new_value, result, expected_fields, passed, failed,
    )
  }
  println("WPT setter href: \{passed.val}/\{passed.val + failed.val} passed")
  if failed.val > 0 {
    println("WARN: \{failed.val} href setter cases failed")
    assert_eq(failed.val, 0)
  }
}
