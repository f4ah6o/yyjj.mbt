///|
/// Unit tests for SourceMapping and position lookups.

///|
fn mk_map(
  sl : Int,
  sc : Int,
  so : Int,
  sl2 : Int,
  sc2 : Int,
  so2 : Int,
  tl : Int,
  tc : Int,
  to_ : Int,
  tl2 : Int,
  tc2 : Int,
  to2 : Int,
) -> @common.SourceMapping {
  @common.SourceMapping::new(
    @common.Pos::new(sl, sc, so),
    @common.Pos::new(sl2, sc2, so2),
    @common.Pos::new(tl, tc, to_),
    @common.Pos::new(tl2, tc2, to2),
  )
}

///|
test "lookup_target_returns_target_start" {
  let mappings = [mk_map(0, 0, 0, 0, 4, 4, 1, 2, 10, 1, 6, 14)]
  let found = @common.lookup_target_position(mappings, 0, 2, 2)
  guard found is Some(p) else { abort("expected target hit") }
  assert_eq(p, @common.Pos::new(1, 2, 10))
}

///|
test "lookup_target_misses_outside_range" {
  let mappings = [mk_map(0, 0, 0, 0, 4, 4, 1, 2, 10, 1, 6, 14)]
  let miss = @common.lookup_target_position(mappings, 5, 0, 100)
  assert_true(miss is None)
}

///|
test "lookup_source_is_inverse_of_target" {
  let mappings = [mk_map(0, 0, 0, 0, 4, 4, 1, 2, 10, 1, 6, 14)]
  let t = @common.lookup_target_position(mappings, 0, 2, 2)
  guard t is Some(tp) else { abort("target lookup failed") }
  let s = @common.lookup_source_position(
    mappings,
    tp.line,
    tp.column,
    tp.offset,
  )
  guard s is Some(sp) else { abort("source lookup failed") }
  assert_eq(sp, @common.Pos::new(0, 0, 0))
}

///|
test "lookup_empty_mappings_always_misses" {
  let miss = @common.lookup_target_position([], 0, 0, 0)
  assert_true(miss is None)
}

///|
test "conversion_result_empty" {
  let r = @common.ConversionResult::empty()
  assert_eq(r.output, "")
  assert_eq(r.mappings.length(), 0)
}

///|
test "lookup_first_matching_wins" {
  let mappings = [
    mk_map(0, 0, 0, 0, 10, 10, 2, 0, 50, 2, 4, 54),
    mk_map(0, 0, 0, 0, 10, 10, 3, 0, 60, 3, 4, 64),
  ]
  let t = @common.lookup_target_position(mappings, 0, 5, 5)
  guard t is Some(tp) else { abort("expected hit") }
  assert_eq(tp.line, 2)
}
