///|
/// Convert YAML CST to pretty-printable document
pub fn to_doc(node : YamlNode) -> @pretty.Doc {
  node_to_doc(node, 0)
}

///|
/// Unwrap nested YAnchor nodes, collecting all anchor names and the innermost value
/// YAnchor(outer, YAnchor(inner, v)) => ([outer, inner], v)
fn unwrap_anchors(node : YamlNode) -> (Array[String], YamlNode) {
  match node {
    YAnchor(name, inner) => {
      let (rest_names, inner_value) = unwrap_anchors(inner)
      // Add name to the beginning of the array
      let result = [name]
      for n in rest_names {
        result.push(n)
      }
      (result, inner_value)
    }
    _ => ([], node)
  }
}

///|
fn node_to_doc(node : YamlNode, indent : Int) -> @pretty.Doc {
  let trivia = node.trivia()
  let leading = trivia_to_doc(trivia.leading, true)
  let trailing = trivia_to_doc(trivia.trailing, false)
  let content = match node {
    YNull(_) => @pretty.text("null")
    YBool(true, _) => @pretty.text("true")
    YBool(false, _) => @pretty.text("false")
    YNumber(n, _) => @pretty.text(n)
    YString(s, style, _) => string_to_doc(s, style, indent)
    YSequence(elements, YamlCollectionStyle::Flow, _) =>
      flow_sequence_to_doc(elements, indent)
    YSequence(elements, YamlCollectionStyle::Block, _) =>
      sequence_to_doc(elements, indent)
    YMapping(pairs, YamlCollectionStyle::Flow, _) =>
      flow_mapping_to_doc(pairs, indent)
    YMapping(pairs, YamlCollectionStyle::Block, _) =>
      mapping_to_doc(pairs, indent)
    YAlias(name, _) => @pretty.text("*" + name)
    YAnchor(name, value) => {
      // Unwrap nested anchors to avoid double anchoring in output
      // YAnchor(outer, YAnchor(inner, v)) => print as "&outer &inner v"
      let (inner_names, inner_value) = unwrap_anchors(value)
      // Prepend the current name to the inner names
      let anchor_names = {
        let result = [name]
        for n in inner_names {
          result.push(n)
        }
        result
      }
      if is_nested_structure(inner_value) {
        // Multiple anchors on the same line, nested structure below
        let anchor_text = anchor_names.map(fn(n) { "&" + n }).join(" ")
        @pretty.concat([
          @pretty.text(anchor_text),
          @pretty.nest(
            2,
            @pretty.concat([
              @pretty.hardline(),
              node_to_doc(inner_value, indent),
            ]),
          ),
        ])
      } else {
        // All inline
        let anchor_text = anchor_names.map(fn(n) { "&" + n }).join(" ")
        @pretty.concat([
          @pretty.text(anchor_text + " "),
          node_to_doc(inner_value, indent),
        ])
      }
    }
  }
  @pretty.concat([leading, content, trailing])
}

///|
fn string_to_doc(
  s : String,
  style : YamlScalarStyle,
  indent : Int,
) -> @pretty.Doc {
  // Handle empty strings - quote them appropriately for each style
  if s.is_empty() {
    match style {
      SingleQuoted => @pretty.text("''")
      _ => @pretty.text("\"\"")
    }
  } else {
    match style {
      Plain =>
        // Quote strings that look like numbers, bools, or null to preserve type
        if needs_quoting(s) {
          @pretty.text("\"" + escape_double_quoted(s) + "\"")
        } else {
          @pretty.text(s)
        }
      SingleQuoted => @pretty.text("'" + escape_single_quoted(s) + "'")
      DoubleQuoted => @pretty.text("\"" + escape_double_quoted(s) + "\"")
      // For block scalars:
      // - Content must be indented more than the parent context (YAML spec)
      // - Root mapping (indent=2 for values): use 2 (no nest wrapper to help)
      // - Nested mapping (indent>=4 for values): use indent-2 (nest adds 2)
      Literal => {
        let block_indent = if indent <= 2 { 2 } else { indent - 2 }
        literal_block_to_doc(s, block_indent)
      }
      Folded => {
        let block_indent = if indent <= 2 { 2 } else { indent - 2 }
        folded_block_to_doc(s, block_indent)
      }
    }
  }
}

