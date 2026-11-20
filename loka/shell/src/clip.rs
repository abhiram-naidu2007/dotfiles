use std::io::Read;
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::Mutex;

const KEEP: usize = 200;
const SHOWN: usize = 40;
static STORE: Mutex<()> = Mutex::new(());

#[derive(Clone, Debug)]
pub struct Item {
    pub id: u32,
    pub text: String,
    pub image: Option<PathBuf>,
    /// Pinned items stay on top and survive pruning and "clear".
    pub pinned: bool,
    pub kind: Kind,
}

/// What a text entry looks like, for its icon and how it is drawn.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Kind {
    Text,
    Link,
    /// A hex colour; the value is 0xRRGGBB.
    Colour(u32),
    Path,
    Code,
    Image,
}

pub fn kind_of(raw: &str) -> Kind {
    let t = raw.trim();
    if let Some(h) = t.strip_prefix('#')
        && matches!(h.len(), 3 | 6 | 8)
        && h.chars().all(|c| c.is_ascii_hexdigit())
    {
        let full: String = if h.len() == 3 { h.chars().flat_map(|c| [c, c]).collect() } else { h[..6].to_owned() };
        return Kind::Colour(u32::from_str_radix(&full, 16).unwrap_or(0));
    }
    if !t.contains(char::is_whitespace) && (t.starts_with("https://") || t.starts_with("http://")) {
        return Kind::Link;
    }
    if !t.contains('\n') && (t.starts_with('/') || t.starts_with("~/")) && !t.contains(' ') {
        return Kind::Path;
    }
    let marks = [";\n", "{\n", "fn ", "=> ", "def ", "import ", "#include", "const ", "let ", "</", "()"];
    if t.contains('\n') && marks.iter().filter(|m| t.contains(*m)).count() >= 2 {
        return Kind::Code;
    }
    Kind::Text
}

fn pins_path() -> PathBuf {
    dir().join("pins")
}

fn pins() -> Vec<u32> {
    std::fs::read_to_string(pins_path()).unwrap_or_default().split_whitespace().filter_map(|s| s.parse().ok()).collect()
}

fn save_pins(p: &[u32]) {
    let s: Vec<String> = p.iter().map(|i| i.to_string()).collect();
    let _ = std::fs::write(pins_path(), s.join("\n"));
}

/// Pin or unpin an entry.
pub fn pin(id: u32) {
    let mut p = pins();
    if let Some(i) = p.iter().position(|x| *x == id) {
        p.remove(i);
    } else {
        p.push(id);
    }
    save_pins(&p);
}

fn dir() -> PathBuf {
    std::env::var_os("XDG_DATA_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(".local/share"))
        .join("loka/clip")
}

fn entries() -> Vec<(u32, PathBuf)> {
    let mut v: Vec<(u32, PathBuf)> = std::fs::read_dir(dir())
        .into_iter()
        .flatten()
        .flatten()
        .filter_map(|e| {
            let p = e.path();
            Some((p.file_stem()?.to_str()?.parse().ok()?, p))
        })
        .collect();
    v.sort_by_key(|e| std::cmp::Reverse(e.0));
    v
}

fn ext(p: &std::path::Path) -> &str {
    p.extension().and_then(|e| e.to_str()).unwrap_or_default()
}

fn xclip(args: &[&str]) -> Vec<u8> {
    Command::new("xclip").args(["-selection", "clipboard"]).args(args).stderr(Stdio::null()).output().map(|o| o.stdout).unwrap_or_default()
}

pub fn store() {
    let _lock = STORE.lock();
    let targets = String::from_utf8_lossy(&xclip(&["-t", "TARGETS", "-o"])).into_owned();
    let (data, kind) = if let Some(t) = targets.lines().find(|t| matches!(*t, "image/png" | "image/jpeg" | "image/webp")) {
        (xclip(&["-t", t, "-o"]), &t[6..])
    } else if targets.lines().any(|t| matches!(t, "UTF8_STRING" | "STRING") || t.starts_with("text/plain")) {
        (xclip(&["-o"]), "txt")
    } else {
        return;
    };
    if data.is_empty() {
        return;
    }
    let d = dir();
    let _ = std::fs::create_dir_all(&d);
    let old = entries();
    for (_, p) in &old {
        if ext(p) == kind && std::fs::read(p).is_ok_and(|b| b == data) {
            let _ = std::fs::remove_file(p);
        }
    }
    let id = old.first().map_or(0, |e| e.0) + 1;
    let _ = std::fs::write(d.join(format!("{id}.{kind}")), &data);
    let pinned = pins();
    for (_, p) in entries().into_iter().filter(|e| !pinned.contains(&e.0)).skip(KEEP) {
        let _ = std::fs::remove_file(p);
    }
}

fn describe(p: &std::path::Path) -> String {
    let kib = std::fs::metadata(p).map_or(0, |m| m.len() / 1024);
    let dims = std::fs::File::open(p).ok().and_then(|f| png::Decoder::new(std::io::BufReader::new(f)).read_info().ok()).map(|r| {
        let i = r.info();
        format!("{}x{}", i.width, i.height)
    });
    format!("{} · {kib} KiB", dims.unwrap_or_else(|| ext(p).to_owned()))
}

pub fn list() -> Vec<Item> {
    let pinned = pins();
    let mut all = entries();
    // pinned first, each group newest first
    all.sort_by_key(|e| (!pinned.contains(&e.0), std::cmp::Reverse(e.0)));
    all.into_iter()
        .take(SHOWN)
        .map(|(id, p)| {
            let pinned = pinned.contains(&id);
            if ext(&p) != "txt" {
                return Item { id, text: describe(&p), image: Some(p), pinned, kind: Kind::Image };
            }
            let mut head = Vec::with_capacity(300);
            let _ = std::fs::File::open(&p).map(|f| f.take(300).read_to_end(&mut head));
            let raw = String::from_utf8_lossy(&head).trim_end_matches('\u{fffd}').to_string();
            let kind = kind_of(&raw);
            let text = raw.split_whitespace().collect::<Vec<_>>().join(" ");
            Item { id, text, image: None, pinned, kind }
        })
        .collect()
}

pub fn copy(id: u32) {
    let Some((_, p)) = entries().into_iter().find(|e| e.0 == id) else { return };
    let target = if ext(&p) == "txt" { "UTF8_STRING".to_owned() } else { format!("image/{}", ext(&p)) };
    let _ = Command::new("xclip")
        .args(["-selection", "clipboard", "-t", &target, "-i"])
        .arg(&p)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
}

pub fn delete(id: u32) {
    for (_, p) in entries().into_iter().filter(|e| e.0 == id) {
        let _ = std::fs::remove_file(p);
    }
    let mut p = pins();
    p.retain(|x| *x != id);
    save_pins(&p);
}

/// Clear the history; pinned entries stay.
pub fn wipe() {
    let pinned = pins();
    for (_, p) in entries().into_iter().filter(|e| !pinned.contains(&e.0)) {
        let _ = std::fs::remove_file(p);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn kinds() {
        assert_eq!(kind_of("#ff8800"), Kind::Colour(0xff8800));
        assert_eq!(kind_of(" #f80 "), Kind::Colour(0xff8800));
        assert_eq!(kind_of("https://example.org/a?b=1"), Kind::Link);
        assert_eq!(kind_of("see https://x.org"), Kind::Text);
        assert_eq!(kind_of("~/dotfiles/loka"), Kind::Path);
        assert_eq!(kind_of("fn main() {\n    let x = 1;\n}"), Kind::Code);
        assert_eq!(kind_of("hello world"), Kind::Text);
    }
}
