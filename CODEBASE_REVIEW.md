# Codebase Review

**Repository:** `/home/dano/repos/personal/dotfiles`  
**Review date:** 2026-06-14  
**Scope:** Full repository (flake, hosts, modules, scripts, secrets, docs)  
**Validation run:** `just check` passes on `x86_64-linux`; `statix check` reports one warning.

---

## Executive Summary

This is a well-structured unified Nix flake covering three NixOS hosts and one nix-darwin host, with Home Manager, sops-nix, import-tree module discovery, and a consistent `my.*` opt-in namespace. The architecture is sound and the flake evaluates cleanly.

The main gaps are operational and maintainability rather than correctness: stale documentation, hardcoded paths, duplicated cross-platform config, inconsistent `stateVersion` values, always-on modules that bypass the opt-in pattern, and CI that does not validate Darwin or full host configurations. Security posture is generally thoughtful (Tailscale SSH, loopback service binds, sops secrets), but the server firewall still exposes broad dev port ranges inherited from desktop-oriented defaults.

---

## Severity Legend

| Level | Meaning |
|-------|---------|
| **High** | Likely to cause breakage, security exposure, or data loss |
| **Medium** | Maintainability, inconsistency, or latent bugs |
| **Low** | Polish, cleanup, or incremental improvements |
| **Positive** | Patterns worth keeping |

---

## High Priority

### 4. Hardcoded absolute paths throughout the repo

Many modules assume the flake lives at `~/repos/personal/dotfiles`:

| File | Usage |
|------|-------|
| `modules/home-manager.nix` | `NH_FLAKE`, `DOTFILES_DIR`, SSH config `cp` |
| `modules/programs/nh.nix` | flake paths |
| `modules/programs/zsh.nix` | shell script source |
| `modules/hyprland.linux/ags/default.nix` | runtime `cd` into repo |
| `modules/hyprland.linux/noctalia/noctalia.json` | wallpaper paths, avatar |
| `files/home/.shell_scripts/.main_shell` | `SHELL_SCRIPTS` export |

This breaks if the repo is cloned elsewhere, used on another user, or deployed from a non-standard path.

**Recommendation:** Derive paths from `env.home` consistently (already done in some places). For AGS/Noctalia runtime assets, use Nix store paths or `config.home.homeDirectory`-relative symlinks. Consider a single `dotfilesPath` in `createEnv` passed via `specialArgs`.

---

### 5. Darwin configuration is not validated in CI

`just check` runs `nix flake check`, which:

- Validates all three `nixosConfigurations` (akatosh, azura, mara)
- Builds `opencode-cursor-proxy` on both `x86_64-linux` and `aarch64-darwin`
- Does **not** evaluate `darwinConfigurations.boethiah` or `MY797HJWD7`

Running `nix flake check --all-systems` still reports `running 0 flake checks` for darwin configurations.

**Recommendation:** Add explicit checks:

```nix
checks.${darwinSystem}.boethiah =
  self.darwinConfigurations.boethiah.config.system.build.toplevel;
```

Or add a `just check-darwin` recipe. Without this, boethiah-only regressions will not be caught on Linux CI.

**Location:** `flake.nix` — no `checks` entries for darwin configs

---

## Medium Priority

### 7. Inconsistent `stateVersion` across hosts

| Component | Version |
|-----------|---------|
| Home Manager (all Linux) | `22.11` |
| akatosh (NixOS) | `23.11` |
| azura (NixOS) | `23.05` |
| mara (NixOS) | `25.05` |
| boethiah (HM) | `25.05` |
| boethiah (darwin) | `6` |

Wide drift increases upgrade risk. HM at `22.11` while NixOS hosts range `23.05`–`25.05` is especially notable given the GTK4 workaround comment in `home-manager.nix`.

**Recommendation:** Plan a coordinated bump per host, starting with HM `stateVersion` after reading release notes.

---

### 8. Duplicated Home Manager configuration (Linux vs Darwin)

Linux HM config lives in `modules/home-manager.nix`. Darwin reimplements significant portions inline in `hosts/boethiah.nix` (SSH config, gpg-agent, session vars, zsh aliases). A TODO in `home-manager.nix` line 152 acknowledges this.

**Impact:** SSH config differs between platforms (Linux copies from `files/home/.ssh/config`; Darwin inlines a different config). Changes must be made in two places.

**Recommendation:** Extend `home-manager.nix` `darwin` branch or extract shared `home/common.nix`.

