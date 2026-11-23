fn main() {
    println!("cargo:rerun-if-changed=csrc/eld.c");
    let lib = pkg_config::probe_library("libavcodec").expect("libavcodec bulunamadı (libavcodec-dev kurulu olmalı)");
    pkg_config::probe_library("libavutil").expect("libavutil bulunamadı");
    let mut b = cc::Build::new();
    b.file("csrc/eld.c").warnings(true);
    for p in lib.include_paths {
        b.include(p);
    }
    b.compile("pinna_eld");
}
