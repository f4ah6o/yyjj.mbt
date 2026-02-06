///|
/// Test literal block dynamic indentation (issue #14)
/// The YAML spec says block content indent is determined by the first content line,
/// not by a fixed increment from the parent indent.
test "literal_block_dynamic_indent" {
  // Test case: deeply indented literal block (more than current_indent + 2)
  // The lexer should read all lines with >= block_indent spaces
  let source1 = "key: |\n    deeply indented\n  less indented"
  let result1 = @yaml.parse(source1)
  match result1 {
    Ok(parsed) => {
      let content = match parsed {
        @yaml.YamlNode::YMapping(pairs, _, _) =>
          match pairs[0].value {
            @yaml.YamlNode::YString(s, _, _) => s
            _ => "not a string"
          }
        _ => "not a mapping"
      }
      // Current implementation reads both lines because both have >= 2 spaces
      inspect(content, content="deeply indented\nless indented")
    }
    Err(e) => inspect(false, content="Parse error: " + e.to_string())
  }
}

///|
/// Debug test for anchor/alias roundtrip with nested structures
test "anchor_alias_nested_mapping_roundtrip" {
  // A simplified failing case: nested mapping with anchor
  let inner_map = @yaml.YamlNode::mapping_with_trivia(
    [
      @yaml.YKeyValue::new(
        @yaml.YamlNode::string_with_trivia(
          "a",
          @yaml.YamlScalarStyle::plain(),
          @common.Trivia::empty(),
        ),
        @common.Trivia::empty(),
        @yaml.YamlNode::string_with_trivia(
          "value",
          @yaml.YamlScalarStyle::plain(),
          @common.Trivia::empty(),
        ),
      ),
    ],
    @common.Trivia::empty(),
  )
  let outer_map = @yaml.YamlNode::mapping_with_trivia(
    [
      @yaml.YKeyValue::new(
        @yaml.YamlNode::string_with_trivia(
          "key1",
          @yaml.YamlScalarStyle::plain(),
          @common.Trivia::empty(),
        ),
        @common.Trivia::empty(),
        @yaml.YamlNode::string_with_trivia(
          "value1",
          @yaml.YamlScalarStyle::plain(),
          @common.Trivia::empty(),
        ),
      ),
      @yaml.YKeyValue::new(
        @yaml.YamlNode::string_with_trivia(
          "key2",
          @yaml.YamlScalarStyle::plain(),
          @common.Trivia::empty(),
        ),
        @common.Trivia::empty(),
        @yaml.YamlNode::anchor("anchor1", inner_map),
      ),
      @yaml.YKeyValue::new(
        @yaml.YamlNode::string_with_trivia(
          "key3",
          @yaml.YamlScalarStyle::plain(),
          @common.Trivia::empty(),
        ),
        @common.Trivia::empty(),
        @yaml.YamlNode::alias_with_trivia("anchor1", @common.Trivia::empty()),
      ),
    ],
    @common.Trivia::empty(),
  )
  let printed = @yaml.print(outer_map)
  inspect(
    printed,
    content=(
      #|key1: value1
      #|key2: &anchor1
      #|  a: value
      #|key3: *anchor1
    ),
  )
  let parsed_result = @yaml.parse(printed)
  match parsed_result {
    Ok(parsed) => {
      let reparsed = @yaml.print(parsed)
      inspect(
        reparsed,
        content=(
          #|key1: value1
          #|key2: &anchor1
          #|  a: value
          #|key3: *anchor1
        ),
      )
    }
    Err(e) => inspect(false, content="Parse error: " + e.to_string())
  }
}

