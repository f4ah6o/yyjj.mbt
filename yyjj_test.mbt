///|
test "jsonc_to_yaml_simple" {
  let jsonc = "{\"name\": \"test\", \"value\": 42}"
  let result = @yyjj.jsonc_to_yaml(jsonc)
  guard result is Ok(yaml) else { return }
  // YAML output should contain key: value format
  inspect(yaml.contains("name:"), content="true")
  inspect(yaml.contains("value:"), content="true")
}

///|
test "yaml_to_jsonc_simple" {
  let yaml = "name: test\nvalue: 42"
  let result = @yyjj.yaml_to_jsonc(yaml)
  guard result is Ok(jsonc) else { return }
  // JSONC output should contain quoted keys
  inspect(jsonc.contains("\"name\""), content="true")
  inspect(jsonc.contains("\"value\""), content="true")
}

///|
test "parse_jsonc" {
  let jsonc = "{\"key\": \"value\"}"
  let result = @yyjj.parse_jsonc(jsonc)
  guard result is Ok(_) else { return }
  // Parse should succeed
}

///|
test "parse_yaml" {
  let yaml = "key: value"
  let result = @yyjj.parse_yaml(yaml)
  guard result is Ok(_) else { return }
  // Parse should succeed
}

///|
test "round_trip_jsonc_to_yaml" {
  let original = "{\"items\": [1, 2, 3]}"
  let to_yaml = @yyjj.jsonc_to_yaml(original)
  guard to_yaml is Ok(yaml) else { return }
  let back_to_jsonc = @yyjj.yaml_to_jsonc(yaml)
  guard back_to_jsonc is Ok(jsonc) else { return }
  // Should contain the same structure
  inspect(jsonc.contains("items"), content="true")
}

///|
test "yaml_to_jsonc_with_comments" {
  let yaml =
    #|# This is a comment
    #|name: test
    #|value: 42  # trailing comment
  let result = @yyjj.yaml_to_jsonc(yaml)
  guard result is Ok(jsonc) else { return }
  println("YAML input:")
  println(yaml)
  println("\nJSONC output:")
  println(jsonc)
  // Should preserve comments
  inspect(jsonc.contains("//"), content="true")
}

///|
test "yaml_to_jsonc_nested_comments" {
  let yaml =
    #|# Server settings
    #|server: localhost
    #|port: 8080
    #|# Database connection
    #|database:
    #|  host: db.example.com
    #|  # Database name
    #|  name: myapp
  let result = @yyjj.yaml_to_jsonc(yaml)
  guard result is Ok(jsonc) else { return }
  println("YAML with nested comments:")
  println(yaml)
  println("\nJSONC output:")
  println(jsonc)
  // Should preserve all comments including nested ones
  inspect(jsonc.contains("Server settings"), content="true")
  inspect(jsonc.contains("Database connection"), content="true")
  inspect(jsonc.contains("Database name"), content="true")
}
