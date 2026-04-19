///|
/// Negative test corpus — malformed JSONC must surface a ParseError with
/// a span pointing at (or near) the offending source location.

///|
fn assert_err(label : String, input : String) -> Unit {
  match @jsonc.parse(input) {
    Ok(_) => abort("expected parse error for \{label}: \{input}")
    Err(_) => ()
  }
}

///|
fn assert_err_at_line(label : String, input : String, line : Int) -> Unit {
  match @jsonc.parse(input) {
    Ok(_) => abort("expected parse error for \{label}: \{input}")
    Err(e) =>
      if e.span.start.line != line {
        abort(
          "\{label}: expected error at line \{line}, got line \{e.span.start.line} (\{e.message})",
        )
      }
  }
}

///|
test "negative_unclosed_object" {
  assert_err("unclosed object", "{\"key\": 1")
}

///|
test "negative_unclosed_array" {
  assert_err("unclosed array", "[1, 2, 3")
}

///|
test "negative_unclosed_string" {
  assert_err("unclosed string", "\"hello")
}

///|
test "negative_unclosed_block_comment" {
  assert_err("unclosed block comment", "/* never ends")
}

///|
test "negative_missing_colon" {
  assert_err("missing colon between key and value", "{\"key\" \"value\"}")
}

///|
test "negative_missing_value" {
  assert_err("object with trailing colon", "{\"key\":}")
}

///|
test "negative_bare_identifier" {
  assert_err("bare identifier is not a JSONC value", "foobar")
}

///|
test "negative_trailing_content" {
  assert_err("trailing content after complete value", "null extra")
}

///|
test "negative_invalid_escape" {
  assert_err("invalid escape sequence", "\"\\x\"")
}

///|
test "negative_empty_input" {
  assert_err("empty input", "")
}

///|
test "negative_only_whitespace" {
  assert_err("whitespace-only input", "   \n\t  ")
}

///|
test "negative_hex_literal" {
  assert_err("hex literals are not JSONC numbers", "0xFF")
}

///|
test "negative_error_span_reports_line_of_unclosed_array" {
  let source =
    #|[
    #|  1,
    #|  2,
    #|  3
  assert_err_at_line("multiline unclosed array", source, 3)
}

///|
test "negative_error_span_reports_line_of_missing_colon" {
  let source =
    #|{
    #|  "key" "value"
    #|}
  // Span must land somewhere inside the offending line (0-indexed line 1).
  match @jsonc.parse(source) {
    Ok(_) => abort("expected parse error")
    Err(e) =>
      if e.span.start.line != 1 {
        abort(
          "expected error on line 1, got line \{e.span.start.line} (\{e.message})",
        )
      }
  }
}
