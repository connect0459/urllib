// Blackbox tests for UrlSearchParams.
// Run `moon test` to execute and `moon test --update` to refresh snapshots.

// ===== Constructor =====

///|
test "empty string produces empty params" {
  let p = @url.UrlSearchParams::from_string("")
  @debug.assert_eq(p.size(), 0)
  @debug.assert_eq(p.to_string(), "")
}

///|
test "leading question mark is stripped from input" {
  let p = @url.UrlSearchParams::from_string("?a=b")
  @debug.assert_eq(p.get("a"), Some("b"))
}

///|
test "basic key=value pairs are parsed" {
  let p = @url.UrlSearchParams::from_string("a=b&c=d")
  @debug.assert_eq(p.get("a"), Some("b"))
  @debug.assert_eq(p.get("c"), Some("d"))
}

///|
test "key without value gets empty-string value" {
  let p = @url.UrlSearchParams::from_string("a")
  @debug.assert_eq(p.get("a"), Some(""))
}

///|
test "plus sign in value decodes to space" {
  let p = @url.UrlSearchParams::from_string("a=b+c")
  @debug.assert_eq(p.get("a"), Some("b c"))
}

///|
test "plus sign in name decodes to space" {
  let p = @url.UrlSearchParams::from_string("a+b=c")
  @debug.assert_eq(p.get("a b"), Some("c"))
}

///|
test "percent-encoded name and value are decoded" {
  let p = @url.UrlSearchParams::from_string("%61=a")
  @debug.assert_eq(p.get("a"), Some("a"))
}

///|
test "percent-encoded plus is decoded to plus not space" {
  let p = @url.UrlSearchParams::from_string("a=b%2Bc")
  @debug.assert_eq(p.get("a"), Some("b+c"))
}

///|
test "empty pairs from consecutive ampersands are ignored" {
  let p = @url.UrlSearchParams::from_string("&a&&& &&&&&a+b=&")
  @debug.assert_eq(p.has("a"), true)
  @debug.assert_eq(p.has("a b"), true)
}

///|
test "invalid percent sequence is passed through" {
  let p = @url.UrlSearchParams::from_string("b=%2sf%2a")
  @debug.assert_eq(p.get("b"), Some("%2sf*"))
}

///|
test "percent sign followed by invalid hex is passed through" {
  let p = @url.UrlSearchParams::from_string("b=%%2a")
  @debug.assert_eq(p.get("b"), Some("%*"))
}

// ===== get =====

///|
test "get returns None for missing key" {
  let p = @url.UrlSearchParams::from_string("a=b&c=d")
  @debug.assert_eq(p.get("e"), None)
}

///|
test "get returns first value for duplicate keys" {
  let p = @url.UrlSearchParams::from_string("a=b&c=d&a=e")
  @debug.assert_eq(p.get("a"), Some("b"))
}

///|
test "get matches empty-string key" {
  let p = @url.UrlSearchParams::from_string("=b&c=d")
  @debug.assert_eq(p.get(""), Some("b"))
}

// ===== get_all =====

///|
test "get_all returns all values for duplicate keys" {
  let p = @url.UrlSearchParams::from_string("a=b&c=d&a=e")
  @debug.assert_eq(p.get_all("a"), ["b", "e"])
}

///|
test "get_all returns empty array for missing key" {
  let p = @url.UrlSearchParams::from_string("a=b")
  @debug.assert_eq(p.get_all("c"), [])
}

// ===== has =====

///|
test "has returns true for existing key" {
  let p = @url.UrlSearchParams::from_string("a=b&c=d")
  @debug.assert_eq(p.has("a"), true)
  @debug.assert_eq(p.has("c"), true)
}

///|
test "has returns false for missing key" {
  let p = @url.UrlSearchParams::from_string("a=b")
  @debug.assert_eq(p.has("b"), false)
}

///|
test "has with value returns true when name+value pair exists" {
  let p = @url.UrlSearchParams::from_string("a=b&a=d")
  @debug.assert_eq(p.has_entry("a", "b"), true)
  @debug.assert_eq(p.has_entry("a", "d"), true)
  @debug.assert_eq(p.has_entry("a", "c"), false)
}

// ===== append =====

///|
test "append adds name-value pair" {
  let p = @url.UrlSearchParams::new()
  p.append("a", "b")
  @debug.assert_eq(p.get("a"), Some("b"))
  @debug.assert_eq(p.to_string(), "a=b")
}

