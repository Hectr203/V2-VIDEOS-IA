// The built-in microphone's capture source, for a daemon with no camera.
//
// cameracaptured publishes its capture sources from
// +[FigCaptureSourceBackingsProvider sharedCaptureSourceBackingsProvider].
// On iOS 27 that provider is built in one step for the built-in device
// "Default": BWFigCaptureDeviceVendor creates the camera device, and only
// then is the model's AVCaptureSession.plist read, cameras and microphone
// together, by FigCaptureCreateSourceInfoArrayFromDeviceAndModelSpecificPlist.
// A VM loads no ISP plugin, so the vendor has no create function, the
// device copy fails with -12786, and the provider is never made. The
// microphone is lost with the camera, and an AVCaptureSession that records
// audio only (Voice Memos on iOS 27) finds no audio device.
//
// The microphone's source info does not need the device: the plist entry
// with mediaType "soun" is turned into a source by the same exported
// function. When the original provider comes back nil, this builds one from
// the model's plist with every entry but the microphone removed, so the
// function never reaches a camera entry and never touches the (absent)
// device, and returns it instead. The guest's model has no plist of its own,
// so the plist is the first shipped product's that describes a microphone.
// A provider the daemon did build is
// returned unchanged. See Research/Guest/ios27_capture_microphone_source.md.

#include "VCamCapturedPrivate.h"
#include "VCamImage.h"

// FigCaptureGetModelSpecificName(void) -> CFStringRef (not retained)
typedef CFStringRef (*VccModelNameFn)(void);
// FigCaptureSourcePlistCreateAndPreprocessForModelSpecificName(model)
//   -> the preprocessed AVCaptureSession.plist, +1, or NULL
typedef CFDictionaryRef (*VccPlistFn)(CFStringRef model);
// FigCaptureCreateSourceInfoArrayFromDeviceAndModelSpecificPlist(device,
//   plist, plistModificationDate, persist, &sources (+1), &commonSettings (+1))
// The date goes into a dictionary unconditionally, so it must not be NULL;
// persist writes com.apple.cameracapture.volatile, which this never asks for.
typedef void (*VccSourceInfoFn)(void *device, CFDictionaryRef plist,
                                CFDateRef plistModificationDate,
                                Boolean persist, CFArrayRef *outSources,
                                CFDictionaryRef *outCommonSettings);

static IMP vcc_shared_provider_orig = NULL;
static id vcc_mic_provider = nil;
static BOOL vcc_mic_provider_failed = NO;
static BOOL vcc_mic_provider_served = NO;

static BOOL vcc_provider_has_mic(id provider) {
  Ivar iv = class_getInstanceVariable(object_getClass(provider), "_hasMicSource");
  if (!iv) return NO;
  return *(BOOL *)((char *)(__bridge void *)provider + ivar_getOffset(iv));
}

