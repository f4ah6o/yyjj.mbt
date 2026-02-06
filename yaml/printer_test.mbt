///|
test "empty_string_double_quoted_roundtrip" {
  let yaml = "key: \"\""
  match @yaml.parse(yaml) {
    Ok(parsed) => {
      let printed = @yaml.print(parsed)
      inspect(printed, content="key: \"\"")
      match @yaml.parse(printed) {
        Ok(roundtripped) => {
          let orig_stripped = strip_yaml_trivia(parsed)
          let rt_stripped = strip_yaml_trivia(roundtripped)
          inspect(orig_stripped == rt_stripped, content="true")
        }
        Err(_) => inspect(false, content="Failed to parse roundtripped")
      }
    }
    Err(_) => inspect(false, content="Failed to parse initial")
  }
}

///|
test "empty_string_single_quoted_roundtrip" {
  let yaml = "key: ''"
  match @yaml.parse(yaml) {
    Ok(parsed) => {
      let printed = @yaml.print(parsed)
      inspect(printed, content="key: ''")
      match @yaml.parse(printed) {
        Ok(roundtripped) => {
          let orig_stripped = strip_yaml_trivia(parsed)
          let rt_stripped = strip_yaml_trivia(roundtripped)
          inspect(orig_stripped == rt_stripped, content="true")
        }
        Err(_) => inspect(false, content="Failed to parse roundtripped")
      }
    }
    Err(_) => inspect(false, content="Failed to parse initial")
  }
}

///|
test "empty_string_literal_roundtrip" {
  let yaml = "key: |\n"
  match @yaml.parse(yaml) {
    Ok(parsed) => {
      let printed = @yaml.print(parsed)
      match @yaml.parse(printed) {
        Ok(roundtripped) => {
          let orig_stripped = strip_yaml_trivia(parsed)
          let rt_stripped = strip_yaml_trivia(roundtripped)
          inspect(orig_stripped == rt_stripped, content="true")
        }
        Err(_) => inspect(false, content="Failed to parse roundtripped")
      }
    }
    Err(_) => inspect(false, content="Failed to parse initial")
  }
}

///|
test "empty_string_folded_roundtrip" {
  let yaml = "key: >\n"
  match @yaml.parse(yaml) {
    Ok(parsed) => {
      let printed = @yaml.print(parsed)
      match @yaml.parse(printed) {
        Ok(roundtripped) => {
          let orig_stripped = strip_yaml_trivia(parsed)
          let rt_stripped = strip_yaml_trivia(roundtripped)
          inspect(orig_stripped == rt_stripped, content="true")
        }
        Err(_) => inspect(false, content="Failed to parse roundtripped")
      }
    }
    Err(_) => inspect(false, content="Failed to parse initial")
  }
}

///|
test "folded_block_multiline_formatting" {
  let yaml_str = "key: >\n  wrapped\n  text\n  becomes single"
  match @yaml.parse(yaml_str) {
    Ok(parsed) => {
      let printed = @yaml.print(parsed)
      // The folded block should print each line with proper indentation
      inspect(printed.has_prefix("key: >\n"), content="true")
      match @yaml.parse(printed) {
        Ok(roundtripped) => {
          let orig_stripped = strip_yaml_trivia(parsed)
          let rt_stripped = strip_yaml_trivia(roundtripped)
          inspect(orig_stripped == rt_stripped, content="true")
        }
        Err(_) => inspect(false, content="Failed to parse roundtripped")
      }
    }
    Err(_) => inspect(false, content="Failed to parse initial")
  }
}