///|
test "append can add duplicate keys" {
  let p = @url.UrlSearchParams::new()
  p.append("a", "b")
  p.append("a", "b")
  @debug.assert_eq(p.to_string(), "a=b&a=b")
}

///|
test "append empty name and value" {
  let p = @url.UrlSearchParams::new()
  p.append("", "")
  @debug.assert_eq(p.to_string(), "=")
}

// ===== delete =====

///|
test "delete removes all pairs with given name" {
  let p = @url.UrlSearchParams::from_string("a=b&c=d")
  p.delete("a")
  @debug.assert_eq(p.to_string(), "c=d")
}

///|
test "delete removes all duplicates" {
  let p = @url.UrlSearchParams::from_string("a=a&b=b&a=a&c=c")
  p.delete("a")
  @debug.assert_eq(p.to_string(), "b=b&c=c")
}

///|
test "delete with value removes only matching pair" {
  let p = @url.UrlSearchParams::new()
  p.append("a", "b")
  p.append("a", "c")
  p.append("a", "d")
  p.delete_entry("a", "c")
  @debug.assert_eq(p.to_string(), "a=b&a=d")
}

///|
test "delete non-existent key is no-op" {
  let p = @url.UrlSearchParams::from_string("a=b")
  p.delete("c")
  @debug.assert_eq(p.to_string(), "a=b")
}

// ===== set =====

///|
test "set creates new entry when key does not exist" {
  let p = @url.UrlSearchParams::new()
  p.set("a", "b")
  @debug.assert_eq(p.get("a"), Some("b"))
}

///|
test "set replaces all existing entries and keeps first position" {
  let p = @url.UrlSearchParams::from_string("a=a&b=b&a=a&c=c")
  p.set("a", "x")
  @debug.assert_eq(p.to_string(), "a=x&b=b&c=c")
}

// ===== size =====

///|
test "size returns number of pairs" {
  let p = @url.UrlSearchParams::from_string("a=1&b=2&a=3")
  @debug.assert_eq(p.size(), 3)
}

///|
test "size decreases after delete" {
  let p = @url.UrlSearchParams::from_string("a=1&b=2&a=3")
  p.delete("a")
  @debug.assert_eq(p.size(), 1)
}

// ===== to_string / serialization =====

///|
test "serialize space as plus" {
  let p = @url.UrlSearchParams::new()
  p.append("a", "b c")
  @debug.assert_eq(p.to_string(), "a=b+c")
}

///|
test "serialize plus as %2B" {
  let p = @url.UrlSearchParams::new()
  p.append("a", "b+c")
  @debug.assert_eq(p.to_string(), "a=b%2Bc")
}

///|
test "serialize percent as %25" {
  let p = @url.UrlSearchParams::new()
  p.append("a", "b%c")
  @debug.assert_eq(p.to_string(), "a=b%25c")
}

///|
test "serialize ampersand as %26" {
  let p = @url.UrlSearchParams::new()
  p.append("&", "a")
  @debug.assert_eq(p.to_string(), "%26=a")
}

///|
test "serialize equals as %3D" {
  let p = @url.UrlSearchParams::new()
  p.append("=", "a")
  @debug.assert_eq(p.to_string(), "%3D=a")
}

///|
test "safe chars are not encoded" {
  let p = @url.UrlSearchParams::new()
  p.append("a", "*-._")
  @debug.assert_eq(p.to_string(), "a=*-._")
}

///|
test "NUL byte is encoded" {
  let p = @url.UrlSearchParams::new()
  p.append("a", "b\u{0000}c")
  @debug.assert_eq(p.to_string(), "a=b%00c")
}

///|
test "roundtrip: parse then serialize" {
  let p = @url.UrlSearchParams::from_string("a=b&c=d&&e&&")
  @debug.assert_eq(p.to_string(), "a=b&c=d&e=")
}

///|
test "roundtrip: spaces in parsed string become plus in serialized" {
  let p = @url.UrlSearchParams::from_string("a = b &a=b&c=d%20")
  @debug.assert_eq(p.to_string(), "a+=+b+&a=b&c=d+")
}

// ===== sort =====

///|
test "sort orders pairs by name in code unit order" {
  let p = @url.UrlSearchParams::from_string("z=b&a=b&z=a&a=a")
  p.sort()
  @debug.assert_eq(p.to_string(), "a=b&a=a&z=b&z=a")
}

