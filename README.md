# AACstats.tech Addon

Place this folder (named `AACstats`) in your ArcheAge Classic `Addon` directory
and add `AACstats` to `Addon/addons.txt`.

> The folder must be named `AACstats` (no dot) — a `.` is a Lua module-path
> separator and would break `require()`/file paths. The display name is
> `AACstats.tech`.

Tracking runs **silently**: no on-screen window is shown — on load you'll see a
single chat line, `AACstats.tech tracking started`.

The addon writes local JSONL session logs to:

```text
Addon/AACstats/logs/session_<id>.jsonl
```

Upload those files at AACstats.tech. The addon contains no API keys, database
credentials, or login details.

Current capture coverage:

- session start/end
- combat message raw records with best-effort parsed fields
- target snapshots with best-effort class/gearscore
- gear snapshots at session start and every 30 minutes (numeric gear score + per-slot equipment)
- raid state snapshots every 5 minutes (members with name/class/level/gearScore/expedition)
- player buff applied/removed events every 5 seconds
- **gold balance every 15 minutes** (carried + bank) → website Economy tab
- **guild (expedition) detection** on load and every 4 hours

Some fields are best-effort because ArcheAge Classic addon API availability
depends on what is exposed during gameplay and current target/raid state.
