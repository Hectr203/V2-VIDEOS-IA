/*
 * Host proof harness for the scan that finds cameracaptured's call to
 * PrewarmThreadSafeSBPs (VCamCaptured/Prewarm/VCamPrewarmScan.c).
 *
 * The instruction streams are synthetic and laid out like CMCapture's on
 * iPadOS 26.6.2 and iOS 27.0, decoys included: a captured load that calls
 * a stub outside __text (27 has one), a call into __text with no captured
 * argument, and a captured call in the function after the block's return.
 * The encodings match the words in those caches (`pacia x16, x8` is
 * 0xdac10110, `ldr x0, [x20, #0x20]` 0xf9401280, `bl` +0x36c 0x940000db).
 *
 * Build/run:  make -C VPhoneGuestComponents test-vcam-prewarm
 */

#include "VCamPrewarmScan.h"

#include <stdio.h>
#include <string.h>

static int g_checks = 0;
static int g_fails = 0;

#define CHECK(cond, ...)                 \
  do {                                   \
    g_checks++;                          \
    if (!(cond)) {                       \
      g_fails++;                         \
      printf("FAIL %s:%d: ", __FILE__, __LINE__); \
      printf(__VA_ARGS__);               \
      printf("\n");                      \
    }                                    \
  } while (0)

// MARK: - encoders

#define BASE ((uintptr_t)0x1aeb2f000u)
#define WORDS 512u
#define AT(index) (BASE + (uintptr_t)(index) * 4)

static const uint32_t kMovW0Zero = 0x52800000u;
static const uint32_t kRetab = 0xD65F0FFFu;
static const uint32_t kRet = 0xD65F03C0u;
static const uint32_t kMovW0Shader = 0x52916620u;  // mov w0, #0x8b31

static uint32_t enc_branch(uint32_t op, uintptr_t pc, uintptr_t target) {
  return op | ((uint32_t)((int64_t)(target - pc) / 4) & 0x03FFFFFFu);
}
static uint32_t enc_b(uintptr_t pc, uintptr_t target) {
  return enc_branch(0x14000000u, pc, target);
}
static uint32_t enc_bl(uintptr_t pc, uintptr_t target) {
  return enc_branch(0x94000000u, pc, target);
}
static uint32_t enc_adrp(unsigned rd, uintptr_t pc, uintptr_t target) {
  int64_t pages = (int64_t)(target >> 12) - (int64_t)(pc >> 12);
  uint32_t imm = (uint32_t)pages & 0x1FFFFFu;
  return 0x90000000u | ((imm & 3u) << 29) | ((imm >> 2) << 5) | rd;
}
static uint32_t enc_add_imm(unsigned rd, unsigned rn, unsigned imm) {
  return 0x91000000u | (imm << 10) | (rn << 5) | rd;
}
static uint32_t enc_pacia(unsigned rd, unsigned rn) {
  return 0xDAC10000u | (rn << 5) | rd;
}
static uint32_t enc_ldr_x(unsigned rt, unsigned rn, unsigned offset) {
  return 0xF9400000u | ((offset / 8) << 10) | (rn << 5) | rt;
}

// MARK: - layout

enum {
  kEntry = 0,         // mov w0, #0; b internal
  kInternal = 8,
  kSignedInvoke = 20,  // adrp/add/pacia triple
  kInternalEnd = 40,
  kBlock = 64,
  kStubCall = 70,      // ldr x0, [x20, #0x20]; bl <outside __text>
  kPlainCall = 80,     // mov w0, #0x8b31; bl <in __text>
  kPrewarmCall = 90,   // ldr x0, [x20, #0x20]; bl prewarm
  kBlockEnd = 120,
  kNext = 121,         // next function, with its own captured call
  kPrewarm = 200,
};

static uint32_t g_text[WORDS];

static void build_text(void) {
  for (unsigned i = 0; i < WORDS; i++) g_text[i] = VCC_A64_NOP;

  g_text[kEntry] = kMovW0Zero;
  g_text[kEntry + 1] = enc_b(AT(kEntry + 1), AT(kInternal));

  g_text[kInternal] = VCC_A64_PACIBSP;
  // A lone add x16 and an adrp x16 not followed by add/pacia: not a match.
  g_text[kInternal + 3] = enc_add_imm(16, 16, 0x10);
  g_text[kInternal + 6] = enc_adrp(16, AT(kInternal + 6), AT(kBlock));
  g_text[kSignedInvoke] = enc_adrp(16, AT(kSignedInvoke), AT(kBlock));
  g_text[kSignedInvoke + 1] = enc_add_imm(16, 16, (unsigned)(AT(kBlock) & 0xFFFu));
  g_text[kSignedInvoke + 2] = enc_pacia(16, 8);
  g_text[kInternalEnd] = kRetab;
  // After the return: another signed pointer that must not count.
  g_text[kInternalEnd + 2] = enc_adrp(16, AT(kInternalEnd + 2), AT(kPrewarm));
  g_text[kInternalEnd + 3] = enc_add_imm(16, 16, (unsigned)(AT(kPrewarm) & 0xFFFu));
  g_text[kInternalEnd + 4] = enc_pacia(16, 9);

  g_text[kBlock] = VCC_A64_PACIBSP;
  g_text[kStubCall - 1] = enc_ldr_x(0, 20, 0x20);
  g_text[kStubCall] = enc_bl(AT(kStubCall), BASE + 0x8000000u);
  g_text[kPlainCall - 1] = kMovW0Shader;
  g_text[kPlainCall] = enc_bl(AT(kPlainCall), AT(kPrewarm));
  g_text[kPrewarmCall - 1] = enc_ldr_x(0, 20, 0x20);
  g_text[kPrewarmCall] = enc_bl(AT(kPrewarmCall), AT(kPrewarm));
  g_text[kBlockEnd] = kRetab;

  g_text[kNext] = VCC_A64_PACIBSP;
  g_text[kNext + 2] = enc_ldr_x(0, 20, 0x20);
  g_text[kNext + 3] = enc_bl(AT(kNext + 3), AT(kPrewarm));
  g_text[kNext + 4] = kRet;

  g_text[kPrewarm] = VCC_A64_PACIBSP;
  g_text[kPrewarm + 1] = kRetab;
}