///|
test "sort is stable for equal names" {
  let p = @url.UrlSearchParams::from_string("z=z&a=a&z=y&a=b&z=x&a=c")
  p.sort()
  @debug.assert_eq(p.to_string(), "a=a&a=b&a=c&z=z&z=y&z=x")
}

///|
test "sort empty string name before non-empty" {
  let p = @url.UrlSearchParams::from_string("z=z&=f&=t&=x")
  p.sort()
  @debug.assert_eq(p.to_string(), "=f&=t&=x&z=z")
}

// ===== iter / for_each =====

///|
test "for_each visits all pairs in order" {
  let p = @url.UrlSearchParams::from_string("a=1&b=2&c=3")
  let keys : Array[String] = []
  let values : Array[String] = []
  p.for_each(fn(name, value) {
    keys.push(name)
    values.push(value)
  })
  @debug.assert_eq(keys, ["a", "b", "c"])
  @debug.assert_eq(values, ["1", "2", "3"])
}

///|
test "iter yields all pairs" {
  let p = @url.UrlSearchParams::from_string("a=1&b=2")
  let pairs : Array[(String, String)] = []
  for pair in p.iter() {
    pairs.push(pair)
  }
  @debug.assert_eq(pairs, [("a", "1"), ("b", "2")])
}

///|
test "Show for UrlSearchParams outputs serialized form" {
  let p = @url.UrlSearchParams::from_string("a=1&b=2")
  assert_eq("\{p}", "a=1&b=2")
}

///|
test "Show for UrlSearchParams outputs empty string for empty params" {
  let p = @url.UrlSearchParams::new()
  assert_eq("\{p}", "")
}

// ===== keys / values =====

///|
test "keys returns names in list order" {
  let p = @url.UrlSearchParams::from_string("a=1&b=2&c=3")
  let names : Array[String] = []
  for k in p.keys() {
    names.push(k)
  }
  @debug.assert_eq(names, ["a", "b", "c"])
}

///|
test "keys yields duplicate names for duplicate entries" {
  let p = @url.UrlSearchParams::from_string("a=1&b=2&a=3")
  let names : Array[String] = []
  for k in p.keys() {
    names.push(k)
  }
  @debug.assert_eq(names, ["a", "b", "a"])
}

///|
test "keys returns empty iterator for empty params" {
  let p = @url.UrlSearchParams::new()
  let names : Array[String] = []
  for k in p.keys() {
    names.push(k)
  }
  @debug.assert_eq(names, [])
}

///|
test "values returns values in list order" {
  let p = @url.UrlSearchParams::from_string("a=1&b=2&c=3")
  let vals : Array[String] = []
  for v in p.values() {
    vals.push(v)
  }
  @debug.assert_eq(vals, ["1", "2", "3"])
}

///|
test "values yields all values including duplicates" {
  let p = @url.UrlSearchParams::from_string("a=1&b=2&a=3")
  let vals : Array[String] = []
  for v in p.values() {
    vals.push(v)
  }
  @debug.assert_eq(vals, ["1", "2", "3"])
}

///|
test "values returns empty iterator for empty params" {
  let p = @url.UrlSearchParams::new()
  let vals : Array[String] = []
  for v in p.values() {
    vals.push(v)
  }
  @debug.assert_eq(vals, [])
}

// ===== entries =====

///|
test "entries yields all name-value pairs in list order" {
  let p = @url.UrlSearchParams::from_string("a=1&b=2&c=3")
  let pairs : Array[(String, String)] = []
  for pair in p.entries() {
    pairs.push(pair)
  }
  @debug.assert_eq(pairs, [("a", "1"), ("b", "2"), ("c", "3")])
}

///|
test "entries yields duplicate entries" {
  let p = @url.UrlSearchParams::from_string("a=1&b=2&a=3")
  let pairs : Array[(String, String)] = []
  for pair in p.entries() {
    pairs.push(pair)
  }
  @debug.assert_eq(pairs, [("a", "1"), ("b", "2"), ("a", "3")])
}

///|
test "entries returns empty iterator for empty params" {
  let p = @url.UrlSearchParams::new()
  let pairs : Array[(String, String)] = []
  for pair in p.entries() {
    pairs.push(pair)
  }
  @debug.assert_eq(pairs, [])
}

