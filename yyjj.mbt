///|
/// Conversion options.
///
/// A struct rather than keyword args so fields can be added without breaking
/// existing callers. Start from `ConvertOptions::default()` and use the
/// chainable builder methods below.
pub struct ConvertOptions {
  width : Int
  preserve_comments : Bool
}

///|
/// Defaults: 80-column width, comments preserved.
pub fn ConvertOptions::default() -> ConvertOptions {
  { width: 80, preserve_comments: true }
}

///|
/// Return a copy with the given line width.
pub fn ConvertOptions::with_width(
  self : ConvertOptions,
  width : Int,
) -> ConvertOptions {
  { ..self, width, }
}

///|
/// Return a copy with the comment preservation flag set.
pub fn ConvertOptions::with_preserve_comments(
  self : ConvertOptions,
  keep : Bool,
) -> ConvertOptions {
  { ..self, preserve_comments: keep }
}

///|
/// Convert JSONC string to YAML string, preserving comments
pub fn jsonc_to_yaml(
  input : String,
  width? : Int,
) -> Result[String, @common.ParseError] {
  jsonc_to_yaml_with_opts(
    input,
    ConvertOptions::default().with_width(width.unwrap_or(80)),
  )
}

///|
/// Convert JSONC to YAML with full options.
pub fn jsonc_to_yaml_with_opts(
  input : String,
  opts : ConvertOptions,
) -> Result[String, @common.ParseError] {
  match @jsonc.parse(input) {
    Ok(node) => {
      let source = if opts.preserve_comments {
        node
      } else {
        strip_jsonc_trivia(node)
      }
      let yaml_node = @transform.jsonc_to_yaml(source)
      Ok(@yaml.print(yaml_node, width=opts.width))
    }
    Err(e) => Err(e)
  }
}

///|
/// Convert YAML string to JSONC string, preserving comments
pub fn yaml_to_jsonc(
  input : String,
  width? : Int,
) -> Result[String, @common.ParseError] {
  yaml_to_jsonc_with_opts(
    input,
    ConvertOptions::default().with_width(width.unwrap_or(80)),
  )
}

///|
/// Convert YAML to JSONC with full options.
pub fn yaml_to_jsonc_with_opts(
  input : String,
  opts : ConvertOptions,
) -> Result[String, @common.ParseError] {
  match @yaml.parse(input) {
    Ok(node) => {
      let source = if opts.preserve_comments {
        node
      } else {
        strip_yaml_trivia(node)
      }
      let jsonc_node = @transform.yaml_to_jsonc(source)
      Ok(@jsonc.print(jsonc_node, width=opts.width))
    }
    Err(e) => Err(e)
  }
}

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

///|
fn strip_yaml_trivia(node : @yaml.YamlNode) -> @yaml.YamlNode {
  let empty = @common.Trivia::empty()
  match node {
    @yaml.YNull(_) => @yaml.YamlNode::null_with_trivia(empty)
    @yaml.YBool(v, _) => @yaml.YamlNode::bool_with_trivia(v, empty)
    @yaml.YNumber(v, _) => @yaml.YamlNode::number_with_trivia(v, empty)
    @yaml.YString(v, style, _) =>
      @yaml.YamlNode::string_with_trivia(v, style, empty)
    @yaml.YSequence(elements, style, _) => {
      let stripped = elements.map(strip_yaml_trivia)
      @yaml.YamlNode::sequence_with_style(stripped, style, empty)
    }
    @yaml.YMapping(pairs, style, _) => {
      let stripped = pairs.map(fn(kv) {
        @yaml.YKeyValue::new(
          strip_yaml_trivia(kv.key),
          empty,
          strip_yaml_trivia(kv.value),
        )
      })
      @yaml.YamlNode::mapping_with_style(stripped, style, empty)
    }
    @yaml.YAlias(name, _) => @yaml.YamlNode::alias_with_trivia(name, empty)
    @yaml.YAnchor(name, inner) =>
      @yaml.YamlNode::anchor(name, strip_yaml_trivia(inner))
  }
}

///|
/// Parse JSONC string to CST
pub fn parse_jsonc(
  input : String,
) -> Result[@jsonc.JsonNode, @common.ParseError] {
  @jsonc.parse(input)
}

///|
/// Parse YAML string to CST
pub fn parse_yaml(input : String) -> Result[@yaml.YamlNode, @common.ParseError] {
  @yaml.parse(input)
}

