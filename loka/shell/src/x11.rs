use std::error::Error;
use std::os::fd::OwnedFd;

use rustix::mm::{MapFlags, ProtFlags};
use tiny_skia::Pixmap;
use x11rb::connection::{Connection, RequestConnection};
use x11rb::protocol::Event;
use x11rb::protocol::shape::{self, ConnectionExt as _};
use x11rb::protocol::shm::{self, ConnectionExt as _};
use x11rb::protocol::xproto::{
    AtomEnum, ClipOrdering, ColormapAlloc, ConnectionExt as _, CreateGCAux, CreateWindowAux, EventMask, ImageFormat,
    PropMode, Rectangle, VisualClass, Visualid, Window, WindowClass,
};
use x11rb::rust_connection::RustConnection;
use x11rb::wrapper::ConnectionExt as _;

use crate::canvas::IRect;

pub type Result<T> = std::result::Result<T, Box<dyn Error>>;

x11rb::atom_manager! {
    pub Atoms: AtomsCookie {
        _NET_WM_WINDOW_TYPE,
        _NET_WM_WINDOW_TYPE_DOCK,
        _NET_WM_NAME,
        UTF8_STRING,
    }
}

pub struct Display {
    pub conn: RustConnection,
    keymap: Vec<u32>,
    per: u8,
    min_kc: u8,
    screen: usize,
    visual: Visualid,
    colormap: u32,
    atoms: Atoms,
}

pub struct Surface {
    pub win: Window,
    gc: u32,
    seg: shm::Seg,
    map: *mut u8,
    len: usize,
    pub width: u16,
    pub height: u16,
    pub pixmap: Pixmap,
    _fd: OwnedFd,
}

impl Display {
    pub fn connect() -> Result<Self> {
        let (conn, screen) = x11rb::connect(None)?;
        if conn.extension_information(shm::X11_EXTENSION_NAME)?.is_none() {
            return Err("X server lacks MIT-SHM".into());
        }
        let root = conn.setup().roots[screen].root;
        let visual = conn.setup().roots[screen]
            .allowed_depths
            .iter()
            .filter(|d| d.depth == 32)
            .flat_map(|d| d.visuals.iter())
            .find(|v| v.class == VisualClass::TRUE_COLOR)
            .map(|v| v.visual_id)
            .ok_or("no 32-bit TrueColor visual")?;
        let colormap = conn.generate_id()?;
        conn.create_colormap(ColormapAlloc::NONE, colormap, root, visual)?;
        let atoms = Atoms::new(&conn)?.reply()?;
        let (min_kc, max_kc) = (conn.setup().min_keycode, conn.setup().max_keycode);
        let km = conn.get_keyboard_mapping(min_kc, max_kc - min_kc + 1)?.reply()?;
        Ok(Self { conn, screen, visual, colormap, atoms, keymap: km.keysyms, per: km.keysyms_per_keycode, min_kc })
    }

    pub fn screen_size(&self) -> (u16, u16) {
        let s = &self.conn.setup().roots[self.screen];
        (s.width_in_pixels, s.height_in_pixels)
    }

