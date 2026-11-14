mod anim;
mod app;
mod audio;
mod bar;
mod canvas;
mod config;
mod dot;
mod i3;
mod icons;
mod ipc;
mod island;
mod menu;
mod model;
mod mpris;
mod notify;
mod pages;
mod services;
mod stats;
mod text;
mod theme;
mod tray;
mod ui;
mod walls;
mod watch;
mod x11;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.get(1).map(|s| s.as_str()) == Some("msg") {
        let msg = args[2..].join(" ");
        match ipc::send(&msg) {
            Ok(_) => std::process::exit(0),
            Err(e) => {
                eprintln!("loka: {e}");
                std::process::exit(1);
            }
        }
    }
    if let Err(e) = app::run() {
        eprintln!("loka: {e}");
        std::process::exit(1);
    }
}
