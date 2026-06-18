# Arch Guide — obtaining CI secrets for the AUR pipeline

The Arch packaging job (`arch-aur`) stamps the version + sha256sums into
`beskid_distrib/arch/PKGBUILD`, regenerates `.SRCINFO`, and pushes both to the
AUR package `beskid-bin` via `KSXGitHub/github-actions-deploy-aur@v3`.

## Prerequisites (one-time, manual)

1. **Create an AUR account.** Register at https://aur.archlinux.org/ (needs a
   verified email). The account name is your `AUR_USERNAME`.

2. **Generate an SSH key for AUR.** On your machine:
   ```sh
   ssh-keygen -t ed25519 -C "beskid-aur-deploy" -f ~/.ssh/aur_beskid -N ""
   ```
   This produces `~/.ssh/aur_beskid` (private) and `~/.ssh/aur_beskid.pub`
   (public).

3. **Add the public key to your AUR account.** In the AUR web UI:
   **My Account → SSH Public Key → paste the contents of `aur_beskid.pub`**.

4. **Create the `beskid-bin` package (so you own it).** Clone the empty AUR
   package locally and push a first revision so the CI can update it:
   ```sh
   git clone ssh://aur@aur.archlinux.org/beskid-bin.git
   cd beskid-bin
   # copy in beskid_distrib/arch/PKGBUILD (stamp a real version + sha256 first)
   makepkg --printsrcinfo > .SRCINFO
   git add PKGBUILD .SRCINFO
   git commit -m "init beskid-bin"
   git push origin master
   ```
   Only the first push needs to be manual — after the package exists and you
   are listed as a maintainer, the CI action updates it on every release.

## Secrets required

| Secret | Purpose |
|---|---|
| `DISTRIB_GH_PAT` | Read the linux-amd64 CLI + LSP assets from `beskid_compiler` to compute sha256sums. (Shared with Windows/Ubuntu.) |
| `AUR_SSH_PRIVATE_KEY` | The **private** key (`aur_beskid` contents) the action uses to SSH-authenticate to `aur.archlinux.org` and push. |
| `AUR_USERNAME` | AUR account name (used as the git commit author name by the action). |
| `AUR_EMAIL` | Email for AUR commits (the address registered on your AUR account). |

## Obtaining `AUR_SSH_PRIVATE_KEY`

1. Read the private key file you generated above:
   ```sh
   cat ~/.ssh/aur_beskid
   ```
   It must include the `-----BEGIN OPENSSH PRIVATE KEY-----` and
   `-----END OPENSSH PRIVATE KEY-----` lines, and all newlines. A common mistake
   is to paste only one line.

2. Add to the **superrepo** (`Cyber-Nomad-Collective/beskid`):
   **Settings → Secrets and variables → Actions → New repository secret.**
   - Name: `AUR_SSH_PRIVATE_KEY`
   - Value: the entire file contents.

## Obtaining `AUR_USERNAME` / `AUR_EMAIL`

These are **not** secret — they are your AUR account name and email — but they
are stored as repository secrets to keep them out of the workflow file (so they
can be rotated/changed without editing YAML). Add them the same way with names
`AUR_USERNAME` and `AUR_EMAIL`.

## Install (end users)

```sh
# with any AUR helper (yay / paru):
yay -S beskid-bin
# verify:
beskid --version
beskid_lsp --version
```

The package installs `beskid` and `beskid_lsp` to `/usr/bin` (already on PATH
on Arch).
