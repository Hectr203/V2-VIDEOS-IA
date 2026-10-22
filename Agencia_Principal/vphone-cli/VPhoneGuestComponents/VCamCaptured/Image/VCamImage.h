#ifndef VCAM_IMAGE_H
#define VCAM_IMAGE_H

// Runtime view of a loaded Mach-O image (CMCapture) and the structural
// scans and in-place code patches built on it. No image VMAs are
// hardcoded: everything is recovered from dlsym anchors, load commands and
// instruction patterns.

#include <mach-o/loader.h>
#include <mach-o/nlist.h>

#include "VCamCapturedPrivate.h"

#pragma GCC visibility push(hidden)

#define VCC_MAX_DATA_RANGES 8

typedef struct {
  uintptr_t start;
  uintptr_t end;
} vcc_range_t;

typedef struct {
  const struct mach_header_64 *mh;
  intptr_t slide;
  const uint32_t *text;
  size_t text_words;  // count of 4-byte instructions
  vcc_range_t data_ranges[VCC_MAX_DATA_RANGES];
  unsigned data_range_count;
  // LC_SYMTAB pointers (may be 0 on DSC dylibs that strip private symbols
  // from the per-image symtab; callers must handle gracefully).
  const struct nlist_64 *symtab;
  const char *strtab;
  uint32_t nsyms;
} vcc_image_t;

// MARK: - resolution (VCamImageResolution.m)

// Resolves the image that defines `anchor_sym`. Returns 0 on success, a
// negative step number on failure.
int vcc_image_resolve(vcc_image_t *out, const char *anchor_sym);

// Walks the image's LC_SYMTAB for `name`. Returns the slid VMA, or 0.
uintptr_t vcc_lookup_lc_symtab(const vcc_image_t *img, const char *name);

// PC of the per-source ownership `cbz w0; cbz w25` pair inside
// _captureSourceServer_handleCopySourcesMessage, or 0.
uintptr_t vcc_find_per_source_filter(const vcc_image_t *img);

// PC of the client-allowlist filter chain, or 0. On a hit, writes the
// signing-identifier and prewarming-bundle function addresses.
uintptr_t vcc_find_filter_chain(const vcc_image_t *img,
                                uintptr_t *si_fn_out,
                                uintptr_t *prewarm_fn_out);

// Absolute page-aligned target of `adrp Xn, <page>` at adrp_pc.
uintptr_t vcc_adrp_target(uintptr_t adrp_pc, uint32_t adrp);

// YES when the pointer stored at slot_addr is a heap-allocated CFArray.
BOOL vcc_slot_value_is_cfarray(uintptr_t slot_addr);

// Collects every `bl <X>; adrp; str x0, [Xn, #imm]` store target in the
// first maxInsns instructions of func. Returns the count written.
unsigned vcc_collect_call_then_store_globals(uintptr_t func,
                                             unsigned maxInsns,
                                             unsigned lookahead,
                                             uintptr_t *out_addrs,
                                             unsigned cap);

// A CFString constant resolved by symbol name, or NULL.
CFStringRef vcc_cfconst(const char *symname);

// A function resolved by symbol name (PAC-signed for a C call), or NULL.
void *vcc_dlsym_fn(const char *name);

// MARK: - code patching (VCamCodePatch.m)

// Rewrites the two instructions at pc to NOP. Returns 1 on success.
int vcc_patch_two_nops(uintptr_t pc);

// Rewrites the word at pc from expected_word to new_word. Returns 1 on
// success, 0 when the word does not match or the page cannot be written.
int vcc_patch_word(uintptr_t pc, uint32_t expected_word, uint32_t new_word);

// Rewrites every `needle` word in __text to `replacement`. Returns the
// number of words patched.
unsigned vcc_scan_and_patch(const vcc_image_t *img,
                            uint32_t needle,
                            uint32_t replacement,
                            const char *what);

#pragma GCC visibility pop

#endif