    pub fn create_surface(&self, x: i16, y: i16, width: u16, height: u16, class: &str) -> Result<Surface> {
        let root = self.conn.setup().roots[self.screen].root;
        let win = self.conn.generate_id()?;
        let aux = CreateWindowAux::new()
            .override_redirect(1)
            .colormap(self.colormap)
            .border_pixel(0)
            .background_pixel(0)
            .event_mask(
                EventMask::EXPOSURE
                    | EventMask::KEY_PRESS
                    | EventMask::BUTTON_PRESS
                    | EventMask::BUTTON_RELEASE
                    | EventMask::POINTER_MOTION
                    | EventMask::LEAVE_WINDOW,
            );
        self.conn
            .create_window(32, win, root, x, y, width, height, 0, WindowClass::INPUT_OUTPUT, self.visual, &aux)?;
        let wm_class = format!("{class}\0{class}\0");
        self.conn
            .change_property8(PropMode::REPLACE, win, AtomEnum::WM_CLASS, AtomEnum::STRING, wm_class.as_bytes())?;
        self.conn
            .change_property8(PropMode::REPLACE, win, self.atoms._NET_WM_NAME, self.atoms.UTF8_STRING, class.as_bytes())?;
        self.conn.change_property32(
            PropMode::REPLACE,
            win,
            self.atoms._NET_WM_WINDOW_TYPE,
            AtomEnum::ATOM,
            &[self.atoms._NET_WM_WINDOW_TYPE_DOCK],
        )?;
        let gc = self.conn.generate_id()?;
        self.conn.create_gc(gc, win, &CreateGCAux::new().graphics_exposures(0))?;

        let len = width as usize * height as usize * 4;
        let fd = rustix::fs::memfd_create("loka-surface", rustix::fs::MemfdFlags::CLOEXEC)?;
        rustix::fs::ftruncate(&fd, len as u64)?;
        let map = unsafe {
            rustix::mm::mmap(std::ptr::null_mut(), len, ProtFlags::READ | ProtFlags::WRITE, MapFlags::SHARED, &fd, 0)?
        } as *mut u8;
        let seg = self.conn.generate_id()?;
        let dup = rustix::io::fcntl_dupfd_cloexec(&fd, 3)?;
        self.conn.shm_attach_fd(seg, dup, false)?;
        let pixmap = Pixmap::new(width as u32, height as u32).ok_or("bad surface size")?;
        self.conn.map_window(win)?;
        self.conn.flush()?;
        Ok(Surface { win, gc, seg, map, len, width, height, pixmap, _fd: fd })
    }

    pub fn set_input_region(&self, s: &Surface, rects: &[IRect]) -> Result<()> {
        let r: Vec<Rectangle> = rects
            .iter()
            .map(|r| Rectangle { x: r.x as i16, y: r.y as i16, width: r.w as u16, height: r.h as u16 })
            .collect();
        self.conn
            .shape_rectangles(shape::SO::SET, shape::SK::INPUT, ClipOrdering::UNSORTED, s.win, 0, 0, &r)?;
        Ok(())
    }

    pub fn present(&self, s: &mut Surface, damage: IRect) -> Result<()> {
        let d = damage.clip(s.width as i32, s.height as i32);
        if d.w <= 0 || d.h <= 0 {
            return Ok(());
        }
        let stride = s.width as usize * 4;
        let src = s.pixmap.data();
        let dst = unsafe { std::slice::from_raw_parts_mut(s.map, s.len) };
        for row in d.y as usize..(d.y + d.h) as usize {
            let a = row * stride + d.x as usize * 4;
            let b = a + d.w as usize * 4;
            for (o, i) in dst[a..b].as_chunks_mut::<4>().0.iter_mut().zip(src[a..b].as_chunks::<4>().0.iter()) {
                o[0] = i[2];
                o[1] = i[1];
                o[2] = i[0];
                o[3] = i[3];
            }
        }
        self.conn.shm_put_image(
            s.win,
            s.gc,
            s.width,
            s.height,
            d.x as u16,
            d.y as u16,
            d.w as u16,
            d.h as u16,
            d.x as i16,
            d.y as i16,
            32,
            ImageFormat::Z_PIXMAP.into(),
            false,
            s.seg,
            0,
        )?;
        self.conn.flush()?;
        Ok(())
    }


    pub fn next_event(&self) -> Result<Option<Event>> {
        Ok(self.conn.poll_for_event()?)
    }
}

impl Drop for Surface {
    fn drop(&mut self) {
        unsafe {
            let _ = rustix::mm::munmap(self.map as *mut _, self.len);
        }
    }
}

impl Display {
    pub fn keysym(&self, keycode: u8, state: u16) -> u32 {
        let i = keycode.saturating_sub(self.min_kc) as usize * self.per as usize;
        let shift = state & 0x1 != 0;
        let lock = state & 0x2 != 0;
        let base = self.keymap.get(i).copied().unwrap_or(0);
        let shifted = self.keymap.get(i + 1).copied().filter(|k| *k != 0).unwrap_or(base);
        let letter = (0x61..=0x7a).contains(&base);
        if shift ^ (lock && letter) { shifted } else { base }
    }

    pub fn grab_keyboard(&self, s: &Surface) -> bool {
        use x11rb::protocol::xproto::{GrabMode, GrabStatus};
        match self.conn.grab_keyboard(false, s.win, x11rb::CURRENT_TIME, GrabMode::ASYNC, GrabMode::ASYNC) {
            Ok(c) => c.reply().map(|r| r.status == GrabStatus::SUCCESS).unwrap_or(false),
            Err(_) => false,
        }
    }

