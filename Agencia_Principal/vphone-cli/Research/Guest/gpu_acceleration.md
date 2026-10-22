# GPU Acceleration in the Guest

Upstream issue Lakr233/vphone-cli#22 asks two things: why a Metal check run
inside the guest printed `device: (null)`, and why a guest whose apps do get
Metal is still laggy for a while after every boot. This note answers both from
measurements taken on 2026-10-04: macOS 27.0.1 (26A434), Apple M5 Pro,
cloudOS 26.4 (23E5207q) kernel, iPadOS 26.6.2 (23G90) userland, iPad Pro guests
`hz120-ipadpro` and `gpuaccel-ipad`. The measuring method is in
`display_refresh_rate.md`.

## The GPU Is in Use

The guest's Metal device is `Apple Paravirtual device GPU`. Each guest process
that uses Metal has a host `com.apple.gpusw.ParavirtualizedGraphicsGPUTask`
process that replays its commands on the host GPU through the host's own AGX
driver.

The issue's check, extended with a compute pass (a 2048×2048 RGBA16F texture, 64
`sin`/`cos` iterations per pixel) and run as a command-line tool:

| | Guest | Host (M5 Pro) |
| --- | --- | --- |
| GPU time for the pass, warm | 2.3–3.8 ms | 2.0–3.3 ms |
| Empty command buffer, commit and `waitUntilCompleted` | 0.12–0.27 ms | 0.02 ms |
| Compile from source and build the pipeline, warm | 80–220 ms | 265 ms uncached |
| The same, first time in a boot | 4.3–8.3 s | — |

GPU work runs at about native speed. A synchronous round trip costs six to
thirteen times the host's, and the first compile in a boot is slow.

The device reports `MTLGPUFamilyCommon3` and argument buffers tier 1, and no
Apple family or Metal 3. An app that requires those sees a lesser GPU than the
host has.

## `device: (null)` Outside an App

Reproduced on 26.6.2 with the tool run as root from a launchd job:

```
kernel: System Policy: MetalTest(648) deny(1) iokit-open-user-client AppleParavirtDeviceUserClient
kernel: IOUC AppleParavirtDeviceUserClient failed sandbox in process pid 648, MetalTest
MetalTest: Failed to create an IOGPUDevice... IOServiceOpen returned kIOReturn(0xE00002E2)
```

A 26.x sandbox knows nothing of the research board's paravirtual devices. An
app's container profile lets the app open the GPU's user client; the platform
policy every other process falls under does not. So Metal works in apps and in
the system UI, and a daemon or a command-line tool gets no device. The same gate
refused, on the same guest:

| User client | Refused to |
| --- | --- |
| `AppleParavirtDeviceUserClient` (Metal) | the command-line tool |
| `AppleVideoToolboxParavirtualizationUserClient` (video decoder) | `com.apple.WebKit` |
| `AppleVirtIONeuralEngineDeviceUserClient` (Neural Engine) | `spotlightknowledged`, `callservicesd` |
| `IOSurfaceAcceleratorParavirtClient` (scaler) | `vphoned` |

On a 27 base this gate is already off: `kernel-boot-iouc_sandbox_gate` is
boot-essential there, because 27 refuses backboardd its framebuffer. The patch
`kernel-cfw-paravirt_user_clients` makes a narrower edit on a 26.x or 18.x base,
and `standard` turns it on (see "On in `standard`" below). With it, on
`gpuaccel-ipad`, the tool prints `device: Apple Paravirtual device GPU` and the
console holds no `failed sandbox` line at all.

### Narrow by class name

