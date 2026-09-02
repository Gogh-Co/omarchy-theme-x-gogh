# AGENTS.md

Guidance for AI coding agents working in this repo. This is an
[Omarchy](https://omarchy.org) plugin: a QML bar widget + fullscreen overlay
that lets a user browse [Gogh](https://github.com/Gogh-Co/Gogh)'s ~370
terminal color schemes and install/apply one as a real Omarchy theme.

## Source of truth vs. deployed copy

This repo (`~/Downloads/omarchy-theme-x-gogh/`) is the source of truth.
Omarchy loads plugins from `~/.config/omarchy/plugins/<manifest id>/`, so a
working install is a **copy** of this repo at
`~/.config/omarchy/plugins/mgldvd.gogh-themes/`. There is no symlink between
them. After editing anything here, mirror the change into the installed copy
before testing:

```bash
cp -r ~/Downloads/omarchy-theme-x-gogh/. ~/.config/omarchy/plugins/mgldvd.gogh-themes/
```

(or copy the single changed file both ways — whichever direction you edited
in). Verify the two are in sync before considering a change done:

```bash
diff -rq ~/.config/omarchy/plugins/mgldvd.gogh-themes/ ~/Downloads/omarchy-theme-x-gogh/ \
  --exclude=.git --exclude=LICENSE --exclude=LICENSE-APACHE --exclude=LICENSE-MIT \
  --exclude=logo --exclude=preview.png --exclude=AGENTS.md
```

(`logo/`, `preview.png`, `LICENSE*`, `AGENTS.md` are repo-only scaffolding —
they don't need to exist in the installed copy.)

## Layout

```
manifest.json          # id, kinds, entry points, license — id MUST match the dir name
BarWidget.qml           # bar icon (click = toggle overlay, middle-click = random theme)
Overlay.qml              # fullscreen picker: grid, search, filters, favorites/history, rotation panel
GoghThemeSearch.js       # search + variant-filter helpers used by Overlay.qml
bin/
  gogh-list-json.sh      # downloads + 24h-caches Gogh's themes.json, slims it for the picker
  gogh-theme-install     # theme_name -> colors.toml -> symlinks active wallpaper -> omarchy-theme-set
  gogh-to-toml.py        # one Gogh theme JSON object (stdin) -> Omarchy colors.toml (stdout)
  gogh-theme-pick        # terminal/menu fallback entry point
  gogh-theme-random      # picks random (favorites-first) theme, calls gogh-theme-install
  gogh-favorite-set / gogh-favorite-clear
  gogh-history-push
  gogh-rotation-set
  gogh-silent-set
  gogh-config-export / gogh-config-import   # config.json <-> ~/.config/gogh/config-gogh.yml
  gogh-config-to-yaml.py / gogh-config-from-yaml.py   # thin PyYAML wrappers, stdin -> stdout
```

Runtime state lives outside the repo, at
`${XDG_CONFIG_HOME:-~/.config}/gogh-themes/config.json` (favorites, rotation
settings, silent flag, recent history) and
`${XDG_CACHE_HOME:-~/.cache}/omarchy/gogh-themes/themes.json` (cached Gogh
catalog). Never commit either.

## Requirements

`curl`, `jq`, `python3` (already ship with Omarchy). YAML import/export needs
`python-yaml` (`pacman -S python-yaml`).

## Testing changes

There's no unit test suite — this is QML glued to shell scripts, verified by
running it for real.

1. After any edit, sync installed copy <-> repo (see above).
2. `omarchy plugin validate ~/.config/omarchy/plugins/mgldvd.gogh-themes` —
   must produce no output/errors.
3. `omarchy restart shell` — required after nearly every edit.
   `omarchy-shell shell rescanPlugins` is NOT reliable for `bar-widget`
   (Component cached by file URL) or `overlay` (mounted `Item` doesn't
   always rebuild despite `keepLoaded: true`).
4. Tail the log while restarting/interacting to catch QML errors:
   `qs log -p /usr/share/omarchy/shell -v`
5. Check for a bar-icon regression:
   `jq '.bar.layout.right' ~/.config/omarchy/shell.json` should still list
   `mgldvd.gogh-themes`. This entry flakily drops after `omarchy restart
   shell` for reasons never root-caused — the fix is always
   `omarchy bar move mgldvd.gogh-themes --section right`.
6. Test `bin/*` scripts standalone from a terminal first (fast feedback)
   before testing through the QML UI.
7. There is no way to inject a real mouse click in this environment (no
   `uinput` permission, no `ydotool`/`wlrctl`/`dotool`). To visually verify
   UI that's gated behind user interaction (e.g. the settings panel), use
   the **temp-test trick**: temporarily flip the relevant `property bool ...:
   false` to `true` at its declaration, comment out wherever `open()` resets
   it back to `false`, `omarchy restart shell`, open the overlay, `grim
   <path>.png` (or `grim -g "$(slurp)" <path>.png` for a region), inspect
   with the Read tool, then revert both temporary edits and restart again.
   `hyprctl dispatch 'hl.dsp.cursor.move({ x = X, y = Y })'` can move the
   cursor but does not reliably fire Qt hover/motion events, so it's not a
   substitute for a real click.

## Gotchas (all cost real debugging time — don't reintroduce them)

- **Plugin directory name must exactly equal `manifest.json`'s `id`.** A
  mismatch fails `overlay`/`panel`/`menu` entry points with a misleading Qt
  "File name case mismatch" warning followed by an unrelated
  `ReferenceError: errorString is not defined` inside Omarchy's own
  `shell.qml`. Not documented on `plugins.omarchy.org/develop.html`.
- **`StdioCollector.text` is a property; `FileView.text` is a function.**
  Using the wrong form for either fails silently — no error in `qs log`.
- **Every script that writes `config.json` must use a unique temp file**
  (`tmp=$(mktemp "$CONFIG_FILE.XXXXXX")`), never a fixed name like
  `config.json.tmp`. A single rotation tick fires two independent
  `Quickshell.execDetached` calls (`gogh-rotation-set` and
  `gogh-history-push`) that can race; a shared temp filename lets one
  process's write truncate another's mid-flight, corrupting the file.
  Confirmed clean under a 60-concurrent-writer stress test after the fix.
- **Never touch the user's actual wallpaper.** Gogh themes carry no
  background image. Leaving `backgrounds/` empty makes `omarchy-theme-set`
  fire its own "No background was found" notification but otherwise leaves
  the wallpaper alone — which is correct. `gogh-theme-install` silences that
  notification by symlinking whatever wallpaper is *currently active*
  (`readlink -f ~/.local/state/omarchy/current/background`) into the new
  theme's `backgrounds/` dir, so `omarchy-theme-set` "finds" a background
  that's already on screen. Do not generate, copy, or otherwise materialize
  a new image here — a solid-color placeholder PNG was tried once and it
  got adopted as the user's real wallpaper, which is exactly the failure
  this design avoids.
- **`omarchy-menu-input` has no default-value pre-fill.** It only takes a
  prompt string. Don't design flows that assume a suggested/prefilled
  answer — either hardcode a sensible default path and skip the prompt
  entirely (as `gogh-config-export` does now), or accept whatever the user
  types verbatim.
- **Astral Unicode literals (e.g. 🎨, outside the BMP) get corrupted** when
  written raw into QML source through file-editing tools — use the `"\u{...}"`
  escape form instead. BMP glyphs (★ ☆ ⚙, all ≤3-byte UTF-8) are safe to
  paste directly.
- **`omarchy-menu-select` option strings need 3 tab-separated fields**
  (`icon\tlabel\tsubtext`) — passing only 2 gets the first one consumed as
  the icon glyph, not the label.
- Applying a theme is slow (several seconds to ~20s on first use) almost
  entirely inside Omarchy's own `omarchy-theme-set` (parallel app retinting,
  hooks, selector-cache warmup) — this repo's own code (catalog lookup +
  `colors.toml` generation + wallpaper symlink) only adds roughly 100ms.
  Don't chase performance here; it's not where the time goes.

## Conventions

- Plain English for all runtime user-facing strings (notifications, tooltip
  text, UI labels) — not Spanish, regardless of what language the
  conversation with the requester is in.
- Square corners on interactive controls (`Style.cornerRadius`, default 0)
  to match Omarchy's own first-party plugin styling — no pill-shaped
  buttons.
- Bash scripts under `bin/`: `set -euo pipefail`, a local `notify()` wrapper
  around `omarchy-notification-send` (swallow its own failures with
  `|| true`), errors always notify, routine success notifications respect
  the `silent` flag in `config.json`.
- Git commits in this repo: plain, human-authored-looking messages only —
  no AI/agent attribution, co-author trailers, or tool references of any
  kind in commit messages.
