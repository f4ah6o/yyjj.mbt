///|
/// Render mode
priv enum Mode {
  Flat
  Break
}

///|
/// Render a document to a string with given width
pub fn render(doc : Doc, width : Int) -> String {
  let buf = StringBuilder::new()
  let items : Array[(Int, Mode, Doc)] = [(0, Break, doc)]
  render_items(buf, width, items)
  buf.to_string()
}

///|
fn render_items(
  buf : StringBuilder,
  width : Int,
  items : Array[(Int, Mode, Doc)]
) -> Unit {
  let mut column = 0
  while items.length() > 0 {
    let item = items.pop()
    guard item is Some((indent, mode, doc)) else { break }
    match doc {
      Nil => ()
      Text(s) => {
        buf.write_string(s)
        column += s.length()
      }
      Line =>
        match mode {
          Flat => {
            buf.write_char(' ')
            column += 1
          }
          Break => {
            buf.write_char('\n')
            for i = 0; i < indent; i = i + 1 {
              buf.write_char(' ')
            }
            column = indent
          }
        }
      HardLine => {
        buf.write_char('\n')
        for i = 0; i < indent; i = i + 1 {
          buf.write_char(' ')
        }
        column = indent
      }
      Concat(a, b) => {
        items.push((indent, mode, b))
        items.push((indent, mode, a))
      }
      Nest(i, d) => items.push((indent + i, mode, d))
      Group(d) => {
        // Try flat mode first
        if fits(width - column, [(indent, Flat, d)]) {
          items.push((indent, Flat, d))
        } else {
          items.push((indent, Break, d))
        }
      }
    }
  }
}

///|
fn fits(width : Int, items : Array[(Int, Mode, Doc)]) -> Bool {
  let mut remaining = width
  if remaining < 0 {
    return false
  }
  while items.length() > 0 {
    let item = items.pop()
    guard item is Some((indent, mode, doc)) else { break }
    match doc {
      Nil => ()
      Text(s) => remaining -= s.length()
      Line =>
        match mode {
          Flat => remaining -= 1
          Break => return true // Line break always fits
        }
      HardLine => return true
      Concat(a, b) => {
        items.push((indent, mode, b))
        items.push((indent, mode, a))
      }
      Nest(i, d) => items.push((indent + i, mode, d))
      Group(d) => items.push((indent, mode, d))
    }
    if remaining < 0 {
      return false
    }
  }
  true
}

// Convenience constructors

///|
pub fn text(s : String) -> Doc {
  Text(s)
}

///|
pub fn line() -> Doc {
  Line
}

///|
pub fn hardline() -> Doc {
  HardLine
}

///|
pub fn nest(indent : Int, doc : Doc) -> Doc {
  Nest(indent, doc)
}

///|
pub fn group(doc : Doc) -> Doc {
  Group(doc)
}

///|
/// Concatenate documents
pub fn concat(docs : Array[Doc]) -> Doc {
  if docs.is_empty() {
    return Nil
  }
  let mut result = docs[0]
  for i = 1; i < docs.length(); i = i + 1 {
    result = Concat(result, docs[i])
  }
  result
}

///|
/// Join documents with separator
pub fn join(docs : Array[Doc], sep : Doc) -> Doc {
  if docs.is_empty() {
    return Nil
  }
  let mut result = docs[0]
  for i = 1; i < docs.length(); i = i + 1 {
    result = Concat(result, Concat(sep, docs[i]))
  }
  result
}
