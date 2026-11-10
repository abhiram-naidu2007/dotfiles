//! evry: instant file-name search over the whole disk, after voidtools' Everything.
//!
//! The index is one flat file that is memory-mapped for each query, so there is
//! no daemon and nothing stays in RAM. A query is a SIMD substring scan over
//! every file name on the disk (about 10 ms for a million names).
//!
//!   evry index [--if-older SECS]      walk the disk, write ~/.cache/evry/index.bin
//!   evry [q] [-l N] [--tsv|-0] WORD.. search (also the default command)
//!   evry open PATH                    open with the desktop handler, remember it
//!   evry stat                         entries, size and age of the index
//!
//! Query language (all words must match, order does not matter):
//!   thesis pdf        both words appear in the path, at least one in the name
//!   Thesis            a capital letter makes that word case sensitive
//!   notes/            anything inside a folder whose name contains "notes"
//!   docs/intro        "intro" somewhere below a folder containing "docs"
//!   ext:pdf  *.pdf    extension filter (comma list: ext:png,jpg)
//!   pdf: doc: img: vid: audio: code: zip:    file-type shortcuts
//!   dir: file:        folders only / files only
//!   home: sys:        only inside / only outside the home directory
//! With no plain word the result is sorted by modification time, so "pdf:" is
//! "my most recent PDFs" and an empty query is "what did I touch last".

use memchr::memmem;
use memmap2::Mmap;
use std::collections::{HashMap, HashSet};
use std::ffi::OsString;
use std::fs::{self, File};
use std::io::{self, BufWriter, IsTerminal, Write};
use std::os::unix::ffi::{OsStrExt, OsStringExt};
use std::os::unix::fs::MetadataExt;
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::{Instant, SystemTime, UNIX_EPOCH};

const MAGIC: &[u8; 8] = b"EVRY\x02\0\0\0";
const HEADER: usize = 32;

const F_DIR: u8 = 1;
const F_LINK: u8 = 2;
const F_HOME: u8 = 4; // inside $HOME
const F_HIDDEN: u8 = 8; // some path component starts with '.'
const F_JUNK: u8 = 16; // inside a package cache or vendored tree
const INHERIT: u8 = F_HOME | F_HIDDEN | F_JUNK;

fn now() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0)
}

fn home() -> PathBuf {
    PathBuf::from(std::env::var_os("HOME").unwrap_or_else(|| OsString::from("/")))
}

fn xdg(var: &str, fallback: &str) -> PathBuf {
    match std::env::var_os(var) {
        Some(v) if !v.is_empty() => PathBuf::from(v),
        _ => home().join(fallback),
    }
}

fn index_path() -> PathBuf {
    match std::env::var_os("EVRY_INDEX") {
        Some(p) => PathBuf::from(p),
        None => xdg("XDG_CACHE_HOME", ".cache").join("evry/index.bin"),
    }
}

fn history_path() -> PathBuf {
    xdg("XDG_STATE_HOME", ".local/state").join("evry/history")
}

// ---------------------------------------------------------------- settings

struct Settings {
    root: PathBuf,
    home: PathBuf,
    skip_paths: Vec<PathBuf>,
    skip_names: HashSet<Vec<u8>>,
    junk_names: HashSet<Vec<u8>>,
    real_mounts: HashSet<PathBuf>,
    threads: usize,
}