The patch does not flip the whole gate. The deny block ends by logging
`IOUC %s failed sandbox in process %s`, and its first `%s` is the class name —
already in `x0` as a C string eight bytes before the fail-log `adrp`. The patch
overwrites that `ldr Xt, [sp, #imm]` with a branch to a code cave that reads the
first eight bytes of the class name, and branches to the gate's NotPermitted
allow target only when they equal one of four prefixes — `ApplePar`, `AppleVid`,
`AppleVir`, `IOSurfac` (AppleParavirt\*, AppleVideoToolboxParavirt\*,
AppleVirtIO\*, IOSurfaceAcceleratorParavirtClient). Any other class runs the
displaced `ldr` and falls through to the real deny, so every other sandbox denial
stays. The cave's fixed words are verified by clang/as assembly and a capstone
round-trip; the two position-dependent branches come from `ARM64Encoder`. The
anchor is the fail-string xref, the NotPermitted allow target and the deny-entry
`cbnz`, the same three the broad gate uses; the declaration is
`kernel-cfw-paravirt_user_clients` (sites `.redirect` and `.cave`).

Verified on a fresh iPad Pro guest (`narrowtest-ipad`, 26.6.2, both opt-in
patches on): it boots, and a plain command-line tool prints

```
RootDomainUserClient IOServiceOpen -> 0xe00002e2 (denied)
Metal device -> ALLOWED
```

— the paravirtual GPU opens from a daemon context while a non-allowlisted client
is still refused. It first shipped off in `standard`, as a per-VM choice; it is
now on, for the reason below.

What it does not change: HLS video in Safari already played at the stream's
60 frames per second without it, with `mediaplaybackd` at 9% of a core and
`videocodecd` at 4%, so WebKit being refused the decoder is not a visible cost
there.

### On in `standard`

`standard` stopped blocking the patch on 2026-10-04. The case put forward for it
was `cameracaptured`, measured on an iPadOS 26.6.2 guest with the old
`standard`. **Corrected the same day:** the crash below is not the gate
refusing the GPU. `cameracaptured` already has a Metal device (its preload
returns early without one), and it dies on a bug in the paravirtual driver's
heap textures, which the patch does not touch ("Heap Textures Have No CPU
Layout" below). What was observed:

- At every boot it prewarms its capture shaders
  (`FigCapturePreloadShadersInternal` → CMCapture `PrewarmThreadSafeSBPs` →
  NRFV3 `-[NRFProcessorV3 prewarm]`) and dies with SIGSEGV at `0xc` inside
  `AppleParavirtGPUMetalIOGPUFamily`. launchd restarts it, and it crash-loops.
- While it does, the first process to touch the AVCapture defaults blocks on a
  synchronous XPC to it (`AVCaptureProprietaryDefaultsSingleton` →
  `csr_ensureClientEstablished`). When a guest app starts recording, that process
  is SpringBoard: Control Center's sensor indicator builds an
  `AVCaptureDeviceDiscoverySession` on the main thread, and the guest UI freezes.
  `audiomxd`'s recording `StartIO` waits 18 s on the same path, and the first
  recording after boot fails.

What stops the crash is `libvcamcaptured` skipping that prewarm, below. The
patch stays on in `standard` for what #22 asked: a daemon or a tool on a 26.x
or 18.x guest gets the GPU and the other paravirtual devices an app already
reaches.

**What this widens.** The edit is at the IOUserClient sandbox gate only. A
process whose own sandbox profile refuses `iokit-open-user-client` for a class
whose name begins with `ApplePar`, `AppleVid`, `AppleVir` or `IOSurfac` is now
let through that gate; every other class is still refused there. The checks a
driver makes itself (entitlements in `newUserClient`, its argument validation)
are untouched; the MACF check before this gate was already opened by
`patch_iouc_failed_macf` (JB-10). The match is on the first eight bytes of the
class name, so it admits every class with one of those prefixes, not only the
four named in the table above: on this research board that means the
paravirtual GPU and device clients (`AppleParavirt*`), the paravirtual
VideoToolbox decoder (`AppleVideo*`), the VirtIO drivers (`AppleVirtIO*`, among
them the Neural Engine) and IOSurface's clients (`IOSurface*`, the root
client as well as the paravirtual accelerator). Who gains: daemons, command-line
tools and system XPC services that run under the platform profile or a profile
of their own — `cameracaptured`, `com.apple.WebKit` processes,
`spotlightknowledged`, `callservicesd`, `vphoned`, and anything a researcher
runs from a shell or a launchd job. Apps gain nothing: their container profile
already opens these devices. On which bases: 26.x and 18.x. On 27 the patch
skips by version, because the boot-essential `kernel-boot-iouc_sandbox_gate`
already opens every user client there, so a 27 guest is unchanged.

