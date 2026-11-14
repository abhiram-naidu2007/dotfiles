use std::ffi::CString;
use std::io::BufReader;
use std::os::unix::net::UnixStream;
use std::sync::mpsc::{Receiver, Sender, channel};
use std::sync::{Mutex, OnceLock};
use std::time::Duration;

use pulseaudio::protocol::{self, ChannelVolume, Command, Prop, Volume as PaVolume};
use pulseaudio::protocol::port_info::PortAvailable;

use crate::model::{Dev, Stream};
use crate::services::{Msg, Volume, Waker};

type Conn = (BufReader<UnixStream>, u16, u32);

#[derive(Clone, Debug, Default, PartialEq)]
pub struct AudioState {
    pub out: Option<Volume>,
    pub mic: Option<Volume>,
    pub sinks: Vec<Dev>,
    pub sources: Vec<Dev>,
    pub streams: Vec<Stream>,
}

pub enum Ctl {
    Step(f32),
    Set(f32),
    ToggleMute,
    MicSet(f32),
    MicMute,
    StreamSet(u32, f32),
    StreamMute(u32),
    DefaultSink(String),
    DefaultSource(String),
}

static CTL: OnceLock<Mutex<Sender<Ctl>>> = OnceLock::new();

pub fn control(c: Ctl) {
    if let Some(tx) = CTL.get().and_then(|m| m.lock().ok()) {
        let _ = tx.send(c);
    }
}

type Res<T> = Result<T, Box<dyn std::error::Error>>;

fn connect(name: &str) -> Res<Conn> {
    let path = pulseaudio::socket_path_from_env().ok_or("no audio server")?;
    let mut sock = BufReader::new(UnixStream::connect(path)?);
    let cookie = pulseaudio::cookie_path_from_env().and_then(|p| std::fs::read(p).ok()).unwrap_or_default();
    let auth = protocol::AuthParams { version: protocol::MAX_VERSION, supports_shm: false, supports_memfd: false, cookie };
    protocol::write_command_message(sock.get_mut(), 0, &Command::Auth(auth), protocol::MAX_VERSION)?;
    let (_, reply) = protocol::read_reply_message::<protocol::AuthReply>(&mut sock, protocol::MAX_VERSION)?;
    let ver = protocol::MAX_VERSION.min(reply.version);
    let mut props = protocol::Props::new();
    props.set(Prop::ApplicationName, CString::new(name)?);
    protocol::write_command_message(sock.get_mut(), 1, &Command::SetClientName(props), ver)?;
    let _ = protocol::read_reply_message::<protocol::SetClientNameReply>(&mut sock, ver)?;
    Ok((sock, ver, 2))
}

fn ask<T: protocol::CommandReply>(c: &mut Conn, cmd: Command) -> Res<T> {
    let (sock, ver, seq) = c;
    protocol::write_command_message(sock.get_mut(), *seq, &cmd, *ver)?;
    *seq += 1;
    let (_, r) = protocol::read_reply_message::<T>(sock, *ver)?;
    Ok(r)
}

fn ack(c: &mut Conn, cmd: Command) -> Res<()> {
    let (sock, ver, seq) = c;
    protocol::write_command_message(sock.get_mut(), *seq, &cmd, *ver)?;
    *seq += 1;
    protocol::read_ack_message(sock)?;
    Ok(())
}

fn level(cv: &ChannelVolume) -> f32 {
    let max = cv.channels().iter().map(|v| v.as_u32()).max().unwrap_or(0);
    max as f32 / PaVolume::NORM.as_u32() as f32
}

fn cvol(n: usize, v: f32) -> ChannelVolume {
    let raw = (v.max(0.0) * PaVolume::NORM.as_u32() as f32).round() as u32;
    let mut cv = ChannelVolume::empty();
    for _ in 0..n.max(1) {
        cv.push(PaVolume::from_u32_clamped(raw));
    }
    cv
}

fn label(desc: &Option<CString>, name: &CString) -> String {
    let d = desc.as_ref().map(|d| d.to_string_lossy().into_owned()).unwrap_or_else(|| name.to_string_lossy().into_owned());
    match d.find("cAVS ") {
        Some(i) => d[i + 5..].to_owned(),
        None => d,
    }
}

