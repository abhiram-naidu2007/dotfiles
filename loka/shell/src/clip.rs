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
    for (_, p) in entries().into_iter().skip(KEEP) {
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
    entries()
        .into_iter()
        .take(SHOWN)
        .map(|(id, p)| {
            if ext(&p) != "txt" {
                return Item { id, text: describe(&p), image: Some(p) };
            }
            let mut head = Vec::with_capacity(300);
            let _ = std::fs::File::open(&p).map(|f| f.take(300).read_to_end(&mut head));
            let text = String::from_utf8_lossy(&head).trim_end_matches('\u{fffd}').split_whitespace().collect::<Vec<_>>().join(" ");
            Item { id, text, image: None }
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
}

pub fn wipe() {
    for (_, p) in entries() {
        let _ = std::fs::remove_file(p);
    }
}
