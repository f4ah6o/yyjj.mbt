///|
/// Micro-benchmarks for yyjj conversion. Run with:
///
///     moon bench --target js
///
/// These exist to catch gross perf regressions in parse+transform+print.
/// They do not replace end-to-end measurements on real corpora, but they
/// give a stable baseline for quick checks during refactors.

///|
/// Small JSONC fixture (~100 bytes).
fn small_jsonc() -> String {
  (
    #|{
    #|  "name": "yyjj",
    #|  "version": "1.0",
    #|  "tags": ["cli", "lib"]
    #|}
  )
}

///|
/// Small YAML fixture (~60 bytes).
fn small_yaml() -> String {
  (
    #|name: yyjj
    #|version: "1.0"
    #|tags:
    #|  - cli
    #|  - lib
  )
}

///|
/// Medium JSONC fixture (~1 KB), shaped like a GitHub Actions workflow.
fn medium_jsonc() -> String {
  let parts : Array[String] = []
  parts.push("{\n  \"name\": \"CI\",\n  \"jobs\": [\n")
  for i = 0; i < 10; i = i + 1 {
    let idx = i.to_string()
    parts.push(
      "    {\"id\": \"job" +
      idx +
      "\", \"runs\": \"ubuntu-latest\", \"steps\": [\"checkout\", \"build\", \"test\"]}" +
      (if i < 9 { ",\n" } else { "\n" }),
    )
  }
  parts.push("  ]\n}\n")
  let buf = StringBuilder::new()
  for p in parts {
    buf.write_string(p)
  }
  buf.to_string()
}

///|
test "bench: jsonc_to_yaml small" (b : @bench.T) {
  let source = small_jsonc()
  b.bench(fn() { let _ = @lib.jsonc_to_yaml(source) })
}

///|
test "bench: yaml_to_jsonc small" (b : @bench.T) {
  let source = small_yaml()
  b.bench(fn() { let _ = @lib.yaml_to_jsonc(source) })
}

///|
test "bench: jsonc_to_yaml medium" (b : @bench.T) {
  let source = medium_jsonc()
  b.bench(fn() { let _ = @lib.jsonc_to_yaml(source) })
}

///|
test "bench: parse_jsonc medium" (b : @bench.T) {
  let source = medium_jsonc()
  b.bench(fn() { let _ = @lib.parse_jsonc(source) })
}

///|
test "bench: roundtrip jsonc small" (b : @bench.T) {
  let source = small_jsonc()
  b.bench(fn() {
    match @lib.jsonc_to_yaml(source) {
      Ok(yaml) => {
        let _ = @lib.yaml_to_jsonc(yaml)
      }
      Err(_) => ()
    }
  })
}
