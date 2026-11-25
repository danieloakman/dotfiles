# Agent notes

## Checks

- Host-only / current-machine changes: `just check-host`
- Broader flake / multi-host changes: `just check`

`just check-host` only evaluates the Nix config. It does **not** prove a service works at runtime.

## After a NixOS rebuild

When a change affects systemd units, ports, env vars, `home.file` / agent skills, or service wiring, treat the work as incomplete until it has been verified **after** `just switch` (or equivalent `nh os switch`) on the target host.

Verify the live system, not only the evaluation. Typical checks:

- `systemctl is-active` / `systemctl status` for the units you touched
- `systemctl is-active home-manager-<user>.service` when the change touches Home Manager (`home.file`, skills, HM programs)
- `journalctl -u <unit>` (system) or `journalctl --user -u <unit>` — many home-manager services are user units
- `systemctl show <unit> -p Environment` or `systemctl cat` for expected env
- `ss -tlnp` (or similar) that the intended bind address/port is listening — and that nothing else owns that port
- A real request against the service (`curl` health/API, drop a sample file into a consume dir, etc.)

Port/endpoint collisions and silent unit failures only show up this way; eval alone will look fine.

### Home Manager skill links

Interactive agent skills go through `my.programs.agents.skill-dirs` (per-file symlinks under `~/.claude/skills`). Do not hand-roll `home.file.".claude/skills/…"`.

If activation fails with `Read-only file system` while moving/linking under `~/.claude/skills/<name>`, that path is almost certainly a **whole-dir** store symlink left from an older install. Remove it (`rm` the directory symlink — not files inside the store), then re-switch.

## Gotchas

### Nixpkgs pin / Rust system-lib carries

After a nixpkgs bump, if a Rust package fails with `AWS_LC_SYS_USE_SYSTEM`, missing `libzstd` / oniguruma / sqlite via pkg-config, or similar — treat it as a **system-lib carry**. `cargoSetupHook` forces those system libs; the first panic is rarely the full set. Look up the nixpkgs issue/PR (or master `package.nix`) for the complete `buildInputs` list before rebuilding. Local exemplars: `modules/programs/t3code.nix`, `modules/programs/localsend.nix`.
