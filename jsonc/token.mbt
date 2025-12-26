///|
/// JSONC token types
pub enum TokenKind {
  // Structural tokens
  LBrace // {
  RBrace // }
  LBracket // [
  RBracket // ]
  Colon // :
  Comma // ,
  // Value tokens
  String(String) // String literal (unescaped value)
  Number(String) // Number literal (raw text)
  True // true
  False // false
  Null // null
  // Trivia tokens (preserved for comments)
  LineComment(String) // // comment
  BlockComment(String) // /* comment */
  Whitespace(String) // spaces, tabs
  Newline // \n or \r\n
  // Special
  Eof
  Invalid(String) // Error token with message
} derive(Eq, Show)

///|
/// A token with its span
pub struct Token {
  kind : TokenKind
  span : @common.Span
} derive(Eq, Show)

///|
/// Create a new token
pub fn Token::new(kind : TokenKind, span : @common.Span) -> Token {
  { kind, span }
}

///|
/// Check if token is trivia (whitespace or comment)
pub fn Token::is_trivia(self : Token) -> Bool {
  match self.kind {
    Whitespace(_) | Newline | LineComment(_) | BlockComment(_) => true
    _ => false
  }
}

///|
/// Check if token is a comment
pub fn Token::is_comment(self : Token) -> Bool {
  match self.kind {
    LineComment(_) | BlockComment(_) => true
    _ => false
  }
}
