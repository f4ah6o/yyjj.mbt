///|
/// Unit tests for ParseError construction and formatting.

///|
fn span_at(line : Int, col : Int, offset : Int) -> @common.Span {
  @common.Span::at(@common.Pos::new(line, col, offset))
}

///|
test "unexpected_token_message_contains_token" {
  let e = @common.ParseError::unexpected_token("foo", span_at(0, 0, 0))
  assert_true(e.message.contains("foo"))
}

///|
test "invalid_escape_message_shows_char" {
  let e = @common.ParseError::invalid_escape('x', span_at(0, 0, 0))
  assert_true(e.message.contains("x"))
}

///|
test "format_uses_one_indexed_line_and_column" {
  let e = @common.ParseError::unexpected_eof(span_at(3, 7, 42))
  let rendered = e.format()
  assert_true(rendered.contains("line 4"))
  assert_true(rendered.contains("column 8"))
}

///|
test "invalid_indentation_encodes_values" {
  let e = @common.ParseError::invalid_indentation(4, 2, span_at(0, 0, 0))
  assert_true(e.message.contains("4"))
  assert_true(e.message.contains("2"))
}

///|
test "unresolved_alias_names_alias" {
  let e = @common.ParseError::unresolved_alias("anchor", span_at(0, 0, 0))
  assert_true(e.message.contains("anchor"))
}