fn prop(p: &protocol::Props, k: Prop) -> String {
    p.get(k).map(|b| String::from_utf8_lossy(b).trim_end_matches('\0').to_owned()).unwrap_or_default()
}

fn full(c: &mut Conn) -> Res<AudioState> {
    let info: protocol::ServerInfo = ask(c, Command::GetServerInfo)?;
    let dsink = info.default_sink_name.map(|s| s.to_string_lossy().into_owned()).unwrap_or_default();
    let dsrc = info.default_source_name.map(|s| s.to_string_lossy().into_owned()).unwrap_or_default();
    let sinks: protocol::SinkInfoList = ask(c, Command::GetSinkInfoList)?;
    let sources: protocol::SourceInfoList = ask(c, Command::GetSourceInfoList)?;
    let inputs: protocol::SinkInputInfoList = ask(c, Command::GetSinkInputInfoList)?;
    let mut st = AudioState::default();
    for s in &sinks {
        let name = s.name.to_string_lossy().into_owned();
        let is_def = name == dsink;
        if is_def {
            st.out = Some(Volume { level: level(&s.cvolume), muted: s.muted });
        }
        let gone = s.ports.get(s.active_port).map(|p| p.available == PortAvailable::No).unwrap_or(false);
        if !gone || is_def {
            st.sinks.push(Dev { name, label: label(&s.description, &s.name), default: is_def });
        }
    }
    for s in &sources {
        let name = s.name.to_string_lossy().into_owned();
        if name.ends_with(".monitor") {
            continue;
        }
        let is_def = name == dsrc;
        if is_def {
            st.mic = Some(Volume { level: level(&s.cvolume), muted: s.muted });
        }
        let gone = s.ports.get(s.active_port).map(|p| p.available == PortAvailable::No).unwrap_or(false);
        if !gone || is_def {
            st.sources.push(Dev { name, label: label(&s.description, &s.name), default: is_def });
        }
    }
    for i in &inputs {
        let app = prop(&i.props, Prop::ApplicationName);
        let low = app.to_lowercase();
        if low.contains("cava") || low.contains("loka") || !i.has_volume {
            continue;
        }
        st.streams.push(Stream {
            index: i.index,
            app: if app.is_empty() { i.name.to_string_lossy().into_owned() } else { app },
            media: prop(&i.props, Prop::MediaName),
            level: level(&i.cvolume),
            muted: i.muted,
        });
    }
    Ok(st)
}

fn watch(w: &Waker) -> Res<()> {
    let mut q = connect("loka")?;
    let (mut ev, ver, _) = connect("loka-events")?;
    let mask = protocol::SubscriptionMask::SINK
        | protocol::SubscriptionMask::SOURCE
        | protocol::SubscriptionMask::SINK_INPUT
        | protocol::SubscriptionMask::SERVER;
    protocol::write_command_message(ev.get_mut(), 2, &Command::Subscribe(mask), ver)?;
    protocol::read_ack_message(&mut ev)?;
    let mut last = full(&mut q)?;
    w.send(Msg::Audio(last.clone()));
    loop {
        let _ = protocol::read_command_message(&mut ev, ver)?;
        let now = full(&mut q)?;
        if now != last {
            last = now.clone();
            w.send(Msg::Audio(now));
        }
    }
}

fn default_sink(c: &mut Conn) -> Res<protocol::SinkInfo> {
    let info: protocol::ServerInfo = ask(c, Command::GetServerInfo)?;
    let name = info.default_sink_name.ok_or("no default sink")?;
    ask(c, Command::GetSinkInfo(protocol::GetSinkInfo { index: None, name: Some(name) }))
}

fn default_source(c: &mut Conn) -> Res<protocol::SourceInfo> {
    let info: protocol::ServerInfo = ask(c, Command::GetServerInfo)?;
    let name = info.default_source_name.ok_or("no default source")?;
    ask(c, Command::GetSourceInfo(protocol::GetSourceInfo { index: None, name: Some(name) }))
}

