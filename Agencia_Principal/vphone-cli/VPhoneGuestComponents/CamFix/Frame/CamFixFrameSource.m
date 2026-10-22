// The vphoned shared frame, read in this process and turned into the
// CoreMedia, CoreGraphics and IOSurface objects the hooks hand to clients.
// Every conversion goes through the shared data plane.

#import "CamFixPrivate.h"
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>

// MARK: - shm reader

// Mapped once, lazily, by whichever of the preview queue and the photo
// queues gets here first; the lock keeps a second caller from mapping the
// file again. The mapping outlives the descriptor.
static const uint8_t *cfx_shm_base = NULL;
static size_t cfx_shm_size = 0;
static pthread_mutex_t cfx_shm_lock = PTHREAD_MUTEX_INITIALIZER;

static BOOL cfx_shm_open(void) {
  pthread_mutex_lock(&cfx_shm_lock);
  BOOL mapped = cfx_shm_base != NULL;
  if (!mapped) {
    int fd = open(VPHONE_VCAM_SHM_PATH, O_RDONLY | O_CLOEXEC);
    struct stat st;
    if (fd < 0) {
      cfxlog(@"shm open failed: %s (errno=%d)", VPHONE_VCAM_SHM_PATH, errno);
    } else if (fstat(fd, &st) == 0) {
      void *p = mmap(NULL, (size_t)st.st_size, PROT_READ, MAP_SHARED, fd, 0);
      if (p != MAP_FAILED) {
        cfx_shm_size = (size_t)st.st_size;
        cfx_shm_base = (const uint8_t *)p;
        mapped = YES;
        cfxlog(@"shm mapped %s size=%zu", VPHONE_VCAM_SHM_PATH, cfx_shm_size);
      }
    }
    if (fd >= 0) close(fd);
  }
  pthread_mutex_unlock(&cfx_shm_lock);
  return mapped;
}

// One owner for "map the frame and check it is usable": opens the shm,
// rejects a zeroed header, and rejects pixel data that runs past the
// mapping. Planar 4:2:0 frames carry a chroma plane after luma, and the
// data plane reads it, so it counts toward the checked length. On success
// fills *frame with the header fields and a pointer into the mapping.
// Returns NO when the frame cannot be read.
static BOOL cfx_shm_frame(vcc_frame_desc_t *frame) {
  if (!cfx_shm_open()) return NO;
  const vphone_vcam_shm_header_t *hdr = (const vphone_vcam_shm_header_t *)cfx_shm_base;
  uint32_t w = hdr->width, h = hdr->height, bpr = hdr->bytes_per_row;
  uint32_t fmt = hdr->pixel_format;
  if (!w || !h || !bpr) {
    cfxlog(@"shm header zeros");
    return NO;
  }
  size_t len = (size_t)bpr * h;
  if (vcc_is_planar_yuv(fmt)) len += (size_t)(2u * (w / 2)) * (h / 2);
  if ((size_t)VPHONE_VCAM_SHM_HEADER_SIZE + len > cfx_shm_size) {
    cfxlog(@"shm: pixel range exceeds mapping");
    return NO;
  }
  memset(frame, 0, sizeof(*frame));
  frame->width = w;
  frame->height = h;
  frame->bytes_per_row = bpr;
  frame->pixel_format = fmt;
  frame->timestamp_ns = hdr->timestamp_ns;
  frame->frame_index = hdr->frame_index;
  frame->pixels = cfx_shm_base + VPHONE_VCAM_SHM_HEADER_SIZE;
  frame->pixels_length = len;
  return YES;
}

static void cfx_cg_release_data(void *info, const void *data, size_t size) {
  (void)info; (void)size;
  free((void *)data);
}

// Snapshot the shm frame and decode it to tightly packed BGRA. Every RGB
// consumer (CGImage, JPEG, IOSurface) goes through here, so the wire pixel
// format is honored instead of assumed. Returns a malloc'd buffer of
// w * 4 * h bytes; the caller frees it.
static uint8_t *cfx_bgra_from_shm(uint32_t *outW, uint32_t *outH) {
  vcc_frame_desc_t frame;
  if (!cfx_shm_frame(&frame)) return NULL;
  uint8_t *bgra = NULL;
  uint32_t bpr = 0;
  if (vcc_bgra_bytes_from_frame(&frame, &bgra, &bpr) != 0) return NULL;
  *outW = frame.width;
  *outH = frame.height;
  return bgra;
}