///|
test "entries and iter produce identical results" {
  let p = @url.UrlSearchParams::from_string("x=1&y=2&x=3")
  let from_entries : Array[(String, String)] = []
  for pair in p.entries() {
    from_entries.push(pair)
  }
  let from_iter : Array[(String, String)] = []
  for pair in p.iter() {
    from_iter.push(pair)
  }
  @debug.assert_eq(from_entries, from_iter)
}

///|
test "from_pairs preserves pair order and duplicate names" {
  let p = @url.UrlSearchParams::from_pairs([("a", "1"), ("b", "2"), ("a", "3")])
  @debug.assert_eq(p.to_string(), "a=1&b=2&a=3")
  @debug.assert_eq(p.get_all("a"), ["1", "3"])
}

///|
test "from_pairs with no pairs produces empty params" {
  let p = @url.UrlSearchParams::from_pairs([])
  @debug.assert_eq(p.size(), 0)
}

///|
test "from_pairs serializes like append" {
  let appended = @url.UrlSearchParams::new()
  appended.append("q", "a b&c")
  let p = @url.UrlSearchParams::from_pairs([("q", "a b&c")])
  @debug.assert_eq(p.to_string(), appended.to_string())
}

///|
test "from_pairs does not alias the input array" {
  let pairs = [("a", "1")]
  let p = @url.UrlSearchParams::from_pairs(pairs)
  pairs.push(("b", "2"))
  @debug.assert_eq(p.size(), 1)
}

///|
test "from_pairs replaces a lone high surrogate in a stored value" {
  let high = (0xD800).unsafe_to_char().to_string()
  let p = @url.UrlSearchParams::from_pairs([("k", "a" + high)])
  @debug.assert_eq(p.get("k"), Some("a\u{FFFD}"))
}

///|
test "from_pairs replaces a lone low surrogate in a stored value" {
  let low = (0xDC00).unsafe_to_char().to_string()
  let p = @url.UrlSearchParams::from_pairs([("k", low + "a")])
  @debug.assert_eq(p.get("k"), Some("\u{FFFD}a"))
}

///|
test "from_pairs replaces a lone surrogate in a stored name" {
  let high = (0xD800).unsafe_to_char().to_string()
  let p = @url.UrlSearchParams::from_pairs([(high + "k", "v")])
  @debug.assert_eq(p.get("\u{FFFD}k"), Some("v"))
}

///|
test "from_record keeps insertion order of keys" {
  let m : Map[String, String] = Map([])
  m["z"] = "1"
  m["a"] = "2"
  let p = @url.UrlSearchParams::from_record(m)
  @debug.assert_eq(p.to_string(), "z=1&a=2")
}

///|
test "from_record with empty map produces empty params" {
  let p = @url.UrlSearchParams::from_record(Map([]))
  @debug.assert_eq(p.size(), 0)
}

///|
test "from_record replaces a lone surrogate in a stored value" {
  let m : Map[String, String] = Map([])
  m["k"] = "v" + (0xDC00).unsafe_to_char().to_string()
  let p = @url.UrlSearchParams::from_record(m)
  @debug.assert_eq(p.get("k"), Some("v\u{FFFD}"))
}

///|
test "from_record replaces a lone surrogate in a stored name" {
  let m : Map[String, String] = Map([])
  m[(0xD800).unsafe_to_char().to_string() + "k"] = "v"
  let p = @url.UrlSearchParams::from_record(m)
  @debug.assert_eq(p.get("\u{FFFD}k"), Some("v"))
}

///|
test "from_record keeps valid surrogate pairs as one supplementary character" {
  let m : Map[String, String] = Map([])
  m["k"] = "😀"
  let p = @url.UrlSearchParams::from_record(m)
  @debug.assert_eq(p.get("k"), Some("😀"))
}

///|
test "from_pairs keeps valid surrogate pairs as one supplementary character" {
  let p = @url.UrlSearchParams::from_pairs([("k", "😀")])
  @debug.assert_eq(p.get("k"), Some("😀"))
}

///|
test "from_pairs replaces a high surrogate not followed by a low surrogate" {
  let high = (0xD800).unsafe_to_char().to_string()
  let p = @url.UrlSearchParams::from_pairs([("k", high + "x")])
  @debug.assert_eq(p.get("k"), Some("\u{FFFD}x"))
}
