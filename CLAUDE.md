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

## Real-machine verification — the only test this repo can have

There is no build, no package manager and no test suite here, and there cannot be a useful one:
**these scripts partition disks, write bootloader entries and edit `sudoers`.** A function that
decides to run `sgdisk` is not the partition table it produces, and a heredoc that writes a sudoers
line is not a system you can still `sudo` on. Reading the script carefully is necessary and is not
evidence.

The only real test is a **fresh VM booted from the real Arch ISO, running the script end to end, and
rebooting into what it produced.** A run that does not reach a second boot has not been tested.

What "real machine" means here, concretely:

- **A throwaway QEMU/libvirt guest with a fresh disk image every time.** Reusing an image an earlier
  run mutated means the next run is testing a machine the previous run broke — and a script that is
  accidentally idempotent on a dirty disk will fail on a clean one.
- **A real reboot into the installed system**, not just a successful script exit. The failures that
  matter — wrong UUID in `fstab`, an initramfs the bootloader does not look for, a broken
  `sudoers`, a missing subvolume mount — all surface at boot, not during the install.
- **Every supported path.** Encrypted and unencrypted, EXT4 and BTRFS-with-subvolumes: they are
  different code paths and a green run through one says nothing about the others.
- **Real hardware for GPU passthrough.** IOMMU groups, `vfio-pci` binding order and a second GPU
  cannot be modelled in a guest. That part of the repo is verified on the machine it is for, or not
  at all.

### The names, so you can ask for them by name

| Name | What it means here |
| --- | --- |
| **E2E / on-machine acceptance test** | Boot the ISO in a fresh guest, run the script, reboot, and assert on observable results — the system boots, `findmnt` shows the intended subvolumes, `bootctl list` shows the entry, the user can `sudo`, the expected services are enabled. Never on the script's own log lines. |
| **Contract test** | Checks that assumptions about **things outside this repo** still hold, which is most of what these scripts do. The Arch ISO's bundled tooling changes; `pacman` output and flags change; `sgdisk` partition numbering, `systemd-boot` entry syntax, the NVIDIA package names and the `vfio` kernel parameters all move over time. A script that shells out is a written-down guess about another program's behaviour, and only a real run measures it. |
| **Mutation testing** (here: by hand) | Break one step on purpose — a wrong UUID, a missing `mkinitcpio` run — re-run in the guest, confirm it actually fails or produces an unbootable system, restore. **A check that has never failed has not been tested**, and with `set -e` only partially applied here, "the script finished" is a much weaker signal than it looks. |
| **State-invariant test** | Asserts a relationship **between two things** neither one alone can prove: `fstab`'s UUIDs against what `blkid` reports; the initramfs filename against what the bootloader entry references; the BTRFS subvolume layout against the mount options; `crypttab`/kernel cmdline against the LUKS container. Each file can be individually well-formed while the pair leaves an unbootable machine. |
| **Test pollution / isolation leak** | Running any of this on your own system. It is not flakiness — it is a repartitioned disk or a `sudoers` file edited **without `visudo`**, which means a syntax error locks out privilege escalation with no warning and no undo. Guest only. Snapshot before, and know how to roll back. |

### Rules that came out of real bugs, not theory

- **Prove every check can fail before you trust it green.** Break a step deliberately and confirm the
  guest ends up broken in the way you expect. Given the partial error checking here, a script that
  exits 0 is not a claim that every step ran.
- **Never assert on a count you cannot predict.** "Installed more than 40 packages", "the ESP is
  about 300 MB" — both go green against a genuinely broken run as soon as a mirror or a config
  changes, because the magnitude depends on the input, not on the bug. Assert the **invariant**: the
  machine boots unattended; `fstab` names the UUID `blkid` reports; the bootloader entry points at an
  initramfs that exists; the user can `sudo`; a second run over the same config does not corrupt what
  the first produced.
- **A UUID, subvolume path or bootloader entry must die with the filesystem it describes.** A stale
  entry pointing at a partition that was recreated produces a machine that fails to boot with a
  message that blames the wrong thing.
- **Never run these scripts outside a guest** — including "just the small helper". `sudoers` is
  edited without `visudo` on purpose, so a mistake is not recoverable from a normal session.
- **Claim exactly what you verified.** Say which paths you actually ran (encrypted/unencrypted,
  EXT4/BTRFS), whether the guest rebooted, and what was only read rather than executed. "The script
  looks right" is not a result.

- **Mutation gate (60%) — does not apply here, and that is why it is written down.** The template
  requires a 60% mutation threshold over business logic, and there is no in-process suite to mutate:
  the deliverable partitions disks and installs a system, so the only honest test is the real-machine
  run described above. The discipline still applies **by hand** — break the check on purpose, confirm
  it goes red, restore. A check that has never failed has not been tested. If pure helper functions
  are ever extracted with a real suite around them, the automated gate applies to those from that
  day.

## Agentic PR verification (MANDATORY on every PR)

**Every PR MUST be verified end-to-end before merge, and the verdict MUST be posted as a PR
comment** via `gh pr comment`. A headless agent (`claude -p`, local) drives the change and posts
the result; it **never merges** — it waits for you. Running the pass and posting the verdict
comment is **not optional**. It catches what a diff and shellcheck miss: a script that parses
fine but breaks partway through an install, a wrong partition/variable name, a step that silently
no-ops.

- **Engine.** These are unattended install scripts, not a running app — there is nothing to point
  Playwright at. Verification means: run the changed stage(s) end-to-end in a **safe, disposable
  sandbox** (an Arch Linux container/chroot or a throwaway VM snapshot) and inspect the
  output/log, falling back to `bash -n` (syntax check) + a dry-run/`--help` invocation only when
  no sandbox is available. **Never** run `installer-1.sh`, `after-install-2.sh`,
  `libvirt-subvol-3.sh` or `gpu-pass-4.sh` against a real disk, partition, or the host machine —
  these scripts partition disks, encrypt volumes, and modify `sudo`; a live run outside a sandbox
  is destructive and irreversible.
- **Two layers.** Deterministic checks (shellcheck) stay the hard merge gate; the agentic pass is
  advisory and never vetoes a merge on its own — but running it and posting the verdict comment is
  mandatory.
- **Hard limits.** The verdict awaits your close; the agent never merges.

## Working rules

- **These scripts are destructive and machine-specific** — never run them here; only edit. Assume
  they run on a fresh Arch install as root.
- **Keep the run order** encoded in the `-N` suffix; a new stage gets the next number.
- **Shared logic goes in `common-functions.sh`**, sourced by each stage.
- **Reuse before you write** — before adding a function to a stage, grep the tree for it
  (`grep -rn '^[a-z_]*()' .scripts/`). If `common-functions.sh` already has it, source and call it;
  if a second stage needs the same block, it moves there in the same change instead of being pasted.
  Copy-pasted bash rots silently: the fix lands in stage 3 and stage 5 keeps the bug — and here a
  stale copy runs as root on a real disk.
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