**Why that is acceptable for `standard`.** These are research VMs, already
running with the sandbox hooks stubbed and the trust cache admitting anything;
this gate is what still stopped a daemon from opening a device an app opens
freely. The devices are the guest's own paravirtual hardware, their host side
is a per-VM ParavirtualizedGraphics task or the VM process, and every app on the
guest already reaches them, so the attack surface they expose is already
exposed. The narrow patch is still the right shape on 26.x: the broad
gate-off would open `RootDomainUserClient` and every other client too, which
nothing here needs.

A VM that wants the old behaviour unticks the patch
(`vphone-cli fw set-patches <vm> --block kernel-cfw-paravirt_user_clients`) and
re-patches.

The patch was introduced opt-in as `kernel-exp-paravirt_user_clients` and renamed
`kernel-cfw-paravirt_user_clients` when `standard` turned it on, as the naming
rule in `Skills/authoring-patch-sets/SKILL.md` requires. A VM whose
`PatchSelection.plist` still names the old identifier gets `unknownPatch` from
`fw patch` until that entry is removed.

## Lag After Every Boot

Home Screen page swipes on `hz120-ipadpro`, by time since the VM started:

| Since start | On time | Hitches | Host shader compile | Busiest guest processes |
| --- | --- | --- | --- | --- |
| 7 s | 84% | 14 | 59% of a core | dasd 53%, SpringBoard 35%, backboardd 28%, MTLCompilerService 22% |
| 54 s | 89% | 1 | 1% | SpringBoard 25%, backboardd 17% |
| 85 s | 98% | 3 | 0% | backboardd 28%, SpringBoard 28% |

That is the lag the issue describes: after-boot work in the guest plus shaders
being compiled again, gone in about a minute and a half.

The shaders are compiled again because the host's shader cache is never hit.
Opening four apps that had all been opened in earlier boots cost 1.40 CPU-seconds
of host `MTLCompilerService` the first time after a restart and 0.19 the second
time in the same boot.

### Why the cache misses

Virtualization gives ParavirtualizedGraphics a cache directory per VM,
`$DARWIN_USER_CACHE_DIR/com.apple.paravirtualizedgraphics-<number>`, and each
host GPU task keeps its Metal function cache in a `task-<key>` directory under
it. `-[PGRemoteTask calculateCachePathAndExtension:taskRoot:]` picks the key:

- when the device's feature byte `0x36` is set, it reads 60 bytes of the guest's
  task root page and takes the 20 at offset `0x28`; if they are not all zero,
  the key is those 20 bytes in hex, 40 characters;
- otherwise the key is ten random bytes, 20 characters.