---

### 9. SSH config managed via imperative `cp` (Linux)

`modules/home-manager.nix` activation copies SSH config instead of declarative `home.file`:

```nix
cp $HOME/repos/personal/dotfiles/files/home/.ssh/config $HOME/.ssh/config
```

This bypasses Home Manager's backup/rollback semantics and won't update if the source changes unless activation re-runs.

**Recommendation:** Replace with `home.file.".ssh/config".source = ../../files/home/.ssh/config` (or `text`).

---

### 10. sops-nix is Linux-only; Darwin secrets story is incomplete

`modules/services/secrets.linux.nix` always imports `sops-nix.nixosModules.sops` with a comment that boethiah had trouble. Darwin relies on `pass` and Homebrew instead (e.g. `zsh.nix`, `gcalcli.nix`).

**Impact:** Credential handling is inconsistent across platforms. Linux modules assume `config.sops.secrets.*` exists; Darwin uses `pass` paths.

**Recommendation:** Either implement `secrets.darwin.nix` with sops-nix darwin module, or document the intentional split and audit all `config.sops` references for darwin safety.

---

### 11. Tailscale is always enabled without a master enable flag

`modules/services/tailscale.nix` sets `services.tailscale.enable = true` unconditionally on Linux. Sub-options (`enableAsExitNode`, `useRoutingFeatures`) exist, but there is no `my.services.tailscale.enable` to disable Tailscale on a host.

Similarly, `serve.enable = false` means all `tailscale-svc-*-up` helper scripts must be run manually after each reboot — easy to forget.

**Recommendation:**

- Add `my.services.tailscale.enable` (default `true` for backward compat)
- Consider systemd oneshot units or `services.tailscale.serve` integration to auto-expose services

---

### 12. Always-on modules bypass the `my.*` opt-in pattern

These modules apply on every host with no enable toggle:

| Module | Always configures |
|--------|-------------------|
| `user.nix` | User account, SSH keys |
| `home-manager.nix` | HM integration |
| `system.nix` | Locale, fonts, pipewire, nix settings |
| `zsh.nix` | Zsh + plugins |
| `git.nix` | `.gitconfig`, GPG signing |
| `lazygit.nix` | Lazygit |
| `nh.nix` | nh flake paths |
| `network.nix` | NetworkManager, firewall |
| `password-store.nix` | pass, browserpass, git-sync |
| `secrets.linux.nix` | sops secrets |
| `gpg-home.linux.nix` | gpg-agent, gnome-keyring |
| `power-management.linux.nix` | TLP, thermald, scheduler |
| `btop.nix` | btop |
| `tailscale.nix` | Tailscale daemon |

This is fine if intentional, but it prevents minimal/server-only profiles and makes the `my.*` pattern inconsistent.

**Recommendation:** Document which modules are "base" vs opt-in. For mara, consider gating desktop-oriented base config (pipewire, bluetooth, printing) behind `env.deviceType`.

---

### 13. mara runs both Helix (default editor) and LazyVim

`hosts/mara.nix` enables:

- `helix` with `isDefaultEditor = true`
- `lazyvim` with `isDefaultEditor` commented out

Both full editor stacks are installed on a headless server primarily accessed via SSH. Helix wins for `$EDITOR`, but LazyVim still pulls Neovim + LazyVim plugin tree (visible in flake check traces).

**Recommendation:** Disable `lazyvim` on mara unless actively used over SSH.

---

### 14. Multiple pinned nixpkgs commits increase eval complexity

`flake.nix` pins separate nixpkgs revisions for:

- `openvpn24`
- `guake`
- `llama-cpp`
- `hyprland` (0.53.3 — TODO to migrate to 0.54+)
- `stirling-pdf` (v1.5.0 — v2 broke things)

Each pin is a separate package set eval. Combined with 15+ flake inputs, `nix flake check` takes ~45s.

**Recommendation:** Periodically consolidate pins as upstream catches up. Track the Hyprland migration TODO.

---

### 15. `statix` lint warning in opencode module

`statix check` warns about repeated `home` keys in `modules/programs/opencode/default.nix` (lines 221–225). Should merge into a single `home = { ... }` attrset.

**Recommendation:** Run `just fmt` / `statix fix` or refactor the `home-manager.users` block.

---

### 16. Tailscale tailnet names hardcoded in multiple files