static id vcc_build_mic_provider(Class providerClass) {
  VccModelNameFn modelName =
      (VccModelNameFn)vcc_dlsym_fn("FigCaptureGetModelSpecificName");
  VccPlistFn plistFn = (VccPlistFn)vcc_dlsym_fn(
      "FigCaptureSourcePlistCreateAndPreprocessForModelSpecificName");
  VccSourceInfoFn sourceInfoFn = (VccSourceInfoFn)vcc_dlsym_fn(
      "FigCaptureCreateSourceInfoArrayFromDeviceAndModelSpecificPlist");
  if (!modelName || !plistFn || !sourceInfoFn) return nil;

  // The guest's own model name (VPHONE600 on the iOS 27 iPhone guest) has
  // no plist: CMCapture ships one folder per product the firmware was built
  // for (D47 in the iPhone17,3 restore image). Take the model's own plist
  // when there is one, else the first shipped product folder that describes
  // a microphone.
  NSMutableArray<NSString *> *models = [NSMutableArray array];
  NSString *ownModel = (__bridge NSString *)modelName();
  if (ownModel) [models addObject:ownModel];
  NSString *resources =
      [NSBundle bundleWithIdentifier:@"com.apple.CMCapture"].resourcePath
          ?: @"/System/Library/PrivateFrameworks/CMCapture.framework";
  NSArray *folders =
      [[NSFileManager.defaultManager contentsOfDirectoryAtPath:resources
                                                         error:NULL]
          sortedArrayUsingSelector:@selector(compare:)];
  for (NSString *folder in folders) {
    // "iOS" holds the plist for external cameras, not a product.
    if ([folder isEqual:@"iOS"] || [models containsObject:folder]) continue;
    NSString *plistPath = [[resources stringByAppendingPathComponent:folder]
        stringByAppendingPathComponent:@"AVCaptureSession.plist"];
    if ([NSFileManager.defaultManager fileExistsAtPath:plistPath])
      [models addObject:folder];
  }

  NSString *model = nil;
  NSDictionary *plist = nil;
  NSMutableArray *microphones = [NSMutableArray array];
  for (NSString *candidate in models) {
    plist = CFBridgingRelease(plistFn((__bridge CFStringRef)candidate));
    if (![plist isKindOfClass:NSDictionary.class]) {
      vcc_log(@"  mic source: no AVCaptureSession.plist for model %@", candidate);
      continue;
    }
    for (id entry in plist[@"AVCaptureDevices"]) {
      if ([entry isKindOfClass:NSDictionary.class] &&
          [entry[@"mediaType"] isEqual:@"soun"]) {
        [microphones addObject:entry];
      }
    }
    if (microphones.count) {
      model = candidate;
      break;
    }
    vcc_log(@"  mic source: model %@ plist has no soun device", candidate);
  }
  if (!model) {
    vcc_log(@"  mic source: no plist describes a microphone (tried %@)",
            [models componentsJoinedByString:@", "]);
    return nil;
  }
  NSMutableDictionary *micOnly = [plist mutableCopy];
  micOnly[@"AVCaptureDevices"] = microphones;

  CFArrayRef sourcesRef = NULL;
  CFDictionaryRef commonRef = NULL;
  @try {
    sourceInfoFn(NULL, (__bridge CFDictionaryRef)micOnly,
                 (__bridge CFDateRef)[NSDate date], false, &sourcesRef,
                 &commonRef);
  } @catch (NSException *e) {
    vcc_log(@"  mic source: source info creation threw %@", e);
    return nil;
  }
  NSArray *sources = CFBridgingRelease(sourcesRef);
  NSDictionary *common = CFBridgingRelease(commonRef);
  if (!sources.count) {
    vcc_log(@"  mic source: no source info from model %@ plist", model);
    return nil;
  }

  SEL initSel = NSSelectorFromString(@"initWithSourceInfoDictionaries:commonSettings:");
  if (![providerClass instancesRespondToSelector:initSel]) {
    vcc_log(@"  mic source: provider has no -initWithSourceInfoDictionaries:commonSettings:");
    return nil;
  }
  // An init: consumes the allocated receiver and returns +1.
  typedef id (*VccInitFn)(id __attribute__((ns_consumed)), SEL, id, id)
      __attribute__((ns_returns_retained));
  id provider = ((VccInitFn)objc_msgSend)([providerClass alloc], initSel,
                                         sources, common);
  vcc_log(@"  mic source: model %@, %lu source info(s), provider %p, hasMicSource=%d",
          model, (unsigned long)sources.count, provider,
          provider ? vcc_provider_has_mic(provider) : 0);
  return provider;
}

static id vcc_shared_provider_hook(id self, SEL _cmd) {
  id provider = ((id (*)(id, SEL))vcc_shared_provider_orig)(self, _cmd);
  if (provider) return provider;

  @synchronized(self) {
    if (!vcc_mic_provider && !vcc_mic_provider_failed) {
      vcc_mic_provider = vcc_build_mic_provider(self);
      vcc_mic_provider_failed = (vcc_mic_provider == nil);
    }
    if (vcc_mic_provider && !vcc_mic_provider_served) {
      vcc_mic_provider_served = YES;
      vcc_log(@"  mic source: daemon built no provider; serving the microphone-only one");
    }
    return vcc_mic_provider;
  }
}

BOOL vcc_microphone_only_source_active(void) {
  return vcc_mic_provider_served;
}

void vcc_install_microphone_source(void) {
  Class cls = NSClassFromString(@"FigCaptureSourceBackingsProvider");
  if (!cls) {
    vcc_log(@"  mic source: FigCaptureSourceBackingsProvider missing (pre-iOS 27 layout)");
    return;
  }
  Method m = class_getClassMethod(cls, NSSelectorFromString(@"sharedCaptureSourceBackingsProvider"));
  if (!m) {
    vcc_log(@"  mic source: +sharedCaptureSourceBackingsProvider missing");
    return;
  }
  vcc_shared_provider_orig = method_setImplementation(m, (IMP)vcc_shared_provider_hook);
  vcc_log(@"  mic source: wrapped +[FigCaptureSourceBackingsProvider sharedCaptureSourceBackingsProvider] (orig imp=%p)",
          vcc_shared_provider_orig);
}