impl Settings {
    /// Defaults, then ~/.config/evry/config (one "key value" per line):
    ///   root PATH | skip PATH | skip-name NAME | junk-name NAME | mount PATH | threads N
    fn load() -> Settings {
        let home = home();
        let mut s = Settings {
            root: PathBuf::from("/"),
            skip_paths: ["/proc", "/sys", "/dev", "/run", "/tmp", "/var/tmp", "/var/cache", "/var/lib/docker",
                "/var/lib/snapd", "/var/lib/flatpak/repo", "/snap", "/lost+found", "/mnt", "/media"]
                .iter()
                .map(PathBuf::from)
                .chain([home.join(".cache"), home.join(".local/share/Trash")])
                .collect(),
            // Listed, but never entered.
            skip_names: [".git", "node_modules", "__pycache__", ".mypy_cache", ".pytest_cache", ".tox", ".ccls-cache", ".gradle"]
                .iter()
                .map(|n| n.as_bytes().to_vec())
                .collect(),
            // Entered, but everything below ranks low.
            junk_names: ["site-packages", "dist-packages", "pkgs", "vendor", "target", "miniconda3", "anaconda3", "go",
                "snap", "build", "dist", "venv", "env"]
                .iter()
                .map(|n| n.as_bytes().to_vec())
                .collect(),
            real_mounts: HashSet::new(),
            threads: std::thread::available_parallelism().map(|n| n.get()).unwrap_or(2).clamp(1, 6),
            home,
        };
        if let Ok(text) = fs::read_to_string(xdg("XDG_CONFIG_HOME", ".config").join("evry/config")) {
            for line in text.lines() {
                let line = line.trim();
                let Some((key, val)) = line.split_once(char::is_whitespace) else { continue };
                let val = val.trim();
                match key {
                    "root" => s.root = PathBuf::from(val),
                    "skip" => s.skip_paths.push(PathBuf::from(val)),
                    "skip-name" => drop(s.skip_names.insert(val.as_bytes().to_vec())),
                    "junk-name" => drop(s.junk_names.insert(val.as_bytes().to_vec())),
                    "mount" => drop(s.real_mounts.insert(PathBuf::from(val))),
                    "threads" => s.threads = val.parse().unwrap_or(s.threads).max(1),
                    _ => {}
                }
            }
        }
        // Other file systems are entered only when they hold real files (not proc, tmpfs, squashfs ...).
        const REAL: [&str; 12] =
            ["ext2", "ext3", "ext4", "btrfs", "xfs", "f2fs", "zfs", "bcachefs", "ntfs", "ntfs3", "vfat", "exfat"];
        if let Ok(mounts) = fs::read_to_string("/proc/self/mounts") {
            for line in mounts.lines() {
                let mut it = line.split(' ');
                if let (Some(_), Some(point), Some(kind)) = (it.next(), it.next(), it.next()) {
                    if REAL.contains(&kind) || kind == "fuseblk" {
                        s.real_mounts.insert(PathBuf::from(point.replace("\\040", " ")));
                    }
                }
            }
        }
        s
    }
}

// ------------------------------------------------------------------ index

struct Child {
    name: Vec<u8>,
    mtime: u32,
    size: u64,
    dev: u64,
    dir: bool,
    link: bool,
}

fn read_children(path: &Path) -> Vec<Child> {
    let Ok(rd) = fs::read_dir(path) else { return Vec::new() };
    let mut out = Vec::new();
    for entry in rd.flatten() {
        let Ok(md) = entry.metadata() else { continue }; // lstat: links are not followed
        let name = entry.file_name().into_vec();
        if name.contains(&b'\n') || name.contains(&b'\t') {
            continue; // would break the line-based name table
        }
        let ft = md.file_type();
        out.push(Child {
            name,
            mtime: md.mtime().clamp(0, u32::MAX as i64) as u32,
            size: if ft.is_dir() { 0 } else { md.size() },
            dev: md.dev(),
            dir: ft.is_dir(),
            link: ft.is_symlink(),
        });
    }
    out
}

/// Map `f` over `items` on `threads` threads, keeping the order.
fn par_map<T: Sync, R: Send>(items: &[T], threads: usize, f: impl Fn(&T) -> R + Sync) -> Vec<R> {
    if threads <= 1 || items.len() < 32 {
        return items.iter().map(f).collect();
    }
    let next = AtomicUsize::new(0);
    let parts: Vec<Vec<(usize, R)>> = std::thread::scope(|scope| {
        let workers: Vec<_> = (0..threads)
            .map(|_| {
                scope.spawn(|| {
                    let mut out = Vec::new();
                    loop {
                        let i = next.fetch_add(1, Ordering::Relaxed);
                        if i >= items.len() {
                            break out;
                        }
                        out.push((i, f(&items[i])));
                    }
                })
            })
            .collect();
        workers.into_iter().map(|w| w.join().expect("walker thread")).collect()
    });
    let mut slots: Vec<Option<R>> = (0..items.len()).map(|_| None).collect();
    for part in parts {
        for (i, r) in part {
            slots[i] = Some(r);
        }
    }
    slots.into_iter().map(|r| r.expect("every item mapped")).collect()
}

