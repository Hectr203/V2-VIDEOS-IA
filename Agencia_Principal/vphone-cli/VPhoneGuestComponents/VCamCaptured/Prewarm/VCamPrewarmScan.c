#include "VCamPrewarmScan.h"

// The shape the scan expects, as built on iPadOS 26.6.2 (23G90) and
// iOS 27.0 (24A435):
//
//   _FigCapturePreloadShaders:
//     mov  w0, #0
//     b    _FigCapturePreloadShadersInternal
//
//   _FigCapturePreloadShadersInternal:          (one return, at the end)
//     ...
//     adrp x16, block_invoke_2@PAGE
//     add  x16, x16, block_invoke_2@PAGEOFF
//     pacia x16, x8                             the stack block's invoke
//     ...  dispatch_async / dispatch_sync on com.apple.coremedia.precompilation
//
//   ___FigCapturePreloadShadersInternal_block_invoke_2:
//     ...
//     ldr  x0, [x20, #0x20]                     the captured command queue
//     bl   _PrewarmThreadSafeSBPs
//
// Only the last pair loads x0 from a block capture right before calling a
// function of the same __text; other captured loads in that block (27 has
// one) go to stubs outside it.

// MARK: - decoding

#define VCC_SCAN_LIMIT 4096u  // words; each function here is under 600

static int64_t vcc_sign_extend(uint64_t value, unsigned bits) {
  uint64_t sign = 1ull << (bits - 1);
  return (int64_t)((value ^ sign) - sign);
}

static int vcc_is_b(uint32_t w) { return (w & 0xFC000000u) == 0x14000000u; }
static int vcc_is_bl(uint32_t w) { return (w & 0xFC000000u) == 0x94000000u; }

static uintptr_t vcc_branch_target(uintptr_t pc, uint32_t w) {
  return pc + (uintptr_t)(vcc_sign_extend(w & 0x03FFFFFFu, 26) * 4);
}

// ret, retaa, retab.
static int vcc_is_return(uint32_t w) {
  return w == 0xD65F03C0u || w == 0xD65F0BFFu || w == 0xD65F0FFFu;
}

// adrp x16, <page>
static int vcc_is_adrp_x16(uint32_t w) {
  return (w & 0x9F00001Fu) == 0x90000010u;
}

static uintptr_t vcc_adrp_page(uintptr_t pc, uint32_t w) {
  uint64_t imm = (((uint64_t)(w >> 5) & 0x7FFFFu) << 2) | ((w >> 29) & 0x3u);
  return (pc & ~(uintptr_t)0xFFF) +
         (uintptr_t)(vcc_sign_extend(imm, 21) * 4096);
}

// add x16, x16, #imm (unshifted)
static int vcc_is_add_x16_x16(uint32_t w) {
  return (w & 0xFFC003FFu) == 0x91000210u;
}

// pacia x16, <any>
static int vcc_is_pacia_x16(uint32_t w) {
  return (w & 0xFFFFFC1Fu) == 0xDAC10010u;
}

// ldr x0, [x<n>, #0x20], n != sp: the first capture of a block literal.
static int vcc_is_ldr_x0_capture(uint32_t w) {
  return (w & 0xFFFFFC1Fu) == 0xF9401000u && ((w >> 5) & 0x1Fu) != 31;
}

// MARK: - text access

static const uint32_t *vcc_word(const vcc_prewarm_text_t *t, uintptr_t addr) {
  if (addr < t->addr || (addr & 3)) return NULL;
  size_t index = (addr - t->addr) / 4;
  return index < t->count ? &t->words[index] : NULL;
}

static size_t vcc_words_from(const vcc_prewarm_text_t *t, uintptr_t addr) {
  size_t left = t->count - (addr - t->addr) / 4;
  return left < VCC_SCAN_LIMIT ? left : VCC_SCAN_LIMIT;
}

static int vcc_is_function(const vcc_prewarm_text_t *t, uintptr_t addr) {
  const uint32_t *w = vcc_word(t, addr);
  return w && *w == VCC_A64_PACIBSP;
}

// Another function starts here: the scans stop at a return or at the next
// prologue, whichever comes first.
static int vcc_ends_function(const uint32_t *w, size_t i) {
  return vcc_is_return(w[i]) || (i > 0 && w[i] == VCC_A64_PACIBSP);
}

// MARK: - scan

int vcc_find_prewarm_call(const vcc_prewarm_text_t *text,
                          uintptr_t preload_entry,
                          vcc_prewarm_site_t *out) {
  // 1. The exported entry tail-calls the internal function. Accept the
  //    entry itself when it branches nowhere first (a build that folded
  //    the two).
  const uint32_t *entry = vcc_word(text, preload_entry);
  if (!entry) return -1;
  uintptr_t internal = preload_entry;
  size_t entry_words = vcc_words_from(text, preload_entry);
  for (size_t i = 0; i < 4 && i < entry_words; i++) {
    if (vcc_is_b(entry[i])) {
      internal = vcc_branch_target(preload_entry + i * 4, entry[i]);
      break;
    }
    if (vcc_is_bl(entry[i]) || vcc_ends_function(entry, i)) break;
  }
  if (!vcc_is_function(text, internal)) return -1;

  // 2. The block's invoke is the one function pointer the internal
  //    function signs with pacia x16.
  const uint32_t *fn = vcc_word(text, internal);
  size_t fn_words = vcc_words_from(text, internal);
  uintptr_t invoke = 0;
  unsigned invokes = 0;
  for (size_t i = 0; i < fn_words && !vcc_ends_function(fn, i); i++) {
    if (i < 2 || !vcc_is_pacia_x16(fn[i])) continue;
    if (!vcc_is_add_x16_x16(fn[i - 1]) || !vcc_is_adrp_x16(fn[i - 2])) continue;
    invoke = vcc_adrp_page(internal + (i - 2) * 4, fn[i - 2]) +
             ((fn[i - 1] >> 10) & 0xFFFu);
    invokes++;
  }
  if (invokes != 1) return -2;
  if (!vcc_is_function(text, invoke)) return -3;

  // 3. In the block, the one call whose argument is the block's first
  //    capture and whose callee is a function of this image.
  const uint32_t *block = vcc_word(text, invoke);
  size_t block_words = vcc_words_from(text, invoke);
  uintptr_t site = 0, callee = 0;
  unsigned calls = 0;
  for (size_t i = 1; i < block_words && !vcc_ends_function(block, i); i++) {
    if (!vcc_is_bl(block[i]) || !vcc_is_ldr_x0_capture(block[i - 1])) continue;
    uintptr_t pc = invoke + i * 4;
    uintptr_t target = vcc_branch_target(pc, block[i]);
    if (!vcc_is_function(text, target)) continue;
    site = pc;
    callee = target;
    calls++;
  }
  if (calls != 1) return -4;

  out->internal = internal;
  out->block_invoke = invoke;
  out->call_site = site;
  out->prewarm = callee;
  return 0;
}
