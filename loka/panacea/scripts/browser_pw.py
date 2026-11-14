#!/usr/bin/env python3

import base64
import glob
import json
import os
import sys

HOME = os.path.expanduser("~")

def log(*a):
    print(*a, file=sys.stderr)

import ctypes as C

class NSS:
    def __init__(self):
        self.lib = None
        for name in ("libnss3.so", "libnss3.dylib", "nss3.dll"):
            try:
                self.lib = C.CDLL(name)
                break
            except OSError:
                continue
        if not self.lib:
            raise OSError("libnss3 not found")

    def init(self, profile):
        self.lib.NSS_Init.argtypes = [C.c_char_p]
        if self.lib.NSS_Init(profile.encode()) != 0:
            raise OSError("NSS_Init failed for " + profile)

    def shutdown(self):
        try:
            self.lib.NSS_Shutdown()
        except Exception:
            pass

    def decrypt(self, b64):
        class SECItem(C.Structure):
            _fields_ = [("type", C.c_uint),
                        ("data", C.c_char_p),
                        ("len", C.c_uint)]

        raw = base64.b64decode(b64)
        inp = SECItem(0, raw, len(raw))
        out = SECItem(0, None, 0)
        self.lib.PK11SDR_Decrypt.argtypes = [C.POINTER(SECItem),
                                             C.POINTER(SECItem), C.c_void_p]
        if self.lib.PK11SDR_Decrypt(C.byref(inp), C.byref(out), None) != 0:
            return None
        return C.string_at(out.data, out.len).decode("utf-8", "replace")

def firefox_profiles():
    xdg = os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config"))
    roots = [
        os.path.join(HOME, ".mozilla", "firefox"),
        os.path.join(xdg, "mozilla", "firefox"),
        os.path.join(HOME, ".librewolf"),
        os.path.join(xdg, "librewolf"),
        os.path.join(HOME, ".floorp"),
        os.path.join(HOME, ".zen"),
        os.path.join(HOME, ".var", "app", "org.mozilla.firefox",
                     ".mozilla", "firefox"),
    ]
    profiles = []
    for root in roots:
        for logins in glob.glob(os.path.join(root, "*", "logins.json")):
            profiles.append(os.path.dirname(logins))
    return profiles

def collect_firefox():
    out = []
    profiles = firefox_profiles()
    if not profiles:
        return out
    try:
        nss = NSS()
    except OSError as e:
        log("firefox:", e)
        return out

    for prof in profiles:
        try:
            with open(os.path.join(prof, "logins.json")) as f:
                data = json.load(f)
        except Exception:
            continue
        try:
            nss.init(prof)
        except OSError as e:
            log("firefox:", e)
            continue
        name = os.path.basename(prof)
        for item in data.get("logins", []):
            host = item.get("hostname", "") or ""
            if not host.startswith(("http://", "https://")):
                continue
            user = nss.decrypt(item.get("encryptedUsername", ""))
            pw = nss.decrypt(item.get("encryptedPassword", ""))
            if pw is None:
                continue
            out.append({
                "url": item.get("hostname", ""),
                "login": user or "",
                "pw": pw,
                "browser": "Firefox (%s)" % name,
            })
        nss.shutdown()
    return out

def chromium_key(secret_label_app):
    try:
        import secretstorage
    except Exception as e:
        log("chromium: python-secretstorage missing:", e)
        return None
    try:
        from hashlib import pbkdf2_hmac
        bus = secretstorage.dbus_init()
        password = None
        for coll in secretstorage.get_all_collections(bus):
            try:
                if coll.is_locked():
                    coll.unlock()
            except Exception:
                pass
            for item in coll.get_all_items():
                if item.get_label() == secret_label_app + " Safe Storage":
                    password = item.get_secret()
                    break
            if password is not None:
                break
        if password is None:
            password = b"peanuts"
        return pbkdf2_hmac("sha1", password, b"saltysalt", 1, 16)
    except Exception as e:
        log("chromium: keyring error:", e)
        return None

def chromium_decrypt(blob, key):
    if not blob:
        return ""
    try:
        if blob[:3] in (b"v10", b"v11"):
            from cryptography.hazmat.primitives.ciphers.aead import AESGCM
            nonce = blob[3:15]
            ct = blob[15:]
            return AESGCM(key).decrypt(nonce, ct, None).decode(
                "utf-8", "replace")
    except Exception as e:
        log("chromium: decrypt:", e)
    return None

CHROMIUM_ROOTS = [
    (".config/google-chrome", "Chrome", "Chrome"),
    (".config/chromium", "Chromium", "Chromium"),
    (".config/BraveSoftware/Brave-Browser", "Brave", "Brave"),
    (".config/vivaldi", "Vivaldi", "Vivaldi"),
    (".config/microsoft-edge", "Edge", "Microsoft Edge"),
]

def collect_chromium():
    import sqlite3
    import shutil
    import tempfile
    out = []
    for rel, name, secret_app in CHROMIUM_ROOTS:
        root = os.path.join(HOME, rel)
        if not os.path.isdir(root):
            continue
        key = chromium_key(secret_app)
        if key is None:
            continue
        for db in glob.glob(os.path.join(root, "*", "Login Data")):
            tmp = tempfile.mktemp(suffix=".db")
            try:
                shutil.copyfile(db, tmp)
                con = sqlite3.connect(tmp)
                rows = con.execute(
                    "SELECT origin_url, username_value, password_value "
                    "FROM logins").fetchall()
                con.close()
            except Exception as e:
                log("chromium:", e)
                continue
            finally:
                try:
                    os.unlink(tmp)
                except OSError:
                    pass
            prof = os.path.basename(os.path.dirname(db))
            for url, user, enc in rows:
                if not (url or "").startswith(("http://", "https://")):
                    continue
                pw = chromium_decrypt(enc, key)
                if pw is None or pw == "":
                    continue
                out.append({
                    "url": url or "",
                    "login": user or "",
                    "pw": pw,
                    "browser": "%s (%s)" % (name, prof),
                })
    return out

def main():
    found = []
    try:
        found += collect_firefox()
    except Exception as e:
        log("firefox failed:", e)
    try:
        found += collect_chromium()
    except Exception as e:
        log("chromium failed:", e)

    seen = set()
    uniq = []
    for e in found:
        k = (e["url"], e["login"], e["pw"])
        if k in seen:
            continue
        seen.add(k)
        uniq.append(e)

    json.dump(uniq, sys.stdout, ensure_ascii=False)

if __name__ == "__main__":
    main()
