///|
/// JSONC Lexer - tokenizes JSONC source preserving comments
pub struct Lexer {
  source : String
  mut pos : Int // current byte offset
  mut line : Int // current line (0-indexed)
  mut column : Int // current column (0-indexed)
}

///|
/// Create a new lexer for the given source
pub fn Lexer::new(source : String) -> Lexer {
  { source, pos: 0, line: 0, column: 0 }
}

///|
/// Get current position
fn Lexer::current_pos(self : Lexer) -> @common.Pos {
  @common.Pos::new(self.line, self.column, self.pos)
}

///|
/// Check if at end of input
fn Lexer::is_eof(self : Lexer) -> Bool {
  self.pos >= self.source.length()
}

///|
/// Get char at position
fn Lexer::char_at(self : Lexer, idx : Int) -> Char {
  self.source[idx].to_int().unsafe_to_char()
}

///|
/// Peek current character without consuming
fn Lexer::peek(self : Lexer) -> Char? {
  if self.is_eof() {
    None
  } else {
    Some(self.char_at(self.pos))
  }
}

///|
/// Consume current character and advance
fn Lexer::advance(self : Lexer) -> Char? {
  if self.is_eof() {
    return None
  }
  let ch = self.char_at(self.pos)
  self.pos += 1
  if ch == '\n' {
    self.line += 1
    self.column = 0
  } else {
    self.column += 1
  }
  Some(ch)
}

///|
/// Skip while predicate is true, return collected string
fn Lexer::skip_while(self : Lexer, pred : (Char) -> Bool) -> String {
  let start = self.pos
  while not(self.is_eof()) && pred(self.char_at(self.pos)) {
    let _ = self.advance()

  }
  (try! self.source[start:self.pos]).to_string()
}

///|
/// Lex the next token
pub fn Lexer::next_token(self : Lexer) -> Token {
  let start = self.current_pos()
  match self.peek() {
    None => Token::new(Eof, @common.Span::at(start))
    Some(ch) =>
      match ch {
        // Structural tokens
        '{' => {
          let _ = self.advance()
          Token::new(LBrace, @common.Span::new(start, self.current_pos()))
        }
        '}' => {
          let _ = self.advance()
          Token::new(RBrace, @common.Span::new(start, self.current_pos()))
        }
        '[' => {
          let _ = self.advance()
          Token::new(LBracket, @common.Span::new(start, self.current_pos()))
        }
        ']' => {
          let _ = self.advance()
          Token::new(RBracket, @common.Span::new(start, self.current_pos()))
        }
        ':' => {
          let _ = self.advance()
          Token::new(Colon, @common.Span::new(start, self.current_pos()))
        }
        ',' => {
          let _ = self.advance()
          Token::new(Comma, @common.Span::new(start, self.current_pos()))
        }
        // String
        '"' => self.lex_string(start)
        // Whitespace
        ' ' | '\t' => {
          let ws = self.skip_while(fn(c) { c == ' ' || c == '\t' })
          Token::new(
            Whitespace(ws),
            @common.Span::new(start, self.current_pos()),
          )
        }
        // Newline
        '\n' => {
          let _ = self.advance()
          Token::new(Newline, @common.Span::new(start, self.current_pos()))
        }
        '\r' => {
          let _ = self.advance()
          // Handle \r\n as single newline
          if self.peek() == Some('\n') {
            let _ = self.advance()

          }
          Token::new(Newline, @common.Span::new(start, self.current_pos()))
        }
        // Comments or division (we don't have division in JSON)
        '/' => self.lex_comment_or_invalid(start)
        // Numbers
        '-' | '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' =>
          self.lex_number(start)
        // Keywords
        't' => self.lex_keyword("true", True, start)
        'f' => self.lex_keyword("false", False, start)
        'n' => self.lex_keyword("null", Null, start)
        // Invalid character
        _ => {
          let _ = self.advance()
          Token::new(
            Invalid("unexpected character: " + ch.to_string()),
            @common.Span::new(start, self.current_pos()),
          )
        }
      }
  }
}

