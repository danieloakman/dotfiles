# Handoff: Noctalia v5 migration

## Goal
Migrate the Hyprland UI shell from Noctalia **v4** (Quickshell, BirdeeHub
`nix-wrapper-modules`) to Noctalia **v5** (native rewrite, official flake). Done as a
**new module** so v4 stays intact for rollback.

## Status: core migration complete and verified
Branch `feat/upgrade-noctalia-v5`, pushed to `origin`. Two commits:
- `e74fee1` Add Noctalia v5 flake input and Cachix cache
- `19707c4` Add noctalia-v5 shell module and switch akatosh to it

See the full plan (context, decisions, mappings, verification) at:
`/home/dano/.claude/plans/see-https-docs-noctalia-dev-v5-getting-s-melodic-noodle.md`

### What changed (see `git show` for detail)
- `flake.nix` / `flake.lock` — new input `noctalia.url = "github:noctalia-dev/noctalia"`
  (no `nixpkgs.follows`, keeps Cachix usable) + `noctalia.cachix.org` substituter & key.
- `modules/hyprland.linux/default.nix` — `"noctalia-v5"` added to `uiShell` enum.
- `modules/hyprland.linux/noctalia-v5/default.nix` — **new** module. Uses the official
  `inputs.noctalia.homeModules.default` (`programs.noctalia`), a clean
  `my.desktop.noctaliaV5` options namespace, minimal declarative TOML, v5 `noctalia msg`
  keybinds. v4 folder `modules/hyprland.linux/noctalia/` untouched.
- `hosts/akatosh.nix` — `uiShell = "noctalia-v5"`; host opts ported to `noctaliaV5`.

### Verified
- Generated `~/.config/noctalia/config.toml` builds and passes the module's built-in
  `noctalia config validate` (`validateConfig` defaults true).
- `nixosConfigurations.akatosh` toplevel evaluates cleanly.
- **NOT yet done:** actual `nixos-rebuild switch` / runtime smoke test on the machine.

## Key v5 facts (confirmed against source at the noctalia flake `outPath`)
- Binary/command: `noctalia` (was `noctalia-shell`). IPC: `noctalia msg <cmd>`.
- Config: TOML at `~/.config/noctalia/*.toml` (read-only OK). GUI/runtime state at
  `~/.local/state/noctalia/settings.toml` — loads last and **overrides** declarative config.
- IPC command names came from `grep 'registerHandler(' src/`. Emoji = `panel-toggle
  launcher /emo`. Media = `media <toggle|next|previous>`. Full list in the plan.
- Home module option contract: `enable`, `systemd.enable`, `package` (defaulted via
  `mkDefault` by `homeModules.default`), `settings` (attrset→TOML), `validateConfig`,
  `customPalettes`.

## Gotcha for the next agent
Flakes only see **git-tracked** files. The new `noctalia-v5/default.nix` was invisible
to `nix eval` until `git add`ed. Any new files must be staged before building.

## Remaining / deferred work (decisions already made with user)
1. **Runtime test**: `nixos-rebuild switch --flake .#akatosh`, then confirm bar on DP-2
   only, Super+Space launcher, volume/brightness/media keys, avatar/wallpaper/location.
   Rollback = set `uiShell = "noctalia"`.
2. **pass-menu plugin** (Super+Q password launcher): DEFERRED. v4 QML at
   `modules/hyprland.linux/noctalia/plugins/pass-menu/`. Needs rewrite as a v5 Luau
   `launcher_provider` (docs: `/v5/plugins/development/`). Re-add `pass`+`wtype` packages
   and the keybind when done.
3. **Dropped, no v5 equivalent**: web-search launcher (Super+S), bar widgets
   workspace-overview / tailscale / network-manager-vpn.
4. `notifications.monitors` from akatosh was not ported (no confirmed v5 key). Route via
   `noctaliaV5.settingsExtra` if wanted.
5. Optional cleanup (unrelated, surfaced during review): `hyprland.cachix.org` in
   `flake.nix` substituters is dead weight — this repo consumes nixpkgs's hyprland (a raw
   commit pin), not the hyprwm/Hyprland flake.

## Suggested skills
- `/run` or `/verify` — drive the actual `nixos-rebuild` + runtime smoke test (item 1).
- `/code-review` — review the two commits before merging.
- Use the `Explore`/`Plan` agents for the pass-menu Luau rewrite (item 2).
