// Keeps cameracaptured from prewarming its GPU sample buffer processors on
// the paravirtual GPU, where the prewarm faults at every launch.
//
// At launch the daemon calls FigCapturePreloadShaders. The block it queues
// on com.apple.coremedia.precompilation calls PrewarmThreadSafeSBPs(queue),
// which loads each video processor bundle and runs its -prewarm. NRFV3's
// runs -[RawDFProcessor initWithCommandQueue:] ->
// -[RawDFInferenceGen initWithMetalContext:] ->
// -[ToneMappingCurves initWithWithContext:], which makes textures from a
// shared MTLHeap and fills them with -replaceRegion:mipmapLevel:slice:
// withBytes:bytesPerRow:bytesPerImage:. The guest's Metal driver,
// AppleParavirtGPUMetalIOGPUFamily (cloudOS 26.4, 23E5207q), keeps a
// texture's CPU layout in the AppleParavirtTexture ivar _dimension. Every
// initialiser fills it except -initWithHeap:resource:offset:length:
// descriptor:, the one -[AppleParavirtHeap newTextureWithDescriptor:] uses,
// and -replaceRegion: reads it without a check: KERN_INVALID_ADDRESS at
// 0xc. The daemon has a working Metal device (the preload stops by itself
// when it has none: it needs a command queue first), so this is not the
// sandbox gate on the GPU's user client and kernel-exp-paravirt_user_clients
// does not change it. While the daemon crash-loops, every process that
// first touches AVCapture blocks in a synchronous XPC to it; SpringBoard's
// main thread among them.
//
// Prewarming only compiles shaders before first use, and nothing waits on
// PrewarmThreadSafeSBPs: it returns nothing, stores no global and signals
// nothing. So with the paravirtual driver installed, its one call is
// replaced with a NOP. The rest of the preload still runs: the processor
// flags it records, the data migration, and the deferred shader cache copy
// whose semaphore deferred photo processing waits on for up to 180 s.
// See Research/Guest/gpu_acceleration.md.

#include <ptrauth.h>

#include "VCamImage.h"
#include "VCamPrewarmScan.h"

// Present on every guest this project restores; its absence means another
// GPU, whose driver has not been seen to have the heap texture fault.
static const char *const kParavirtMetalDriver =
    "/System/Library/Extensions/AppleParavirtGPUMetalIOGPUFamily.bundle/"
    "AppleParavirtGPUMetalIOGPUFamily";

void vcc_install_gpu_prewarm_skip(void) {
  if (access(kParavirtMetalDriver, F_OK) != 0) {
    vcc_log(@"gpu prewarm: kept, no paravirtual Metal driver (errno %d)",
            errno);
    return;
  }

  vcc_image_t img;
  int rc = vcc_image_resolve(&img, "FigCapturePreloadShaders");
  if (rc != 0) {
    vcc_log(@"gpu prewarm: kept, CMCapture not resolved (step %d)", rc);
    return;
  }
  void *entry = ptrauth_strip(dlsym(RTLD_DEFAULT, "FigCapturePreloadShaders"),
                              ptrauth_key_function_pointer);

  vcc_prewarm_text_t text = {img.text, (uintptr_t)img.text, img.text_words};
  vcc_prewarm_site_t site;
  rc = vcc_find_prewarm_call(&text, (uintptr_t)entry, &site);
  if (rc != 0) {
    vcc_log(@"gpu prewarm: kept, PrewarmThreadSafeSBPs call not found "
            @"(step %d)", rc);
    return;
  }

  // Unslid addresses, as `ipsw dyld symaddr` prints them for this cache.
  uintptr_t slide = (uintptr_t)img.slide;
  uint32_t call = *(const uint32_t *)site.call_site;
  int ok = vcc_patch_word(site.call_site, call, VCC_A64_NOP);
  vcc_log(@"gpu prewarm: internal 0x%lx block 0x%lx call 0x%lx -> "
          @"PrewarmThreadSafeSBPs 0x%lx: %@",
          (unsigned long)(site.internal - slide),
          (unsigned long)(site.block_invoke - slide),
          (unsigned long)(site.call_site - slide),
          (unsigned long)(site.prewarm - slide),
          ok ? @"skipped" : @"patch failed, kept");
}
