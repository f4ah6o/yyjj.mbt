///|
test "lex_simple_object" {
  let lexer = @jsonc.Lexer::new("{\"key\": 123}")
  let tokens = lexer.tokenize()
  let kinds = tokens.map(fn(t) { t.kind })
  inspect(
    kinds,
    content="[LBrace, String(\"key\"), Colon, Whitespace(\" \"), Number(\"123\"), RBrace, Eof]",
  )
}

///|
test "lex_with_comments" {
  let source = (
    #|{
    #|  "a": 1 // comment
    #|}
  )
  let lexer = @jsonc.Lexer::new(source)
  let tokens = lexer.tokenize()
  let comment_tokens = tokens.filter(fn(t) { t.is_comment() })
  inspect(comment_tokens.length(), content="1")
}

///|
test "lex_block_comment" {
  let lexer = @jsonc.Lexer::new("/* block */ true")
  let tokens = lexer.tokenize()
  let kinds = tokens.map(fn(t) { t.kind })
  inspect(
    kinds,
    content="[BlockComment(\" block \"), Whitespace(\" \"), True, Eof]",
  )
}

///|
test "lex_string_escapes" {
  let lexer = @jsonc.Lexer::new("\"hello\\nworld\\t\\\"quoted\\\"\"")
  let tokens = lexer.tokenize()
  guard tokens[0].kind is @jsonc.String(s) else { return }
  // String content is unescaped and doesn't include outer quotes
  inspect(s, content="hello\nworld\t\"quoted\"")
}

///|
test "lex_unicode_escape" {
  let lexer = @jsonc.Lexer::new("\"\\u0041\"") // A
  let tokens = lexer.tokenize()
  guard tokens[0].kind is @jsonc.String(s) else { return }
  inspect(s, content="A")
}

///|
test "lex_numbers" {
  let lexer = @jsonc.Lexer::new("123 -456 3.14 1e10 2.5E-3")
  let tokens = lexer.tokenize()
  let nums = tokens.filter(
    fn(t) {
      match t.kind {
        @jsonc.Number(_) => true
        _ => false
      }
    },
  )
  inspect(nums.length(), content="5")
}

///|
test "lex_keywords" {
  let lexer = @jsonc.Lexer::new("true false null")
  let tokens = lexer.tokenize()
  let kinds = tokens.map(fn(t) { t.kind })
  inspect(
    kinds,
    content="[True, Whitespace(\" \"), False, Whitespace(\" \"), Null, Eof]",
  )
}

///|
test "lex_trailing_comma" {
  let lexer = @jsonc.Lexer::new("[1, 2, 3,]")
  let tokens = lexer.tokenize()
  // Should tokenize successfully including the trailing comma
  let commas = tokens.filter(
    fn(t) {
      match t.kind {
        @jsonc.Comma => true
        _ => false
      }
    },
  )
  inspect(commas.length(), content="3")
}
