///|
test "parse_simple_object" {
  let result = @jsonc.parse("{\"key\": \"value\"}")
  guard result is Ok(node) else { return }
  guard node is @jsonc.JObject(props, _) else { return }
  inspect(props.length(), content="1")
  inspect(props[0].key, content="key")
}

///|
test "parse_nested_object" {
  let source =
    #|{
    #|  "outer": {
    #|    "inner": 123
    #|  }
    #|}
  let result = @jsonc.parse(source)
  guard result is Ok(node) else { return }
  guard node is @jsonc.JObject(props, _) else { return }
  inspect(props.length(), content="1")
}

///|
test "parse_array" {
  let result = @jsonc.parse("[1, 2, 3]")
  guard result is Ok(node) else { return }
  guard node is @jsonc.JArray(elements, _) else { return }
  inspect(elements.length(), content="3")
}

///|
test "parse_trailing_comma" {
  let result = @jsonc.parse("[1, 2, 3,]")
  guard result is Ok(node) else { return }
  guard node is @jsonc.JArray(elements, _) else { return }
  inspect(elements.length(), content="3")
}

///|
test "parse_with_line_comment" {
  let source =
    #|{
    #|  "key": 1 // trailing comment
    #|}
  let result = @jsonc.parse(source)
  guard result is Ok(node) else { return }
  guard node is @jsonc.JObject(props, _) else { return }
  // Check that the value has a trailing comment
  let trivia = props[0].value.trivia()
  inspect(trivia.trailing.length(), content="1")
}

///|
test "parse_with_leading_comment" {
  let source =
    #|{
    #|  // leading comment
    #|  "key": 1
    #|}
  let result = @jsonc.parse(source)
  guard result is Ok(node) else { return }
  guard node is @jsonc.JObject(props, _) else { return }
  // Check that the key has a leading comment
  let trivia = props[0].key_trivia
  inspect(trivia.leading.length(), content="1")
}

///|
test "parse_with_block_comment" {
  let source = "/* comment */ true"
  let result = @jsonc.parse(source)
  guard result is Ok(node) else { return }
  guard node is @jsonc.JBool(val, trivia) else { return }
  inspect(val, content="true")
  inspect(trivia.leading.length(), content="1")
}

///|
test "parse_keywords" {
  let result1 = @jsonc.parse("true")
  guard result1 is Ok(@jsonc.JBool(true, _)) else { return }
  let result2 = @jsonc.parse("false")
  guard result2 is Ok(@jsonc.JBool(false, _)) else { return }
  let result3 = @jsonc.parse("null")
  guard result3 is Ok(@jsonc.JNull(_)) else { return }
}

///|
test "parse_numbers" {
  let result1 = @jsonc.parse("123")
  guard result1 is Ok(@jsonc.JNumber(n, _)) else { return }
  inspect(n, content="123")
  let result2 = @jsonc.parse("-45.67e8")
  guard result2 is Ok(@jsonc.JNumber(n2, _)) else { return }
  inspect(n2, content="-45.67e8")
}