#[derive(Default)]
struct Builder {
    parent: Vec<u32>,
    off: Vec<u32>,
    mtime: Vec<u32>,
    size: Vec<u64>,
    flags: Vec<u8>,
    depth: Vec<u8>,
    names: Vec<u8>,
}

impl Builder {
    fn push(&mut self, parent: u32, name: &[u8], mtime: u32, size: u64, flags: u8, depth: u8) -> u32 {
        let i = self.parent.len() as u32;
        self.parent.push(parent);
        self.off.push(self.names.len() as u32);
        self.mtime.push(mtime);
        self.size.push(size);
        self.flags.push(flags);
        self.depth.push(depth);
        self.names.extend_from_slice(name);
        self.names.push(b'\n');
        i
    }
}

fn bytes_of<T>(v: &[T]) -> &[u8] {
    // Plain integer slices only.
    unsafe { std::slice::from_raw_parts(v.as_ptr() as *const u8, std::mem::size_of_val(v)) }
}

fn pad8(n: usize) -> usize {
    (n + 7) & !7
}

/// Breadth-first walk, one level at a time, so a parent always has a smaller
/// index than its children (the query relies on that).
fn build_index(s: &Settings) -> io::Result<(usize, PathBuf)> {
    let mut b = Builder::default();
    let root_md = fs::symlink_metadata(&s.root)?;
    let root_name = s.root.as_os_str().as_bytes();
    let root_name = if root_name == b"/" { &b""[..] } else { root_name };
    let root_flags = F_DIR | if s.root.starts_with(&s.home) { F_HOME } else { 0 };
    b.push(0, root_name, root_md.mtime().clamp(0, u32::MAX as i64) as u32, 0, root_flags, 0);

    let mut frontier: Vec<(u32, PathBuf, u64)> = vec![(0, s.root.clone(), root_md.dev())];
    while !frontier.is_empty() {
        let listings = par_map(&frontier, s.threads, |(_, path, _)| read_children(path));
        let mut next = Vec::new();
        for ((pidx, ppath, pdev), children) in frontier.iter().zip(listings) {
            let pflags = b.flags[*pidx as usize] & INHERIT;
            let depth = b.depth[*pidx as usize].saturating_add(1);
            for c in children {
                let mut flags = pflags;
                if c.dir {
                    flags |= F_DIR;
                }
                if c.link {
                    flags |= F_LINK;
                }
                if c.name.first() == Some(&b'.') {
                    flags |= F_HIDDEN;
                }
                if s.junk_names.contains(&c.name) {
                    flags |= F_JUNK;
                }
                let full = if c.dir { Some(ppath.join(std::ffi::OsStr::from_bytes(&c.name))) } else { None };
                if let Some(full) = &full {
                    if *full == s.home {
                        flags |= F_HOME;
                    }
                }
                let i = b.push(*pidx, &c.name, c.mtime, c.size, flags, depth);
                if let Some(full) = full {
                    let enter = !s.skip_names.contains(&c.name)
                        && !s.skip_paths.iter().any(|p| *p == full)
                        && (c.dev == *pdev || s.real_mounts.contains(&full));
                    if enter {
                        next.push((i, full, c.dev));
                    }
                }
            }
        }
        frontier = next;
    }
    if b.names.len() > u32::MAX as usize {
        return Err(io::Error::other("name table over 4 GiB"));
    }
    b.off.push(b.names.len() as u32);
    let lower = b.names.to_ascii_lowercase();

    let path = index_path();
    if let Some(dir) = path.parent() {
        fs::create_dir_all(dir)?;
    }
    let tmp = path.with_extension(format!("tmp{}", std::process::id()));
    {
        let mut w = BufWriter::with_capacity(1 << 20, File::create(&tmp)?);
        let n = b.parent.len();
        w.write_all(MAGIC)?;
        w.write_all(&(n as u64).to_le_bytes())?;
        w.write_all(&(b.names.len() as u64).to_le_bytes())?;
        w.write_all(&now().to_le_bytes())?;
        for section in [
            bytes_of(&b.size),
            bytes_of(&b.parent),
            bytes_of(&b.off),
            bytes_of(&b.mtime),
            &b.flags[..],
            &b.depth[..],
            &b.names[..],
            &lower[..],
        ] {
            w.write_all(section)?;
            w.write_all(&[0u8; 8][..pad8(section.len()) - section.len()])?;
        }
        w.flush()?;
    }
    fs::rename(&tmp, &path)?;
    Ok((b.parent.len(), path))
}