    pub fn ungrab_keyboard(&self) {
        let _ = self.conn.ungrab_keyboard(x11rb::CURRENT_TIME);
        let _ = self.conn.flush();
    }

    pub fn watch_clipboard(&self, s: &Surface) -> Result<()> {
        use x11rb::protocol::xfixes::{self, ConnectionExt as _, SelectionEventMask};
        self.conn.xfixes_query_version(5, 0)?.reply()?;
        let clip = self.conn.intern_atom(false, b"CLIPBOARD")?.reply()?.atom;
        self.conn.xfixes_select_selection_input(s.win, clip, SelectionEventMask::SET_SELECTION_OWNER)?;
        let _ = xfixes::X11_EXTENSION_NAME;
        Ok(())
    }
}

impl Display {
    pub fn grab_pointer(&self, s: &Surface) -> bool {
        use x11rb::protocol::xproto::{EventMask, GrabMode, GrabStatus};
        let mask = EventMask::BUTTON_PRESS | EventMask::BUTTON_RELEASE | EventMask::POINTER_MOTION;
        match self.conn.grab_pointer(true, s.win, mask, GrabMode::ASYNC, GrabMode::ASYNC, x11rb::NONE, x11rb::NONE, x11rb::CURRENT_TIME) {
            Ok(c) => c.reply().map(|r| r.status == GrabStatus::SUCCESS).unwrap_or(false),
            Err(_) => false,
        }
    }

    pub fn ungrab_pointer(&self) {
        let _ = self.conn.ungrab_pointer(x11rb::CURRENT_TIME);
        let _ = self.conn.flush();
    }

    pub fn destroy(&self, s: Surface) {
        let _ = self.conn.shm_detach(s.seg);
        let _ = self.conn.free_gc(s.gc);
        let _ = self.conn.destroy_window(s.win);
        let _ = self.conn.flush();
        drop(s);
    }

    pub fn watch_screen(&self) -> Result<()> {
        use x11rb::protocol::randr::{ConnectionExt as _, NotifyMask};
        let root = self.conn.setup().roots[self.screen].root;
        self.conn.randr_query_version(1, 5)?.reply()?;
        self.conn.randr_select_input(root, NotifyMask::SCREEN_CHANGE)?;
        Ok(())
    }

    pub fn current_size(&self) -> (u16, u16) {
        use x11rb::protocol::xproto::ConnectionExt as _;
        let root = self.conn.setup().roots[self.screen].root;
        self.conn
            .get_geometry(root)
            .ok()
            .and_then(|c| c.reply().ok())
            .map(|g| (g.width, g.height))
            .unwrap_or_else(|| self.screen_size())
    }

    pub fn move_window(&self, s: &Surface, x: i16, y: i16) {
        use x11rb::protocol::xproto::ConfigureWindowAux;
        let _ = self.conn.configure_window(s.win, &ConfigureWindowAux::new().x(x as i32).y(y as i32));
    }

    pub fn reload_keymap(&mut self) {
        use x11rb::protocol::xproto::ConnectionExt as _;
        let (min_kc, max_kc) = (self.conn.setup().min_keycode, self.conn.setup().max_keycode);
        if let Ok(Ok(km)) = self.conn.get_keyboard_mapping(min_kc, max_kc - min_kc + 1).map(|c| c.reply()) {
            self.keymap = km.keysyms;
            self.per = km.keysyms_per_keycode;
            self.min_kc = min_kc;
        }
    }
}

pub fn keysym_char(ks: u32) -> Option<char> {
    match ks {
        0x20..=0x7e | 0xa0..=0xff => char::from_u32(ks),
        0x0100_0000..=0x0110_ffff => char::from_u32(ks - 0x0100_0000),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::keysym_char;

    #[test]
    fn keysyms_map_to_chars() {
        assert_eq!(keysym_char(0x61), Some('a'));
        assert_eq!(keysym_char(0x41), Some('A'));
        assert_eq!(keysym_char(0xe9), Some('é'));
        assert_eq!(keysym_char(0x0100_0c05), Some('అ'));
        assert_eq!(keysym_char(0xff0d), None);
    }
}
