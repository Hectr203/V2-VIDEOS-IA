#include "VCamImage.h"
#include "VCamSynthetic.h"
#include "vcam_dataplane.h"

// MARK: - synthetic source construction

NSString *const kVccSynthDeviceID = @"vphone:vcam:device:0";
NSString *const kVccSynthStreamID = @"vphone:vcam:stream:video:0";

id vcc_build_backing(void) {
  Class backingClass = NSClassFromString(@"FigCaptureSourceBacking");
  if (!backingClass) {
    vcc_log(@"  FigCaptureSourceBacking class missing");
    return nil;
  }
  CFStringRef k_uid  = vcc_cfconst("kFigCaptureSourceAttributeKey_UniqueID");
  CFStringRef k_dt   = vcc_cfconst("kFigCaptureSourceAttributeKey_DeviceType");
  CFStringRef k_ln   = vcc_cfconst("kFigCaptureSourceAttributeKey_LocalizedName");
  CFStringRef k_mid  = vcc_cfconst("kFigCaptureSourceAttributeKey_ModelID");
  CFStringRef k_pos  = vcc_cfconst("kFigCaptureSourceAttributeKey_Position");
  CFStringRef k_st   = vcc_cfconst("kFigCaptureSourceAttributeKey_SourceType");
  CFStringRef k_cdid = vcc_cfconst("kFigCaptureSourceAttributeKey_CaptureDeviceID");
  if (!k_uid || !k_dt) {
    vcc_log(@"  required attr keys missing");
    return nil;
  }

  NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
  attrs[(__bridge NSString *)k_uid] = @"vphone:vcam:0";
  // DeviceType: empirical sweep
  //   - 1 (BuiltInWideAngleCamera): Camera.app routes to the real ISP /
  //     hardware path and fails immediately because no hardware backs
  //     us — viewfinder stream pool isn't even spun up.
  //   - 2: Camera.app's Photo/Video tabs use the generic / soft path
  //     and at least start the FigCameraViewfinderStream init pool
  //     (~2000/sec) before stalling at openWithDestination:. This is
  //     where we have a chance to inject a destination.
  // Keep 2 until the inject-destination shape is figured out.
  attrs[(__bridge NSString *)k_dt]  = @(2);
  if (k_ln)  attrs[(__bridge NSString *)k_ln]  = @"vphone Virtual Camera";
  if (k_mid) attrs[(__bridge NSString *)k_mid] = @"vphone-vcam-1";
  if (k_pos) attrs[(__bridge NSString *)k_pos] = @(1);
  // sourceType MUST be 1 (video) for the daemon's media-type filter to
  // include this source in a vide-typed FigCaptureSourceRemoteCopyCaptureSources
  // request. Without it, attrs[SourceType] = nil → intValue = 0 → fails
  // the tbnz w8 gate in handleCopySourcesMessage.
  if (k_st)  attrs[(__bridge NSString *)k_st]  = @(1);
  // captureSession_buildGraphWithConfiguration (CMCapture vmaddr 0x1ae2b1910)
  // iterates the source list and calls
  // _FigCaptureSourceGetAttribute(source, kFigCaptureSourceAttributeKey_CaptureDeviceID)
  // then -[NSMutableArray addObject:] with the result. If the key is missing
  // the call returns nil and the array throws NSInvalidArgumentException
  // ("object cannot be nil") inside -[__NSArrayM insertObject:atIndex:] —
  // which kills cameracaptured as soon as any AVCaptureSession references
  // our synth.
  //
  // The value must be a string, NOT a number. -[BWFigCaptureDeviceVendor
  // _createDevice:reason:clientPID:figCaptureDevice:] sends isEqualToString:
  // to it; an NSNumber raises "unrecognized selector". Use a unique opaque
  // string outside whatever pattern Apple uses for hardware cameras.
  if (k_cdid) attrs[(__bridge NSString *)k_cdid] = kVccSynthDeviceID;

  // After hooking _FigCaptureSourceGetAttribute via lldb we observed
  // Camera.app's graph builder also queries these 5 boolean / scheme keys
  // against our synth. Provide explicit values so the builder doesn't bail
  // on a nil capability check. Verified order observed via lldb:
  //   SmartCameraSupported, StillImageNoiseReductionAndFusionScheme,
  //   MidFrameSynchronizationNotSupported, TimeOfFlightAssistedAutoFocusSupported,
  //   StructuredLightAssistedAutoFocusSupported
  // Resolve the canonical CFString constant by symbol name when possible (some
  // are defined in a private framework not in the dyld exports trie, so we fall
  // back to the plain string after the Fig naming convention:
  // kFigSupportedFormat_VideoMinFrameRate → "VideoMinFrameRate").
  NSString *(^figKeyN)(const char *) = ^NSString *(const char *symname) {
    void **slot = dlsym(RTLD_DEFAULT, symname);
    if (slot && *slot) return (__bridge NSString *)(CFStringRef)(*slot);
    const char *cs = symname;
    const char *u = strrchr(cs, '_');
    if (u) cs = u + 1;
    return [NSString stringWithUTF8String:cs];
  };
  attrs[figKeyN("kFigCaptureSourceAttributeKey_SmartCameraSupported")] = @NO;
  attrs[figKeyN("kFigCaptureSourceAttributeKey_StillImageNoiseReductionAndFusionScheme")] = @(0);
  attrs[figKeyN("kFigCaptureSourceAttributeKey_MidFrameSynchronizationNotSupported")] = @NO;
  attrs[figKeyN("kFigCaptureSourceAttributeKey_TimeOfFlightAssistedAutoFocusSupported")] = @NO;
  attrs[figKeyN("kFigCaptureSourceAttributeKey_StructuredLightAssistedAutoFocusSupported")] = @NO;

  // Construct a FigCaptureSourceVideoFormat via its private init taking a
  // stream format dictionary. Required keys recovered by reversing
  // `-[FigCaptureSourceFormat formatDescription]` + `-format` + `-dimensions`:
  //   "Name"            (NSString)  -- required by base init's cbz guard
  //   "Width"           (NSNumber)  -- becomes dimensions.width
  //   "Height"          (NSNumber)  -- becomes dimensions.height
  //   "PixelFormatType" (NSNumber)  -- 4cc fed to CMVideoFormatDescriptionCreate
  // All other keys read by the subclass init fall through to default
  // (0/nil) values via objectForKeyedSubscript: chains.
  NSArray *formats = @[];
  Class fmtClass = NSClassFromString(@"FigCaptureSourceVideoFormat");
  if (fmtClass) {
    // Publish TWO formats: one BGRA, one 420v at the same 1280x720
    // dimensions. Clients that filter on BGRA (e.g. Loupe / Magnifier)
    // see one; clients that pick the canonical ISP pixel format (AVF's
    // _preferredFormatForPreset: matcher for AVCaptureSessionPresetHigh)
    // pick the 420v one. Same preset list + frame-rate range on both.
    // Phase 3: AVCaptureDeviceFormat consistency. Key names below are
    // grounded in Apple's shipped CMCapture/CMCaptureCore (extracted from
    // the dyld shared cache — same Fig framework family the guest runs);
    // semantics come from the public AVCaptureDeviceFormat API spec in
    // the SDK headers. Every value tells the same story as the delivered
    // samples (see vcam_dataplane.c):
    //
    //   AVF property                     <- published key            value
    //   ---------------------------------------------------------------
    //   videoFieldOfView                 <- VideoFieldOfView         63.0
    //     (same constant derives the per-frame camera intrinsic matrix
    //      focal length: fx = (w/2)/tan(FOV/2) — one knob, no drift)
    //   videoSupportedFrameRateRanges    <- MinFrameRate/MaxFrameRate  1..60
    //   videoMaxZoomFactor               <- VideoStabilizationTypeOverrideForStandard=3
    //     (maxZoomFactor's dimension-table fast path; yields 16.0 for
    //      1280-wide — keeps setVideoZoomFactor: in range for Camera.app)
    //   videoHDRSupported                <- HDRSupported             NO (8-bit SDR)
    //   isCameraIntrinsicMatrixDeliverySupported
    //                                    <- CameraCalibrationDataDeliverySupported YES
    //                                       IntrinsicMatrixReferenceWidth/Height
    //     (we attach kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix to
    //      every delivered sample, so YES is truthful)
    //   dimensions / formatDescription   <- Width/Height/PixelFormatType 1280x720 '420v'|'BGRA'
    //
    // Deliberately NOT published (encoding unknown without runtime ground
    // truth; a wrong shape could break the FigCaptureSourceVideoFormat
    // init): HighResStillImageDimensions, supportedColorSpaces
    // ("ColorSpace"), stabilization mode lists, photo dimensions.
    NSDictionary *commonKeys = @{
      @"DefaultActiveFormat" : @NO,  // overridden on the active one
      figKeyN("kFigSupportedFormat_VideoMinFrameRate") : @(1),
      figKeyN("kFigSupportedFormat_VideoMaxFrameRate") : @(60),
      // Horizontal field of view in degrees. Same constant that derives the
      // per-frame camera intrinsic matrix focal length, so AVCaptureDevice
      // format.fieldOfView and the CMSampleBuffer intrinsics tell one story.
      // Calibration knob — measure on a physical device before trusting.
      @"VideoFieldOfView" : @(VCC_VCAM_HFOV_DEG),
      // 8-bit SDR delivery: advertising HDR would be a lie AVF clients
      // would act on (tone mapping, EDR pipelines).
      @"HDRSupported" : @NO,
      // We attach kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix to
      // every delivered sample with the principal point at frame center —
      // so intrinsic delivery is supported, referenced to the full frame.
      @"CameraCalibrationDataDeliverySupported" : @YES,
      @"IntrinsicMatrixReferenceWidth" : @1280,
      @"IntrinsicMatrixReferenceHeight" : @720,
      // -[FigCaptureSourceVideoFormat maxZoomFactor] takes a fast path that
      // returns 1.0 for raw bayer formats; for BGRA (our case) it falls to
      // a fancy path that reads stabilizationTypeOverrideForCinematic / -ForStandard
      // and consults a dimension-table when either equals 3. Setting this
      // key to 3 makes the table apply (returns 16.0 for 1280-wide formats),
      // which keeps -[AVCaptureFigVideoDevice setVideoZoomFactor:] from
      // throwing "out-of-range [1, activeFormat.videoMaxZoomFactor]" when
      // Camera.app sets a default zoom > 1.0.
      @"VideoStabilizationTypeOverrideForStandard" : @(3),
      // Without AVCaptureSessionPresets, -[AVCaptureDevice
      // supportsAVCaptureSessionPreset:] returns NO for every preset
      // (canAddInput=False everywhere except InputPriority). Camera.app
      // uses High/Photo — list them all so common AVF clients pass.
      @"AVCaptureSessionPresets" : @[
        @"AVCaptureSessionPresetHigh",
        @"AVCaptureSessionPreset1280x720",
        @"AVCaptureSessionPreset640x480",
        @"AVCaptureSessionPresetMedium",
        @"AVCaptureSessionPresetLow",
        @"AVCaptureSessionPresetPhoto",
        @"AVCaptureSessionPreset352x288",
      ],
    };
    NSMutableDictionary *bgra_fmt = [@{
      @"Name"            : @"vphone-vcam-720p-bgra",
      @"Width"           : @1280,
      @"Height"          : @720,
      @"PixelFormatType" : @(0x42475241u),  // 'BGRA'
    } mutableCopy];
    [bgra_fmt addEntriesFromDictionary:commonKeys];

    NSMutableDictionary *y420v_fmt = [@{
      @"Name"            : @"vphone-vcam-720p-420v",
      @"Width"           : @1280,
      @"Height"          : @720,
      @"PixelFormatType" : @(0x34323076u),  // '420v'
    } mutableCopy];
    [y420v_fmt addEntriesFromDictionary:commonKeys];
    // Mark 420v as default — it's what AVF's preset matcher prefers when
    // picking _setActiveFormat: under standard presets.
    y420v_fmt[@"DefaultActiveFormat"] = @YES;

    SEL fmtInitSel = NSSelectorFromString(
        @"initWithFigCaptureStreamFormatDictionary:");
    NSMutableArray *formatObjs = [NSMutableArray array];
    for (NSDictionary *fmtDict in @[ bgra_fmt, y420v_fmt ]) {
      id fmtAlloc = ((id (*)(Class, SEL))objc_msgSend)(fmtClass,
                                                         @selector(alloc));
      id fmtObj = nil;
      if (fmtAlloc) {
        fmtObj = ((id (*)(id, SEL, id))objc_msgSend)(
            fmtAlloc,
            fmtInitSel,
            fmtDict);
      }
      vcc_log(@"  FigCaptureSourceVideoFormat (%@) = %p",
              fmtDict[@"Name"],
              fmtObj);
      if (fmtObj) [formatObjs addObject:fmtObj];
    }
    formats = formatObjs;
  } else {
    vcc_log(@"  FigCaptureSourceVideoFormat class missing");
  }

  SEL initSel = NSSelectorFromString(
      @"initWithMediaType:attributes:cachedProperties:formats:"
      @"missingFormatNames:synchronizedStreamUniqueIDs:"
      @"unsynchronizedStreamUniqueIDs:");
  id alloced = ((id (*)(Class, SEL))objc_msgSend)(backingClass,
                                                    @selector(alloc));
  if (!alloced) return nil;
  uint32_t mediaTypeVideo = 0x76696465;  // 'vide'
  // Advertise one realtime (unsynchronized) video stream. Without a stream
  // uniqueID the client-side AVCaptureFigVideoDevice has no ports: sessions
  // never ask the vendor for streams, no capture graph is built for
  // third-party clients, and their AVCaptureVideoDataOutputs starve.
  // Camera.app never noticed because its viewfinder path is driven
  // independently.
  NSArray *unsyncStreams = @[ kVccSynthStreamID ];
  id backing = ((id (*)(id, SEL, uint32_t, id, id, id, id, id, id))objc_msgSend)(
      alloced,
      initSel,
      mediaTypeVideo,
      attrs,
      [NSMutableDictionary dictionary],
      formats,
      @[],
      @[],
      unsyncStreams);
  vcc_log(@"  backing = %p (attrs.count=%lu formats.count=%lu streams=%@)",
          backing,
          (unsigned long)attrs.count,
          (unsigned long)formats.count,
          unsyncStreams);
  return backing;
}
