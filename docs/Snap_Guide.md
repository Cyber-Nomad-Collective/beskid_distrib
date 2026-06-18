# Snap Guide — obtaining CI secrets for the Snap Store pipeline

The Snap packaging job (`linux-snap`) builds the snap with
`canonical/action-build@v1` from `beskid_distrib/snap/snapcraft.yaml`, then
publishes it to the Snap Store with `canonical/action-publish@v1`.

## Prerequisites (one-time, manual)

1. **Register the snap name.** Sign in to https://snapcraft.io/ with your
   Ubuntu One account. Register the name `beskid`:
   https://snapcraft.io/snaps → **Register a snap name** → `beskid`. The name
   must be free; if it is taken and unused, file a name-dispute request.

2. **Set the snap to classic confinement.** Because Beskid ships prebuilt
   glibc-linked binaries that need to run without confinement jail restrictions,
   `snapcraft.yaml` declares `confinement: classic`. Classic confinement
   requires manual review/permission from the Snap Store team. Request it on
   the snap's page: **Settings → Edit → request classic confinement** with a
   justification ("ships prebuilt native binaries"). Until approved, publish
   with `confinement: strict` temporarily and switch once approved.

3. **Verify the snap builds locally** (optional but recommended before CI):
   ```sh
   cd beskid_distrib/snap
   # place bin/beskid and bin/beskid_lsp (the linux-amd64 assets) under ./bin
   snapcraft
   sudo snap install --classic beskid_*.snap --dangerous
   beskid --version
   ```

## Secret required

| Secret | Purpose |
|---|---|
| `SNAPCRAFT_STORE_CREDENTIALS` | Snap Store login credentials the `action-publish` step uses to push the built `.snap` to the registered `beskid` snap. The legacy `SNAPCRAFT_TOKEN` is deprecated; `SNAPCRAFT_STORE_CREDENTIALS` is the current recommended secret name. |

## Obtaining `SNAPCRAFT_STORE_CREDENTIALS`

1. **Install snapcraft locally** (one time):
   ```sh
   # macOS (via multipass) or any Linux:
   sudo snap install snapcraft --classic
   ```

2. **Export a login credential file** (non-interactive, no MFA prompt in CI):
   ```sh
   snapcraft login
   # enter Ubuntu One credentials + complete 2FA
   snapcraft export-login --snaps=beskid --channels=stable,edge --acls package_push,package_release,package_update ~/snap-creds.txt
   ```
   - `--snaps=beskid` scopes the credential to only the `beskid` snap.
   - `--acls package_push,package_release,package_update` grants the minimum
     ACLs needed by `action-publish`.

3. **Read the credential string** (it is a single base64-ish line):
   ```sh
   cat ~/snap-creds.txt
   ```

4. **Add to the superrepo** (`Cyber-Nomad-Collective/beskid`):
   **Settings → Secrets and variables → Actions → New repository secret.**
   - Name: `SNAPCRAFT_STORE_CREDENTIALS`
   - Value: the contents of `snap-creds.txt` (the single line).

5. Delete the local file once the secret is saved:
   ```sh
   shred -u ~/snap-creds.txt  # or rm on macOS
   ```

## What the snap does

- `confinement: classic` → the snap's binaries run as if installed normally,
  placing `beskid` and `beskid-lsp` (commands) on PATH.
- `base: core22` → matches the glibc ABI the compiler workflow's
  `x86_64-unknown-linux-gnu` build targets.
- `architectures: build-on: [amd64], build-for: [amd64]` → single-arch in v1.
- The build pulls the prebuilt linux-amd64 binaries (fetched into `snap/bin`
  by the CI job before `snapcraft` runs).

## Install (end users)

```sh
sudo snap install beskid --classic
beskid --version
```

`--classic` is required because the snap uses classic confinement.

## Rotation

`snapcraft export-login` credentials expire. Re-run the export step and update
the `SNAPCRAFT_STORE_CREDENTIALS` secret when they do (Snap Store does not
publish a fixed expiry; check the dashboard for the credential's validity).
