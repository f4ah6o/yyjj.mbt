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
pub fn ParseError::new(kind : ParseErrorKind, span : Span, message : String) -> ParseError {
  { kind, span, message }
}

///|
/// Create an unexpected token error
pub fn ParseError::unexpected_token(token : String, span : Span) -> ParseError {
  {
    kind: UnexpectedToken(token),
    span,
    message: "unexpected token: " + token,
  }
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
  span : Span
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
