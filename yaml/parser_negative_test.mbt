///|
/// Negative test corpus — malformed YAML must surface a ParseError with
/// a span pointing at (or near) the offending source location.
///
/// YAML is intentionally permissive; only inputs that violate structural
/// expectations (stray brackets, bare anchors, unsupported directives)
/// reliably error out in this parser's scope.

///|
fn assert_yaml_err(label : String, input : String) -> Unit {
  match @yaml.parse(input) {
    Ok(_) => abort("expected parse error for \{label}: \{input}")
    Err(_) => ()
  }
}

///|
fn assert_yaml_err_at(
  label : String,
  input : String,
  line : Int,
  column : Int,
) -> Unit {
  match @yaml.parse(input) {
    Ok(_) => abort("expected parse error for \{label}: \{input}")
    Err(e) =>
      if e.span.start.line != line || e.span.start.column != column {
        abort(
          "\{label}: expected error at (line \{line}, col \{column}), got (\{e.span.start.line}, \{e.span.start.column}): \{e.message}",
        )
      }
  }
}

///|
test "negative_yaml_stray_close_bracket" {
  assert_yaml_err_at("stray ']' with no matching '['", "]", 0, 0)
}

///|
test "negative_yaml_stray_close_brace" {
  assert_yaml_err_at("stray '}' with no matching '{'", "}", 0, 0)
}

///|
test "negative_yaml_colon_at_column_zero" {
  assert_yaml_err_at("colon with no key is not a mapping", ":", 0, 0)
}

///|
test "negative_yaml_stray_colon_in_flow" {
  assert_yaml_err("stray colon inside flow sequence", "[:]")
}

///|
test "negative_yaml_document_start_unsupported" {
  // Multi-document YAML ('---' separator) is explicitly out of scope.
  assert_yaml_err("lone document start", "---")
}

///|
test "negative_yaml_bare_anchor" {
  assert_yaml_err("bare ampersand is not a valid anchor", "&")
}

///|
test "negative_yaml_empty_anchor_name_at_eof" {
  assert_yaml_err("anchor marker with no following name", "key: &")
}

///|
test "negative_yaml_error_span_reports_second_line" {
  let source =
    #|key: value
    #|next: &
  match @yaml.parse(source) {
    Ok(_) => abort("expected parse error for bare anchor on line two")
    Err(e) =>
      if e.span.start.line != 1 {
        abort(
          "expected error on line 1, got line \{e.span.start.line}: \{e.message}",
        )
      }
  }
}