///|
/// Lex a string literal
fn Lexer::lex_string(self : Lexer, start : @common.Pos) -> Token {
  let _ = self.advance() // consume opening "
  let buf = StringBuilder::new()
  while true {
    match self.peek() {
      None =>
        return Token::new(
          Invalid("unclosed string"),
          @common.Span::new(start, self.current_pos()),
        )
      Some('"') => {
        let _ = self.advance()
        break
      }
      Some('\\') => {
        let _ = self.advance()
        match self.peek() {
          None =>
            return Token::new(
              Invalid("unclosed string"),
              @common.Span::new(start, self.current_pos()),
            )
          Some(esc) => {
            let _ = self.advance()
            match esc {
              '"' => buf.write_char('"')
              '\\' => buf.write_char('\\')
              '/' => buf.write_char('/')
              'b' => buf.write_char('\u0008') // backspace
              'f' => buf.write_char('\u000C') // form feed
              'n' => buf.write_char('\n')
              't' => buf.write_char('\t')
              'r' => buf.write_char('\r')
              'u' => {
                // Unicode escape \uXXXX
                let mut hex = ""
                for i = 0; i < 4; i = i + 1 {
                  match self.peek() {
                    Some(h) if is_hex_digit(h) => {
                      hex = hex + h.to_string()
                      let _ = self.advance()

                    }
                    _ =>
                      return Token::new(
                        Invalid("invalid unicode escape"),
                        @common.Span::new(start, self.current_pos()),
                      )
                  }
                }
                match parse_hex(hex) {
                  Some(code) => buf.write_char(code.unsafe_to_char())
                  None =>
                    return Token::new(
                      Invalid("invalid unicode escape"),
                      @common.Span::new(start, self.current_pos()),
                    )
                }
              }
              _ =>
                return Token::new(
                  Invalid("invalid escape sequence: \\" + esc.to_string()),
                  @common.Span::new(start, self.current_pos()),
                )
            }
          }
        }
      }
      Some(ch) if ch.to_int() < 0x20 =>
        // Control characters not allowed in strings
        return Token::new(
          Invalid("control character in string"),
          @common.Span::new(start, self.current_pos()),
        )
      Some(ch) => {
        let _ = self.advance()
        buf.write_char(ch)
      }
    }
  }
  Token::new(
    String(buf.to_string()),
    @common.Span::new(start, self.current_pos()),
  )
}

///|
/// Lex a comment (// or /* */)
fn Lexer::lex_comment_or_invalid(self : Lexer, start : @common.Pos) -> Token {
  let _ = self.advance() // consume first /
  match self.peek() {
    Some('/') => {
      let _ = self.advance() // consume second /
      // Line comment - read until newline
      let content = self.skip_while(fn(c) { c != '\n' && c != '\r' })
      Token::new(
        LineComment(content),
        @common.Span::new(start, self.current_pos()),
      )
    }
    Some('*') => {
      let _ = self.advance() // consume *
      // Block comment - read until */
      let buf = StringBuilder::new()
      while true {
        match self.peek() {
          None =>
            return Token::new(
              Invalid("unclosed block comment"),
              @common.Span::new(start, self.current_pos()),
            )
          Some('*') => {
            let _ = self.advance()
            if self.peek() == Some('/') {
              let _ = self.advance()
              break
            } else {
              buf.write_char('*')
            }
          }
          Some(ch) => {
            let _ = self.advance()
            buf.write_char(ch)
          }
        }
      }
      Token::new(
        BlockComment(buf.to_string()),
        @common.Span::new(start, self.current_pos()),
      )
    }
    _ =>
      Token::new(
        Invalid("unexpected character: /"),
        @common.Span::new(start, self.current_pos()),
      )
  }
}

