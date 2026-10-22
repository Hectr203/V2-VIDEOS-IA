# patch_shared_region_size — widen the arm64 shared region for an iOS 27 userland

## 1. Patch Metadata

- Patch ID: `kernel-boot-shared_region_size` (record: one, same ID)
- Patcher: `KernelCustomFirmwarePatcher.patchSharedRegionSize()` in
  `VPhoneExecutable/VPhoneCommand/FirmwarePatcher/Kernel/CustomFirmwarePatches/Memory/KernelCustomFirmwarePatchSharedRegionSize.swift`
- Declaration: `FirmwareKernelCustomFirmwarePatchSet`
  (`com.vphone.patchset.kernel.cfw`), `bootEssential`, applicability
  `iOSBase: .major(27)` — the same gate `applyIOS27` already uses. On a 26.x /
  18.x base the patch never runs and the kernel stays byte-identical.
- Analysis date: 2026-10-06
- Analyst note: static analysis plus a full guest validation the same day
  (§14). Both vphone600 26.4 variants verified byte-exactly, and the patched
  kernel booted an iPhone18,2 27.0.1 guest to its home screen.

## 2. Patch Goal

The vphone600 26.4 kernel bakes `SHARED_REGION_BASE_ARM64 ==
SHARED_REGION_SIZE_ARM64 == 0x180000000` (6 GiB) into
`vm_shared_region_create`'s arm64 case. An iOS 27.0.1 iPhone18,1/18,2 dyld
shared cache spans `0x185804000` — over 6 GiB at slide 0, so
`_shared_region_map_and_slide` returns `ENOMEM`, dyld cannot map
`libSystem.B.dylib`, and launchd panics on first boot (issue #596; the
`cfw install` region check added the same day refuses such installs with
exactly this explanation).

Zeroing `maxSlide` (row 10 of `0_binary_patch_comparison.md`) only reclaims
the slide: `0x185804000 > 0x180000000` still. The region itself must grow.

Apple's own answer in the iOS 27 kernel is a three-table lookup by cpu class
with the arm64 default row at `0x380000000` (14 GiB). That value cannot be
copied into the 26.4 kernel wholesale — see §12 for the ceiling arithmetic —
so this patch grows the region to `0x1C0000000` (7 GiB), the largest size
whose top stays under the 26.4 kernel's own task-map ceilings, and keeps the
base at `0x180000000`.

## 3. Target Function(s) and Binary Location

The block is the arm64 case of the subtype dispatch inside
`vm_shared_region_create` (inlined into its caller; the research kernel keeps
no local symbol at the site):

| Kernel | Block file offset | Block VA | Branch target |
| --- | --- | --- | --- |
| `kernelcache.research.vphone600` | `0x1E0F4E8` | `0xfffffe0008e134e8` | `0xfffffe0008e13558` |
| `kernelcache.release.vphone600`  | `0x1D074E8` | `0xfffffe0008d0b4e8` | `0xfffffe0008d0b558` |

The two variants are byte-identical across the whole 20-byte block.

## 4. Kernel Source File Location

- `osfmk/vm/vm_shared_region.c`, `vm_shared_region_create` — the
  `case CPU_TYPE_ARM64:` arm of the settings switch
  (`base_address = SHARED_REGION_BASE_ARM64; size = SHARED_REGION_SIZE_ARM64;
  pmap_nesting_start/size = …`). Constants from
  `osfmk/mach/shared_region.h`:
  `SHARED_REGION_BASE_ARM64 0x180000000`, `SHARED_REGION_SIZE_ARM64
  0x180000000`, and `SHARED_REGION_NESTING_BASE/SIZE_ARM64` defined as the
  same two. Confidence: **high** (xnu checkout in `Research/Reference/xnu`
  matches the disassembly register-for-register).

## 5. Function Call Stack

Caller (the `queue_enter`/`vm_shared_region_lastid` loop,
`vm_shared_region_lookup_or_create`) → `vm_shared_region_create` →, with the
patched values in `x26` (base) and `x22` (size):

- `pmap_set_nested` (`0xfffffe0008e52c20` research)
- `csm_setup_nested_address_space(nested_pmap, base, size)` (TXM)
- `pmap_set_shared_region(config_pmap, nested_pmap, base, size)` (SPTM)
- `vm_map_create_options(nested_pmap, 0, size)` — the sub map
- `vm_map_create_options(config_pmap, base, base + size)` — the config map

The `[sp, #0x70]` pair the original `dup`/`str` fills is the
{`pmap_nesting_start`, `pmap_nesting_size`} pair, later consumed as the
nesting range — same values as base/size in this kernel.

