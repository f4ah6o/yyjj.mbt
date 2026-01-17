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
          #|  
          #|  _: &__ 'zWee'
          #|KU5ACG: *__
        ),
      )
    }
    Err(e) => inspect(e.to_string())
  }
}