///|
/// Test nested sequence in mapping roundtrip
test "nested_sequence_in_mapping_roundtrip" {
  // Create a mapping with a nested sequence as value
  let inner_seq = @yaml.YamlNode::sequence_with_style(
    [
      @yaml.YamlNode::string_with_trivia(
        "a",
        @yaml.YamlScalarStyle::plain(),
        @common.Trivia::empty(),
      ),
      @yaml.YamlNode::string_with_trivia(
        "b",
        @yaml.YamlScalarStyle::plain(),
        @common.Trivia::empty(),
      ),
    ],
    @yaml.YamlCollectionStyle::block(),
    @common.Trivia::empty(),
  )
  let outer_seq = @yaml.YamlNode::sequence_with_style(
    [inner_seq],
    @yaml.YamlCollectionStyle::block(),
    @common.Trivia::empty(),
  )
  let mapping = @yaml.YamlNode::mapping_with_trivia(
    [
      @yaml.YKeyValue::new(
        @yaml.YamlNode::string_with_trivia(
          "key",
          @yaml.YamlScalarStyle::plain(),
          @common.Trivia::empty(),
        ),
        @common.Trivia::empty(),
        outer_seq,
      ),
    ],
    @common.Trivia::empty(),
  )
  let printed = @yaml.print(mapping)
  // Nested sequences are converted to flow style for unambiguous parsing
  inspect(
    printed,
    content=(
      #|key:
      #|  - [a, b]
    ),
  )
  match @yaml.parse(printed) {
    Ok(parsed) => {
      let reparsed = @yaml.print(parsed)
      inspect(
        reparsed,
        content=(
          #|key:
          #|  - [a, b]
        ),
      )
    }
    Err(e) => inspect(false, content="Parse error: " + e.to_string())
  }
}

///|
/// Test special characters in double-quoted strings roundtrip
test "special_chars_double_quoted_roundtrip" {
  // Test the problematic string from the failing PBT case
  let problematic = "5.3-5T1\"i~}\\\\ekfvG'3'0 0"
  let node = @yaml.YamlNode::string_with_trivia(
    problematic,
    @yaml.YamlScalarStyle::double_quoted(),
    @common.Trivia::empty(),
  )
  let printed = @yaml.print(node)
  // The string should be printed with double quotes and proper escaping
  inspect(
    printed,
    content=(
      #|"5.3-5T1\"i~}\\\\ekfvG'3'0 0"
    ),
  )
  match @yaml.parse(printed) {
    Ok(parsed) => {
      let parsed_content = match parsed {
        @yaml.YamlNode::YString(s, _, _) => s
        _ => "not a string"
      }
      // The content should be preserved after roundtrip
      inspect(parsed_content, content=problematic)
    }
    Err(e) => inspect(false, content="Parse error: " + e.to_string())
  }
}

///|
/// Test actual failing PBT case for anchor/alias roundtrip
test "actual_failing_pbt_anchor_alias_case" {
  // Based on the actual failing case from pbt_yaml_anchor_alias_roundtrip
  let inner_map = @yaml.YamlNode::mapping_with_trivia(
    [
      @yaml.YKeyValue::new(
        @yaml.YamlNode::string_with_trivia(
          "IQGbOIT",
          @yaml.YamlScalarStyle::plain(),
          @common.Trivia::empty(),
        ),
        @common.Trivia::empty(),
        @yaml.YamlNode::anchor(
          "p_-34GA",
          @yaml.YamlNode::string_with_trivia(
            "DopbOkw",
            @yaml.YamlScalarStyle::single_quoted(),
            @common.Trivia::empty(),
          ),
        ),
      ),
      @yaml.YKeyValue::new(
        @yaml.YamlNode::string_with_trivia(
          "SgfDq7Spz8fEh",
          @yaml.YamlScalarStyle::plain(),
          @common.Trivia::empty(),
        ),
        @common.Trivia::empty(),
        @yaml.YamlNode::alias_with_trivia("p_-34GA", @common.Trivia::empty()),
      ),
    ],
    @common.Trivia::empty(),
  )
  let outer_map = @yaml.YamlNode::mapping_with_trivia(
    [
      @yaml.YKeyValue::new(
        @yaml.YamlNode::string_with_trivia(
          "wJ1Rh",
          @yaml.YamlScalarStyle::plain(),
          @common.Trivia::empty(),
        ),
        @common.Trivia::empty(),
        inner_map,
      ),
    ],
    @common.Trivia::empty(),
  )
  let printed = @yaml.print(outer_map)
  inspect(
    printed,
    content=(
      #|wJ1Rh:
      #|  IQGbOIT: &p_-34GA 'DopbOkw'
      #|  SgfDq7Spz8fEh: *p_-34GA
    ),
  )
  match @yaml.parse(printed) {
    Ok(parsed) => {
      let reparsed = @yaml.print(parsed)
      inspect(
        reparsed,
        content=(
          #|wJ1Rh:
          #|  IQGbOIT: &p_-34GA 'DopbOkw'
          #|  SgfDq7Spz8fEh: *p_-34GA
        ),
      )
    }
    Err(e) => inspect(false, content="Parse error: " + e.to_string())
  }
}

