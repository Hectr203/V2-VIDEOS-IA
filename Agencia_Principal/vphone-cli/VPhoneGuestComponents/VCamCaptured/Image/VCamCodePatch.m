#include <libkern/OSCacheControl.h>
#include <mach/mach.h>
#include <pthread.h>

#include "VCamImage.h"

// MARK: - in-place code patching

// The patch targets are shared-cache __text pages of CMCapture — live XPC
// server code that other cameracaptured threads execute at any moment.
// vm_protect(RW) strips the execute permission for the whole page until
// the matching vm_protect(RX) returns, so a thread whose PC lands in that
// page inside the window dies with SIGBUS KERN_PROTECTION_FAILURE (two
// such crashes were caught on the flashlight and capturesource reply
// queues while this very patcher was in-flight). Stopping every other
// thread for the few-hundred-µs window makes the flip safe; the stopped
// section runs no locks, no allocation and no logging, so a thread caught
// holding any userspace lock cannot deadlock us.
static pthread_mutex_t s_patch_world_lock = PTHREAD_MUTEX_INITIALIZER;

typedef struct {
  thread_act_t *threads;
  mach_msg_type_number_t count;
} vcc_stopped_world_t;

static void vcc_stop_world(vcc_stopped_world_t *world) {
  world->threads = NULL;
  world->count = 0;
  if (task_threads(mach_task_self(), &world->threads,
                   &world->count) != KERN_SUCCESS) {
    return;
  }
  mach_port_t self = mach_thread_self();
  for (mach_msg_type_number_t i = 0; i < world->count; i++) {
    if (world->threads[i] != self) {
      (void)thread_suspend(world->threads[i]);
    }
  }
  mach_port_deallocate(mach_task_self(), self);
}

static void vcc_resume_world(vcc_stopped_world_t *world) {
  if (!world->threads) return;
  mach_port_t self = mach_thread_self();
  for (mach_msg_type_number_t i = 0; i < world->count; i++) {
    if (world->threads[i] != self) {
      (void)thread_resume(world->threads[i]);
    }
    mach_port_deallocate(mach_task_self(), world->threads[i]);
  }
  mach_port_deallocate(mach_task_self(), self);
  vm_deallocate(mach_task_self(), (vm_address_t)world->threads,
                world->count * sizeof(thread_act_t));
  world->threads = NULL;
  world->count = 0;
}

