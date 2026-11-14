use std::fs;
use std::path::PathBuf;
use std::time::Instant;

pub struct Stats {
    prev_total: u64,
    prev_idle: u64,
    rc6: Option<PathBuf>,
    prev_rc6: Option<(u64, Instant)>,
    dgpu: Option<PathBuf>,
    pub cpu: i32,
    pub mem: i32,
    pub igpu: i32,
    pub dgpu_on: bool,
}

fn read(p: &std::path::Path) -> Option<String> {
    fs::read_to_string(p).ok()
}

fn cpu_times() -> Option<(u64, u64)> {
    let s = read("/proc/stat".as_ref())?;
    let line = s.lines().next()?;
    let v: Vec<u64> = line.split_whitespace().skip(1).filter_map(|x| x.parse().ok()).collect();
    let idle = v.get(3).copied()? + v.get(4).copied().unwrap_or(0);
    Some((v.iter().sum(), idle))
}

impl Stats {
    pub fn new() -> Self {
        let rc6 = fs::read_dir("/sys/class/drm").ok().and_then(|d| {
            d.filter_map(|e| e.ok())
                .map(|e| e.path().join("gt/gt0/rc6_residency_ms"))
                .find(|p| p.exists())
        });
        let dgpu = fs::read_dir("/sys/bus/pci/devices").ok().and_then(|d| {
            d.filter_map(|e| e.ok()).map(|e| e.path()).find(|p| {
                read(&p.join("vendor")).map(|v| v.trim() == "0x10de").unwrap_or(false)
                    && read(&p.join("class")).map(|c| c.trim().starts_with("0x0300")).unwrap_or(false)
            })
        });
        let (t, i) = cpu_times().unwrap_or((0, 0));
        Self { prev_total: t, prev_idle: i, rc6, prev_rc6: None, dgpu, cpu: -1, mem: -1, igpu: -1, dgpu_on: false }
    }

    pub fn sample(&mut self) {
        if let Some((t, i)) = cpu_times() {
            let dt = t.saturating_sub(self.prev_total);
            let di = i.saturating_sub(self.prev_idle);
            if let Some(v) = ((dt - di.min(dt)) * 100).checked_div(dt) {
                self.cpu = v as i32;
            }
            self.prev_total = t;
            self.prev_idle = i;
        }
        if let Some(s) = read("/proc/meminfo".as_ref()) {
            let mut total = 0u64;
            let mut avail = 0u64;
            for l in s.lines() {
                let mut it = l.split_whitespace();
                match (it.next(), it.next().and_then(|v| v.parse::<u64>().ok())) {
                    (Some("MemTotal:"), Some(v)) => total = v,
                    (Some("MemAvailable:"), Some(v)) => avail = v,
                    _ => {}
                }
            }
            if let Some(v) = ((total - avail.min(total)) * 100).checked_div(total) {
                self.mem = v as i32;
            }
        }
        if let Some(p) = &self.rc6
            && let Some(r) = read(p).and_then(|s| s.trim().parse::<u64>().ok()) {
                let now = Instant::now();
                if let Some((pr, pt)) = self.prev_rc6 {
                    let span = now.duration_since(pt).as_millis() as u64;
                    if let Some(idle) = (r.saturating_sub(pr) * 100).checked_div(span) {
                        self.igpu = (100 - idle.min(100) as i32).clamp(0, 100);
                    }
                }
                self.prev_rc6 = Some((r, now));
            }
        self.dgpu_on = self
            .dgpu
            .as_ref()
            .and_then(|p| read(&p.join("power/runtime_status")))
            .map(|s| s.trim() == "active")
            .unwrap_or(false);
    }

    pub fn gpu(&self) -> i32 {
        self.igpu
    }
}