///|
/// Check if a string needs quoting in YAML to preserve its type
fn needs_quoting(s : String) -> Bool {
  if s.is_empty() {
    return true
  }
  // Check for leading spaces (not preserved in plain scalars in block context)
  let first_char = s[0].to_int().unsafe_to_char()
  if first_char == ' ' || first_char == '\t' {
    return true
  }
  // Check for trailing spaces (always trimmed in plain scalars)
  let last_char = s[s.length() - 1].to_int().unsafe_to_char()
  if last_char == ' ' || last_char == '\t' {
    return true
  }
  // Check for characters that require quoting in Plain scalars
  // Note: Backslash is valid in plain scalars and does not require quoting
  // Note: Colon (:) only requires quoting when followed by space or at end
  for i = 0; i < s.length(); i = i + 1 {
    let ch = s[i].to_int().unsafe_to_char()
    match ch {
      ':' => {
        // Colon only requires quoting when followed by space/tab/newline or at end
        // (to distinguish from key-value separator)
        let at_end = i + 1 >= s.length()
        if at_end {
          return true
        }
        let next = s[i + 1].to_int().unsafe_to_char()
        if next == ' ' || next == '\t' || next == '\n' || next == '\r' {
          return true
        }
      }
      '['
      | ']'
      | '{'
      | '}'
      | ','
      | '#'
      | '"'
      | '\''
      | '|'
      | '>'
      | '&'
      | '*'
      | '%'
      | '@'
      | '`' => return true
      _ => ()
    }
  }
  // Check for YAML keywords
  match s {
    "null" | "Null" | "NULL" | "~" => true
    "true" | "True" | "TRUE" | "yes" | "Yes" | "YES" | "on" | "On" | "ON" =>
      true
    "false" | "False" | "FALSE" | "no" | "No" | "NO" | "off" | "Off" | "OFF" =>
      true
    _ => looks_like_number(s)
  }
}

///|
/// Check if string looks like a number (would be parsed as number in YAML)
fn looks_like_number(s : String) -> Bool {
  if s.is_empty() {
    return false
  }
  let mut i = 0
  // Optional minus
  if s[0].to_int().unsafe_to_char() == '-' {
    i += 1
    if i >= s.length() {
      return false
    }
  }
  // Check digits
  let first_digit = s[i].to_int().unsafe_to_char()
  if first_digit < '0' || first_digit > '9' {
    return false
  }
  // Rest must be digits, dots, or exponent chars
  while i < s.length() {
    let ch = s[i].to_int().unsafe_to_char()
    if (ch >= '0' && ch <= '9') ||
      ch == '.' ||
      ch == 'e' ||
      ch == 'E' ||
      ch == '+' ||
      ch == '-' {
      i += 1
    } else {
      return false
    }
  }
  true
}

///|
fn escape_single_quoted(s : String) -> String {
  // In single-quoted YAML, only '' is an escape
  let buf = StringBuilder::new()
  for i = 0; i < s.length(); i = i + 1 {
    let ch = s[i].to_int().unsafe_to_char()
    if ch == '\'' {
      buf.write_string("''")
    } else {
      buf.write_char(ch)
    }
  }
  buf.to_string()
}

///|
fn escape_double_quoted(s : String) -> String {
  let buf = StringBuilder::new()
  for i = 0; i < s.length(); i = i + 1 {
    let ch = s[i].to_int().unsafe_to_char()
    match ch {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(ch)
    }
  }
  buf.to_string()
}

///|
/// Split string by newlines into array of lines
fn split_newlines(s : String) -> Array[String] {
  let result : Array[String] = []
  let mut buf = StringBuilder::new()
  for i = 0; i < s.length(); i = i + 1 {
    let ch = s[i].to_int().unsafe_to_char()
    if ch == '\n' {
      result.push(buf.to_string())
      buf = StringBuilder::new()
    } else {
      buf.write_char(ch)
    }
  }
  result.push(buf.to_string())
  result
}

///|
/// Format a literal block with proper indentation for its nesting level
fn literal_block_to_doc(s : String, indent : Int) -> @pretty.Doc {
  let lines = split_newlines(s)
  if lines.is_empty() {
    return @pretty.concat([@pretty.text("|"), @pretty.hardline()])
  }
  let all_docs : Array[@pretty.Doc] = []
  for i = 0; i < lines.length(); i = i + 1 {
    let line = lines[i]
    // Each line is indented to the current indent level
    // The pretty printer will add the nesting via @pretty.nest(2) in mapping_to_doc
    let indent_str = " ".repeat(indent)
    all_docs.push(
      @pretty.concat([
        @pretty.text(indent_str),
        @pretty.text(line),
        @pretty.hardline(),
      ]),
    )
  }
  @pretty.concat([
    @pretty.text("|"),
    @pretty.hardline(),
    @pretty.concat(all_docs),
  ])
}

