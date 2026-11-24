#!/usr/bin/env python3
"""Turns Cargo.lock into flatpak-builder sources so the build needs no network."""
import json
import sys
import tomllib

lock = tomllib.load(open(sys.argv[1] if len(sys.argv) > 1 else "Cargo.lock", "rb"))
out = []
for p in lock["package"]:
    if not p.get("source", "").startswith("registry+"):
        continue
    name, ver, sha = p["name"], p["version"], p["checksum"]
    dest = f"cargo/vendor/{name}-{ver}"
    out.append({"type": "archive", "archive-type": "tar-gzip",
                "url": f"https://static.crates.io/crates/{name}/{name}-{ver}.crate",
                "sha256": sha, "dest": dest})
    out.append({"type": "inline", "contents": json.dumps({"package": sha, "files": {}}),
                "dest": dest, "dest-filename": ".cargo-checksum.json"})
out.append({"type": "inline", "dest": "cargo", "dest-filename": "config",
            "contents": '[source.crates-io]\nreplace-with = "vendored-sources"\n\n'
                        '[source.vendored-sources]\ndirectory = "cargo/vendor"\n'})
json.dump(out, sys.stdout, indent=4)
print()
