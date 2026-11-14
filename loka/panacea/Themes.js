.pragma library

var list = [
    { id: "nothing",  name: "Nothing",     bg: "#000000", fg: "#ffffff", on: "#ffffff", ok: "#ffffff", crit: "#d71921" },
    { id: "meridian", name: "Meridian",    bg: "#000000", fg: "#eceff4", on: "#eceff4", ok: "#eceff4", crit: "#d71921", world: true, line: "Lighthouse, black sea, dot clock", fonts: ["JetBrainsMono Nerd Font", "Inter Tight", "Inter Display"] },
    { id: "sakuga",   name: "Sakuga",      bg: "#0a0b10", fg: "#f4f6fa", on: "#e23a42", ok: "#f4f6fa", crit: "#ff4d57", world: true, line: "Key frames, sky blue, ink red", fonts: ["Inter Tight", "Inter Tight", "Inter Display"] },
    { id: "katha",    name: "Katha",       bg: "#0e1440", fg: "#f6ebd3", on: "#e8b04a", ok: "#f28fb0", crit: "#e2553f", world: true, line: "Tirumala hill, lamps, Pichwai night", fonts: ["Anek Telugu", "Anek Telugu", "Ramaraja"] },
    { id: "toon",     name: "Toon",        bg: "#2a2244", fg: "#fff5e4", on: "#ffd45c", ok: "#8ee3c8", crit: "#ff7a8a", world: true, line: "Soft round type, evening snow walk", fonts: ["Rounded Mplus 1c", "Rounded Mplus 1c", "Rounded Mplus 1c"] }
];

function worlds() {
    return list.filter(function (t) { return t.world === true; });
}

function of(id) {
    for (var i = 0; i < list.length; i++)
        if (list[i].id === id) return list[i];
    return list[0];
}
