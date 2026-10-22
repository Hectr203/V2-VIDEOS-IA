# Guest layout, ssh and the bootstrap

A fresh guest has vphoned and the system changes the project ships, and
nothing else: no package manager, no sshd, no shell tools. Everything in this
file is about adding that environment (the "bootstrap") and then finding your
way around it. Until it is installed, work only through `guest send` and
`guest rpc`.

## Contents

- Two layouts: roothide and rootless
- Installing the bootstrap
- First package install
- Inspecting and removing it
- ssh: the shell is not in the real root
- Handing a file to vphoned
- Installing a `.deb`
- What vphoned maintains for you

## Two layouts: roothide and rootless

| | roothide (recommended) | rootless (deprecated) |
| --- | --- | --- |
| Root of the environment | `/var/containers/Bundle/Application/.jbroot-<16 hex>` | `/var/jb`, a symlink to a physical directory under `/private/preboot` |
| Default directory name | `.jbroot-000114514191980C` when none exists (the last byte is a checksum) | none |
| Apps go in | `<jbroot>/Applications` | `/var/jb/Applications` |
| Package `Architecture` | whatever the bootstrap's `dpkg --print-architecture` says; do not assume | `iphoneos-arm64` |
| After installing an app | register it: `system.uicache` or `apps.refresh` | `uicache -p` in the postinst |

The directory names `/var/jb` and `.jbroot-<hex>` are fixed by those two
bootstraps. Always find the real root with `bootstrap.inspect`; do not
hard-code it.

```sh
vphone-launchpad-cli guest rpc myphone bootstrap.inspect
vphone-launchpad-cli guest rpc myphone device.info     # see the layout fields below
```

`device.info` reports `jailbreak.layout` (`roothide`, `rootless`, `rootful` or
`null`), `jailbreak.jbroot` and `jailbreak.source`. These key names belong to
the host-guest protocol; read them as they are. Both null means there is no
bootstrap yet (a read-only `/` is not evidence of a rootful one).

Prefer **roothide** for new work. Rootless is kept for older setups.

## Installing the bootstrap

The bootstrap is the Irisin app plus the base directories and links a package
manager needs. Two equivalent ways:

- **In the VM window:** menu **Apps > Install Bootstrap…**, pick the layout in
  the sheet. Holding Option shows **Install Bootstrap from File…** (a local
  Irisin `.deb`). The item is enabled only when vphoned advertises
  `bootstrap_install`.
- **Over RPC:**

  ```sh
  vphone-launchpad-cli guest rpc myphone bootstrap.install '{"layout":"roothide"}'
  vphone-launchpad-cli guest rpc myphone bootstrap.status
  ```

What `bootstrap.install` does, in order, and what to look at when a step fails:

1. **preparing**: selects the layout. Refuses with an error if
   `/private/var/db/vphoned/bootstrap.json` says a bootstrap is already
   installed. (An uninstall writes a tombstone so this check is accurate.)
2. **downloading**: fetches the latest `Lakr233/Irisin` release for the guest's
   architecture and checks the GitHub SHA-256 digest and the Debian control
   fields. The guest needs network. `bootstrap.status` reports
   `downloaded_bytes` and `total_bytes` when the server gives a length.
3. **extracting / installing**: unpacks the `.deb`, copies the payload into the
   environment, creates Irisin's mobile-owned data directory, registers the app
   and loads its daemon. No maintainer script runs.
4. **firmware**: writes the `firmware` record (the guest iOS version) into the
   environment's `Library/dpkg/status`, so Irisin's resolver sees it.
5. **completed** or **failed** (with `error`). A launchd start error comes back
   as `service_start_warning` while the install still stands; the daemon starts
   on demand when Irisin opens, or after a reboot.

For a local package: upload the `.deb` to exactly
`/var/root/Library/Caches/vphoned-irisin-<UUID>.deb` (regular file, at most
64 MiB, no symlinks) and pass it as `package_path`. vphoned validates name,
architecture, version, executables and the launchd plist.

For roothide, vphoned also builds what a bootstrap installer would: `tmp`,
`var`, `etc`, the `dev` and `rootfs` links, copies of the passwd files, the
user databases, and the `.jbroot` loader links. Do not recreate these by hand;
they are repaired at every vphoned start.

## First package install

This step is done in the guest UI, in Irisin; there is no RPC for it.

1. Open Irisin and the **OwnGoal Packages** repository
   (`https://apt.owngoal.dev/`). Find **OwnGoal Bootstrap for vphone**
   (`owngoal-bootstrap-vphone`).
2. Install it with **Bootstrap Install**.

