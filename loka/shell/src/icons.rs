use std::collections::HashMap;
use std::path::{Path, PathBuf};

use tiny_skia::{FilterQuality, Pixmap, PixmapPaint, Transform};

use crate::config::home;

pub struct Icons {
    index: Option<HashMap<String, String>>,
    cache: HashMap<(String, u32), Option<Pixmap>>,
}

fn app_dirs() -> Vec<PathBuf> {
    let mut v = vec![home().join(".local/share/applications")];
    let data = std::env::var("XDG_DATA_DIRS").unwrap_or_else(|_| "/usr/local/share:/usr/share".into());
    for d in data.split(':').filter(|d| !d.is_empty()) {
        v.push(Path::new(d).join("applications"));
    }
    v.push(PathBuf::from("/var/lib/snapd/desktop/applications"));
    v
}

fn build_index() -> HashMap<String, String> {
    let mut map = HashMap::new();
    for dir in app_dirs() {
        let Ok(rd) = std::fs::read_dir(&dir) else { continue };
        for e in rd.flatten() {
            let p = e.path();
            if p.extension().and_then(|x| x.to_str()) != Some("desktop") {
                continue;
            }
            let Ok(text) = std::fs::read_to_string(&p) else { continue };
            let mut icon = None;
            let mut wm = None;
            let mut name = None;
            let mut exec = None;
            let mut main = false;
            for line in text.lines() {
                if line.starts_with('[') {
                    main = line == "[Desktop Entry]";
                    continue;
                }
                if !main {
                    continue;
                }
                if let Some(v) = line.strip_prefix("Icon=") {
                    icon = Some(v.trim().to_owned());
                } else if let Some(v) = line.strip_prefix("StartupWMClass=") {
                    wm = Some(v.trim().to_lowercase());
                } else if let Some(v) = line.strip_prefix("Name=") {
                    name = Some(v.trim().to_lowercase());
                } else if let Some(v) = line.strip_prefix("Exec=") {
                    exec = v.split_whitespace().next().map(|x| Path::new(x).file_name().and_then(|f| f.to_str()).unwrap_or(x).to_lowercase());
                }
            }
            let Some(icon) = icon else { continue };
            let stem = p.file_stem().and_then(|s| s.to_str()).unwrap_or_default().to_lowercase();
            let last = stem.rsplit('.').next().unwrap_or(&stem).to_owned();
            for k in [wm, Some(stem.clone()), Some(last), name, exec].into_iter().flatten() {
                map.entry(k).or_insert_with(|| icon.clone());
            }
        }
    }
    map
}

const THEMES: [&str; 4] = ["Papirus-Dark", "Papirus", "breeze-dark", "hicolor"];
const SIZES: [&str; 9] = ["32x32", "24x24", "22x22", "48x48", "16x16", "64x64", "scalable", "128x128", "256x256"];

pub fn lookup(name: &str, extra_dir: &str) -> Option<PathBuf> {
    if !extra_dir.is_empty() {
        for ext in ["svg", "png"] {
            let f = Path::new(extra_dir).join(format!("{name}.{ext}"));
            if f.exists() {
                return Some(f);
            }
        }
    }
    find_icon(name)
}

fn find_icon(name: &str) -> Option<PathBuf> {
    let p = Path::new(name);
    if p.is_absolute() {
        return p.exists().then(|| p.to_path_buf());
    }
    let bases = [home().join(".local/share/icons"), home().join(".icons"), PathBuf::from("/usr/share/icons")];
    for theme in THEMES {
        for base in &bases {
            let t = base.join(theme);
            if !t.exists() {
                continue;
            }
            for size in SIZES {
                for ext in ["svg", "png"] {
                    let f = t.join(size).join("apps").join(format!("{name}.{ext}"));
                    if f.exists() {
                        return Some(f);
                    }
                }
            }
        }
    }
    for ext in ["svg", "png", "xpm"] {
        let f = PathBuf::from("/usr/share/pixmaps").join(format!("{name}.{ext}"));
        if f.exists() && ext != "xpm" {
            return Some(f);
        }
    }
    None
}

