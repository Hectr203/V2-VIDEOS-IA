// Logging and the "is this bound to our virtual camera" probes every hook
// shares.

#import "CamFixPrivate.h"

// MARK: - logging

void cfxlog(NSString *fmt, ...) {
  va_list ap; va_start(ap, fmt);
  NSString *line = [[NSString alloc] initWithFormat:fmt arguments:ap];
  va_end(ap);
  FILE *fp = fopen(VPHONE_VCAM_APP_LOG_PATH, "a");
  if (fp) {
    fprintf(fp, "[camfix:%d] %s\n", getpid(), line.UTF8String ?: "?");
    fclose(fp);
  } else {
    NSLog(@"camfix: %@", line);
  }
}

// MARK: - vcam binding probes

BOOL cfx_session_is_for_vcam(AVCaptureSession *session) {
  @try {
    for (AVCaptureInput *inp in session.inputs) {
      if ([inp isKindOfClass:[AVCaptureDeviceInput class]]) {
        AVCaptureDevice *d = ((AVCaptureDeviceInput *)inp).device;
        if ([d.uniqueID isEqualToString:VCAM_UID]) return YES;
      }
    }
  } @catch (NSException *e) {}
  return NO;
}

BOOL cfx_output_is_for_vcam(id self) {
  @try {
    NSArray *conns = [self valueForKey:@"connections"];
    for (AVCaptureConnection *conn in conns) {
      for (AVCaptureInputPort *port in conn.inputPorts) {
        id input = port.input;
        if ([input isKindOfClass:[AVCaptureDeviceInput class]]) {
          AVCaptureDevice *d = ((AVCaptureDeviceInput *)input).device;
          if ([d.uniqueID isEqualToString:VCAM_UID]) return YES;
        }
      }
    }
  } @catch (NSException *e) {
    cfxlog(@"connection probe exception: %@", e);
  }
  return NO;
}
