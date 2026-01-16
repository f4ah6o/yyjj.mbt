///|
/// Property-Based Tests for yyjj (main package)
/// Auto-generated from pbt/yyjj.pbt.mbt.md

///|
test "prop_jsonc_to_yaml_to_jsonc_roundtrip" {
  // Test fixtures for end-to-end conversion
  let fixtures = [
    "null", "true", "false", "42", "-1", "3.14", "\"hello\"", "[]", "{}", "[1, 2, 3]",
    "{\"key\": \"value\"}", "{\"a\": 1, \"b\": 2}", "{\"nested\": {\"key\": \"value\"}}",
    "[null, true, false]", "{\"arr\": [1, 2, 3], \"empty\": [], \"obj\": {}}", "{\n  // This is a comment\n  \"key\": \"value\"\n}",
    "{\"users\": [{\"name\": \"Alice\", \"age\": 30}, {\"name\": \"Bob\", \"age\": 25}]}",
  ]
  for source in fixtures {
    match jsonc_to_yaml(source, width=80) {
      Ok(yaml_str) =>
        match yaml_to_jsonc(yaml_str, width=80) {
          Ok(jsonc_str) =>
            match parse_jsonc(source) {
              Ok(original) =>
                match parse_jsonc(jsonc_str) {
                  Ok(roundtrip) =>
                    assert_eq(
                      strip_jsonc_trivia_e2e(original),
                      strip_jsonc_trivia_e2e(roundtrip),
                    )
                  Err(_) =>
                    inspect(false, content="Failed to parse roundtripped JSONC")
                }
              Err(_) => inspect(false, content="Failed to parse original JSONC")
            }
          Err(e) =>
            inspect(
              false,
              content="yaml_to_jsonc failed: " + @common.ParseError::format(e),
            )
        }
      Err(e) =>
        inspect(
          false,
          content="jsonc_to_yaml failed: " + @common.ParseError::format(e),
        )
    }
  }
}

// Helper to strip trivia for structural comparison

///|
fn strip_jsonc_trivia_e2e(node : @jsonc.JsonNode) -> @jsonc.JsonNode {
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

///|
test "prop_yaml_to_jsonc_to_yaml_roundtrip" {
  // Test fixtures for end-to-end conversion
  let fixtures = [
    "null", "true", "false", "42", "-1", "3.14", "hello", "\"hello\"", "[]", "{}",
    "- item1\n- item2\n- item3", "key: value", "key1: value1\nkey2: value2", "nested:\n  key: value",
    "- 1\n- 2\n- 3", "# This is a comment\nkey: value", "# Header\nlist:\n  - one\n  - two",
  ]
  for source in fixtures {
    match yaml_to_jsonc(source, width=80) {
      Ok(jsonc_str) =>
        match jsonc_to_yaml(jsonc_str, width=80) {
          Ok(yaml_str) =>
            match parse_yaml(source) {
              Ok(original) =>
                match parse_yaml(yaml_str) {
                  Ok(roundtrip) =>
                    assert_eq(
                      strip_yaml_trivia_e2e(original),
                      strip_yaml_trivia_e2e(roundtrip),
                    )
                  Err(_) =>
                    inspect(false, content="Failed to parse roundtripped YAML")
                }
              Err(_) => inspect(false, content="Failed to parse original YAML")
            }
          Err(e) =>
            inspect(
              false,
              content="jsonc_to_yaml failed: " + @common.ParseError::format(e),
            )
        }
      Err(e) =>
        inspect(
          false,
          content="yaml_to_jsonc failed: " + @common.ParseError::format(e),
        )
    }
  }
}

// Helper to strip trivia for structural comparison

///|
fn strip_yaml_trivia_e2e(node : @yaml.YamlNode) -> @yaml.YamlNode {
  let empty = @common.Trivia::empty()
  let flow = @yaml.YamlCollectionStyle::flow()
  let plain = @yaml.YamlScalarStyle::plain()
  match node {
    @yaml.YNull(_) => @yaml.YamlNode::null_with_trivia(empty)
    @yaml.YBool(v, _) => @yaml.YamlNode::bool_with_trivia(v, empty)
    @yaml.YNumber(v, _) => @yaml.YamlNode::number_with_trivia(v, empty)
    @yaml.YString(v, _, _) =>
      // Normalize string style to Plain (JSONC doesn't preserve YAML styles)
      @yaml.YamlNode::string_with_trivia(v, plain, empty)
    @yaml.YSequence(elements, style, _) => {
      let stripped = elements.map(strip_yaml_trivia)
      let normalized_style = if elements.is_empty() { flow } else { style }
      @yaml.YamlNode::sequence_with_style(stripped, normalized_style, empty)
    }
    @yaml.YMapping(pairs, style, _) => {
      let stripped = pairs.map(fn(kv) {
        @yaml.YKeyValue::new(
          strip_yaml_trivia(kv.key),
          empty,
          strip_yaml_trivia(kv.value),
        )
      })
      let normalized_style = if pairs.is_empty() { flow } else { style }
      @yaml.YamlNode::mapping_with_style(stripped, normalized_style, empty)
    }
    @yaml.YAlias(name, _) => @yaml.YamlNode::alias_with_trivia(name, empty)
    @yaml.YAnchor(name, inner) =>
      @yaml.YamlNode::anchor(name, strip_yaml_trivia(inner))
  }
}