struct Index {
    map: Mmap,
    n: usize,
    built: u64,
    o_size: usize,
    o_parent: usize,
    o_off: usize,
    o_mtime: usize,
    o_flags: usize,
    o_depth: usize,
    o_names: usize,
    o_lower: usize,
    names_len: usize,
}

impl Index {
    fn open() -> io::Result<Index> {
        let bad = |why: &str| io::Error::new(io::ErrorKind::InvalidData, why.to_string());
        let file = File::open(index_path())?;
        let map = unsafe { Mmap::map(&file)? };
        if map.len() < HEADER || &map[..8] != MAGIC {
            return Err(bad("not an evry index (run: evry index)"));
        }
        let word = |at: usize| u64::from_le_bytes(map[at..at + 8].try_into().unwrap()) as usize;
        let (n, names_len, built) = (word(8), word(16), word(24) as u64);
        let o_size = HEADER;
        let o_parent = o_size + pad8(n * 8);
        let o_off = o_parent + pad8(n * 4);
        let o_mtime = o_off + pad8((n + 1) * 4);
        let o_flags = o_mtime + pad8(n * 4);
        let o_depth = o_flags + pad8(n);
        let o_names = o_depth + pad8(n);
        let o_lower = o_names + pad8(names_len);
        if n == 0 || map.len() < o_lower + names_len {
            return Err(bad("index is truncated (run: evry index)"));
        }
        Ok(Index { map, n, built, o_size, o_parent, o_off, o_mtime, o_flags, o_depth, o_names, o_lower, names_len })
    }
    fn slice<T>(&self, at: usize, len: usize) -> &[T] {
        // Sections start on 8-byte boundaries of a page-aligned map.
        unsafe { std::slice::from_raw_parts(self.map.as_ptr().add(at) as *const T, len) }
    }
    fn size(&self) -> &[u64] { self.slice(self.o_size, self.n) }
    fn parent(&self) -> &[u32] { self.slice(self.o_parent, self.n) }
    fn off(&self) -> &[u32] { self.slice(self.o_off, self.n + 1) }
    fn mtime(&self) -> &[u32] { self.slice(self.o_mtime, self.n) }
    fn flags(&self) -> &[u8] { self.slice(self.o_flags, self.n) }
    fn depth(&self) -> &[u8] { self.slice(self.o_depth, self.n) }
    fn names(&self) -> &[u8] { self.slice(self.o_names, self.names_len) }
    fn lower(&self) -> &[u8] { self.slice(self.o_lower, self.names_len) }
    fn name_in<'a>(&self, blob: &'a [u8], i: usize) -> &'a [u8] {
        let off = self.off();
        &blob[off[i] as usize..off[i + 1] as usize - 1]
    }
    fn path(&self, i: usize) -> Vec<u8> {
        let (parent, names) = (self.parent(), self.names());
        let mut chain = Vec::with_capacity(16);
        let mut j = i;
        while j != 0 {
            chain.push(j);
            j = parent[j] as usize;
        }
        let mut out = self.name_in(names, 0).to_vec();
        for &j in chain.iter().rev() {
            out.push(b'/');
            out.extend_from_slice(self.name_in(names, j));
        }
        if out.is_empty() {
            out.push(b'/');
        }
        out
    }
}

// ------------------------------------------------------------------ query

struct Term {
    needle: Vec<u8>,
    case_sensitive: bool,
    bit: u16,
}

