# WIP - YAML Parser Fixes

## Date
2025-12-26

## Current Status
**42 out of 44 tests passing**

The YAML parser has been significantly improved and can now handle:
- Multi-key mappings at the same level ✓
- YAML 1.1 boolean keywords (`on`, `off`, `yes`, `no`) as mapping keys ✓
- Empty values (implicit null) followed by sibling keys ✓
- Nested mappings with sequences ✓
- Deeply nested structures in many cases ✓

## Known Limitations
The parser still has issues with **deeply nested structures where a sequence is followed by sibling keys at the same level**. For example:

```yaml
on:
  workflow_dispatch:
  push:
    paths:
      - file.yml
  pull_request:    # This key is missed after parsing the paths sequence
    paths:
      - file.yml
```

In this case, `pull_request` is not being parsed as a sibling of `push` because the parser's dedent handling is not correctly preserving the parent mapping's continuation state.

## Fixes Applied

### 1. Lexer: Multi-level dedent emission
Fixed `handle_indent()` in `lexer.mbt` to emit multiple dedent tokens when dedenting across multiple indentation levels.

Previously, when going from indent 6 to indent 2, only `Dedent(4)` would be emitted. Now it correctly emits `Dedent(4)` and `Dedent(2)` in sequence.

The key change is keeping `at_line_start = true` after emitting a dedent if `to_level > spaces`, allowing the lexer to continue processing more dedents.

### 2. Parser: Indented mapping support
- Added `parse_indented_mapping()` function to parse indented block mappings
- Added Indent case in `parse_value()` to detect and handle indented sequences/mappings
- Track `base_indent` level to determine when to exit nested mappings

### 3. Parser: Dedent handling improvements
- Modified dedent handling in `parse_mapping_with_first_key` to preserve parent-level dedents
- Added logic to detect sibling keys after dedenting
- Fixed exit condition to use `n <= base_indent` for consistency

## Test Results
- **Total tests**: 44
- **Passing**: 42
- **Failing**: 2 (`yaml_parse_nested_mapping`, `yaml_parse_github_actions_structure`)

Both failing tests expect 3 key-value pairs but only find 2, indicating the dedent handling logic still needs refinement.

## Next Steps
The current issue is that `parse_indented_mapping` exits too early when it sees a dedent at its `base_indent` level. The parser should:
1. Continue parsing when dedenting TO the current level (not past it)
2. Only exit when dedenting PAST the current level

This requires adjusting the exit condition from `n <= base_indent` to `n < base_indent` in the correct locations.
