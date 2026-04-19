///|
/// Unit tests for the Wadler-Lindig pretty printer.
///
/// Covers the algebraic laws that downstream packages implicitly rely on:
/// associativity of concat, behaviour of group/nest, and the width contract
/// that render(..., w) respects w whenever a fitting layout exists.

///|
/// Width of the widest line in s (0 for empty string).
fn max_line_width(s : String) -> Int {
  let mut max = 0
  let mut current = 0
  for i = 0; i < s.length(); i = i + 1 {
    let ch = s[i]
    if ch == '\n' {
      if current > max {
        max = current
      }
      current = 0
    } else {
      current += 1
    }
  }
  if current > max {
    max = current
  }
  max
}

///|
test "render_nil_is_empty" {
  inspect(@pretty.render(@pretty.Doc::nil(), 80), content="")
}

///|
test "render_text_is_verbatim" {
  inspect(@pretty.render(@pretty.text("hello"), 80), content="hello")
}

///|
test "render_hardline_always_breaks" {
  let doc = @pretty.concat([
    @pretty.text("a"),
    @pretty.hardline(),
    @pretty.text("b"),
  ])
  inspect(@pretty.render(doc, 1000), content="a\nb")
}

///|
test "render_soft_line_is_space_when_fits" {
  let doc = @pretty.group(
    @pretty.concat([@pretty.text("a"), @pretty.line(), @pretty.text("b")]),
  )
  inspect(@pretty.render(doc, 80), content="a b")
}

///|
test "render_soft_line_breaks_when_overflow" {
  let doc = @pretty.group(
    @pretty.concat([@pretty.text("aaa"), @pretty.line(), @pretty.text("bbb")]),
  )
  // width 5 forces break since "aaa bbb" (7) does not fit.
  inspect(@pretty.render(doc, 5), content="aaa\nbbb")
}

///|
test "render_nest_indents_after_break" {
  let doc = @pretty.nest(
    2,
    @pretty.concat([@pretty.text("{"), @pretty.hardline(), @pretty.text("x")]),
  )
  inspect(@pretty.render(doc, 10), content="{\n  x")
}

///|
test "render_respects_width_when_possible" {
  // A long list of short tokens separated by soft lines must break to fit.
  let items = [
    @pretty.text("one"),
    @pretty.line(),
    @pretty.text("two"),
    @pretty.line(),
    @pretty.text("three"),
    @pretty.line(),
    @pretty.text("four"),
  ]
  let doc = @pretty.group(@pretty.concat(items))
  let rendered = @pretty.render(doc, 6)
  // Each token fits on its own line; layout must never exceed width 6.
  if max_line_width(rendered) > 6 {
    abort("width exceeded: \{rendered}")
  }
}

///|
test "render_concat_is_associative" {
  // (a <> b) <> c == a <> (b <> c) under render.
  let a = @pretty.text("x")
  let b = @pretty.text("y")
  let c = @pretty.text("z")
  let left = @pretty.concat([@pretty.concat([a, b]), c])
  let right = @pretty.concat([a, @pretty.concat([b, c])])
  assert_eq(@pretty.render(left, 80), @pretty.render(right, 80))
}

///|
test "render_concat_nil_identity" {
  let a = @pretty.text("hello")
  let lid = @pretty.concat([@pretty.Doc::nil(), a])
  let rid = @pretty.concat([a, @pretty.Doc::nil()])
  assert_eq(@pretty.render(lid, 80), @pretty.render(a, 80))
  assert_eq(@pretty.render(rid, 80), @pretty.render(a, 80))
}

///|
test "render_nest_is_additive" {
  // nest(2, nest(3, d)) == nest(5, d) for the indentation applied at breaks.
  let inner = @pretty.concat([@pretty.hardline(), @pretty.text("x")])
  let nested = @pretty.nest(2, @pretty.nest(3, inner))
  let flat = @pretty.nest(5, inner)
  assert_eq(@pretty.render(nested, 80), @pretty.render(flat, 80))
}

///|
test "render_group_idempotent" {
  let inner = @pretty.concat([
    @pretty.text("a"),
    @pretty.line(),
    @pretty.text("b"),
  ])
  let once = @pretty.group(inner)
  let twice = @pretty.group(@pretty.group(inner))
  assert_eq(@pretty.render(once, 80), @pretty.render(twice, 80))
  assert_eq(@pretty.render(once, 2), @pretty.render(twice, 2))
}

///|
test "render_join_matches_manual_concat" {
  let items = [@pretty.text("a"), @pretty.text("b"), @pretty.text("c")]
  let joined = @pretty.join(items, @pretty.text(", "))
  inspect(@pretty.render(joined, 80), content="a, b, c")
}

///|
test "render_empty_concat_is_nil" {
  inspect(@pretty.render(@pretty.concat([]), 80), content="")
  inspect(@pretty.render(@pretty.join([], @pretty.text(",")), 80), content="")
}

///|
test "render_group_inside_group_picks_same_layout" {
  // An outer group that fits should keep everything flat, even nested groups.
  let inner = @pretty.group(
    @pretty.concat([@pretty.text("a"), @pretty.line(), @pretty.text("b")]),
  )
  let outer = @pretty.group(
    @pretty.concat([
      @pretty.text("["),
      inner,
      @pretty.text(", "),
      inner,
      @pretty.text("]"),
    ]),
  )
  inspect(@pretty.render(outer, 80), content="[a b, a b]")
}
