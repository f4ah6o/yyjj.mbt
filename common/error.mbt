///|
/// Parse error kind
pub enum ParseErrorKind {
  UnexpectedToken(String)
  UnexpectedEof
  InvalidEscape(Char)
  InvalidNumber(String)
  InvalidIndentation(Int, Int) // expected, actual
  UnclosedString
  UnclosedComment
  UnresolvedAlias(String)
  TrailingContent
} derive(Eq, Show)

///|
/// Create unexpected token error kind
pub fn ParseErrorKind::unexpected_token(msg : String) -> ParseErrorKind {
  UnexpectedToken(msg)
}

///|
/// Create trailing content error kind
pub fn ParseErrorKind::trailing_content() -> ParseErrorKind {
  TrailingContent
}

///|
/// Parse error with location information
pub struct ParseError {
  kind : ParseErrorKind
  span : Span
  message : String
} derive(Eq, Show)

///|
/// Create a new parse error
pub fn ParseError::new(
  kind : ParseErrorKind,
  span : Span,
  message : String,
) -> ParseError {
  { kind, span, message }
}

///|
/// Create an unexpected token error
pub fn ParseError::unexpected_token(token : String, span : Span) -> ParseError {
  { kind: UnexpectedToken(token), span, message: "unexpected token: " + token }
}

///|
/// Create an unexpected EOF error
pub fn ParseError::unexpected_eof(span : Span) -> ParseError {
  { kind: UnexpectedEof, span, message: "unexpected end of input" }
}

///|
/// Create an invalid escape sequence error
pub fn ParseError::invalid_escape(ch : Char, span : Span) -> ParseError {
  {
    kind: InvalidEscape(ch),
    span,
    message: "invalid escape sequence: \\" + ch.to_string(),
  }
}

///|
/// Create an invalid number error
pub fn ParseError::invalid_number(num : String, span : Span) -> ParseError {
  { kind: InvalidNumber(num), span, message: "invalid number: " + num }
}

///|
/// Create an unclosed string error
pub fn ParseError::unclosed_string(span : Span) -> ParseError {
  { kind: UnclosedString, span, message: "unclosed string literal" }
}

///|
/// Create an unclosed comment error
pub fn ParseError::unclosed_comment(span : Span) -> ParseError {
  { kind: UnclosedComment, span, message: "unclosed block comment" }
}

///|
/// Create an unresolved alias error
pub fn ParseError::unresolved_alias(name : String, span : Span) -> ParseError {
  { kind: UnresolvedAlias(name), span, message: "unresolved alias: " + name }
}

///|
/// Create an invalid indentation error
pub fn ParseError::invalid_indentation(
  expected : Int,
  actual : Int,
  span : Span,
) -> ParseError {
  {
    kind: InvalidIndentation(expected, actual),
    span,
    message: "invalid indentation: expected " +
    expected.to_string() +
    " spaces, got " +
    actual.to_string(),
  }
}

///|
/// Format error for display
pub fn ParseError::format(self : ParseError) -> String {
  "error at line " +
  (self.span.start.line + 1).to_string() +
  ", column " +
  (self.span.start.column + 1).to_string() +
  ": " +
  self.message
}

///|
/// Format the error with a source excerpt and an ASCII caret pointing at the
/// offending location. Lines are 1-indexed in the output. Passes through the
/// source text unchanged.
///
/// Example output:
///
///     error at line 2, column 8: unexpected token: foo
///       1 | key: value
///       2 |   next: foo
///         |        ^
pub fn ParseError::format_pretty(self : ParseError, source : String) -> String {
  let header = self.format()
  let target_line = self.span.start.line
  let target_col = self.span.start.column
  let lines = split_lines(source)
  if target_line < 0 || target_line >= lines.length() {
    return header
  }
  let line_number_text = (target_line + 1).to_string()
  let gutter_width = line_number_text.length()
  let buf = StringBuilder::new()
  buf.write_string(header)
  buf.write_char('\n')
  if target_line > 0 {
    let prev_num = target_line.to_string()
    let prev_pad = repeat_char(' ', gutter_width - prev_num.length())
    buf.write_string("  ")
    buf.write_string(prev_pad)
    buf.write_string(prev_num)
    buf.write_string(" | ")
    buf.write_string(lines[target_line - 1])
    buf.write_char('\n')
  }
  buf.write_string("  ")
  buf.write_string(line_number_text)
  buf.write_string(" | ")
  buf.write_string(lines[target_line])
  buf.write_char('\n')
  let gutter_blank = repeat_char(' ', gutter_width)
  buf.write_string("  ")
  buf.write_string(gutter_blank)
  buf.write_string(" | ")
  let caret_padding = repeat_char(' ', target_col)
  buf.write_string(caret_padding)
  buf.write_char('^')
  buf.to_string()
}

///|
/// Repeat a character count times.
fn repeat_char(ch : Char, count : Int) -> String {
  if count <= 0 {
    return ""
  }
  let buf = StringBuilder::new()
  for i = 0; i < count; i = i + 1 {
    buf.write_char(ch)
  }
  buf.to_string()
}

///|
/// Split source text into lines on '\n'. Strips a trailing '\r' on each line
/// so CRLF inputs format the same as LF inputs. Preserves empty lines.
fn split_lines(source : String) -> Array[String] {
  let lines : Array[String] = []
  let buf = StringBuilder::new()
  for ch in source {
    if ch == '\n' {
      let line = buf.to_string()
      let trimmed = if line.length() > 0 &&
        line[line.length() - 1].to_int().unsafe_to_char() == '\r' {
        line[:line.length() - 1].to_string()
      } else {
        line
      }
      lines.push(trimmed)
      buf.reset()
    } else {
      buf.write_char(ch)
    }
  }
  lines.push(buf.to_string())
  lines
}