That one meta package depends on everything a guest needs: `apt`, `dpkg`,
`bash`, `zsh`, `sudo`, the core command-line tools, `openssh-server`, `curl`,
`git`, `uikittools`, `launchctl` and the OwnGoal apps (Irisin, Fila, iGhostVT,
Xrash, Inspector). Do not install those packages one by one: they depend on each
other, and `openssh-server` declares some dependencies circularly, so separate
installs can fail partway. After the first pass, install further packages
normally. If the first pass fails, do not repair it in place:
**Apps > Uninstall Bootstrap…**, then start over.

Because this needs someone at the screen, drive it with `ui.tree`,
`ui.tap_element` and screenshots, or ask the user to do it.

## Inspecting and removing it

```sh
vphone-launchpad-cli guest rpc myphone bootstrap.inspect       # every root found
vphone-launchpad-cli guest rpc myphone bootstrap.uninstall '{"roots":["<path from inspect>"],"force":true}'
```

Uninstall removes **every listed root**, unloads their daemons, unregisters
their apps, marks the record uninstalled and **reboots the guest** (add
`"reboot":false` to skip). The paths must match the current inspection
exactly. Irisin's data under `/var/mobile/Documents` is kept. It destroys the
user's installed packages, so run it only when asked or as the stated recovery
for a failed first install.

## ssh: the shell is not in the real root

ssh exists only after `openssh-server` is installed (see above); a fresh guest
refuses port 22. `iproxy`, `idevice_id` and `ideviceinstaller` are third-party
libimobiledevice tools; ask the user before installing them. Reach the guest
through the host's usbmuxd with `iproxy`:

```sh
UDID=$(idevice_id -l | head -1)     # or xcrun devicectl list devices: Reality "virtual"
iproxy 2222 22 -u "$UDID" &
ssh -p 2222 mobile@127.0.0.1         # the credentials are not documented in the repo; ask the user
```

On roothide the session lands **inside the jbroot**, not the real root:

- `/` in the shell is the environment's root. `/tmp`, `/var/mobile` and `/etc`
  there are the bootstrap's copies, not the guest's.
- The real filesystem is at **`/rootfs`**. `/rootfs/private/var/...` is the
  guest's `/private/var/...`. Logs, app data and preferences are found there.
- vphoned's `files.*`, `apps.*` and other RPCs use the **real** paths. A path
  you see in the ssh shell is not valid for RPC until it is translated.
- There is no `sudo` in a bare jbroot. Install `sudo` as a package first, log in
  as root if the user has set that up, or do root work over RPC.

Rule of thumb: when ssh and RPC disagree about whether a file exists, the
difference is the `/rootfs` prefix.

## Handing a file to vphoned

To let an RPC (for example `apps.install`) read a file you put in through ssh:

```sh
scp -P 2222 App.ipa mobile@127.0.0.1:/tmp/App.ipa      # lands in the jbroot's /tmp
ssh -p 2222 mobile@127.0.0.1 'mv /tmp/App.ipa /rootfs/private/var/tmp/App.ipa'
vphone-launchpad-cli guest rpc myphone apps.install '{"path":"/private/var/tmp/App.ipa"}'
```

Without ssh, use RPC only: `files.write` for small text. Binaries need the
HTTP route `PUT /v1/files/content?path=<abs path>`, which exists only when the
VM was launched with `vphone-cli vm launch --api-listen` outside `vm start`; ask
the user rather than relaunching a running machine.

## Installing a `.deb`

With a bootstrap present, `dpkg` and `apt` work from an ssh shell as the
environment's tools:

```sh
scp -P 2222 pkg.deb mobile@127.0.0.1:/tmp/
ssh -p 2222 mobile@127.0.0.1 'sudo dpkg -i /tmp/pkg.deb'    # needs sudo installed, or a root login
```

A package that ships an app must register it afterwards (`uicache -p` in the
postinst for rootless, or `system.uicache` over RPC). Do not install a package
over a half-built bootstrap.

## What vphoned maintains for you

You do not need to run these; knowing they exist explains odd behavior:

- `.jbroot` loader links in every directory holding a Mach-O file, re-walked one
  second after `Library/dpkg` changes. A `dyld ... @loader_path/.jbroot/...`
  crash means a link is missing there.
- sshd host keys and user databases, deferred until the packages exist, then
  created within about a second of the next package operation or at the next
  vphoned start.
- The `firmware` record in `dpkg/status`, updated after an iOS version change.

When something here misbehaves, read the notes listed in
[finding-docs](finding-docs.md), especially `Research/Guest/roothide_bootstrap_base.md`
and `Research/roothide_loader_links.md`.
