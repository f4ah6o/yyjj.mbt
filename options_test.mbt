///|
/// Tests for ConvertOptions and the `*_with_opts` entry points.

///|
test "default_options_have_sane_values" {
  let opts = @yyjj.ConvertOptions::default()
  assert_eq(opts.width, 80)
  assert_true(opts.preserve_comments)
}

///|
test "with_width_only_overrides_width" {
  let opts = @yyjj.ConvertOptions::default().with_width(120)
  assert_eq(opts.width, 120)
  assert_true(opts.preserve_comments)
}

///|
test "with_preserve_comments_only_overrides_flag" {
  let opts = @yyjj.ConvertOptions::default().with_preserve_comments(false)
  assert_eq(opts.width, 80)
  assert_false(opts.preserve_comments)
}

///|
test "jsonc_to_yaml_with_opts_matches_keyword_form" {
  let source = "{\"k\": 1}"
  let a = @yyjj.jsonc_to_yaml(source, width=40)
  let b = @yyjj.jsonc_to_yaml_with_opts(
    source,
    @yyjj.ConvertOptions::default().with_width(40),
  )
  guard a is Ok(ra) else { abort("a failed") }
  guard b is Ok(rb) else { abort("b failed") }
  assert_eq(ra, rb)
}

///|
test "preserve_comments_false_strips_jsonc_comments" {
  let source =
    #|{
    #|  // a leading comment
    #|  "k": 1
    #|}
  let keep = @yyjj.jsonc_to_yaml_with_opts(
    source,
    @yyjj.ConvertOptions::default(),
  )
  let drop = @yyjj.jsonc_to_yaml_with_opts(
    source,
    @yyjj.ConvertOptions::default().with_preserve_comments(false),
  )
  guard keep is Ok(kept) else { abort("keep failed") }
  guard drop is Ok(dropped) else { abort("drop failed") }
  assert_true(kept.contains("a leading comment"))
  assert_false(dropped.contains("a leading comment"))
}

///|
test "preserve_comments_false_strips_yaml_comments" {
  let source =
    #|# a header comment
    #|k: 1
  let keep = @yyjj.yaml_to_jsonc_with_opts(
    source,
    @yyjj.ConvertOptions::default(),
  )
  let drop = @yyjj.yaml_to_jsonc_with_opts(
    source,
    @yyjj.ConvertOptions::default().with_preserve_comments(false),
  )
  guard keep is Ok(kept) else { abort("keep failed") }
  guard drop is Ok(dropped) else { abort("drop failed") }
  assert_true(kept.contains("a header comment"))
  assert_false(dropped.contains("a header comment"))
}
