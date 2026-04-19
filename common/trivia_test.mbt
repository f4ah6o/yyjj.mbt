///|
/// Unit tests for comments and trivia.

///|
fn sample_comment(content : String) -> @common.Comment {
  @common.Comment::new(
    content,
    @common.CommentKind::line(),
    @common.Span::at(@common.Pos::zero()),
    false,
  )
}

///|
test "trivia_empty_is_empty" {
  let t = @common.Trivia::empty()
  assert_true(t.is_empty())
}

///|
test "trivia_with_leading_not_empty" {
  let t = @common.Trivia::with_leading([sample_comment("hi")])
  assert_false(t.is_empty())
}

///|
test "trivia_with_trailing_not_empty" {
  let t = @common.Trivia::with_trailing([sample_comment("hi")])
  assert_false(t.is_empty())
}

///|
test "trivia_merge_preserves_order" {
  let a = @common.Trivia::with_leading([sample_comment("a1")])
  let b = @common.Trivia::with_leading([sample_comment("b1")])
  let merged = a.merge(b)
  assert_eq(merged.leading.length(), 2)
  assert_eq(merged.leading[0].content, "a1")
  assert_eq(merged.leading[1].content, "b1")
}

///|
test "trivia_merge_combines_leading_and_trailing" {
  let a = @common.Trivia::with_leading([sample_comment("lead")])
  let b = @common.Trivia::with_trailing([sample_comment("trail")])
  let merged = a.merge(b)
  assert_eq(merged.leading.length(), 1)
  assert_eq(merged.trailing.length(), 1)
}

///|
test "trivia_merge_with_empty_is_identity" {
  let a = @common.Trivia::new([sample_comment("l")], [sample_comment("t")])
  let e = @common.Trivia::empty()
  let la = e.merge(a)
  let ra = a.merge(e)
  assert_eq(la.leading.length(), 1)
  assert_eq(la.trailing.length(), 1)
  assert_eq(ra.leading.length(), 1)
  assert_eq(ra.trailing.length(), 1)
}

///|
test "comment_kind_distinct" {
  assert_true(@common.CommentKind::line() != @common.CommentKind::block())
}
