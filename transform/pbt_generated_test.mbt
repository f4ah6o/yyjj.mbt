///|
/// Property-Based Tests for transform
/// Auto-generated from transform.pbt.mbt.md

///|
test "prop_jsonc_yaml_jsonc_roundtrip" {
  // Test fixtures for cross-format round-trip
  let fixtures = [
    "null", "true", "false", "42", "-1", "3.14", "\"hello\"", "[]", "{}", "[1, 2, 3]",
    "{\"key\": \"value\"}", "{\"a\": 1, \"b\": 2}", "{\"nested\": {\"key\": \"value\"}}",
    "[null, true, false]", "{\"arr\": [1, 2, 3], \"empty\": [], \"obj\": {}}",
  ]
  for source in fixtures {
    let result1 = @jsonc.parse(source)
    guard result1 is Ok(jsonc_node) else { continue }
    let yaml_node = @transform.jsonc_to_yaml(jsonc_node)
    let jsonc_node2 = @transform.yaml_to_jsonc(yaml_node)
    let stripped1 = strip_jsonc_trivia(jsonc_node)
    let stripped2 = strip_jsonc_trivia(jsonc_node2)
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