Legacy (`tail9f1d8`) and current (`dinosaur-crocodile`) tailnet DNS names appear across hosts, services, and SSH config:

- `hosts/mara.nix`, `hosts/boethiah.nix`
- `modules/services/homepage.linux.nix`, `cockpit.linux.nix`, `paperless.linux.nix`, etc.

**Recommendation:** Define `my.tailnet.domain` (or `env.tailnetDomain`) once in `createEnv` / host config and reference it in modules.

---

### 17. `boethiah` registered under two hostnames

`flake.nix` defines both `boethiah` and `MY797HJWD7` darwin configurations pointing at the same config — a workaround for a hostname rename issue.

**Recommendation:** Document the migration path to a single hostname. Consider a `networking.hostName` assertion or activation script to enforce the desired name.

---

### 18. Power management contradictions on server

`modules/services/power-management.linux.nix` for non-laptop hosts:

- Sets `cpuFreqGovernor = "performance"` (line 40)
- Comments say servers should use `powersave` or `ondemand` (lines 38–39)
- Also applies aggressive power-saving kernel params and ethtool offload disabling for servers

The comment and the value disagree.

**Recommendation:** Align governor with intent. If mara's ethernet stability fixes need `performance`, update the comment.

---

### 19. No CI/CD pipeline in the repository

There is no `.github/workflows/` (or equivalent). Validation relies on manually running `just check` locally.

**Recommendation:** Add a lightweight workflow:

```yaml
- run: nix flake check
- run: statix check .
```

Optionally run on both Linux and macOS runners.

---

### 20. `node_modules` present in the working tree

`node_modules/` exists under:

- `modules/programs/opencode/cursor-proxy/`
- `modules/scripts/bun/`

`.gitignore` excludes `node_modules`, and only 2 git-tracked `node_modules` paths were found (likely lock/metadata). The directories still add noise to searches and disk usage.

**Recommendation:** Ensure builds use `bun2nix` / flake inputs only. Add `node_modules` cleanup to `just clean` if needed.

---

## Low Priority / Improvements

### 21. Large volume of TODO comments (30+)

Notable TODOs:

| Area | TODO |
|------|------|
| `flake.nix` | Migrate Hyprland to v0.54+ |
| `home-manager.nix` | Declarative SSH; Darwin HM; PIA config in sops |
| `modules/programs/git.nix` | SSH signing instead of GPG |
| `modules/services/ssh.nix` | Remove module once Tailscale SSH is stable |
| `modules/services/streaming.linux.nix` | Refactor to Jellyfin pattern |
| `modules/hyprland.linux/ags/` | Use AGS launcher instead of rofi; known slider bug |
| `modules/gnome.linux/` | Wayland rofi issues |

**Recommendation:** Triage into issues or a `MAINTENANCE.md` backlog.

---

### 22. Deprecated `gcalcli` module still present

`modules/programs/gcalcli.nix` is marked deprecated in favor of `gws`. No host enables it currently.

**Recommendation:** Remove the module once `gws` covers all calendar workflows.

---

### 23. Commented-out dead code in host files

`hosts/akatosh.nix`, `hosts/mara.nix`, and others contain large commented blocks (GNOME, n8n, lazyvim, wakeonlan, zellij). This adds noise when reading host intent.

**Recommendation:** Delete commented blocks; git history preserves them.

---

### 24. Platform suffix naming inconsistency

Module layout mixes conventions:

- `*.linux.nix` files (e.g. `cockpit.linux.nix`)
- `*.linux/` directories (e.g. `postiz.linux/`, `hyprland.linux/`)
- `default.linux.nix` (cursor-agent-http)

import-tree handles all of these, but the inconsistency makes discovery harder.

**Recommendation:** Standardize on one convention (file suffix vs directory).

---

### 25. `noctalia.json` contains host-specific absolute paths

`modules/hyprland.linux/noctalia/noctalia.json` hardcodes `/home/dano/...` for wallpapers and avatar. The Nix module overlays some values, but the JSON file itself is akatosh-specific.

**Recommendation:** Use placeholder values in the JSON; let Nix overlays supply all host-specific paths.

---

### 26. AGS bar depends on live repo checkout at runtime

`modules/hyprland.linux/ags/default.nix` starts AGS via:

```bash
cd ~/repos/personal/dotfiles/modules/hyprland.linux/ags && bun start
```

This is fragile outside the expected directory layout and couples the running system to an unbuilt working tree.