// Patch two consecutive instructions starting at `pc` to NOP. iOS __TEXT
// is W^X-enforced + TXM-validated. Try in order:
//  (a) vm_protect with VM_PROT_COPY: kernel COWs the page into an anon
//      mapping and grants RW. Standard iOS-hooker recipe (libhooker etc).
//  (b) vm_allocate scratch + memcpy + vm_remap(OVERWRITE|FIXED) overlay.
// Either way, scratch_writable -> patch -> set RX -> icache flush.
// Returns 1 on success. All logging happens after the world is resumed:
// inside the stopped section nothing may touch malloc or a lock a frozen
// thread could be holding.
int vcc_patch_two_nops(uintptr_t pc) {
  uintptr_t page_size = (uintptr_t)getpagesize();
  uintptr_t page_start = pc & ~(page_size - 1);
  uintptr_t end = pc + 8;
  uintptr_t page_end =
      ((end + page_size - 1) & ~(page_size - 1));
  vm_size_t span = (vm_size_t)(page_end - page_start);
  mach_port_t self_task = mach_task_self();
  int result = 0;
  kern_return_t kr_a_copy = KERN_SUCCESS, kr_a_rx = KERN_SUCCESS;
  kern_return_t kr_b = KERN_SUCCESS;

  pthread_mutex_lock(&s_patch_world_lock);
  vcc_stopped_world_t world;
  vcc_stop_world(&world);

  // (a) vm_protect with VM_PROT_COPY (= 0x10) to force COW.
  kern_return_t kr = vm_protect(
      self_task,
      (vm_address_t)page_start,
      span,
      FALSE,
      VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
  kr_a_copy = kr;
  if (kr == KERN_SUCCESS) {
    uint32_t nop = 0xD503201Fu;
    ((uint32_t *)pc)[0] = nop;
    ((uint32_t *)pc)[1] = nop;
    kr = vm_protect(
        self_task,
        (vm_address_t)page_start,
        span,
        FALSE,
        VM_PROT_READ | VM_PROT_EXECUTE);
    kr_a_rx = kr;
    if (kr == KERN_SUCCESS) {
      sys_icache_invalidate((void *)pc, 8);
      result = 1;
    }
  }
  if (result) goto out;

  // (b) Scratch allocation + vm_remap with FIXED|OVERWRITE.
  {
    vm_address_t scratch = 0;
    kr_b = vm_allocate(self_task, &scratch, span, VM_FLAGS_ANYWHERE);
    if (kr_b != KERN_SUCCESS) goto out;
    memcpy((void *)scratch, (const void *)page_start, span);
    uint32_t nop = 0xD503201Fu;
    uintptr_t scratch_pc = scratch + (pc - page_start);
    ((uint32_t *)scratch_pc)[0] = nop;
    ((uint32_t *)scratch_pc)[1] = nop;
    kr_b = vm_protect(
        self_task,
        scratch,
        span,
        FALSE,
        VM_PROT_READ | VM_PROT_EXECUTE);
    if (kr_b != KERN_SUCCESS) {
      vm_deallocate(self_task, scratch, span);
      goto out;
    }
    vm_address_t target = (vm_address_t)page_start;
    vm_prot_t cur_prot = 0, max_prot = 0;
    kr_b = vm_remap(
        self_task,
        &target,
        span,
        0,
        VM_FLAGS_FIXED | VM_FLAGS_OVERWRITE,
        self_task,
        scratch,
        FALSE,
        &cur_prot,
        &max_prot,
        VM_INHERIT_NONE);
    if (kr_b != KERN_SUCCESS) {
      vm_deallocate(self_task, scratch, span);
      goto out;
    }
    sys_icache_invalidate((void *)pc, 8);
    result = 1;
  }

out:
  vcc_resume_world(&world);
  pthread_mutex_unlock(&s_patch_world_lock);

  if (result && kr_a_copy == KERN_SUCCESS) {
    vcc_log(@"  vm_protect+COPY patch OK @ 0x%lx", (unsigned long)pc);
  } else if (result) {
    vcc_log(@"  vm_remap OK: page=0x%lx span=%zu", (unsigned long)page_start,
            (size_t)span);
  } else if (kr_a_copy != KERN_SUCCESS) {
    vcc_log(@"  vm_protect+COPY failed: %d", kr_a_copy);
    vcc_log(@"  vm_remap failed: %d", kr_b);
  } else {
    vcc_log(@"  vm_protect restore RX failed: %d (page=0x%lx)", kr_a_rx,
            (unsigned long)page_start);
    vcc_log(@"  vm_remap failed: %d", kr_b);
  }
  return result;
}

// Patch a single 32-bit ARM64 instruction word at `pc` to `new_word`.
// Uses the same stop-the-world vm_protect(VM_PROT_COPY) → write →
// vm_protect(RX) → icache flush dance as vcc_patch_two_nops. Verifies
// the original word matches `expected_word` before writing so an iOS
// version skew doesn't silently corrupt the wrong code. Returns 1 on
// success.
int vcc_patch_word(uintptr_t pc,
                   uint32_t expected_word,
                   uint32_t new_word) {
  uint32_t cur = ((const uint32_t *)pc)[0];
  if (cur != expected_word) {
    vcc_log(@"  patch_word @ 0x%lx: expected 0x%08x, found 0x%08x — skip",
            (unsigned long)pc,
            expected_word,
            cur);
    return 0;
  }
  uintptr_t page_size = (uintptr_t)getpagesize();
  uintptr_t page_start = pc & ~(page_size - 1);
  uintptr_t end = pc + 4;
  uintptr_t page_end = ((end + page_size - 1) & ~(page_size - 1));
  vm_size_t span = (vm_size_t)(page_end - page_start);
  mach_port_t self_task = mach_task_self();
  kern_return_t kr_rw = KERN_SUCCESS, kr_rx = KERN_SUCCESS;
  int result = 0;

  pthread_mutex_lock(&s_patch_world_lock);
  vcc_stopped_world_t world;
  vcc_stop_world(&world);

  kern_return_t kr = vm_protect(
      self_task,
      (vm_address_t)page_start,
      span,
      FALSE,
      VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
  kr_rw = kr;
  if (kr == KERN_SUCCESS) {
    ((uint32_t *)pc)[0] = new_word;
    kr = vm_protect(
        self_task,
        (vm_address_t)page_start,
        span,
        FALSE,
        VM_PROT_READ | VM_PROT_EXECUTE);
    kr_rx = kr;
    if (kr == KERN_SUCCESS) {
      sys_icache_invalidate((void *)pc, 4);
      result = 1;
    }
  }

  vcc_resume_world(&world);
  pthread_mutex_unlock(&s_patch_world_lock);

  if (result) {
    vcc_log(@"  patch_word OK @ 0x%lx: 0x%08x -> 0x%08x",
            (unsigned long)pc,
            expected_word,
            new_word);
  } else if (kr_rw != KERN_SUCCESS) {
    vcc_log(@"  patch_word vm_protect+COPY failed: %d", kr_rw);
  } else {
    vcc_log(@"  patch_word restore RX failed: %d", kr_rx);
  }
  return result;
}

// Scan the image's __text for every occurrence of `needle` and rewrite
// each to `replacement` via vcc_patch_word. Replaces hardcoded image
// VMAs for patches whose addresses we don't know per-build but whose
// instruction encoding is a stable fingerprint (e.g. `mov w20, #-12783`
// MOVN encodings used for error-prep). Returns the count patched.
unsigned vcc_scan_and_patch(const vcc_image_t *img,
                            uint32_t needle,
                            uint32_t replacement,
                            const char *what) {
  if (!img->text || !img->text_words) return 0;
  unsigned hits = 0;
  for (size_t i = 0; i < img->text_words; i++) {
    if (img->text[i] != needle) continue;
    uintptr_t pc = (uintptr_t)&img->text[i];
    if (vcc_patch_word(pc, needle, replacement)) hits++;
  }
  vcc_log(@"  scan_and_patch %s (0x%08x -> 0x%08x): %u hit(s)",
          what ? what : "?",
          needle,
          replacement,
          hits);
  return hits;
}
