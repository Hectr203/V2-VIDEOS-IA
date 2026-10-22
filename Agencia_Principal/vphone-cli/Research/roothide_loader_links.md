# RootHide loader links for later-installed applications

## Observation and boundary

The 2026-09-24 TrollSpeed crash reports an unresolved
`@loader_path/.jbroot/usr/lib/libroothide.dylib`. dyld tried the physical
`<jbroot>/Applications/TrollSpeed.app/.jbroot/usr/lib/libroothide.dylib`
and stopped before the application began executing. This identifies a loader
path failure, but the report alone does not prove whether the `.jbroot` link,
the target `usr/lib/libroothide.dylib`, or both are missing. Inspect both on
the guest before changing anything.

RootHide's [developer documentation](https://github.com/roothide/Developer/blob/main/roothide.md)
specifies a `.jbroot` link in every directory containing a Mach-O image and
says package installation or the jailbreak's loader normally creates it.
Apple's [dynamic library documentation](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/DynamicLibraries/100-Articles/DynamicLibraryDesignGuidelines.html)
defines `@loader_path` relative to the referencing image. A link beside the
main executable alone will not cover a dependent image in an embedded
framework or extension directory.

## Present vphone behavior

- `GuestIrisinInstaller.ensureRootHideLinks` seeds the bootstrap root and
  `bin`, `sbin`, `usr/bin`, `usr/sbin`, `usr/lib`, `usr/libexec`, and
  `usr/lib/pam` at initial bootstrap installation and on `vphoned` startup.
  The PAM modules need their own link: without it sshd reports
  `PAM: initialisation failed`. It does not cover
  `Applications/*.app` installed later.