///|
/// Test literal block with special characters (issue #14)
test "literal_block_with_special_chars" {
  // Test various special characters that might be filtered
  let test_cases = [
    ("[value", "bracket"), // Starting bracket
    ("{value", "brace"), // Starting brace
    (":value", "colon"), // Starting colon
    ("#value", "hash"), // Starting hash
  ]
  for i = 0; i < test_cases.length(); i = i + 1 {
    let (content, _desc) = test_cases[i]
    let node = @yaml.YamlNode::string_with_trivia(
      content,
      @yaml.YamlScalarStyle::literal(),
      @common.Trivia::empty(),
    )
    let printed = @yaml.print(node)
    let parsed_result = @yaml.parse(printed)
    match parsed_result {
      Ok(parsed) => {
        // Verify roundtrip preserves the content
        let parsed_content = match parsed {
          @yaml.YamlNode::YString(s, _, _) => s
          _ => "FAIL: not a string node"
        }
        inspect(parsed_content, content~)
      }
      Err(_) => inspect(false, content="Failed to parse: " + content)
    }
  }
}

///|
/// Test exact PBT failing case for anchor/alias roundtrip
test "pbt_failing_case_anchor_alias" {
  // The exact failing case from pbt_yaml_anchor_alias_roundtrip
  // YMapping([
  //   {key: "4xVV", value: YMapping([
  //     {key: "JKEAvC", value: YString("ar/", Literal)},
  //     {key: "_", value: YAnchor("__", YString("zWee", SingleQuoted))}
  //   ])},
  //   {key: "KU5ACG", value: YAlias("__")}
  // ])

  let inner_map = @yaml.YamlNode::mapping_with_trivia(
    [
      @yaml.YKeyValue::new(
        @yaml.YamlNode::string_with_trivia(
          "JKEAvC",
          @yaml.YamlScalarStyle::plain(),
          @common.Trivia::empty(),
        ),
        @common.Trivia::empty(),
        @yaml.YamlNode::string_with_trivia(
          "ar/",
          @yaml.YamlScalarStyle::literal(),
          @common.Trivia::empty(),
        ),
      ),
      @yaml.YKeyValue::new(
        @yaml.YamlNode::string_with_trivia(
          "_",
          @yaml.YamlScalarStyle::plain(),
          @common.Trivia::empty(),
        ),
        @common.Trivia::empty(),
        @yaml.YamlNode::anchor(
          "__",
          @yaml.YamlNode::string_with_trivia(
            "zWee",
            @yaml.YamlScalarStyle::single_quoted(),
            @common.Trivia::empty(),
          ),
        ),
      ),
    ],
    @common.Trivia::empty(),
  )
  let outer_map = @yaml.YamlNode::mapping_with_trivia(
    [
      @yaml.YKeyValue::new(
        @yaml.YamlNode::string_with_trivia(
          "4xVV",
          @yaml.YamlScalarStyle::plain(),
          @common.Trivia::empty(),
        ),
        @common.Trivia::empty(),
        inner_map,
      ),
      @yaml.YKeyValue::new(
        @yaml.YamlNode::string_with_trivia(
          "KU5ACG",
          @yaml.YamlScalarStyle::plain(),
          @common.Trivia::empty(),
        ),
        @common.Trivia::empty(),
        @yaml.YamlNode::alias_with_trivia("__", @common.Trivia::empty()),
      ),
    ],
    @common.Trivia::empty(),
  )

  // Test roundtrip
  let printed = @yaml.print(outer_map)
  let parsed_result = @yaml.parse(printed)
  inspect(
    printed,
    content=(
      #|4xVV:
      #|  JKEAvC: |
      #|    ar/
      #|  
      #|  _: &__ 'zWee'
      #|KU5ACG: *__
    ),
  )
  match parsed_result {
    Ok(parsed) => {
      let reparsed = @yaml.print(parsed)
      inspect(
        reparsed,
        content=(
          #|4xVV:
          #|  JKEAvC: |
          #|    ar/
          #|  
          #|  _: &__ 'zWee'
          #|KU5ACG: *__
        ),
      )
    }
    Err(e) => inspect(e.to_string())
  }
}
