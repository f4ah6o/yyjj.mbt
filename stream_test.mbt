///|
/// Tests for multi-document YAML stream parse/print.

///|
test "parse_yaml_stream_single_document" {
  let result = @yyjj.parse_yaml_stream("key: value")
  guard result is Ok(docs) else { abort("expected ok") }
  assert_eq(docs.length(), 1)
}

///|
test "parse_yaml_stream_two_documents" {
  let source =
    #|a: 1
    #|---
    #|b: 2
  let result = @yyjj.parse_yaml_stream(source)
  guard result is Ok(docs) else { abort("expected ok") }
  assert_eq(docs.length(), 2)
}

///|
test "parse_yaml_stream_ignores_leading_separator" {
  let source =
    #|---
    #|a: 1
  let result = @yyjj.parse_yaml_stream(source)
  guard result is Ok(docs) else { abort("expected ok") }
  assert_eq(docs.length(), 1)
}

///|
test "parse_yaml_stream_propagates_parse_error" {
  let source =
    #|a: 1
    #|---
    #|b: &
  let result = @yyjj.parse_yaml_stream(source)
  assert_true(result is Err(_))
}

///|
test "print_yaml_stream_inserts_separators" {
  let source =
    #|a: 1
    #|---
    #|b: 2
  let parsed = @yyjj.parse_yaml_stream(source)
  guard parsed is Ok(docs) else { abort("parse failed") }
  let printed = @yyjj.print_yaml_stream(docs)
  assert_true(printed.contains("---"))
  assert_true(printed.contains("a:"))
  assert_true(printed.contains("b:"))
}

///|
test "print_yaml_stream_empty_list" {
  assert_eq(@yyjj.print_yaml_stream([]), "")
}

///|
test "print_yaml_stream_single_has_no_separator" {
  let parsed = @yyjj.parse_yaml_stream("k: 1")
  guard parsed is Ok(docs) else { abort("parse failed") }
  let printed = @yyjj.print_yaml_stream(docs)
  assert_false(printed.contains("---"))
}

///|
test "parse_yaml_stream_roundtrip_via_print" {
  let source =
    #|first: 1
    #|---
    #|second: 2
    #|---
    #|third: 3
  let parsed = @yyjj.parse_yaml_stream(source)
  guard parsed is Ok(docs) else { abort("parse failed") }
  assert_eq(docs.length(), 3)
  let printed = @yyjj.print_yaml_stream(docs)
  // Re-parse to verify the output is a valid stream of the same length.
  let reparsed = @yyjj.parse_yaml_stream(printed)
  guard reparsed is Ok(docs2) else { abort("reparse failed") }
  assert_eq(docs2.length(), 3)
}