///|
/// Lex a number
fn Lexer::lex_number(self : Lexer, start : @common.Pos) -> Token {
  let num_start = self.pos
  // Optional minus
  if self.peek() == Some('-') {
    let _ = self.advance()

  }
  // Integer part
  match self.peek() {
    Some('0') => {
      let _ = self.advance()

    }
    Some(c) if c >= '1' && c <= '9' => {
      let _ = self.advance()
      while self.peek() is Some(d) && d >= '0' && d <= '9' {
        let _ = self.advance()

      }
    }
    _ =>
      return Token::new(
        Invalid("invalid number"),
        @common.Span::new(start, self.current_pos()),
      )
  }
  // Fractional part
  if self.peek() == Some('.') {
    let _ = self.advance()
    if not(self.peek() is Some(d) && d >= '0' && d <= '9') {
      return Token::new(
        Invalid("invalid number: expected digit after decimal point"),
        @common.Span::new(start, self.current_pos()),
      )
    }
    while self.peek() is Some(d) && d >= '0' && d <= '9' {
      let _ = self.advance()

    }
  }
  // Exponent part
  if self.peek() is Some(e) && (e == 'e' || e == 'E') {
    let _ = self.advance()
    if self.peek() is Some(s) && (s == '+' || s == '-') {
      let _ = self.advance()

    }
    if not(self.peek() is Some(d) && d >= '0' && d <= '9') {
      return Token::new(
        Invalid("invalid number: expected digit in exponent"),
        @common.Span::new(start, self.current_pos()),
      )
    }
    while self.peek() is Some(d) && d >= '0' && d <= '9' {
      let _ = self.advance()

    }
  }
  let num = (try! self.source[num_start:self.pos]).to_string()
  Token::new(Number(num), @common.Span::new(start, self.current_pos()))
}

///|
/// Lex a keyword (true, false, null)
fn Lexer::lex_keyword(
  self : Lexer,
  expected : String,
  kind : TokenKind,
  start : @common.Pos,
) -> Token {
  for i = 0; i < expected.length(); i = i + 1 {
    match self.peek() {
      Some(c) if c == expected[i].to_int().unsafe_to_char() => {
        let _ = self.advance()

      }
      _ => {
        // Not a keyword, might be an identifier (invalid in JSON)
        let ident = self.skip_while(fn(c) { is_ident_char(c) })
        return Token::new(
          Invalid(
            "unexpected identifier: " + (try! expected[:i]).to_string() + ident,
          ),
          @common.Span::new(start, self.current_pos()),
        )
      }
    }
  }
  // Check that keyword is not followed by identifier char
  if self.peek() is Some(c) && is_ident_char(c) {
    let rest = self.skip_while(fn(c) { is_ident_char(c) })
    return Token::new(
      Invalid("unexpected identifier: " + expected + rest),
      @common.Span::new(start, self.current_pos()),
    )
  }
  Token::new(kind, @common.Span::new(start, self.current_pos()))
}

///|
/// Tokenize entire source into array of tokens
pub fn Lexer::tokenize(self : Lexer) -> Array[Token] {
  let tokens : Array[Token] = []
  while true {
    let tok = self.next_token()
    let is_eof = tok.kind == Eof
    tokens.push(tok)
    if is_eof {
      break
    }
  }
  tokens
}

// Helper functions

///|
fn is_hex_digit(c : Char) -> Bool {
  (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

///|
fn parse_hex(s : String) -> Int? {
  let mut result = 0
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i].to_int().unsafe_to_char()
    let digit = if c >= '0' && c <= '9' {
      c.to_int() - '0'.to_int()
    } else if c >= 'a' && c <= 'f' {
      c.to_int() - 'a'.to_int() + 10
    } else if c >= 'A' && c <= 'F' {
      c.to_int() - 'A'.to_int() + 10
    } else {
      return None
    }
    result = result * 16 + digit
  }
  Some(result)
}

///|
fn is_ident_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '_'
}