#[derive(Default)]
struct Query {
    terms: Vec<Term>,
    norm: u16, // bits of words that may match the name or any folder above it
    anc: u16,  // bits of words that must match a folder above ("word/")
    exts: Vec<Vec<u8>>,
    want_dir: Option<bool>,
    want_home: Option<bool>,
}

fn class_exts(class: &str) -> Option<&'static str> {
    Some(match class {
        "pdf" => "pdf",
        "doc" | "docs" => "pdf,djvu,epub,doc,docx,odt,rtf,txt,md,tex,typ,ppt,pptx,odp,xls,xlsx,ods,csv",
        "img" | "pic" | "image" => "png,jpg,jpeg,webp,gif,svg,bmp,tiff,avif,heic,ico",
        "vid" | "video" => "mp4,mkv,webm,mov,avi,m4v,flv",
        "audio" | "music" => "mp3,flac,ogg,opus,wav,m4a,aac",
        "code" => "py,rs,c,h,cpp,hpp,cc,go,js,ts,tsx,jsx,lua,sh,fish,java,kt,rb,zig,hs,ml,jl,m,ipynb,typ,tex,toml,yaml,yml,json,css,html",
        "zip" | "archive" => "zip,tar,gz,xz,zst,bz2,7z,rar,deb,appimage",
        _ => return None,
    })
}

impl Query {
    fn parse(words: &[String]) -> Query {
        let mut q = Query::default();
        let add_exts = |q: &mut Query, list: &str| {
            q.exts.extend(list.split(',').filter(|e| !e.is_empty()).map(|e| e.trim_start_matches('.').to_ascii_lowercase().into_bytes()))
        };
        for word in words.iter().flat_map(|w| w.split_whitespace()) {
            if let Some(list) = word.strip_prefix("ext:").or_else(|| word.strip_prefix("*.")) {
                add_exts(&mut q, list);
                continue;
            }
            if let Some(class) = word.strip_suffix(':') {
                match class {
                    "dir" | "folder" => q.want_dir = Some(true),
                    "file" => q.want_dir = Some(false),
                    "home" => q.want_home = Some(true),
                    "sys" => q.want_home = Some(false),
                    _ => match class_exts(class) {
                        Some(list) => add_exts(&mut q, list),
                        None => q.add_term(class, false),
                    },
                }
                continue;
            }
            // "a/b/c": a and b must match folders above, c is an ordinary word.
            let mut parts: Vec<&str> = word.split('/').collect();
            let last = parts.pop().unwrap_or("");
            for part in parts {
                q.add_term(part, true);
            }
            q.add_term(last, false);
        }
        q
    }
    fn add_term(&mut self, text: &str, ancestor_only: bool) {
        if text.is_empty() || self.terms.len() >= 16 {
            return;
        }
        let bit = 1u16 << self.terms.len();
        if ancestor_only {
            self.anc |= bit;
        } else {
            self.norm |= bit;
        }
        self.terms.push(Term {
            needle: text.as_bytes().to_vec(),
            case_sensitive: text.bytes().any(|b| b.is_ascii_uppercase()),
            bit,
        });
    }
}

/// Set `bit` for every entry whose own name contains `needle`.
fn mark(blob: &[u8], off: &[u32], needle: &[u8], bit: u16, own: &mut [u16]) {
    let finder = memmem::Finder::new(needle);
    let n = own.len();
    let (mut pos, mut i) = (0usize, 0usize);
    while let Some(hit) = finder.find(&blob[pos..]) {
        let at = pos + hit;
        i += off[i + 1..=n].partition_point(|&start| start as usize <= at);
        own[i] |= bit;
        pos = off[i + 1] as usize; // one hit per name is enough
    }
}

struct Hit {
    score: i64,
    idx: u32,
}