**Recommendation:** Package AGS config via `bun2nix` or `writeShellScript` with store paths, similar to `cursor-proxy`.

---

### 27. `createNixCache` trusted substituters may be stale

`flake.nix` trusts `nix-community.cachix.org`, `srid.cachix.org`, and `hyprland.cachix.org`. The Hyprland pin may not match the cachix binary cache version.

**Recommendation:** Verify substituters still provide cache hits after Hyprland migration.

---

### 28. Typo in `user.nix`

`"Accese to storage devices"` → `"Access to storage devices"`

---

### 29. `just update` requires sudo

`justfile` `update` recipe runs `sudo nix flake update`. This is unusual — flake update typically does not need root.

**Recommendation:** Drop `sudo` unless there is a specific reason.

---

### 30. Homepage widget config partially hardcoded

`modules/services/homepage.linux.nix` has `# TODO: move this to an option` for widget/service definitions. Much of the dashboard layout is module-internal rather than host-configurable.

**Recommendation:** Expose `my.services.homepage.services` overrides per host (partially exists via options; default widgets could move to host).

---

## Security Notes

| Topic | Assessment |
|-------|------------|
| Secrets management | Good: sops-nix + age, group-based permissions, secrets not in plaintext |
| SSH | Good: Tailscale SSH enabled; optional openssh binds loopback only |
| SSH keys in git | Expected for `authorizedKeys`; public keys only |
| Firewall | Mixed: Tailscale trust is good; broad dev port ranges on server are not |
| Service exposure | Good pattern: loopback bind + Tailscale serve scripts |
| Tailscale exit node | mara advertises exit node — ensure ACLs restrict who can use it |
| `shields-up=false` | Tailscale shields down by default — intentional for homelab? |
| git signing | GPG key fingerprint in `.gitconfig` — public metadata, acceptable |
| `allowed_signers` | SSH public keys in repo — expected for commit signing |

---

## Positive Patterns (Keep These)

1. **Unified flake** for NixOS + nix-darwin — one repo, one `just switch` workflow
2. **`my.*` option namespace** — clean host-level feature toggles in thin host files
3. **`import-tree` auto-discovery** — no manual module list maintenance
4. **`env.selectPlatform`** — elegant cross-platform merging (`linux` / `darwin` / `any`)
5. **`createEnv` abstraction** — `deviceType`, `hasGPU`, `isOnWayland` drive conditional config
6. **sops-nix integration** — centralized secrets with declarative service wiring
7. **Assertions** — opencode/llama-cpp, immich mediaLocation, podman/docker mutual exclusion, stylix wallpaper
8. **Distributed builds** — azura/mara use akatosh as remote builder
9. **nh + justfile** — consistent rebuild, GC, and secrets editing workflow
10. **Tailscale serve helpers** — consistent `tailscale-svc-<name>-up/down` pattern across services
11. **Specialisation on mara** — `remote-desktop` tag for optional desktop profile
12. **Sub-flakes for bun scripts** — isolated `bun-scripts` and `bun2nix-systems` inputs

---

## Suggested Prioritized Roadmap

### Quick wins (1–2 hours each)

1. Fix README staleness
2. Fix statix warning in `opencode/default.nix`
3. Disable `lazyvim` on mara if unused
4. Replace SSH `cp` with `home.file` on Linux
5. Add `checks` for darwin configurations in `flake.nix`

### Medium effort (half day each)

6. Introduce `dotfilesPath` in `createEnv` to eliminate hardcoded paths
7. Split firewall rules by `deviceType`
8. Consolidate HM config for Darwin into `home-manager.nix`
9. Add GitHub Actions for `just check` + `statix check`

### Larger projects

10. Hyprland 0.54+ migration (flake pin + config changes)
11. sops-nix on Darwin (or formalize pass-only credential model)
12. Package AGS/Noctalia assets without runtime repo dependency
13. Coordinated `stateVersion` bump across all hosts

---

## Appendix: Repository Stats

| Metric | Value |
|--------|-------|
| NixOS hosts | 3 (akatosh, azura, mara) |
| Darwin hosts | 1 (boethiah / MY797HJWD7) |
| Module files (`modules/**/*.nix`) | ~87 |
| Flake inputs | ~20 |
| `just check` result | Pass (linux) |
| `statix check` result | 1 warning |
| Open TODOs | ~30 |

---

*Generated by automated codebase review. Re-run `just check` after applying fixes.*
