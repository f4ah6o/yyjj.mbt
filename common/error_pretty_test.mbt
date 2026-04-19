///|
/// Tests for ParseError::format_pretty (source excerpt + caret rendering).

///|
fn mk_err_at(line : Int, col : Int, offset : Int) -> @common.ParseError {
  let span = @common.Span::at(@common.Pos::new(line, col, offset))
  @common.ParseError::unexpected_token("foo", span)
}

///|
test "format_pretty_single_line_source" {
  let err = mk_err_at(0, 5, 5)
  let rendered = err.format_pretty("hello world")
  assert_true(rendered.contains("error at line 1"))
  assert_true(rendered.contains("hello world"))
  assert_true(rendered.contains("^"))
}

///|
test "format_pretty_includes_previous_line_for_context" {
  let source =
    #|first line
    #|second line
  let err = mk_err_at(1, 0, 11)
  let rendered = err.format_pretty(source)
  assert_true(rendered.contains("first line"))
  assert_true(rendered.contains("second line"))
}

///|
test "format_pretty_caret_column_matches_span" {
  let source = "ab cd"
  let err = mk_err_at(0, 3, 3)
  let rendered = err.format_pretty(source)
  // The caret line should have 3 spaces after the gutter "  N | ",
  // then '^'. Verify the string contains "| \{spaces}^".
  assert_true(rendered.contains("|    ^"))
}

///|
test "format_pretty_falls_back_to_format_for_out_of_range" {
  let err = mk_err_at(10, 0, 100)
  let rendered = err.format_pretty("short")
  // Out-of-range line: falls back to single-line format with no caret.
  assert_eq(rendered, err.format())
}

///|
test "format_pretty_handles_crlf_input" {
  let err = mk_err_at(1, 0, 12)
  let rendered = err.format_pretty("first\r\nsecond")
  // CRLF: the \r must not leak into the output line.
  assert_true(rendered.contains("first\n"))
  assert_false(rendered.contains("first\r"))
}