## 6. Patch Hit Points

Before (5 instructions; every word identical in both variants):

```
f6 07 61 b2   mov  x22, #0x180000000     ; size — ORR logical-immediate alias
c0 0e 08 4e   dup  v0.2d, x22
e0 1f 80 3d   str  q0, [sp, #0x70]       ; nesting pair {base, size}
fa 07 61 b2   mov  x26, #0x180000000     ; base — same alias
18 00 00 14   b    <common>              ; preserved
```

After (the first four words; the branch untouched):

```
16 00 b8 d2   movz x22, #0xc000, lsl #16
36 00 c0 f2   movk x22, #0x1, lsl #32     ; x22 = 0x1C0000000
fa 07 61 b2   mov  x26, #0x180000000     ; the kernel's own base word, verbatim
fa 5b 07 a9   stp  x26, x22, [sp, #0x70] ; nesting pair {base, size}
```

All three new words are keystone 0.9.2 (`kstool`, Homebrew, outside the
repository), the provenance `ARM64EncoderKeystoneParityTests` pins. The base
word is copied, not re-encoded: `0x180000000` spans bits 31 and 32, so one
`movz` cannot spell it and the kernel's single-instruction ORR
logical-immediate is the only one-instruction form; reproducing it would mean
hand-rolling the logical-immediate encode table the guardrails keep out.

Why a block rewrite at all: because stock base == size, the compiler used one
register for both and splatted it into the nesting pair. Patching only the
`mov x22` would leave the `dup`-shaped pair carrying the old constant into
one lane — and the new size needs two lanes of its own, so the pair must
become an `stp` of two different registers. Four instructions in, four out.

## 7. Current Patch Search Logic

- Anchor: raw scan of `__TEXT_EXEC` for `dup Vd.2d, Xn`
  (`word & 0xFFFFFC00 == 0x4E080C00`; Rn/Rd free) — the one instruction only
  this block issues between two `#0x180000000` materialisations.
- Capstone window confirm at each hit (`dupOff-4 ..< dupOff+16`):
  i0 `mov Xs, #0x180000000` (mov/movz 2-operand or unaliased `orr Xs, xzr,
  #…` 3-operand), i1 `dup Vd.2d, Xs` sourcing i0's register, i2
  `str Vd, [sp, #disp]` with the same vector lane (dup says `v0`, str says
  `q0`; Capstone gives them different register ids, so lanes are compared by
  number), i3 `mov Xb, #0x180000000` with `Xb != Xs`, i4 an unconditional `b`.
- Exactly one hit must survive, else the patch fails and logs how many
  candidates it saw. i0 is taken as the size register and i3 as the base
  register — the layout both shipped variants use; the roles are not
  distinguishable inside the window alone, only from the downstream call
  flow (§5).
- The rewrite reuses the block's own registers and pair slot, so a future
  kernel with a different allocation still patches correctly.
- Replacement bytes come only from `ARM64Encoder.encodeMovzX`,
  `encodeMovkX`, `encodeStpX` plus the verified original base word.

## 8. Pseudocode (Before)

```
case cpu_subtype class of
0x100000c (arm64, 16k):  base = 0x180000000; size = 0x180000000;
                         nesting = {0x180000000, 0x180000000}
0x200000c (arm64_32):    base = 0x1a000000;  size = 0x88000000; …
0xc (arm):               base = 0x40000000;  size = 0x40000000; …
```

## 9. Pseudocode (After)

```
0x100000c (arm64, 16k):  base = 0x180000000; size = 0x1C0000000;
                         nesting = {0x180000000, 0x1C0000000}
(others untouched)
```

## 10. Validation (Static Evidence)

- `ipsw macho disass` over both decompressed kernels around the block and
  downstream through the `csm_setup_nested_address_space` /
  `pmap_set_shared_region` / both `vm_map_create_options` calls; register
  flow matches `vm_shared_region.c` exactly (`x1/x2 = base/size` in the
  first, `x2/x3` in the second, `0,size` and `base,base+size` in the maps).
- The dyld cache contract read from the 24A446 iPhone18,2 IPSW: header of the
  main cache records `sharedRegionStart 0x180000000`,
  `sharedRegionSize 0x185804000`, `maxSlide 0x20000000`; subcache
  `sharedRegionStart` fields run `0x180400000 … 0x2dd25c000` — the whole
  cache maps inside `[0x180000000, 0x340000000)`.
