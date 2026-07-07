# archlinux-script-installer — Claude Guide

Collection of Bash scripts that install Arch Linux (almost) unattended for the maintainer's
personal setup, plus NVIDIA GPU-passthrough VM configuration. **Personal use only** — the
scripts do deliberately unusual things (edit `sudo` without `visudo`, partial error checking).
Read `README.md` and `TODO` before touching anything.

## What this repo is

Not an app — an ordered set of shell scripts under `.scripts/`, plus drop-in config assets
under `.scripts/additional_resources/` (CoolerControl, MangoHud, systemd-boot entries, udev
rules, laptop scripts). Supports encrypted/unencrypted installs, EXT4 or BTRFS + subvolumes,
snapper snapshots, GRUB/systemd-boot, KDE Plasma, and `envycontrol` on NVIDIA laptops.

## Superpowers — use whenever applicable

Always prefer **superpowers** skills over ad-hoc approaches. If there's even a small chance a
skill applies, invoke it via the `Skill` tool before acting (including before clarifying
questions).

- **Process skills first** — `brainstorming` before creative/feature work, `systematic-debugging`
  before fixing bugs, `test-driven-development` before writing implementation.
- **Then implementation skills** — domain-specific skills guide execution.
- **Verify before claiming done** — `verification-before-completion` / `requesting-code-review`.

User instructions always take precedence over skills; skills override default behavior.

### Mode switch

- **"lite mode"** — fully disables superpowers: no skill is invoked, not even the applicability
  check, until **"normal mode"** is said.
- **"normal mode"** (default) — standard superpowers behavior, plus: when delegating coding work,
  dispatch at most 1 agent at a time, and never use a model above Sonnet (no Opus).
- **"modo desatendido"** (unattended mode) — the user is away and delegates autonomy: work
  without waiting for confirmations and decide yourself instead of asking. You MAY **`git push`
  the feature branches you create** and **open PRs via `gh`**. The hard limits still hold:
  **never merge anything** (no `git merge`, no fast-forward, no `gh pr merge`), **never push to
  `main`**/protected, never `--force`. Deliver branches + PRs for the user to merge. Reverts to
  defaults on **"normal mode"**.

Confirm the switch briefly when it happens.

## Stack

- **Bash** — no build system, no package manager, no tests. Target OS: Arch Linux.
- Assets are plain config files (`.toml`, `.json`, `.conf`, `.rules`, `.reg`).

## Layout

- `.scripts/installer-1.sh` — main install step (stage 1).
- `.scripts/*-N.sh` — ordered stages (`after-install-2.sh`, `libvirt-subvol-3.sh`,
  `gpu-pass-4.sh`); the numeric suffix is the run order.
- `.scripts/common-functions.sh` — shared helpers sourced by the stages.
- `.scripts/additional_resources/` — drop-in configs applied during setup.
- `TODO` — known gaps and temporary fixes; keep it current.

## Commands

```bash
# nothing to build — run the stages in order on the target machine (as root, fresh Arch)
bash .scripts/installer-1.sh
# optional lint if available
shellcheck .scripts/*.sh
```

## Working rules

- **These scripts are destructive and machine-specific** — never run them here; only edit. Assume
  they run on a fresh Arch install as root.
- **Keep the run order** encoded in the `-N` suffix; a new stage gets the next number.
- **Shared logic goes in `common-functions.sh`**, sourced by each stage.
- **Record gotchas / temporary fixes in `TODO`** (and the README NOTE sections) so they aren't lost.
- **shellcheck-clean** where practical; quote variables and use `set -euo pipefail` in new scripts.

## Git & GitHub

- **Commits and branches OK** — create commits and new branches whenever it makes sense, without
  asking first.
- **Never push** (default) — no `git push` under any circumstance, and never `git push --force` /
  `--force-with-lease`. Leave pushing to the user. **Exception:** with **"modo desatendido"**
  active, you may push the feature branches you create (never `main`/protected, never force).
- **Never merge — no permission** — no `git merge`, no fast-forward integration, no `gh pr merge`,
  and no merging of any pull request, in every mode incl. **"modo desatendido"**. Leave every
  merge to the user.
- **GitHub via `gh`** — open PRs, issues, comments, and labels over branches already pushed.
