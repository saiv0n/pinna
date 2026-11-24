# Contributing

Thanks for wanting to help. Bug reports, reports from headphones I don't own, translations and code are all welcome.

## Reporting a bug

Open an issue with the bug template. The most useful thing you can attach is the exported log: This Computer, Export. It starts with the `pinnactl doctor` output and already leaves out serial numbers, the headphone name and the device part of Bluetooth addresses, so it is safe to post.

## Reporting your headphones

Pinna is tested on AirPods Pro 2. If you have another model, the "Headphones report" issue template asks for the few things that tell me whether your model works: which settings show up, which ones do something, and the exported log. Even "everything works" is worth a report, it moves the model up in the README table.

If you want to go further, a debug log while you change settings shows the raw packets:

```bash
systemctl --user stop pinnad
RUST_LOG=debug pinnad 2>&1 | tee pinnad.log
systemctl --user start pinnad
```

Keys and serial numbers are hidden in this log too, but look it over before you post it.

## Building

See [Install](README.md#install) for the dependencies. For a development build:

```bash
cargo build --release
cmake -S app -B app/build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build app/build
```

You don't need headphones for most work. `PINNA_FAKE=1` runs a daemon with pretend AirPods next to the real one, and `pro3`, `max`, `airpods4` or `airpods2` pretend to be those models. The README has the exact commands under [Developing without headphones](README.md#developing-without-headphones).

## Before you open a pull request

```bash
scripts/check.sh
scripts/e2e.sh
```

`check.sh` runs the tests and clippy, then renders every page with every fixture in both themes and languages; any QML warning fails it. `e2e.sh` runs pretend headphones and a pretend media player on a private bus and checks the behaviour end to end. CI runs the Rust part on every push.

A few things I care about:

- Keep a pull request to one change. Small ones get merged fast.
- Settings that can only be checked on a real device go in as experimental and off by default, and the pull request says what you tested it on.
- Comments explain why, not what.
- New text in the app goes through `qsTr`, and `app/i18n/update.py` adds it to the translation files. Turkish must stay complete; if you don't speak it, say so and I'll translate.
- Nothing personal in fixtures or tests: no real names, serials or addresses.
- Commit messages are short and lowercase, like the existing history.

## Translations

Each language is one file. To add one:

```bash
app/i18n/update.py de
```

Then translate `app/i18n/pinna_de.ts` in Qt Linguist or any text editor and rebuild. It shows up on the This Computer page by itself.

## Protocol work

`crates/core` has no OS code and is where the protocol lives: `aap.rs` for the connection packets, `proximity.rs` for the BLE adverts and `state.rs` for the settings table. A new setting usually means one line in the table, a parser test with a captured packet and a row in the app. If you find a packet nobody has documented yet, an issue with the capture and what you did on the headphones is already a big help.