static int scan(uintptr_t entry, vcc_prewarm_site_t *site) {
  vcc_prewarm_text_t text = {g_text, BASE, WORDS};
  memset(site, 0, sizeof(*site));
  return vcc_find_prewarm_call(&text, entry, site);
}

// MARK: - tests

static void test_encodings_match_the_cache(void) {
  CHECK(enc_pacia(16, 8) == 0xDAC10110u, "pacia x16, x8");
  CHECK(enc_ldr_x(0, 20, 0x20) == 0xF9401280u, "ldr x0, [x20, #0x20]");
  CHECK(enc_bl(0x1aeb2fd68u, 0x1aeb300d4u) == 0x940000DBu, "bl +0x36c");
  CHECK(enc_add_imm(16, 16, 0x930) == 0x9124C210u, "add x16, x16, #0x930");
  CHECK(enc_adrp(16, 0x1aeb2f7a0u, 0x1aeb2f930u) == 0x90000010u, "adrp x16, same page");
}

static void test_finds_the_call(void) {
  build_text();
  vcc_prewarm_site_t site;
  int rc = scan(AT(kEntry), &site);
  CHECK(rc == 0, "scan returned %d", rc);
  CHECK(site.internal == AT(kInternal), "internal 0x%lx", (unsigned long)site.internal);
  CHECK(site.block_invoke == AT(kBlock), "block 0x%lx", (unsigned long)site.block_invoke);
  CHECK(site.call_site == AT(kPrewarmCall), "call 0x%lx", (unsigned long)site.call_site);
  CHECK(site.prewarm == AT(kPrewarm), "prewarm 0x%lx", (unsigned long)site.prewarm);
}

static void test_entry_that_is_the_function(void) {
  build_text();
  vcc_prewarm_site_t site;
  int rc = scan(AT(kInternal), &site);
  CHECK(rc == 0 && site.internal == AT(kInternal),
        "folded entry: rc %d internal 0x%lx", rc, (unsigned long)site.internal);
}

static void test_refusals(void) {
  vcc_prewarm_site_t site;

  build_text();
  CHECK(scan(BASE + WORDS * 4, &site) == -1, "entry outside __text");

  build_text();
  g_text[kInternal] = VCC_A64_NOP;
  CHECK(scan(AT(kEntry), &site) == -1, "branch target without a prologue");

  build_text();
  g_text[kSignedInvoke + 2] = VCC_A64_NOP;
  CHECK(scan(AT(kEntry), &site) == -2, "no signed invoke");

  build_text();
  g_text[kSignedInvoke + 5] = enc_adrp(16, AT(kSignedInvoke + 5), AT(kBlock));
  g_text[kSignedInvoke + 6] = enc_add_imm(16, 16, (unsigned)(AT(kBlock) & 0xFFFu));
  g_text[kSignedInvoke + 7] = enc_pacia(16, 8);
  CHECK(scan(AT(kEntry), &site) == -2, "two signed invokes");

  build_text();
  g_text[kBlock] = VCC_A64_NOP;
  CHECK(scan(AT(kEntry), &site) == -3, "invoke without a prologue");

  build_text();
  g_text[kPrewarmCall - 1] = kMovW0Zero;
  CHECK(scan(AT(kEntry), &site) == -4, "no captured call");

  build_text();
  g_text[kPrewarmCall + 4] = enc_ldr_x(0, 19, 0x20);
  g_text[kPrewarmCall + 5] = enc_bl(AT(kPrewarmCall + 5), AT(kPrewarm));
  CHECK(scan(AT(kEntry), &site) == -4, "two captured calls");

  build_text();
  g_text[kPrewarm] = VCC_A64_NOP;
  CHECK(scan(AT(kEntry), &site) == -4, "callee without a prologue");
}

int main(void) {
  test_encodings_match_the_cache();
  test_finds_the_call();
  test_entry_that_is_the_function();
  test_refusals();
  printf("%d checks, %d failures\n", g_checks, g_fails);
  return g_fails ? 1 : 0;
}