pub fn load_scaled(path: &Path, width: u32) -> Option<Pixmap> {
    let data = std::fs::read(path).ok()?;
    let dec = png::Decoder::new(std::io::Cursor::new(data));
    let r = dec.read_info().ok()?;
    let (w0, h0) = { let i = r.info(); (i.width, i.height) };
    let height = (h0 as f32 * width as f32 / w0 as f32).round() as u32;
    drop(r);
    let full = render_path_wh(path, w0, h0)?;
    let mut out = Pixmap::new(width, height.max(1))?;
    let k = width as f32 / w0 as f32;
    let paint = PixmapPaint { quality: FilterQuality::Bicubic, ..PixmapPaint::default() };
    out.draw_pixmap(0, 0, full.as_ref(), &paint, Transform::from_scale(k, k), None);
    Some(out)
}

fn render_path_wh(path: &Path, w: u32, h: u32) -> Option<Pixmap> {
    let mut p = render_path(path, w.max(h))?;
    if w != h {
        let mut out = Pixmap::new(w, h)?;
        out.draw_pixmap(0, 0, p.as_ref(), &PixmapPaint::default(), Transform::identity(), None);
        p = out;
    }
    Some(p)
}

pub fn render_path(path: &Path, size: u32) -> Option<Pixmap> {
    let data = std::fs::read(path).ok()?;
    let mut out = Pixmap::new(size, size)?;
    if path.extension().and_then(|x| x.to_str()) == Some("svg") {
        let tree = resvg::usvg::Tree::from_data(&data, &resvg::usvg::Options::default()).ok()?;
        let s = tree.size();
        let k = size as f32 / s.width().max(s.height());
        resvg::render(&tree, Transform::from_scale(k, k), &mut out.as_mut());
        return Some(out);
    }
    let dec = png::Decoder::new(std::io::Cursor::new(data));
    let mut r = dec.read_info().ok()?;
    let mut buf = vec![0; r.output_buffer_size()?];
    let info = r.next_frame(&mut buf).ok()?;
    let (w, h) = (info.width, info.height);
    let b = &buf[..info.buffer_size()];
    let rgba: Vec<u8> = match info.color_type {
        png::ColorType::Rgba => b.to_vec(),
        png::ColorType::Rgb => b.as_chunks::<3>().0.iter().flat_map(|c| [c[0], c[1], c[2], 255]).collect(),
        png::ColorType::GrayscaleAlpha => b.as_chunks::<2>().0.iter().flat_map(|c| [c[0], c[0], c[0], c[1]]).collect(),
        png::ColorType::Grayscale => b.iter().flat_map(|c| [*c, *c, *c, 255]).collect(),
        _ => return None,
    };
    let mut src = Pixmap::new(w, h)?;
    for (d, s) in src.data_mut().as_chunks_mut::<4>().0.iter_mut().zip(rgba.as_chunks::<4>().0.iter()) {
        let a = s[3] as u16;
        d[0] = (s[0] as u16 * a / 255) as u8;
        d[1] = (s[1] as u16 * a / 255) as u8;
        d[2] = (s[2] as u16 * a / 255) as u8;
        d[3] = s[3];
    }
    let k = size as f32 / w.max(h) as f32;
    let paint = PixmapPaint { quality: FilterQuality::Bicubic, ..PixmapPaint::default() };
    out.draw_pixmap(0, 0, src.as_ref(), &paint, Transform::from_scale(k, k), None);
    Some(out)
}

impl Icons {
    pub fn new() -> Self {
        Self { index: None, cache: HashMap::new() }
    }

    pub fn for_class(&mut self, class: &str, size: u32) -> Option<&Pixmap> {
        let key = (class.to_lowercase(), size);
        if !self.cache.contains_key(&key) {
            let idx = self.index.get_or_insert_with(build_index);
            let c = &key.0;
            let name = idx
                .get(c)
                .or_else(|| idx.get(c.rsplit('.').next().unwrap_or(c)))
                .or_else(|| idx.get(c.split('-').next().unwrap_or(c)))
                .cloned()
                .unwrap_or_else(|| c.clone());
            let pm = find_icon(&name).and_then(|p| render_path(&p, size));
            if self.cache.len() > 64 {
                self.cache.clear();
            }
            self.cache.insert(key.clone(), pm);
        }
        self.cache.get(&key).and_then(|p| p.as_ref())
    }
}