- Unit tests: `KernelCustomFirmwarePatchSharedRegionSizeTests` (synthetic
  kernels: stock rewrite, idempotence over patched bytes, wrong-constant
  refusal, register/disp genericity) plus the env-gated
  `VPHONE_VP600_KERNEL` case over a real IM4P, which pinned the offsets in
  §3 on both variants.

## 11. Expected Failure/Panic if Unpatched

Exactly issue #596: `dyld cache '(null)' not loaded: syscall to map cache
into shared region failed` → `initproc failed to start -- Library not loaded:
/usr/lib/libSystem.B.dylib`. (Since the refusal commit, `cfw install` stops
earlier with `RegionOverflow` naming both sizes.)

## 12. Risk / Side Effects

- **Why not Apple's 0x380000000:** the 26.4 kernel's task-map ceilings are
  compile-time constants derived from the stock 6 GiB region —
  `ARM64_MIN_MAX_ADDRESS = 0x320000000`, `ARM64_MAX_OFFSET_DEVICE_SMALL
  0x358000000`, `LARGE 0x458000000` (`osfmk/arm64/sptm/pmap/pmap.c`). iOS 27
  raised its own ceilings along with the region; this kernel did not, and a
  `[0x180000000, 0x500000000)` region would overrun every ceiling, leaving
  processes no address space above it. `0x1C0000000` tops the region at
  `0x340000000`, under even the SMALL tier, so no other constant needs to
  move. A guest with ≤1 GiB RAM (min tier `0x320000000`) still would not fit,
  but iOS 27 userland does not run there anyway.
- **Headroom:** worst known cache + full slide = `0x185804000 + 0x20000000 =
  0x1A5804000` ≤ `0x1C0000000`, so even with `maxSlide` intact every mapping
  fits deterministically (kernel picks 16 KiB-aligned slides strictly below
  `maxSlide`; `size + maxSlide ≤ region` is the sufficient test, row 10 of
  the comparison doc).
- **commpage** lives at fixed absolute addresses, not region-relative, so it
  does not move.
- **SPTM/TXM acceptance of the wider nesting range is proven by the 2026-10-06
  boot** (§14): `pmap_set_shared_region` and `csm_setup_nested_address_space`
  took the `0x1C0000000` range and the guest reached userspace.
- **`patch-dsc-maxslide` still zeroes the 27 cache's slide** — it self-gates
  against the stock `0x180000000`, so a 27 install maps at slide 0 inside the
  widened region. That is the conservative first-boot posture (the slide-0
  path is what real 17,3 27.0.1 guests already boot on). Keeping the full
  512 MiB slide is a possible follow-up: teach the verb the patched region
  and pass it from `cfw install` on 27.x.

## 13. Symbol Consistency Check

No symbol at the site in either variant (`ipsw macho a2s` finds none in the
`com.apple.kernel` entry); identification is structural, from the subtype
dispatch and the §5 call flow. `match` by structure, no symbol to mismatch
with. The XNU source in `Research/Reference/xnu` is the same generation
(cloudOS 26.4) — constants and call order agree instruction for instruction.

## 14. Open Questions and Confidence

- ~~Does SPTM and TXM accept a nesting range of `0x1C0000000`?~~ **Answered by
  the 2026-10-06 validation** — they do. Procedure as run: bundle
  `2.6.0-local.0d5e6f90` (this branch) installed local, `vm set-bundle
  issue596-ip18` (the half-built #596 repro machine, whose `cfw install` had
  refused that morning), `cfw update-kernel` re-patched the pristine
  kernelcache from `FirmwareOriginals` with the machine's standard selection —
  receipt records `kernel-boot-shared_region_size` under writer
  `cfw update-kernel`, 95 kernel patches total — and swapped it into Preboot
  under the original IM4M; `cfw install` then passed the region check against
  `0x1C0000000` and completed (vphoned installed, maxSlide still zeroed by
  `patch-dsc-maxslide`, restore tree cleaned). `vm start --headless --wait`
  returned with vphoned answering: `dyld[1]: dyld cache mapped system-wide`,
  0 `panic` lines in the console log, `device.info` reporting
  `ios_version 27.0.1` with vphoned at pid 112, `apps.foreground`
  `com.apple.springboard`, screen 440x956 @3x on at the lock screen.
- ~~Does iOS 27 userland tolerate the region being smaller than its own
  `0x380000000` expectation?~~ It does not observe the difference on this
  path: the whole 24A446 cache maps from `sharedRegionStart 0x180000000` with
  every subcache header address resolving inside `[0x180000000, 0x340000000)`,
  and userspace ran to the home screen as above.
- Confidence: **high** — bytes, semantics and now guest boot are all proven.