///|
/// Format a folded block with proper indentation for its nesting level
fn folded_block_to_doc(s : String, indent : Int) -> @pretty.Doc {
  // The lexer has already folded newlines to spaces
  // So we just need to output the content as-is with proper indentation
  if s.is_empty() {
    return @pretty.concat([@pretty.text(">"), @pretty.hardline()])
  }
  let indent_str = " ".repeat(indent)
  @pretty.concat([
    @pretty.text(">"),
    @pretty.hardline(),
    @pretty.concat([
      @pretty.text(indent_str),
      @pretty.text(s),
      @pretty.hardline(),
    ]),
  ])
}

///|
/// Check if a node represents a nested structure (sequence or mapping)
/// that should be printed on multiple lines in block context
fn is_nested_structure(node : YamlNode) -> Bool {
  match node {
    YSequence(_, _, _) | YMapping(_, _, _) => true
    YAnchor(_, inner) => is_nested_structure(inner)
    _ => false
  }
}

///|
fn sequence_to_doc(elements : Array[YamlNode], indent : Int) -> @pretty.Doc {
  if elements.is_empty() {
    return @pretty.text("[]")
  }
  let docs : Array[@pretty.Doc] = []
  for i = 0; i < elements.length(); i = i + 1 {
    let elem = elements[i]
    // When element is a mapping, the first key goes after "- " but subsequent
    // keys need to be indented. We handle this by splitting the mapping.
    match elem {
      YMapping(pairs, YamlCollectionStyle::Block, trivia) if pairs.length() > 1 => {
        // First pair: "- key: value"
        let first_pair = pairs[0]
        let first_key_leading = trivia_to_doc(
          first_pair.key_trivia.leading,
          true,
        )
        let first_key_doc = node_to_doc(first_pair.key, indent + 2)
        let first_value_doc = node_to_doc(first_pair.value, indent + 4)
        let first_key_trailing = trivia_to_doc(
          first_pair.key_trivia.trailing,
          false,
        )
        let is_first_nested = is_nested_structure(first_pair.value)
        let first_doc = if is_first_nested {
          @pretty.concat([
            first_key_leading,
            first_key_doc,
            @pretty.text(":"),
            @pretty.nest(
              2,
              @pretty.concat([@pretty.hardline(), first_value_doc]),
            ),
            first_key_trailing,
          ])
        } else {
          @pretty.concat([
            first_key_leading,
            first_key_doc,
            @pretty.text(":"),
            @pretty.text(" "),
            first_value_doc,
            first_key_trailing,
          ])
        }

        // Remaining pairs need to be indented by 2 (to align with first key)
        let rest_docs : Array[@pretty.Doc] = []
        for j = 1; j < pairs.length(); j = j + 1 {
          let pair = pairs[j]
          let key_leading = trivia_to_doc(pair.key_trivia.leading, true)
          let key_doc = node_to_doc(pair.key, indent + 2)
          let value_doc = node_to_doc(pair.value, indent + 4)
          let key_trailing = trivia_to_doc(pair.key_trivia.trailing, false)
          let is_nested = is_nested_structure(pair.value)
          if is_nested {
            rest_docs.push(
              @pretty.concat([
                key_leading,
                key_doc,
                @pretty.text(":"),
                @pretty.nest(2, @pretty.concat([@pretty.hardline(), value_doc])),
                key_trailing,
              ]),
            )
          } else {
            rest_docs.push(
              @pretty.concat([
                key_leading,
                key_doc,
                @pretty.text(":"),
                @pretty.text(" "),
                value_doc,
                key_trailing,
              ]),
            )
          }
        }
        let leading_trivia = trivia_to_doc(trivia.leading, true)
        let rest_joined = @pretty.join(rest_docs, @pretty.hardline())
        docs.push(
          @pretty.concat([
            leading_trivia,
            @pretty.text("- "),
            first_doc,
            @pretty.nest(2, @pretty.concat([@pretty.hardline(), rest_joined])),
          ]),
        )
      }
      YSequence(inner_elements, YamlCollectionStyle::Block, trivia) => {
        // Nested sequences within sequences are problematic because the parser
        // can't distinguish between continuation of nested vs new outer elements.
        // Use flow style for nested sequences to make output unambiguous.
        // This produces "- [- a, - b]" instead of "- - a\n  - b"
        let leading = trivia_to_doc(trivia.leading, true)
        // Build flow-style representation of the nested sequence
        let inner_docs : Array[@pretty.Doc] = []
        for j = 0; j < inner_elements.length(); j = j + 1 {
          let inner_elem = node_to_doc(inner_elements[j], indent)
          inner_docs.push(inner_elem)
        }
        let inner_joined = @pretty.join(inner_docs, @pretty.text(", "))
        docs.push(@pretty.concat([leading, @pretty.text("- ["), inner_joined, @pretty.text("]")]))
      }
      _ => {
        let elem_doc = node_to_doc(elem, indent + 2)
        docs.push(@pretty.concat([@pretty.text("- "), elem_doc]))
      }
    }
  }
  @pretty.join(docs, @pretty.hardline())
}