fn search(ix: &Index, q: &Query, limit: usize, history: &HashMap<Vec<u8>, (u32, u64)>) -> Vec<Hit> {
    let n = ix.n;
    let (parent, flags, depth, mtime, off) = (ix.parent(), ix.flags(), ix.depth(), ix.mtime(), ix.off());
    let (names, lower) = (ix.names(), ix.lower());
    let now = now() as i64;

    let mut own = vec![0u16; n];
    for t in &q.terms {
        mark(if t.case_sensitive { names } else { lower }, off, &t.needle, t.bit, &mut own);
    }

    let browse = q.norm == 0; // no plain word: newest first
    let unfiltered = q.terms.is_empty() && q.exts.is_empty() && q.want_dir.is_none() && q.want_home.is_none();
    let mut acc = vec![0u16; n];
    acc[0] = own[0];
    let mut hits: Vec<Hit> = Vec::new();
    for i in 1..n {
        let above = acc[parent[i] as usize];
        let me = own[i];
        acc[i] = above | me;
        if (me | above) & q.norm != q.norm || above & q.anc != q.anc || (!browse && me & q.norm == 0) {
            continue;
        }
        let f = flags[i];
        if let Some(d) = q.want_dir {
            if d != (f & F_DIR != 0) {
                continue;
            }
        }
        if let Some(h) = q.want_home {
            if h != (f & F_HOME != 0) {
                continue;
            }
        }
        let lname = &lower[off[i] as usize..off[i + 1] as usize - 1];
        if !q.exts.is_empty() {
            let ext = match memchr::memrchr(b'.', lname) {
                Some(dot) if f & F_DIR == 0 => &lname[dot + 1..],
                _ => continue,
            };
            if !q.exts.iter().any(|e| e == ext) {
                continue;
            }
        }
        let tidy_home = f & (F_HOME | F_HIDDEN | F_JUNK) == F_HOME;
        if unfiltered && (!tidy_home || f & F_DIR != 0) {
            continue; // empty query: recently changed files of mine
        }
        let age = now - mtime[i] as i64;
        let score = if browse {
            mtime[i] as i64 + if tidy_home { 1 << 40 } else { 0 }
        } else {
            let mut s = 0i64;
            for t in &q.terms {
                if t.bit & q.norm == 0 {
                    continue;
                }
                if me & t.bit == 0 {
                    s += 8; // matched only by a folder above
                    continue;
                }
                s += 100;
                let name = if t.case_sensitive { &names[off[i] as usize..off[i + 1] as usize - 1] } else { lname };
                let m = t.needle.len();
                if name.len() == m {
                    s += 120; // the whole name
                } else if name.starts_with(&t.needle) {
                    s += if name[m] == b'.' { 100 } else { 50 }; // whole stem / prefix
                } else if let Some(p) = memmem::find(name, &t.needle) {
                    if matches!(name[p - 1], b'-' | b'_' | b'.' | b' ') {
                        s += 25; // start of a word
                    }
                }
            }
            s -= (lname.len() as i64).min(60) / 2;
            s -= depth[i] as i64 * 2;
            s += if f & F_JUNK != 0 {
                -60
            } else if tidy_home {
                90
            } else if f & F_HOME != 0 {
                40 // dotfiles: hidden, but mine
            } else {
                -30
            };
            if f & F_DIR != 0 {
                s += 12;
            }
            s += match age {
                a if a < 86_400 => 40,
                a if a < 7 * 86_400 => 30,
                a if a < 30 * 86_400 => 20,
                a if a < 365 * 86_400 => 8,
                _ => 0,
            };
            s
        };
        hits.push(Hit { score, idx: i as u32 });
    }

    let order = |a: &Hit, b: &Hit| b.score.cmp(&a.score).then(mtime[b.idx as usize].cmp(&mtime[a.idx as usize]));
    // Keep a wider pool, add what the open-history knows, then cut to the limit.
    let pool = (limit * 8).max(400);
    if hits.len() > pool {
        hits.select_nth_unstable_by(pool - 1, order);
        hits.truncate(pool);
    }
    if !history.is_empty() && !browse {
        for h in hits.iter_mut() {
            if let Some(&(count, last)) = history.get(&ix.path(h.idx as usize)) {
                let fresh = match now - last as i64 {
                    a if a < 7 * 86_400 => 1.0,
                    a if a < 30 * 86_400 => 0.6,
                    _ => 0.3,
                };
                h.score += ((30 * count as i64).min(120) as f64 * fresh) as i64;
            }
        }
    }
    hits.sort_unstable_by(order);
    hits.truncate(limit);
    hits
}

// ---------------------------------------------------------------- history

