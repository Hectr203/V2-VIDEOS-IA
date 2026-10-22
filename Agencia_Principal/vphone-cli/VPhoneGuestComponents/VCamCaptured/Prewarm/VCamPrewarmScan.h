#ifndef VCAM_PREWARM_SCAN_H
#define VCAM_PREWARM_SCAN_H

// Locates cameracaptured's call to PrewarmThreadSafeSBPs by decoding the
// instructions of FigCapturePreloadShaders and the block it dispatches. It
// reads words only, never the process, so the host test runs the same code
// over synthetic and real instruction streams.

#include <stddef.h>
#include <stdint.h>

#pragma GCC visibility push(hidden)

// The instructions the scan matches and the one the patch writes.
#define VCC_A64_NOP 0xD503201Fu
#define VCC_A64_PACIBSP 0xD503237Fu

// An image's __text: `words` as readable memory, `addr` the address the
// code runs at (the same as `words` in the guest; anything in a test).
typedef struct {
  const uint32_t *words;
  uintptr_t addr;
  size_t count;
} vcc_prewarm_text_t;

typedef struct {
  uintptr_t internal;      // FigCapturePreloadShadersInternal
  uintptr_t block_invoke;  // the invoke function of the block it dispatches
  uintptr_t call_site;     // `bl PrewarmThreadSafeSBPs` in that block
  uintptr_t prewarm;       // PrewarmThreadSafeSBPs
} vcc_prewarm_site_t;

// Finds the call starting from the address of the exported
// FigCapturePreloadShaders. Returns 0 and fills *out on success, or the
// negative number of the step that failed:
//   -1 the entry or its branch target is outside __text or not a function
//   -2 the preload function signs no block invoke, or more than one
//   -3 the block invoke is outside __text or not a function
//   -4 the block holds no call of a captured value, or more than one
int vcc_find_prewarm_call(const vcc_prewarm_text_t *text,
                          uintptr_t preload_entry,
                          vcc_prewarm_site_t *out);

#pragma GCC visibility pop

#endif
