///|
/// YAML Parser - parses tokens into CST with trivia attachment
pub struct Parser {
  tokens : Array[Token]
  mut pos : Int
  pending_trivia : Array[@common.Comment]
  mut saw_newline : Bool
}

///|
pub fn Parser::from_source(source : String) -> Parser {
  let lexer = Lexer::new(source)
  let tokens = lexer.tokenize()
  { tokens, pos: 0, pending_trivia: [], saw_newline: false }
}

///|
pub fn Parser::new(tokens : Array[Token]) -> Parser {
  { tokens, pos: 0, pending_trivia: [], saw_newline: false }
}

///|
fn Parser::is_eof(self : Parser) -> Bool {
  self.pos >= self.tokens.length() || self.peek_kind() == Some(Eof)
}

///|
fn Parser::peek(self : Parser) -> Token? {
  if self.pos < self.tokens.length() {
    Some(self.tokens[self.pos])
  } else {
    None
  }
}

///|
fn Parser::peek_kind(self : Parser) -> TokenKind? {
  match self.peek() {
    Some(t) => Some(t.kind)
    None => None
  }
}

///|
fn Parser::advance(self : Parser) -> Token? {
  if self.pos < self.tokens.length() {
    let tok = self.tokens[self.pos]
    self.pos += 1
    Some(tok)
  } else {
    None
  }
}

///|
fn Parser::current_span(self : Parser) -> @common.Span {
  match self.peek() {
    Some(t) => t.span
    None => @common.Span::at(@common.Pos::zero())
  }
}

///|
fn Parser::skip_trivia(self : Parser) -> Unit {
  while true {
    match self.peek_kind() {
      Some(Whitespace(_)) => {
        let _ = self.advance()

      }
      Some(Newline) => {
        let _ = self.advance()
        self.saw_newline = true
      }
      Some(Comment(content)) => {
        let tok = self.advance()
        guard tok is Some(t) else { return }
        let comment = @common.Comment::new(
          content,
          @common.CommentKind::line(),
          t.span,
          self.saw_newline,
        )
        self.pending_trivia.push(comment)
        self.saw_newline = true
      }
      Some(Indent(_)) | Some(Dedent(_)) => {
        // Keep indent/dedent tokens for structure
        break
      }
      _ => break
    }
  }
}

///|
fn Parser::flush_leading(self : Parser) -> Array[@common.Comment] {
  let leading = self.pending_trivia.copy()
  self.pending_trivia.clear()
  self.saw_newline = false
  leading
}

///|
fn Parser::collect_trailing(self : Parser) -> Array[@common.Comment] {
  let trailing : Array[@common.Comment] = []
  while true {
    match self.peek_kind() {
      Some(Whitespace(_)) => {
        let _ = self.advance()

      }
      Some(Comment(content)) => {
        if not(self.saw_newline) {
          let tok = self.advance()
          guard tok is Some(t) else { break }
          let comment = @common.Comment::new(
            content,
            @common.CommentKind::line(),
            t.span,
            false,
          )
          trailing.push(comment)
          self.saw_newline = true
        }
        break
      }
      Some(Newline) => {
        let _ = self.advance()
        self.saw_newline = true
        break
      }
      _ => break
    }
  }
  trailing
}

///|
pub fn Parser::parse(self : Parser) -> Result[YamlNode, @common.ParseError] {
  self.skip_trivia()
  self.parse_value()
}

