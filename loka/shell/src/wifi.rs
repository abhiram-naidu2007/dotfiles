use std::collections::HashSet;
use std::process::{Command, Stdio};

use crate::model::Net;

fn nmcli(args: &[&str]) -> Option<String> {
    let o = Command::new("nmcli").args(args).stdin(Stdio::null()).stderr(Stdio::null()).output().ok()?;
    o.status.success().then(|| String::from_utf8_lossy(&o.stdout).into_owned())
}

fn fields(line: &str) -> Vec<String> {
    let mut out = vec![String::new()];
    let mut it = line.chars();
    while let Some(c) = it.next() {
        match c {
            '\\' => out.last_mut().unwrap().extend(it.next()),
            ':' => out.push(String::new()),
            c => out.last_mut().unwrap().push(c),
        }
    }
    out
}

fn parse(scan: &str, known: &HashSet<String>) -> Vec<Net> {
    let mut nets: Vec<Net> = Vec::new();
    for l in scan.lines() {
        let f = fields(l);
        let [in_use, ssid, sec, signal] = f.as_slice() else { continue };
        if ssid.is_empty() || ssid == "--" {
            continue;
        }
        let connected = in_use == "*";
        let security = match sec.as_str() {
            "" | "--" => "open",
            s if s.contains("802.1X") || s.contains("EAP") => "eap",
            _ => "psk",
        };
        let strength = signal.parse().unwrap_or(0);
        match nets.iter_mut().find(|n| n.ssid == *ssid) {
            Some(n) => {
                if connected || (!n.connected && strength > n.strength) {
                    n.strength = strength;
                    n.security = security;
                }
                n.connected |= connected;
                n.known |= connected;
            }
            None => nets.push(Net { ssid: ssid.clone(), security, strength, known: connected || known.contains(ssid), connected }),
        }
    }
    nets.sort_by_key(|n| (!n.connected, !n.known, -n.strength));
    nets
}

pub fn list() -> Vec<Net> {
    let known = nmcli(&["-t", "-f", "NAME,TYPE", "connection", "show"])
        .unwrap_or_default()
        .lines()
        .map(fields)
        .filter(|f| f.get(1).is_some_and(|t| t == "802-11-wireless"))
        .map(|mut f| f.swap_remove(0))
        .collect();
    parse(&nmcli(&["-t", "-f", "IN-USE,SSID,SECURITY,SIGNAL", "dev", "wifi", "list", "--rescan", "no"]).unwrap_or_default(), &known)
}

pub fn scan() {
    nmcli(&["dev", "wifi", "rescan"]);
}

pub fn connect(ssid: &str, password: Option<&str>) -> bool {
    match password {
        Some(pw) => nmcli(&["dev", "wifi", "connect", ssid, "password", pw]),
        None => nmcli(&["connection", "up", "id", ssid]).or_else(|| nmcli(&["dev", "wifi", "connect", ssid])),
    }
    .is_some()
}

pub fn disconnect() {
    let devs = nmcli(&["-t", "-f", "DEVICE,TYPE", "dev", "status"]).unwrap_or_default();
    if let Some(dev) = devs.lines().map(fields).find(|f| f.get(1).is_some_and(|t| t == "wifi")) {
        nmcli(&["dev", "disconnect", &dev[0]]);
    }
}

pub fn forget(ssid: &str) {
    nmcli(&["connection", "delete", "id", ssid]);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn escaped_fields_split() {
        assert_eq!(fields(r"*:a\:b\\c:WPA2:59"), ["*", r"a:b\c", "WPA2", "59"]);
        assert_eq!(fields(" :::30"), [" ", "", "", "30"]);
    }

    #[test]
    fn scan_merges_sorts_and_classifies() {
        let known = HashSet::from(["home".to_owned()]);
        let n = parse(" :cafe::40\n :home:WPA2:30\n :home:WPA2:70\n*:corp:WPA2 802.1X:20\n :--:WPA2:90\n", &known);
        let row = |i: usize| (n[i].ssid.as_str(), n[i].security, n[i].strength, n[i].known, n[i].connected);
        assert_eq!(n.len(), 3);
        assert_eq!(row(0), ("corp", "eap", 20, true, true));
        assert_eq!(row(1), ("home", "psk", 70, true, false));
        assert_eq!(row(2), ("cafe", "open", 40, false, false));
    }
}