// MARK: - sample buffers

// Photo and video delivery are BGRA. The shared data plane builds the
// CVPixelBuffer, format description and camera attachments and converts
// the wire format when needed. Timing is stream-local (host epoch-ns PTS
// values lose precision past 2^53 in downstream float conversions) and
// advances per buffer, so builds from the preview queue and the photo
// paths serialize on one lock.
static pthread_mutex_t cfx_cmsb_lock = PTHREAD_MUTEX_INITIALIZER;
static vcc_timing_state_t cfx_cmsb_timing;
static BOOL cfx_cmsb_timing_ready = NO;

CMSampleBufferRef cfx_build_cmsb(void) {
  vcc_frame_desc_t frame;
  if (!cfx_shm_frame(&frame)) return NULL;
  uint8_t *pixels = malloc(frame.pixels_length);
  if (!pixels) return NULL;
  memcpy(pixels, frame.pixels, frame.pixels_length);
  frame.pixels = pixels;

  pthread_mutex_lock(&cfx_cmsb_lock);
  if (!cfx_cmsb_timing_ready) {
    vcc_timing_init(&cfx_cmsb_timing);
    cfx_cmsb_timing_ready = YES;
  }
  CMSampleBufferRef sb = vcc_cmsb_from_frame(&frame, VCC_FMT_BGRA, &cfx_cmsb_timing);
  pthread_mutex_unlock(&cfx_cmsb_lock);
  free(pixels);
  if (!sb) cfxlog(@"build_cmsb: shared data plane returned NULL");
  return sb;
}

// MARK: - JPEG + CGImage + IOSurface builders

NSData *cfx_jpeg_from_cgimage(CGImageRef img) {
  if (!img) return nil;
  NSMutableData *data = [NSMutableData data];
  CGImageDestinationRef dest = CGImageDestinationCreateWithData(
      (CFMutableDataRef)data,
      (CFStringRef)@"public.jpeg",
      1,
      NULL);
  if (!dest) return nil;
  CGImageDestinationAddImage(dest, img, NULL);
  BOOL ok = CGImageDestinationFinalize(dest);
  CFRelease(dest);
  return ok ? data : nil;
}

CGImageRef cfx_build_cgimage_from_shm(void) {
  uint32_t w = 0, h = 0;
  uint8_t *bgra = cfx_bgra_from_shm(&w, &h);
  if (!bgra) return NULL;
  size_t len = (size_t)w * 4 * h;
  CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
  CGDataProviderRef dp = CGDataProviderCreateWithData(
      NULL,
      bgra,
      len,
      cfx_cg_release_data);
  CGImageRef img = CGImageCreate(
      w,
      h,
      8,
      32,
      w * 4,
      cs,
      (CGBitmapInfo)(kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst),
      dp,
      NULL,
      false,
      kCGRenderingIntentDefault);
  CGDataProviderRelease(dp);
  CGColorSpaceRelease(cs);
  return img;
}

IOSurfaceRef cfx_build_iosurface_from_shm(uint32_t *outW, uint32_t *outH) {
  uint32_t w = 0, h = 0;
  uint8_t *bgra = cfx_bgra_from_shm(&w, &h);
  if (!bgra) return NULL;
  size_t len = (size_t)w * 4 * h;
  NSDictionary *props = @{
    (NSString *)kIOSurfaceWidth: @(w),
    (NSString *)kIOSurfaceHeight: @(h),
    (NSString *)kIOSurfacePixelFormat: @(kCVPixelFormatType_32BGRA),
    (NSString *)kIOSurfaceBytesPerElement: @(4),
    (NSString *)kIOSurfaceBytesPerRow: @(w * 4),
    (NSString *)kIOSurfaceAllocSize: @(len),
  };
  IOSurfaceRef surf = IOSurfaceCreate((CFDictionaryRef)props);
  if (!surf) { free(bgra); return NULL; }
  IOSurfaceLock(surf, 0, NULL);
  void *base = IOSurfaceGetBaseAddress(surf);
  if (base) memcpy(base, bgra, len);
  IOSurfaceUnlock(surf, 0, NULL);
  free(bgra);
  if (outW) *outW = w;
  if (outH) *outH = h;
  return surf;
}