Across every VM and every boot on this Mac — 1823 task directories — the name is
20 characters, the random form. Not one is keyed. So the keyed branch is never
taken here, for any guest, which matches the feature byte being off:
`-[_PGDevice features]` returns the struct inline at device `+0x4e4`, and byte
`0x36` of it (device `+0x51a`) is what gates the read. The guest side has nothing
to offer it either: the AppleParavirt kext's task-root setup makes no use of a
cdhash or any 20-byte identity (its code-signing strings are XNU's, not the
kext's).

So this cannot be fixed by a guest firmware patch, which is the only thing
`fw`/`cfw` produce:

- The cache that misses is the **host's**, kept by `PGRemoteTask` in the VM
  service's address space.
- Whether it is keyed is decided **host-side** by that feature byte, which is off
  on this ParavirtualizedGraphics version and is not something the guest is seen
  to switch.
- Even with the feature on, the key is read from the guest's task-root page, and
  giving the guest driver code to populate it would be new kext code — but it
  would still only matter if the host read it, which it does not.

Reaching the host cache would mean changing the host ParavirtualizedGraphics
framework. That is Apple's code on the sealed system volume, and the shipped
bundle runs only system libraries, so it is out of scope. The post-boot
recompile is therefore a limitation of the host paravirtual GPU, not a guest
patch we can write. (A per-app `MTLBinaryArchive` inside a guest app would
persist that app's own pipelines, but that is an app change, not a VM one.)

## Heap Textures Have No CPU Layout

On the iPadOS 26.6.2 iPad Pro guest (cloudOS 26.4 driver, `standard` preset),
`cameracaptured` crashed at every boot and launchd throttled its restarts
(`successive crashes = 6`): `SIGSEGV`, `KERN_INVALID_ADDRESS` at `0xc`, on the
precompilation queue:

```
AppleParavirtGPUMetalIOGPUFamily +35956
NRFV3       -[ToneMappingCurves initWithWithContext:] +1076
NRFV3       -[RawDFInferenceGen initWithMetalContext:] +112
NRFV3       -[RawDFProcessor initWithCommandQueue:] +1048
NRFV3       -[NRFProcessorV3 prewarm] +224
CMCapture   PrewarmThreadSafeSBPs +9392
CMCapture   __FigCapturePreloadShadersInternal_block_invoke_2 +1084
```

While it crash-loops, any process that first touches AVCapture defaults waits
in a synchronous XPC to it. SpringBoard's main thread did, through the Control
Center sensor indicator's `AVCaptureDeviceDiscoverySession`, as soon as an app
started recording, and the guest UI froze until the VM was restarted. audiomxd's
`StartIO` for the recording blocked 18 s the same way, so the first recording
after each boot failed.

It is a bug in the guest's Metal driver, not the sandbox gate above:

- `-[ToneMappingCurves initWithWithContext:]` makes a shared `MTLHeap`
  (`setStorageMode:0`, `setSize:0xc800`), takes textures from it with
  `-newTextureWithDescriptor:`, and fills each with
  `-replaceRegion:mipmapLevel:slice:withBytes:bytesPerRow:bytesPerImage:`.
  `+1076` is the return address of that call.
- `AppleParavirtTexture` keeps a texture's CPU layout in the ivar `_dimension`.
  Every initialiser fills it except
  `-initWithHeap:resource:offset:length:descriptor:`, the one
  `-[AppleParavirtHeap newTextureWithDescriptor:]` uses.
  `-replaceRegion:…` (`0x8c28` in the 23E5207q driver; `+35956` is `0x8c74`)
  starts with `ldr x8, [x0, _dimension]; ldur x19, [x8, #0xc]`. That fault is
  at `0xc`. `-getBytes:…fromRegion:…` reads it the same way.
- The daemon has a Metal device. `FigCapturePreloadShadersInternal` takes
  `[[FigMetalContext metalDevice] newCommandQueue]` first and returns early
  when it is nil, and the faulting frame is a method of a real
  `AppleParavirtTexture`. `kernel-exp-paravirt_user_clients` therefore changes
  nothing here; a guest with it crashes the same way.

Any CPU upload into or readback from a heap-allocated texture faults on this
driver, in any process. The prewarm is where `cameracaptured` meets it at every
launch.

To reveal it in a driver, look for the ivar offset slot named `_dimension` in
`xcrun llvm-objdump --macho --objc-meta-data` (`0x6b7ac` in 23E5207q). List the
`ldrsw xN, [x8, #0x7ac]` loads of it with `ipsw macho disass <driver> --vaddr
0xdc8 --count 41000`. In 23E5207q these are every `AppleParavirtTexture` init
except `initWithHeap:…`, plus `dealloc`, `getBytes:…` and `replaceRegion:…`.

### Skipping the prewarm

`libvcamcaptured` removes the one call to `PrewarmThreadSafeSBPs`
(`VPhoneGuestComponents/VCamCaptured/Prewarm/`). Prewarming only compiles
shaders ahead of first use, and nothing waits on that function: it returns
nothing, stores no global and signals nothing. The rest of the preload still
runs. That includes the processor flags `FigCapturePreloadShadersInternal`
records, `DMPerformMigrationIfNeeded`, and the deferred shader cache copy.
Deferred photo processing waits up to 180 s on that copy's semaphore
(`FigWaitForDeferredShaderCacheCopyCompletion`), so skipping the whole preload
would not be safe.

The hook runs synchronously in the dylib's constructor, so it runs before the
daemon's own launch code, and only when
`/System/Library/Extensions/AppleParavirtGPUMetalIOGPUFamily.bundle` is
installed. The call site is found from the one exported symbol, with no fixed
address:

1. `FigCapturePreloadShaders` is `mov w0, #0; b FigCapturePreloadShadersInternal`.
2. In that function, before its return, exactly one
   `adrp x16; add x16, x16, #imm; pacia x16, xN`. This is the block's invoke,
   `__FigCapturePreloadShadersInternal_block_invoke_2`.
3. In the block, before its return, exactly one `ldr x0, [xN, #0x20]; bl`
   whose target is a function of CMCapture's `__text`. That is
   `PrewarmThreadSafeSBPs(commandQueue)`, with the queue as the block's first
   capture. iOS 27 has a second captured load in the block, but it calls a
   stub outside `__text`.

The `bl` becomes a `nop` (`vcc_patch_word`, which checks the old word first).
Over the real bytes, the scan gives these unslid addresses:

| Build | Internal | Block | Call | `PrewarmThreadSafeSBPs` |
| --- | --- | --- | --- | --- |
| iPadOS 26.6.2 (23G90), and the 26.6 cache | `0x1aeb2f06c` | `0x1aeb2f930` | `0x1aeb2fd68` | `0x1aeb300d4` |
| iOS 27.0 (24A435) | `0x1b0758ff0` | `0x1b07598c4` | `0x1b0759d10` | `0x1b075a070` |

`make -C VPhoneGuestComponents test-vcam-prewarm` runs the same scan over a
synthetic stream with these decoys and checks each refusal.

On a guest, check these:

- `/var/mobile/Media/SimulatedCamera/vcamcaptured.log` (and `vcamcaptured:` in
  the system log) has
  `gpu prewarm: internal 0x… block 0x… call 0x… -> PrewarmThreadSafeSBPs 0x…: skipped`,
  with the 23G90 addresses above. Any `gpu prewarm: kept, …` line names the
  step that refused.
- `logs.crashes` has no `cameracaptured` report newer than the update.
- `services.print` with label `com.apple.cameracaptured` shows
  `successive crashes = 0`.
- Starting a recording in an app neither freezes SpringBoard nor delays the
  first recording.

This does not fix the driver. NRF or RawDF processing during a real capture,
or any other heap texture upload, would still fault.

## Settings That Do Nothing Here

Both are private properties of `VZMacGraphicsDeviceConfiguration`, tried on
`gpuaccel-ipad` across restarts and not kept in the code.

- `_enableProcessIsolation = false`. The guest still had ten host GPU task
  processes and the same pacing: Settings 98% on time either way, Safari 70%
  against 68%, Today View 87% against 88%.
- `_deviceFeatureLevel`. The default, 0, already gives what the highest level,
  5 (the framework logs it as "2027"), gives: Common3 and argument buffers tier 1. Level 1
  ("2022") takes both away.

## Reproducing the Check

The tool is the issue's snippet built for the guest:

```zsh
xcrun -sdk iphoneos clang -arch arm64e -miphoneos-version-min=17.0 -fobjc-arc -O2 \
    -framework Foundation -framework Metal -framework QuartzCore -o MetalTest MetalTest.m
codesign -s - -f MetalTest
```

Copy it with `files.write` (`encoding: base64`), `files.chmod` it to 755, and run
it from a launchd plist with `RunAtLoad` and `StandardOutPath` loaded through
`services.load`. `/var/tmp` is emptied at every boot.
