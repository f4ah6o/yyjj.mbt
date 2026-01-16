///|
/// Property-Based Tests for jsonc
/// Auto-generated from jsonc.pbt.mbt.md

///|
test "prop_parse_print_parse_roundtrip" {
  // Test fixtures for round-trip
  let fixtures = [
    "null", "true", "false", "42", "-1", "3.14", "\"hello\"", "[]", "{}", "[1, 2, 3]",
    "{\"key\": \"value\"}", "{\"a\": 1, \"b\": 2}", "{\"nested\": {\"key\": \"value\"}}",
    "[null, true, false]", "{\"arr\": [1, 2, 3], \"empty\": [], \"obj\": {}}",
  ]
  for source in fixtures {
    let result1 = @jsonc.parse(source)
    guard result1 is Ok(node1) else { continue }
    let printed = @jsonc.print(node1)
    let result2 = @jsonc.parse(printed)
    guard result2 is Ok(node2) else {
      inspect(false, content="Failed to parse printed output for: " + source)
      continue
    }
    let stripped1 = strip_jsonc_trivia(node1)
    let stripped2 = strip_jsonc_trivia(node2)
    assert_eq(stripped1, stripped2)
  }
}

// Helper to strip trivia for structural comparison

///|
fn strip_jsonc_trivia(node : @jsonc.JsonNode) -> @jsonc.JsonNode {
  let empty = @common.Trivia::empty()
  match node {
    @jsonc.JNull(_) => @jsonc.JsonNode::null_with_trivia(empty)
    @jsonc.JBool(v, _) => @jsonc.JsonNode::bool_with_trivia(v, empty)
    @jsonc.JNumber(v, _) => @jsonc.JsonNode::number_with_trivia(v, empty)
    @jsonc.JString(v, _) => @jsonc.JsonNode::string_with_trivia(v, empty)
    @jsonc.JArray(elements, _) => {
      let stripped = elements.map(strip_jsonc_trivia)
      @jsonc.JsonNode::array_with_trivia(stripped, empty)
    }
    @jsonc.JObject(props, _) => {
      let stripped = props.map(fn(p) {
        @jsonc.JProperty::new(p.key, empty, strip_jsonc_trivia(p.value))
      })
      @jsonc.JsonNode::object_with_trivia(stripped, empty)
    }
  }
}
