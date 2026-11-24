# Security

Pinna holds the keys your headphones hand over and runs a service on your session bus, so security problems matter. Please don't report them in a public issue.

Use [Report a vulnerability](https://github.com/saiv0n/pinna/security/advisories/new) on GitHub instead. I'll answer within a few days, and once a fix is out the advisory is published with credit to you, unless you'd rather not be named.

Only the latest commit on `main` is supported for now.

## What Pinna does to stay safe

- `pinnad` runs as a user service under systemd with a tight sandbox: no network access, and it can write only to its own config, state and runtime folders plus one WirePlumber config folder.
- The keys are stored with 0600 permissions and are never written to logs.
- Every value that arrives over D-Bus is checked before it reaches the headphones; there is no raw packet method in release builds.
- The app never asks for your password itself. The one optional change to system files, the DeviceID line, shows the exact command and runs it through `pkexec`.
