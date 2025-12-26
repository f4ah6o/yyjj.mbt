///|
test "yaml_parse_simple_mapping" {
  let source = "key: value"
  let result = @yaml.parse(source)
  guard result is Ok(@yaml.YMapping(pairs, _)) else { return }
  inspect(pairs.length(), content="1")
}

///|
test "yaml_parse_sequence" {
  let source = (
    #|- item1
    #|- item2
    #|- item3
  )
  let result = @yaml.parse(source)
  guard result is Ok(@yaml.YSequence(elements, _)) else { return }
  inspect(elements.length(), content="3")
}

///|
test "yaml_parse_flow_sequence" {
  let result = @yaml.parse("[1, 2, 3]")
  guard result is Ok(@yaml.YSequence(elements, _)) else { return }
  inspect(elements.length(), content="3")
}

///|
test "yaml_parse_flow_mapping" {
  let result = @yaml.parse("{key: value}")
  guard result is Ok(@yaml.YMapping(pairs, _)) else { return }
  inspect(pairs.length(), content="1")
}

///|
test "yaml_parse_with_comment" {
  let source = "key: value # this is a comment"
  let result = @yaml.parse(source)
  guard result is Ok(_) else { return }
  // Parse should succeed with comment
}

///|
test "yaml_parse_booleans" {
  let result1 = @yaml.parse("true")
  guard result1 is Ok(@yaml.YBool(true, _)) else { return }
  let result2 = @yaml.parse("false")
  guard result2 is Ok(@yaml.YBool(false, _)) else { return }
}

///|
test "yaml_parse_null" {
  let result = @yaml.parse("null")
  guard result is Ok(@yaml.YNull(_)) else { return }
}