///|
/// Convert a flow-style sequence to document: [elem1, elem2, ...]
fn flow_sequence_to_doc(
  elements : Array[YamlNode],
  indent : Int,
) -> @pretty.Doc {
  let elem_docs = elements.map(fn(e) { node_to_doc(e, indent) })
  let joined = @pretty.join(elem_docs, @pretty.text(", "))
  @pretty.concat([@pretty.text("["), joined, @pretty.text("]")])
}

///|
/// Convert a flow-style mapping to document: {key1: value1, key2: value2, ...}
fn flow_mapping_to_doc(pairs : Array[YKeyValue], indent : Int) -> @pretty.Doc {
  let pair_docs = pairs.map(fn(p) {
    let key_doc = node_to_doc(p.key, indent)
    let value_doc = node_to_doc(p.value, indent)
    @pretty.concat([key_doc, @pretty.text(": "), value_doc])
  })
  let joined = @pretty.join(pair_docs, @pretty.text(", "))
  @pretty.concat([@pretty.text("{"), joined, @pretty.text("}")])
}

///|
fn mapping_to_doc(pairs : Array[YKeyValue], indent : Int) -> @pretty.Doc {
  if pairs.is_empty() {
    return @pretty.text("{}")
  }
  let docs : Array[@pretty.Doc] = []
  for i = 0; i < pairs.length(); i = i + 1 {
    let pair = pairs[i]
    // Output key_trivia leading comments
    let key_leading = trivia_to_doc(pair.key_trivia.leading, true)
    let key_doc = node_to_doc(pair.key, indent)
    let value_doc = node_to_doc(pair.value, indent + 2)
    // Output key_trivia trailing comments (these come AFTER the value)
    let key_trailing = trivia_to_doc(pair.key_trivia.trailing, false)
    // Check if value is a nested structure (sequence or mapping)
    // Note: literal/folded blocks are NOT treated as nested here because
    // the | or > indicator should be on the same line as the key
    let is_nested = match pair.value {
      YSequence(_, _, _) | YMapping(_, _, _) => true
      YAnchor(_, inner) =>
        match inner {
          YSequence(_, _, _) | YMapping(_, _, _) => true
          _ => false
        }
      _ => false
    }
    if is_nested {
      // nest must wrap hardline for indentation to apply
      // key_trailing comes after the nested value
      docs.push(
        @pretty.concat([
          key_leading,
          key_doc,
          @pretty.text(":"),
          @pretty.nest(2, @pretty.concat([@pretty.hardline(), value_doc])),
          key_trailing,
        ]),
      )
    } else {
      // key_trailing comes after the value
      // This includes literal/folded blocks (|/>) which go on the same line as the key
      docs.push(
        @pretty.concat([
          key_leading,
          key_doc,
          @pretty.text(":"),
          @pretty.text(" "),
          value_doc,
          key_trailing,
        ]),
      )
    }
  }
  @pretty.join(docs, @pretty.hardline())
}

///|
fn trivia_to_doc(
  comments : Array[@common.Comment],
  is_leading : Bool,
) -> @pretty.Doc {
  if comments.is_empty() {
    return @pretty.Doc::nil()
  }
  let docs : Array[@pretty.Doc] = []
  for i = 0; i < comments.length(); i = i + 1 {
    let comment = comments[i]
    let text = "#" + comment.content
    if is_leading {
      docs.push(@pretty.concat([@pretty.text(text), @pretty.hardline()]))
    } else {
      docs.push(@pretty.concat([@pretty.text(" "), @pretty.text(text)]))
    }
  }
  @pretty.concat(docs)
}

///|
/// Print YAML to string
pub fn print(node : YamlNode, width? : Int) -> String {
  let w = width.unwrap_or(80)
  let doc = to_doc(node)
  @pretty.render(doc, w)
}