- Irisin unpacks packages without RootHide dpkg's hook, so nothing linked
  deeper package directories. sudo failed (#520) because
  `usr/libexec/sudo/libsudo_util.0.dylib` could not load
  `@loader_path/.jbroot/usr/lib/libvrootapi.dylib`; `apt/methods`,
  `engines-3` and `ossl-modules` have the same gap. After the fixed list,
  `ensureRootHideMachOLinks` walks `bin`, `sbin`, `usr` (minus `usr/share`
  and `usr/include`) and `Library` without following symlinks, reads each
  regular file's magic until a directory shows a thin 64-bit or fat Mach-O,
  and creates `../`×depth + `.jbroot` there. A directory with any `.jbroot`
  entry is skipped, and a failed link is not fatal. It runs at install, on
  `vphoned` startup, and one second after the root's `Library/dpkg` changes:
  `watchBootstrapPackages` keeps a vnode watch on that directory, which
  Irisin, apt and dpkg all rewrite when a package operation finishes.
- The spawn hooks cannot replace that watch. `sudo` is usually run from a
  mobile shell (an ssh session, or `ighostvtd-io`'s zsh), and mobile cannot
  create a link in the root-owned `usr/libexec/sudo`. On 26.6.2, with the
  link removed and the hooks in place, sudo still failed from a mobile shell;
  touching `Library/dpkg` recreated the link and `sudo id` returned root.
- launchd (26.6.2) starts jobs through `posix_spawnp`: xpcproxy, and each
  bootstrap LaunchDaemon such as sshd or ighostvtd. Its only `posix_spawn`
  call re-executes `/sbin/launchd`; app spawns reach the interposed
  `posix_spawn` through another image. The launchd hook interposes both. Before
  it did, no xpcproxy or bootstrap daemon loaded SystemHook, so an ssh
  session had none either.
- SystemHook is chain-loaded into every child, by launchd and by SystemHook's
  `posix_spawn`, `posix_spawnp` and `execve`, whatever the child's
  environment says; only launchd re-executing itself is left alone. A process
  that rebuilds its child's environment, as sshd does for a session, would
  otherwise drop it. `DISABLE_TWEAKS`, `_SafeMode` and `_MSSafeMode` are
  honored in the child's constructor, which then skips ElleKit's
  TweakLoader. Only bootstrap, app, xpcproxy and camera processes are logged.
- SystemHook's constructor loads `TweakLoader.dylib` with `dlopen`, but a
  required `LC_LOAD_DYLIB` is resolved by dyld before that constructor. An
  in-process repair there cannot recover this launch failure. SystemHook in
  the parent of a chained spawn could repair links before spawning instead.
- vphone's `apps.install` calls IcliKit, which installs into an application
  container without creating RootHide loader links. The Irisin bootstrap
  installer and Irisin's own package installer are separate installation
  paths. Neither existing vphone link seeding nor a hook on `dpkg` alone
  covers every one of these paths.

## Implemented boundary

The shared `RootHideLoaderLinks` helper runs before the final spawn in both
`launchdhook-vphone` and `SystemHook-vphone`. It accepts executable paths
inside the selected RootHide bootstrap, including `/var` and `/private/var`
spellings, and creates a relative `.jbroot` link in the executable's own
directory. It resolves and validates an existing link, refuses a non-link or
a link to another root, and never writes into an unrelated app container.
The spawn result is preserved if link creation fails; the hooks log the
failure. It then reads the executable's arm64 load commands: each
`@loader_path/.jbroot/…` `LC_RPATH` directory gets a link, and each
`LC_LOAD_DYLIB`-family dependency that resolves inside the root, directly or
through those rpaths, gets a link in its directory and is walked in turn.
sudo is the case this covers: `usr/bin/sudo` has the rpath
`@loader_path/.jbroot/usr/libexec/sudo` and loads
`@rpath/libsudo_util.0.dylib`. The walk is bounded for PID 1: 32 images,
16 rpaths and 512 KiB of load commands per image, with no symlink followed
out of the root. SystemHook runs the same walk on `TweakLoader.dylib` before
its `dlopen`, which covers `usr/lib/ellekit`. A link needs a writable
directory, so a walk in a mobile process only helps where mobile may write;
the `vphoned` pass above covers the rest.

The fixed bootstrap link seeding in `vphoned` remains necessary. A test
LaunchDaemon loaded after boot spawned without passing through either observed
interposer: a copied RootHide `true` executable under an unlinked app directory
exited with `OS_REASON_DYLD` (status 6), then exited successfully (status 0)
after its `.jbroot` link was created. Removing vphoned's `usr/libexec` seed
could therefore regress the first Irisin daemon launch. That daemon missed
both interposers because launchd started it through `posix_spawnp`, which the
launchd hook did not interpose then. An installer-side link
pass is useful for such jobs and for normal uninstall cleanup, but cannot
cover third-party installers by itself. A dyld path remap could
remove the filesystem links entirely, but would require an early, versioned
patch to the loader, a reliable current-root lookup in every affected process,
and tests for every RootHide load-command form. Its boot-wide reach makes it
the highest-risk option for this specific gap.

## Further verification

1. Check `lstat`/`readlink` of the exact app directory's `.jbroot`, confirm
   `<jbroot>/usr/lib/libroothide.dylib` exists, and inspect the executable's
   `LC_LOAD_DYLIB` entries. Keep the original crash report.
2. Reproduce the missing-link launch on a clone. Confirm launchd logs the
   final physical executable and that the failure happens before SystemHook
   logs its constructor for that PID.
3. With the link in place before spawn, confirm dyld opens the target library,
   TrollSpeed starts, and any later failure is diagnosed separately.
4. Exercise a bundle with a framework or extension referencing the same
   install name, a package upgrade, uninstall, safe mode, and a RootHide root
   rerandomization. Confirm existing non-link `.jbroot` entries are preserved.

On 2026-09-25, a copy of `vphone-27.0-cloudos-26.4` booted with both updated
hooks. Its RootHide `usr/lib/libroothide.dylib` existed. The unlinked
`Applications/Xrash.app` launched and became frontmost; launchd logged
`loader-link ... status=0`, and the new `.jbroot` resolved to the selected
root. The same before/after result was observed for `Applications/irisin.app`.
The test LaunchDaemon described above was unloaded and removed. TrollSpeed
was not installed on this VM, so its exact package remains untested here.
The original named VM then booted with the two updated hooks. Xrash and
Irisin each launched frontmost, and each missing app-directory `.jbroot`
was created and resolved to the selected RootHide root.