fn read_history() -> HashMap<Vec<u8>, (u32, u64)> {
    let mut map = HashMap::new();
    let Ok(data) = fs::read(history_path()) else { return map };
    for line in data.split(|&b| b == b'\n') {
        let mut it = line.splitn(3, |&b| b == b'\t');
        if let (Some(count), Some(last), Some(path)) = (it.next(), it.next(), it.next()) {
            let num = |b: &[u8]| std::str::from_utf8(b).ok().and_then(|s| s.parse::<u64>().ok());
            if let (Some(count), Some(last)) = (num(count), num(last)) {
                map.insert(path.to_vec(), (count as u32, last));
            }
        }
    }
    map
}

fn remember(path: &Path) -> io::Result<()> {
    let mut map = read_history();
    let entry = map.entry(path.as_os_str().as_bytes().to_vec()).or_insert((0, 0));
    *entry = (entry.0 + 1, now());
    let mut rows: Vec<_> = map.into_iter().collect();
    rows.sort_by(|a, b| b.1 .1.cmp(&a.1 .1));
    rows.truncate(500);
    let file = history_path();
    if let Some(dir) = file.parent() {
        fs::create_dir_all(dir)?;
    }
    let mut out = Vec::new();
    for (path, (count, last)) in rows {
        out.extend_from_slice(format!("{count}\t{last}\t").as_bytes());
        out.extend_from_slice(&path);
        out.push(b'\n');
    }
    let tmp = file.with_extension("tmp");
    fs::write(&tmp, out)?;
    fs::rename(tmp, file)
}

// ----------------------------------------------------------------- output

fn human_size(bytes: u64) -> String {
    const UNITS: [&str; 5] = ["B", "KB", "MB", "GB", "TB"];
    let mut v = bytes as f64;
    let mut u = 0;
    while v >= 1000.0 && u < UNITS.len() - 1 {
        v /= 1024.0;
        u += 1;
    }
    if u == 0 {
        format!("{bytes} B")
    } else if v < 10.0 {
        format!("{v:.1} {}", UNITS[u])
    } else {
        format!("{v:.0} {}", UNITS[u])
    }
}

fn human_age(secs: i64) -> String {
    match secs {
        s if s < 90 => "now".into(),
        s if s < 3600 => format!("{}m", s / 60),
        s if s < 86_400 => format!("{}h", s / 3600),
        s if s < 14 * 86_400 => format!("{}d", s / 86_400),
        s if s < 60 * 86_400 => format!("{}w", s / (7 * 86_400)),
        s if s < 365 * 86_400 => format!("{}mo", s / (30 * 86_400)),
        s => format!("{}y", s / (365 * 86_400)),
    }
}

fn usage() -> ! {
    eprintln!(
        "evry: instant file-name search over the whole disk

  evry [q] [-l N] [--tsv | -0] WORD...   search (default command)
  evry index [--if-older SECS]           rebuild the index
  evry open PATH                         open a file and remember it
  evry stat                              index statistics

  words        thesis pdf     all must match, at least one in the file name
  folders      notes/ docs/intro
  filters      ext:pdf  *.png  pdf: doc: img: vid: audio: code: zip: dir: file: home: sys:
  Capitals make a word case sensitive. No plain word = newest first."
    );
    std::process::exit(2)
}

fn cmd_index(args: &[String]) -> io::Result<()> {
    if let Some(pos) = args.iter().position(|a| a == "--if-older") {
        let secs: u64 = args.get(pos + 1).and_then(|s| s.parse().ok()).unwrap_or(600);
        if let Ok(ix) = Index::open() {
            if now().saturating_sub(ix.built) < secs {
                return Ok(());
            }
        }
    }
    // One indexer at a time; a second caller just leaves.
    let lock_path = index_path().with_extension("lock");
    if let Some(dir) = lock_path.parent() {
        fs::create_dir_all(dir)?;
    }
    let lock = File::create(&lock_path)?;
    if lock.try_lock().is_err() {
        return Ok(());
    }
    let started = Instant::now();
    let (n, path) = build_index(&Settings::load())?;
    let size = fs::metadata(&path)?.len();
    println!("{n} entries, {}, {:.1} s -> {}", human_size(size), started.elapsed().as_secs_f64(), path.display());
    Ok(())
}