///|
fn Parser::parse_value(self : Parser) -> Result[YamlNode, @common.ParseError] {
  self.skip_trivia()
  let leading = self.flush_leading()
  match self.peek_kind() {
    Some(Dash) => self.parse_block_sequence(leading)
    Some(PlainScalar(_)) | Some(SingleQuotedScalar(_)) | Some(DoubleQuotedScalar(_)) =>
      self.parse_scalar_or_mapping(leading)
    Some(NullValue) => {
      let _ = self.advance()
      let trailing = self.collect_trailing()
      Ok(YNull(@common.Trivia::new(leading, trailing)))
    }
    Some(TrueValue) => {
      let _ = self.advance()
      let trailing = self.collect_trailing()
      Ok(YBool(true, @common.Trivia::new(leading, trailing)))
    }
    Some(FalseValue) => {
      let _ = self.advance()
      let trailing = self.collect_trailing()
      Ok(YBool(false, @common.Trivia::new(leading, trailing)))
    }
    Some(LBracket) => self.parse_flow_sequence(leading)
    Some(LBrace) => self.parse_flow_mapping(leading)
    Some(LiteralBlock(content)) => {
      let _ = self.advance()
      let trailing = self.collect_trailing()
      Ok(YString(content, Literal, @common.Trivia::new(leading, trailing)))
    }
    Some(FoldedBlock(content)) => {
      let _ = self.advance()
      let trailing = self.collect_trailing()
      Ok(YString(content, Folded, @common.Trivia::new(leading, trailing)))
    }
    Some(Anchor(name)) => {
      let _ = self.advance()
      self.skip_trivia()
      let value = match self.parse_value() {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(YAnchor(name, value))
    }
    Some(Alias(name)) => {
      let _ = self.advance()
      let trailing = self.collect_trailing()
      Ok(YAlias(name, @common.Trivia::new(leading, trailing)))
    }
    Some(Eof) =>
      Ok(YNull(@common.Trivia::new(leading, []))) // Empty document
    Some(kind) =>
      Err(
        @common.ParseError::unexpected_token(
          token_kind_name(kind),
          self.current_span(),
        ),
      )
    None => Err(@common.ParseError::unexpected_eof(self.current_span()))
  }
}

///|
fn Parser::parse_scalar_or_mapping(
  self : Parser,
  leading : Array[@common.Comment]
) -> Result[YamlNode, @common.ParseError] {
  // Get the scalar value
  let (scalar, style) = match self.peek_kind() {
    Some(PlainScalar(s)) => (s, Plain)
    Some(SingleQuotedScalar(s)) => (s, SingleQuoted)
    Some(DoubleQuotedScalar(s)) => (s, DoubleQuoted)
    _ => return Err(@common.ParseError::unexpected_eof(self.current_span()))
  }
  let _ = self.advance()
  // Check if this is a mapping (followed by colon)
  self.skip_trivia()
  if self.peek_kind() == Some(Colon) {
    // This is a mapping
    self.parse_mapping_with_first_key(scalar, style, leading)
  } else {
    // Just a scalar
    let trailing = self.collect_trailing()
    Ok(YString(scalar, style, @common.Trivia::new(leading, trailing)))
  }
}

///|
fn Parser::parse_mapping_with_first_key(
  self : Parser,
  first_key : String,
  key_style : YamlScalarStyle,
  leading : Array[@common.Comment]
) -> Result[YamlNode, @common.ParseError] {
  let pairs : Array[YKeyValue] = []
  let mut key = first_key
  let mut key_style = key_style
  let mut key_leading = leading
  while true {
    // Expect colon
    if self.peek_kind() != Some(Colon) {
      break
    }
    let _ = self.advance() // consume :
    let key_trailing = self.collect_trailing()
    let key_trivia = @common.Trivia::new(key_leading, key_trailing)
    let key_node = YString(key, key_style, @common.Trivia::empty())
    // Parse value
    self.skip_trivia()
    // Handle indent for block value
    if self.peek_kind() is Some(Indent(_)) {
      let _ = self.advance()
      self.skip_trivia()
    }
    let value = match self.parse_value() {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    pairs.push(YKeyValue::new(key_node, key_trivia, value))
    // Handle dedent
    self.skip_trivia()
    while self.peek_kind() is Some(Dedent(_)) {
      let _ = self.advance()
      self.skip_trivia()
    }
    // Check for next key
    self.skip_trivia()
    match self.peek_kind() {
      Some(PlainScalar(s)) => {
        key = s
        key_style = Plain
        key_leading = self.flush_leading()
        let _ = self.advance()
        self.skip_trivia()
      }
      Some(SingleQuotedScalar(s)) => {
        key = s
        key_style = SingleQuoted
        key_leading = self.flush_leading()
        let _ = self.advance()
        self.skip_trivia()
      }
      Some(DoubleQuotedScalar(s)) => {
        key = s
        key_style = DoubleQuoted
        key_leading = self.flush_leading()
        let _ = self.advance()
        self.skip_trivia()
      }
      _ => break
    }
  }
  Ok(YMapping(pairs, @common.Trivia::empty()))
}

///|
fn Parser::parse_block_sequence(
  self : Parser,
  leading : Array[@common.Comment]
) -> Result[YamlNode, @common.ParseError] {
  let elements : Array[YamlNode] = []
  while self.peek_kind() == Some(Dash) {
    let _ = self.advance() // consume -
    self.skip_trivia()
    // Handle indent
    if self.peek_kind() is Some(Indent(_)) {
      let _ = self.advance()
      self.skip_trivia()
    }
    let elem = match self.parse_value() {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    elements.push(elem)
    // Handle dedent and newline
    self.skip_trivia()
    while self.peek_kind() is Some(Dedent(_)) {
      let _ = self.advance()
      self.skip_trivia()
    }
    self.skip_trivia()
  }
  Ok(YSequence(elements, @common.Trivia::new(leading, [])))
}

///|
fn Parser::parse_flow_sequence(
  self : Parser,
  leading : Array[@common.Comment]
) -> Result[YamlNode, @common.ParseError] {
  let _ = self.advance() // consume [
  let elements : Array[YamlNode] = []
  self.skip_trivia()
  while self.peek_kind() != Some(RBracket) && not(self.is_eof()) {
    let elem = match self.parse_value() {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    elements.push(elem)
    self.skip_trivia()
    if self.peek_kind() == Some(Comma) {
      let _ = self.advance()
      self.skip_trivia()
    }
  }
  if self.peek_kind() == Some(RBracket) {
    let _ = self.advance()

  }
  let trailing = self.collect_trailing()
  Ok(YSequence(elements, @common.Trivia::new(leading, trailing)))
}

///|
fn Parser::parse_flow_mapping(
  self : Parser,
  leading : Array[@common.Comment]
) -> Result[YamlNode, @common.ParseError] {
  let _ = self.advance() // consume {
  let pairs : Array[YKeyValue] = []
  self.skip_trivia()
  while self.peek_kind() != Some(RBrace) && not(self.is_eof()) {
    // Parse key
    let (key_str, key_style) = match self.peek_kind() {
      Some(PlainScalar(s)) => {
        let _ = self.advance()
        (s, Plain)
      }
      Some(SingleQuotedScalar(s)) => {
        let _ = self.advance()
        (s, SingleQuoted)
      }
      Some(DoubleQuotedScalar(s)) => {
        let _ = self.advance()
        (s, DoubleQuoted)
      }
      _ => break
    }
    let key_node = YString(key_str, key_style, @common.Trivia::empty())
    self.skip_trivia()
    // Expect colon
    if self.peek_kind() == Some(Colon) {
      let _ = self.advance()

    }
    self.skip_trivia()
    // Parse value
    let value = match self.parse_value() {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    pairs.push(YKeyValue::new(key_node, @common.Trivia::empty(), value))
    self.skip_trivia()
    if self.peek_kind() == Some(Comma) {
      let _ = self.advance()
      self.skip_trivia()
    }
  }
  if self.peek_kind() == Some(RBrace) {
    let _ = self.advance()

  }
  let trailing = self.collect_trailing()
  Ok(YMapping(pairs, @common.Trivia::new(leading, trailing)))
}

///|
fn token_kind_name(kind : TokenKind) -> String {
  match kind {
    Colon => "':'"
    Dash => "'-'"
    Comma => "','"
    LBrace => "'{'"
    RBrace => "'}'"
    LBracket => "'['"
    RBracket => "']'"
    Indent(n) => "indent(" + n.to_string() + ")"
    Dedent(n) => "dedent(" + n.to_string() + ")"
    PlainScalar(s) => "scalar: " + s
    SingleQuotedScalar(s) => "'" + s + "'"
    DoubleQuotedScalar(s) => "\"" + s + "\""
    LiteralBlock(_) => "literal block"
    FoldedBlock(_) => "folded block"
    NullValue => "null"
    TrueValue => "true"
    FalseValue => "false"
    Anchor(n) => "&" + n
    Alias(n) => "*" + n
    Comment(_) => "comment"
    Whitespace(_) => "whitespace"
    Newline => "newline"
    DocumentStart => "---"
    DocumentEnd => "..."
    Eof => "end of input"
    Invalid(msg) => msg
  }
}

///|
pub fn parse(source : String) -> Result[YamlNode, @common.ParseError] {
  let parser = Parser::from_source(source)
  parser.parse()
}
