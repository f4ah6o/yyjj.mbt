///|
/// Additional transform-layer properties:
/// - CST↔CST roundtrip on a richer fixture set than pbt_generated_test.mbt
/// - Anchor extraction invariants (paths line up with the structure)
///
/// These tests work purely on the CST (no string parsing / printing) so they
/// exercise the transform functions in isolation.

///|
fn empty_trivia() -> @common.Trivia {
  @common.Trivia::empty()
}

///|
fn j_num(n : String) -> @jsonc.JsonNode {
  @jsonc.JsonNode::number_with_trivia(n, empty_trivia())
}

///|
fn j_str(s : String) -> @jsonc.JsonNode {
  @jsonc.JsonNode::string_with_trivia(s, empty_trivia())
}

///|
fn j_bool(b : Bool) -> @jsonc.JsonNode {
  @jsonc.JsonNode::bool_with_trivia(b, empty_trivia())
}

///|
fn j_null() -> @jsonc.JsonNode {
  @jsonc.JsonNode::null_with_trivia(empty_trivia())
}

///|
fn j_arr(xs : Array[@jsonc.JsonNode]) -> @jsonc.JsonNode {
  @jsonc.JsonNode::array_with_trivia(xs, empty_trivia())
}

///|
fn j_obj(pairs : Array[(String, @jsonc.JsonNode)]) -> @jsonc.JsonNode {
  let props = pairs.map(fn(kv) {
    @jsonc.JProperty::new(kv.0, empty_trivia(), kv.1)
  })
  @jsonc.JsonNode::object_with_trivia(props, empty_trivia())
}

///|
fn strip_jsonc(node : @jsonc.JsonNode) -> @jsonc.JsonNode {
  let empty = empty_trivia()
  match node {
    @jsonc.JNull(_) => @jsonc.JsonNode::null_with_trivia(empty)
    @jsonc.JBool(v, _) => @jsonc.JsonNode::bool_with_trivia(v, empty)
    @jsonc.JNumber(v, _) => @jsonc.JsonNode::number_with_trivia(v, empty)
    @jsonc.JString(v, _) => @jsonc.JsonNode::string_with_trivia(v, empty)
    @jsonc.JArray(elements, _) => {
      let stripped = elements.map(strip_jsonc)
      @jsonc.JsonNode::array_with_trivia(stripped, empty)
    }
    @jsonc.JObject(props, _) => {
      let stripped = props.map(fn(p) {
        @jsonc.JProperty::new(p.key, empty, strip_jsonc(p.value))
      })
      @jsonc.JsonNode::object_with_trivia(stripped, empty)
    }
  }
}

///|
test "cst_roundtrip_scalars" {
  let fixtures = [
    j_null(),
    j_bool(true),
    j_bool(false),
    j_num("0"),
    j_num("3.14"),
    j_num("-7"),
    j_str(""),
    j_str("hello"),
  ]
  for node in fixtures {
    let y = @transform.jsonc_to_yaml(node)
    let back = @transform.yaml_to_jsonc(y)
    assert_eq(strip_jsonc(node), strip_jsonc(back))
  }
}

///|
test "cst_roundtrip_arrays" {
  let fixtures = [
    j_arr([]),
    j_arr([j_num("1")]),
    j_arr([j_num("1"), j_num("2"), j_num("3")]),
    j_arr([j_null(), j_bool(true), j_str("x")]),
    j_arr([j_arr([j_num("1")]), j_arr([j_num("2")])]),
  ]
  for node in fixtures {
    let y = @transform.jsonc_to_yaml(node)
    let back = @transform.yaml_to_jsonc(y)
    assert_eq(strip_jsonc(node), strip_jsonc(back))
  }
}

///|
test "cst_roundtrip_objects" {
  let fixtures = [
    j_obj([]),
    j_obj([("k", j_num("1"))]),
    j_obj([("a", j_num("1")), ("b", j_str("s"))]),
    j_obj([("nested", j_obj([("inner", j_bool(true))]))]),
    j_obj([("list", j_arr([j_num("1"), j_num("2")]))]),
  ]
  for node in fixtures {
    let y = @transform.jsonc_to_yaml(node)
    let back = @transform.yaml_to_jsonc(y)
    assert_eq(strip_jsonc(node), strip_jsonc(back))
  }
}

///|
test "cst_roundtrip_is_idempotent_under_retransform" {
  // Transforming JSON→YAML→JSON→YAML should match JSON→YAML.
  let source = j_obj([
    ("a", j_num("1")),
    ("b", j_arr([j_num("2"), j_num("3")])),
    ("c", j_obj([("nested", j_bool(true))])),
  ])
  let y1 = @transform.jsonc_to_yaml(source)
  let j1 = @transform.yaml_to_jsonc(y1)
  let y2 = @transform.jsonc_to_yaml(j1)
  // Compare second-generation YAML via the jsonc lens to avoid style diff noise.
  let j2 = @transform.yaml_to_jsonc(y2)
  assert_eq(strip_jsonc(j1), strip_jsonc(j2))
}

///|
test "anchors_empty_for_plain_scalar" {
  let anchors = @transform.extract_jsonc_anchors(j_num("42"))
  assert_eq(anchors.length(), 0)
}

///|
test "anchors_empty_for_trivia_free_tree" {
  let tree = j_obj([("k", j_arr([j_num("1"), j_num("2")]))])
  assert_eq(@transform.extract_jsonc_anchors(tree).length(), 0)
  let y = @transform.jsonc_to_yaml(tree)
  assert_eq(@transform.extract_yaml_anchors(y).length(), 0)
}

///|
test "anchors_record_leading_comment_path" {
  let leading = @common.Comment::new(
    "hi",
    @common.CommentKind::line(),
    @common.Span::at(@common.Pos::zero()),
    false,
  )
  let trivia = @common.Trivia::with_leading([leading])
  let inner = @jsonc.JsonNode::number_with_trivia("1", trivia)
  let tree = @jsonc.JsonNode::object_with_trivia(
    [@jsonc.JProperty::new("k", empty_trivia(), inner)],
    empty_trivia(),
  )
  let anchors = @transform.extract_jsonc_anchors(tree)
  assert_eq(anchors.length(), 1)
  assert_eq(anchors[0].path, ["k"])
  assert_eq(anchors[0].value_kind, "number")
}