fn cmd_stat() -> io::Result<()> {
    let ix = Index::open()?;
    let size = fs::metadata(index_path())?.len();
    println!("{} entries · {} · indexed {} ago", ix.n, human_size(size), human_age((now() - ix.built) as i64));
    Ok(())
}

fn cmd_open(args: &[String]) -> io::Result<()> {
    let Some(path) = args.first() else { usage() };
    let path = fs::canonicalize(path).unwrap_or_else(|_| PathBuf::from(path));
    let _ = remember(&path);
    let opener = std::env::var("EVRY_OPENER").unwrap_or_else(|_| "xdg-open".into());
    Err(std::process::Command::new(opener).arg(&path).exec())
}

fn cmd_query(args: &[String]) -> io::Result<()> {
    let (mut limit, mut tsv, mut nul) = (40usize, false, false);
    let mut words = Vec::new();
    let mut it = args.iter();
    let mut literal = false;
    while let Some(a) = it.next() {
        match a.as_str() {
            _ if literal => words.push(a.clone()),
            "--" => literal = true,
            "-l" | "--limit" => limit = it.next().and_then(|s| s.parse().ok()).unwrap_or(limit),
            "--tsv" => tsv = true,
            "-0" => nul = true,
            "-h" | "--help" => usage(),
            _ => words.push(a.clone()),
        }
    }
    let ix = match Index::open() {
        Ok(ix) => ix,
        Err(_) => {
            eprintln!("evry: no index yet, building one ...");
            build_index(&Settings::load())?;
            Index::open()?
        }
    };
    let q = Query::parse(&words);
    let hits = search(&ix, &q, limit.max(1), &read_history());

    let (flags, size, mtime) = (ix.flags(), ix.size(), ix.mtime());
    let home = home().into_os_string().into_vec();
    let stdout = io::stdout();
    let color = stdout.is_terminal() && !tsv && !nul;
    let mut out = BufWriter::new(stdout.lock());
    let t = now() as i64;
    for h in &hits {
        let i = h.idx as usize;
        let path = ix.path(i);
        let dir = flags[i] & F_DIR != 0;
        let (sz, age) = (if dir { String::new() } else { human_size(size[i]) }, human_age(t - mtime[i] as i64));
        if nul {
            out.write_all(&path)?;
            out.write_all(b"\0")?;
        } else if tsv {
            out.write_all(if dir { b"d\t" } else if flags[i] & F_LINK != 0 { b"l\t" } else { b"f\t" })?;
            out.write_all(&path)?;
            writeln!(out, "\t{sz}\t{age}\t{}", size[i])?;
        } else {
            let shown: Vec<u8> = match path.strip_prefix(&home[..]) {
                Some(rest) if rest.first() == Some(&b'/') || rest.is_empty() => [&b"~"[..], rest].concat(),
                _ => path.clone(),
            };
            let cut = memchr::memrchr(b'/', &shown).map(|p| p + 1).unwrap_or(0);
            if color {
                write!(out, "\x1b[2m{age:>4} {sz:>7}  ")?;
                out.write_all(&shown[..cut])?;
                out.write_all(if dir { b"\x1b[0;1;34m" } else { b"\x1b[0;1m" })?;
                out.write_all(&shown[cut..])?;
                out.write_all(b"\x1b[0m\n")?;
            } else {
                out.write_all(&shown)?;
                out.write_all(b"\n")?;
            }
        }
    }
    out.flush()
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let result = match args.first().map(String::as_str) {
        Some("index") => cmd_index(&args[1..]),
        Some("stat") => cmd_stat(),
        Some("open") => cmd_open(&args[1..]),
        Some("q") => cmd_query(&args[1..]),
        Some("-h") | Some("--help") | Some("help") => usage(),
        _ => cmd_query(&args),
    };
    if let Err(e) = result {
        // A closed pipe (evry ... | head) is not an error.
        if e.kind() != io::ErrorKind::BrokenPipe {
            eprintln!("evry: {e}");
            std::process::exit(1);
        }
    }
}
