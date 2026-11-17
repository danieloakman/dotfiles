# vuln-monitor-triage host reference

Facts for triage against this flake. Confirm in-tree if unsure; this file can
lag a rebuild.

## Platform

- Primary monitored host: **mara** (NixOS).
- NixOS uses **glibc**, not musl. Musl-only advisories (Alpine/OpenWrt/Buildroot
  sshd without PAM) do not apply to mara’s system sshd.
- Interactive checkout: `@repo@` (never commit triage fixes there).
- Triage worktree: `@worktree@`.

## SSH (mara)

Module: `modules/services/ssh.nix` when `my.services.ssh.enable`.

Typical hardened settings on this flake:

- `PasswordAuthentication = false`
- `KbdInteractiveAuthentication = false`
- `UsePAM = true`
- `ListenAddress = "127.0.0.1"` (loopback; remote via Tailscale SSH)

`sshole` / CVE-class musl+no-PAM password bypass: **not_affected** on mara when
those settings hold and the host is glibc NixOS.

## Vulnix path

- Weekly `vulnix --system` on mara; severity floor default **high** (CVSSv3 ≥ 7).
- Whitelist via `my.services.vuln-monitor.ignore-cves` /
  `ignore-packages` / `extra-whitelist`.
- Adding an ignore is an **easy_fix** only when the advisory is clearly a
  false positive for the installed derivation (document why in the PR body).

## Feeds path

Sources (default): oss-security, nixos-security Discourse, nixos.org blog.
Keyword filter is broad; many hits are musl/Alpine/unrelated. Prefer
`not_affected` with a one-line why when conditions cannot hit this flake.

## Checks

- Host-only Nix eval: `just check-host`
- Broader flake: `just check`
- After a merged fix that changes units/ports/services: verify live with
  `systemctl` / `journalctl` / `ss` per `AGENTS.md` (human does switch; agent
  does not).
