///|
struct CliOpts {
  positional : String?
  file : String?
  output : String?
  width : Int
}

///|
fn default_opts() -> CliOpts {
  { positional: None, file: None, output: None, width: 80 }
}

///|
fn parse_opts(
  args : ArrayView[String],
  acc : CliOpts,
) -> Result[CliOpts, String] {
  match args {
    [] => Ok(acc)
    ["-f", path, .. rest] | ["--file", path, .. rest] =>
      if path == "-" {
        parse_opts(rest, acc)
      } else {
        parse_opts(rest, { ..acc, file: Some(path) })
      }
    ["-o", path, .. rest] | ["--output", path, .. rest] =>
      parse_opts(rest, { ..acc, output: Some(path) })
    ["-w", value, .. rest] | ["--width", value, .. rest] =>
      try @string.parse_int(value, base=10) catch {
        _ => Err("invalid width: \{value}")
      } noraise {
        n =>
          if n > 0 {
            parse_opts(rest, { ..acc, width: n })
          } else {
            Err("invalid width: \{value}")
          }
      }
    [value, .. rest] =>
      match acc.positional {
        Some(_) => Err("unexpected argument: \{value}")
        None => parse_opts(rest, { ..acc, positional: Some(value) })
      }
  }
}

///|
fn load_input(opts : CliOpts) -> Result[String, String] {
  match opts.positional {
    Some(text) => Ok(text)
    None =>
      match opts.file {
        Some(path) => read_path(path)
        None => read_path("/dev/stdin")
      }
  }
}

///|
fn read_path(path : String) -> Result[String, String] {
  try @fs.read_file_to_string(path) catch {
    e => Err("failed to read \{path}: \{e}")
  } noraise {
    text => Ok(text)
  }
}

///|
fn emit_output(opts : CliOpts, body : String) -> Result[Unit, String] {
  match opts.output {
    None => {
      println(body)
      Ok(())
    }
    Some(path) =>
      try @fs.write_string_to_file(path, body) catch {
        e => Err("failed to write \{path}: \{e}")
      } noraise {
        _ => Ok(())
      }
  }
}

///|
fn run_convert(
  args : ArrayView[String],
  convert : (String, Int) -> Result[String, @common.ParseError],
  usage : String,
) -> Unit {
  match parse_opts(args, default_opts()) {
    Err(msg) => {
      println("Error: \{msg}")
      println(usage)
    }
    Ok(opts) =>
      match load_input(opts) {
        Err(msg) => println("Error: \{msg}")
        Ok(input) =>
          match convert(input, opts.width) {
            Err(e) => println("Error: \{e.format_pretty(input)}")
            Ok(result) =>
              match emit_output(opts, result) {
                Err(msg) => println("Error: \{msg}")
                Ok(_) => ()
              }
          }
      }
  }
}

///|
fn print_usage() -> Unit {
  println("yyjj - JSONC/YAML bidirectional converter")
  println("")
  println("Usage:")
  println("  yyjj to-yaml  [<input>] [-f <file>|-] [-o <file>] [-w <N>]")
  println("  yyjj to-jsonc [<input>] [-f <file>|-] [-o <file>] [-w <N>]")
  println("  yyjj help")
  println("")
  println("Options:")
  println("  -f, --file <path>    Read input from file (use '-' for stdin)")
  println("  -o, --output <path>  Write output to file (default: stdout)")
  println("  -w, --width <N>      Line width for printing (default: 80)")
  println("")
  println("Input is read from stdin when no <input> or -f is given.")
  println("")
  println("Examples:")
  println("  yyjj to-yaml '{\"name\": \"test\"}'")
  println("  yyjj to-yaml -f config.jsonc -o config.yaml")
  println("  cat config.jsonc | yyjj to-yaml > config.yaml")
}

///|
fn main {
  // process.argv is [node, script_path, subcommand, ...user_args] on JS target.
  let raw = @env.args()
  let args = if raw.length() >= 2 { raw[2:] } else { raw[:] }
  if args.length() < 1 {
    print_usage()
    return
  }
  let command = args[0]
  let rest = args[1:]
  match command {
    "to-yaml" =>
      run_convert(
        rest,
        fn(input, w) { @lib.jsonc_to_yaml(input, width=w) },
        "Usage: yyjj to-yaml [<input>] [-f <file>|-] [-o <file>] [-w <N>]",
      )
    "to-jsonc" =>
      run_convert(
        rest,
        fn(input, w) { @lib.yaml_to_jsonc(input, width=w) },
        "Usage: yyjj to-jsonc [<input>] [-f <file>|-] [-o <file>] [-w <N>]",
      )
    "help" | "--help" | "-h" => print_usage()
    _ => {
      println("Unknown command: \{command}")
      print_usage()
    }
  }
}