///|
/// Parse a multi-document YAML stream (documents separated by lines
/// containing only `---`).
///
/// A leading `---` is treated as the start of the first document. A trailing
/// `---` produces an extra empty document only if there is content after it.
/// Documents that fail to parse propagate their error.
///
/// Note: error spans are relative to the enclosing document, not the full
/// source — line numbers restart at 0 for each segment.
pub fn parse_yaml_stream(
  input : String,
) -> Result[Array[@yaml.YamlNode], @common.ParseError] {
  let segments = split_yaml_documents(input)
  let docs : Array[@yaml.YamlNode] = []
  for segment in segments {
    match @yaml.parse(segment) {
      Ok(node) => docs.push(node)
      Err(e) => return Err(e)
    }
  }
  Ok(docs)
}

///|
/// Print a list of YAML documents as a stream, separating them with `---`
/// directive lines. An empty list produces an empty string.
pub fn print_yaml_stream(docs : Array[@yaml.YamlNode], width? : Int) -> String {
  let w = width.unwrap_or(80)
  let buf = StringBuilder::new()
  for i = 0; i < docs.length(); i = i + 1 {
    if i > 0 {
      buf.write_string("---\n")
    }
    buf.write_string(@yaml.print(docs[i], width=w))
    if !buf.to_string().has_suffix("\n") {
      buf.write_char('\n')
    }
  }
  buf.to_string()
}

///|
/// Split YAML source on `---` document-separator lines.
///
/// A separator line is a line whose content (after trimming trailing spaces)
/// is exactly `---`. The separator itself is dropped; everything before the
/// first separator and everything between separators becomes a segment.
/// A leading separator at line 0 does not introduce an empty leading segment.
fn split_yaml_documents(input : String) -> Array[String] {
  let segments : Array[String] = []
  let current = StringBuilder::new()
  let lines = split_lines_preserving_positions(input)
  let mut seen_content = false
  for line in lines {
    if is_document_separator(line) {
      if seen_content {
        segments.push(current.to_string())
        current.reset()
        seen_content = false
      }
      // Leading separators with no content yet are a no-op.
    } else {
      if seen_content {
        current.write_char('\n')
      }
      current.write_string(line)
      seen_content = true
    }
  }
  if seen_content {
    segments.push(current.to_string())
  }
  if segments.is_empty() {
    segments.push("")
  }
  segments
}

///|
fn split_lines_preserving_positions(source : String) -> Array[String] {
  let lines : Array[String] = []
  let buf = StringBuilder::new()
  for ch in source {
    if ch == '\n' {
      lines.push(buf.to_string())
      buf.reset()
    } else {
      buf.write_char(ch)
    }
  }
  lines.push(buf.to_string())
  lines
}

///|
fn is_document_separator(line : String) -> Bool {
  let mut end = line.length()
  while end > 0 {
    let c = line[end - 1].to_int().unsafe_to_char()
    if c == ' ' || c == '\t' || c == '\r' {
      end = end - 1
    } else {
      break
    }
  }
  if end != 3 {
    return false
  }
  line[0].to_int().unsafe_to_char() == '-' &&
  line[1].to_int().unsafe_to_char() == '-' &&
  line[2].to_int().unsafe_to_char() == '-'
}

///|
/// Print JSONC CST to string
pub fn print_jsonc(node : @jsonc.JsonNode, width? : Int) -> String {
  let w = width.unwrap_or(80)
  @jsonc.print(node, width=w)
}

///|
/// Print YAML CST to string
pub fn print_yaml(node : @yaml.YamlNode, width? : Int) -> String {
  let w = width.unwrap_or(80)
  @yaml.print(node, width=w)
}

///|
/// Transform JSONC CST to YAML CST
pub fn transform_jsonc_to_yaml(node : @jsonc.JsonNode) -> @yaml.YamlNode {
  @transform.jsonc_to_yaml(node)
}

///|
/// Transform YAML CST to JSONC CST
pub fn transform_yaml_to_jsonc(node : @yaml.YamlNode) -> @jsonc.JsonNode {
  @transform.yaml_to_jsonc(node)
}

///|
/// Convert JSONC to YAML with position mapping
/// Returns ConversionResult containing output and source mappings
pub fn jsonc_to_yaml_with_mapping(
  input : String,
) -> Result[@common.ConversionResult, @common.ParseError] {
  @transform.jsonc_to_yaml_with_mapping(input)
}

///|
/// Convert YAML to JSONC with position mapping
/// Returns ConversionResult containing output and source mappings
pub fn yaml_to_jsonc_with_mapping(
  input : String,
) -> Result[@common.ConversionResult, @common.ParseError] {
  @transform.yaml_to_jsonc_with_mapping(input)
}

///|
/// Create position mappings based on comment anchors
/// This is a simplified approach that uses comment positions as reference points
pub fn create_comment_based_mappings(
  input : String,
  output : String,
  is_jsonc_input : Bool,
) -> Array[@common.SourceMapping] {
  @transform.create_comment_based_mappings(input, output, is_jsonc_input)
}