fn apply(c: &mut Conn, cmd: Ctl) -> Res<()> {
    match cmd {
        Ctl::Step(d) => {
            let s = default_sink(c)?;
            let v = (level(&s.cvolume) + d).clamp(0.0, 1.0);
            if s.muted {
                ack(c, Command::SetSinkMute(protocol::SetDeviceMuteParams { device_index: Some(s.index), device_name: None, mute: false }))?;
            }
            ack(c, Command::SetSinkVolume(protocol::SetDeviceVolumeParams { device_index: Some(s.index), device_name: None, volume: cvol(s.cvolume.channels().len(), v) }))
        }
        Ctl::Set(v) => {
            let s = default_sink(c)?;
            if s.muted {
                ack(c, Command::SetSinkMute(protocol::SetDeviceMuteParams { device_index: Some(s.index), device_name: None, mute: false }))?;
            }
            ack(c, Command::SetSinkVolume(protocol::SetDeviceVolumeParams { device_index: Some(s.index), device_name: None, volume: cvol(s.cvolume.channels().len(), v.clamp(0.0, 1.0)) }))
        }
        Ctl::ToggleMute => {
            let s = default_sink(c)?;
            ack(c, Command::SetSinkMute(protocol::SetDeviceMuteParams { device_index: Some(s.index), device_name: None, mute: !s.muted }))
        }
        Ctl::MicSet(v) => {
            let s = default_source(c)?;
            if s.muted {
                ack(c, Command::SetSourceMute(protocol::SetDeviceMuteParams { device_index: Some(s.index), device_name: None, mute: false }))?;
            }
            ack(c, Command::SetSourceVolume(protocol::SetDeviceVolumeParams { device_index: Some(s.index), device_name: None, volume: cvol(s.cvolume.channels().len(), v.clamp(0.0, 1.0)) }))
        }
        Ctl::MicMute => {
            let s = default_source(c)?;
            ack(c, Command::SetSourceMute(protocol::SetDeviceMuteParams { device_index: Some(s.index), device_name: None, mute: !s.muted }))
        }
        Ctl::StreamSet(i, v) => {
            let info: protocol::SinkInputInfo = ask(c, Command::GetSinkInputInfo(i))?;
            if info.muted {
                ack(c, Command::SetSinkInputMute(protocol::SetStreamMuteParams { index: i, mute: false }))?;
            }
            ack(c, Command::SetSinkInputVolume(protocol::SetStreamVolumeParams { index: i, volume: cvol(info.cvolume.channels().len(), v.clamp(0.0, 1.5)) }))
        }
        Ctl::StreamMute(i) => {
            let info: protocol::SinkInputInfo = ask(c, Command::GetSinkInputInfo(i))?;
            ack(c, Command::SetSinkInputMute(protocol::SetStreamMuteParams { index: i, mute: !info.muted }))
        }
        Ctl::DefaultSink(n) => ack(c, Command::SetDefaultSink(CString::new(n)?)),
        Ctl::DefaultSource(n) => ack(c, Command::SetDefaultSource(CString::new(n)?)),
    }
}

fn controller(rx: Receiver<Ctl>) {
    let mut conn: Option<Conn> = None;
    while let Ok(mut cmd) = rx.recv() {
        while let Ok(next) = rx.try_recv() {
            let same = matches!((&cmd, &next), (Ctl::Set(_), Ctl::Set(_)) | (Ctl::MicSet(_), Ctl::MicSet(_)))
                || matches!((&cmd, &next), (Ctl::StreamSet(a, _), Ctl::StreamSet(b, _)) if a == b);
            if same {
                cmd = next;
            } else {
                if conn.is_none() {
                    conn = connect("loka-control").ok();
                }
                if let Some(c) = conn.as_mut()
                    && apply(c, cmd).is_err() {
                        conn = None;
                    }
                cmd = next;
            }
        }
        if conn.is_none() {
            conn = connect("loka-control").ok();
        }
        if let Some(c) = conn.as_mut()
            && apply(c, cmd).is_err() {
                conn = None;
            }
    }
}

pub fn start(w: Waker) {
    let (tx, rx) = channel();
    let _ = CTL.set(Mutex::new(tx));
    let _ = std::thread::Builder::new().name("loka-audio-ctl".into()).stack_size(256 * 1024).spawn(move || controller(rx));
    let _ = std::thread::Builder::new().name("loka-audio".into()).stack_size(512 * 1024).spawn(move || {
        loop {
            let _ = watch(&w);
            std::thread::sleep(Duration::from_secs(2));
        }
    });
}
