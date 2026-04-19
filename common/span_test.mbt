///|
/// Unit tests for position and span primitives.

///|
test "pos_zero_is_origin" {
  let z = @common.Pos::zero()
  assert_eq(z.line, 0)
  assert_eq(z.column, 0)
  assert_eq(z.offset, 0)
}

///|
test "span_at_is_empty" {
  let p = @common.Pos::new(3, 5, 42)
  let s = @common.Span::at(p)
  assert_eq(s.start, p)
  assert_eq(s.end, p)
}

///|
test "span_merge_is_commutative" {
  let p1 = @common.Pos::new(0, 0, 0)
  let p2 = @common.Pos::new(0, 5, 5)
  let p3 = @common.Pos::new(1, 0, 10)
  let p4 = @common.Pos::new(1, 3, 13)
  let a = @common.Span::new(p1, p2)
  let b = @common.Span::new(p3, p4)
  assert_eq(a.merge(b), b.merge(a))
}

///|
test "span_merge_covers_both" {
  let p1 = @common.Pos::new(0, 0, 0)
  let p2 = @common.Pos::new(0, 5, 5)
  let p3 = @common.Pos::new(1, 0, 10)
  let p4 = @common.Pos::new(1, 3, 13)
  let a = @common.Span::new(p1, p2)
  let b = @common.Span::new(p3, p4)
  let m = a.merge(b)
  assert_eq(m.start, p1)
  assert_eq(m.end, p4)
}

///|
test "span_merge_with_self_is_identity" {
  let s = @common.Span::new(
    @common.Pos::new(0, 0, 0),
    @common.Pos::new(2, 7, 23),
  )
  assert_eq(s.merge(s), s)
}

///|
test "span_merge_is_associative" {
  let a = @common.Span::new(
    @common.Pos::new(0, 0, 0),
    @common.Pos::new(0, 2, 2),
  )
  let b = @common.Span::new(
    @common.Pos::new(0, 3, 3),
    @common.Pos::new(0, 5, 5),
  )
  let c = @common.Span::new(
    @common.Pos::new(0, 6, 6),
    @common.Pos::new(0, 8, 8),
  )
  assert_eq(a.merge(b).merge(c), a.merge(b.merge(c)))
}
