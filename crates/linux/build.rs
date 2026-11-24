use std::fmt::Write;

fn unescape(s: &str) -> String {
    s.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&apos;", "'").replace("&amp;", "&")
}

fn between<'a>(s: &'a str, a: &str, b: &str) -> Option<(&'a str, &'a str)> {
    let i = s.find(a)? + a.len();
    let j = s[i..].find(b)? + i;
    Some((&s[i..j], &s[j + b.len()..]))
}

/// Notification texts come from the "Notify" context of the app translations, one file per language.
fn notify_table() {
    let dir = std::path::Path::new("../../app/i18n");
    println!("cargo:rerun-if-changed={}", dir.display());
    let mut out = String::from("static NOTIFY: &[(&str, &[(&str, &str)])] = &[\n");
    let mut files: Vec<_> = std::fs::read_dir(dir).map(|d| d.flatten().map(|e| e.path()).collect()).unwrap_or_default();
    files.sort();
    for f in files {
        let name = f.file_name().and_then(|n| n.to_str()).unwrap_or("");
        let Some(code) = name.strip_prefix("pinna_").and_then(|n| n.strip_suffix(".ts")) else { continue };
        println!("cargo:rerun-if-changed={}", f.display());
        let text = std::fs::read_to_string(&f).unwrap_or_default();
        let Some(start) = text.find("<name>Notify</name>") else { continue };
        let block = &text[start..text[start..].find("</context>").map_or(text.len(), |e| start + e)];
        let _ = writeln!(out, "    ({code:?}, &[");
        for msg in block.split("<message>").skip(1) {
            let src = between(msg, "<source>", "</source>").map(|x| x.0);
            let tr = between(msg, "<translation>", "</translation>").map(|x| x.0);
            if let (Some(src), Some(tr)) = (src, tr)
                && !tr.is_empty()
            {
                let _ = writeln!(out, "        ({:?}, {:?}),", unescape(src), unescape(tr));
            }
        }
        out.push_str("    ]),\n");
    }
    out.push_str("];\n");
    let dest = std::path::Path::new(&std::env::var("OUT_DIR").unwrap()).join("notify.rs");
    std::fs::write(dest, out).unwrap();
}

fn main() {
    notify_table();
    println!("cargo:rerun-if-changed=csrc/eld.c");
    let lib = pkg_config::probe_library("libavcodec").expect("libavcodec not found (install libavcodec-dev)");
    pkg_config::probe_library("libavutil").expect("libavutil not found");
    let mut b = cc::Build::new();
    b.file("csrc/eld.c").warnings(true);
    for p in lib.include_paths {
        b.include(p);
    }
    b.compile("pinna_eld");
}
