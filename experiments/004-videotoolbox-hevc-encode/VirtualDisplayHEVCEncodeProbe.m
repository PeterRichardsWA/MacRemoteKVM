#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>
#import <IOSurface/IOSurface.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <VideoToolbox/VideoToolbox.h>
#import <dispatch/dispatch.h>
#import <math.h>

@interface CGVirtualDisplayMode : NSObject
- (instancetype)initWithWidth:(NSUInteger)width height:(NSUInteger)height refreshRate:(double)refreshRate;
@end

@interface CGVirtualDisplaySettings : NSObject
@property(nonatomic, copy) NSArray *modes;
@property(nonatomic) unsigned int hiDPI;
@end

@interface CGVirtualDisplayDescriptor : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic) unsigned int maxPixelsWide;
@property(nonatomic) unsigned int maxPixelsHigh;
@property(nonatomic) CGSize sizeInMillimeters;
@property(nonatomic) unsigned int vendorID;
@property(nonatomic) unsigned int productID;
@property(nonatomic) unsigned int serialNum;
@property(nonatomic, strong) dispatch_queue_t queue;
@end

@interface CGVirtualDisplay : NSObject
- (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
@property(nonatomic, readonly) CGDirectDisplayID displayID;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;
@end

static NSUInteger integerArgument(int argc, const char *argv[], const char *name, NSUInteger defaultValue) {
    NSString *needle = [NSString stringWithFormat:@"--%s=", name];
    for (int i = 1; i < argc; i++) {
        NSString *argument = [NSString stringWithUTF8String:argv[i]];
        if ([argument hasPrefix:needle]) {
            return (NSUInteger)[[argument substringFromIndex:needle.length] integerValue];
        }
    }
    return defaultValue;
}

static NSString *stringArgument(int argc, const char *argv[], const char *name, NSString *defaultValue) {
    NSString *needle = [NSString stringWithFormat:@"--%s=", name];
    for (int i = 1; i < argc; i++) {
        NSString *argument = [NSString stringWithUTF8String:argv[i]];
        if ([argument hasPrefix:needle]) {
            return [argument substringFromIndex:needle.length];
        }
    }
    return defaultValue;
}

static BOOL waitForSemaphore(dispatch_semaphore_t semaphore, NSTimeInterval timeoutSeconds) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeoutSeconds];
    while ([deadline timeIntervalSinceNow] > 0) {
        if (dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_MSEC)) == 0) {
            return YES;
        }
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    return NO;
}

static void setVTBool(VTCompressionSessionRef session, CFStringRef key, BOOL value) {
    VTSessionSetProperty(session, key, value ? kCFBooleanTrue : kCFBooleanFalse);
}

static void setVTInt(VTCompressionSessionRef session, CFStringRef key, int32_t value) {
    CFNumberRef number = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &value);
    VTSessionSetProperty(session, key, number);
    CFRelease(number);
}

static NSString *statusName(NSInteger status) {
    switch (status) {
        case SCFrameStatusComplete: return @"complete";
        case SCFrameStatusIdle: return @"idle";
        case SCFrameStatusBlank: return @"blank";
        case SCFrameStatusSuspended: return @"suspended";
        case SCFrameStatusStarted: return @"started";
        case SCFrameStatusStopped: return @"stopped";
        default: return [NSString stringWithFormat:@"unknown-%ld", (long)status];
    }
}

@interface AnimatedProbeView : NSView
@property(nonatomic) NSUInteger frameIndex;
@property(nonatomic, strong) NSTimer *timer;
- (void)startAnimatingAtFPS:(NSUInteger)fps;
- (void)stopAnimating;
@end

@implementation AnimatedProbeView

- (BOOL)isFlipped {
    return YES;
}

- (void)startAnimatingAtFPS:(NSUInteger)fps {
    NSTimeInterval interval = 1.0 / (NSTimeInterval)MAX((NSUInteger)1, fps);
    __weak AnimatedProbeView *weakSelf = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(NSTimer *timer) {
        AnimatedProbeView *view = weakSelf;
        if (!view) {
            [timer invalidate];
            return;
        }
        view.frameIndex += 1;
        [view setNeedsDisplay:YES];
    }];
}

- (void)stopAnimating {
    [self.timer invalidate];
    self.timer = nil;
}

- (void)drawRect:(NSRect)dirtyRect {
    NSRect bounds = self.bounds;
    [[NSColor colorWithCalibratedRed:0.04 green:0.05 blue:0.06 alpha:1.0] setFill];
    NSRectFill(bounds);

    CGFloat t = self.frameIndex;
    CGFloat cell = 128.0;
    for (NSInteger y = -1; y < 24; y++) {
        for (NSInteger x = -1; x < 42; x++) {
            CGFloat hue = fmod((CGFloat)(x + y) * 0.035 + t * 0.006, 1.0);
            [[NSColor colorWithCalibratedHue:hue saturation:0.78 brightness:0.78 alpha:1.0] setFill];
            CGFloat dx = fmod((CGFloat)x * cell + t * 5.0, bounds.size.width + cell) - cell;
            CGFloat dy = (CGFloat)y * cell;
            NSRectFill(NSMakeRect(dx, dy, cell - 7.0, cell - 7.0));
        }
    }

    CGFloat boxSize = 220.0;
    CGFloat x = 60.0 + fmod(t * 21.0, MAX(1.0, bounds.size.width - boxSize - 120.0));
    CGFloat y = 140.0 + fmod(t * 11.0, MAX(1.0, bounds.size.height - boxSize - 220.0));
    [[NSColor colorWithCalibratedRed:1.0 green:0.92 blue:0.12 alpha:1.0] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(x, y, boxSize, boxSize) xRadius:18.0 yRadius:18.0] fill];

    NSDictionary *titleAttributes = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:38.0 weight:NSFontWeightBold],
        NSForegroundColorAttributeName: NSColor.whiteColor
    };
    NSDictionary *smallAttributes = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:22.0 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: [NSColor colorWithWhite:0.92 alpha:1.0]
    };
    [@"MacRemoteKVM Experiment 004" drawAtPoint:NSMakePoint(48.0, 38.0) withAttributes:titleAttributes];
    [[NSString stringWithFormat:@"5K SCStream -> VideoToolbox HEVC - view frame %lu", (unsigned long)self.frameIndex]
        drawAtPoint:NSMakePoint(52.0, 88.0) withAttributes:smallAttributes];
}

@end

@class EncodeProbe;
static void compressionOutputCallback(void *outputCallbackRefCon,
                                      void *sourceFrameRefCon,
                                      OSStatus status,
                                      VTEncodeInfoFlags infoFlags,
                                      CMSampleBufferRef sampleBuffer);

@interface EncodeProbe : NSObject <SCStreamOutput, SCStreamDelegate> {
    VTCompressionSessionRef _compressionSession;
}
@property(nonatomic) NSUInteger expectedWidth;
@property(nonatomic) NSUInteger expectedHeight;
@property(nonatomic) NSUInteger refresh;
@property(nonatomic) NSUInteger targetInputFrames;
@property(nonatomic) NSUInteger callbackCount;
@property(nonatomic) NSUInteger completeInputFrames;
@property(nonatomic) NSUInteger submittedFrames;
@property(nonatomic) NSUInteger encodeCallErrors;
@property(nonatomic) NSUInteger encodeCallDroppedFlags;
@property(nonatomic) NSUInteger outputCallbacks;
@property(nonatomic) NSUInteger encodedFrames;
@property(nonatomic) NSUInteger outputDroppedFrames;
@property(nonatomic) NSUInteger outputErrors;
@property(nonatomic) NSUInteger keyFrames;
@property(nonatomic) NSUInteger totalEncodedBytes;
@property(nonatomic) NSUInteger firstWidth;
@property(nonatomic) NSUInteger firstHeight;
@property(nonatomic) NSUInteger lastWidth;
@property(nonatomic) NSUInteger lastHeight;
@property(nonatomic) BOOL sawIOSurface;
@property(nonatomic) BOOL dimensionsMatched;
@property(nonatomic) NSTimeInterval firstInputWallTime;
@property(nonatomic) NSTimeInterval lastInputWallTime;
@property(nonatomic) NSTimeInterval firstOutputWallTime;
@property(nonatomic) NSTimeInterval lastOutputWallTime;
@property(nonatomic, strong) NSDate *startDate;
@property(nonatomic, strong) NSMutableString *csv;
@property(nonatomic, strong) NSString *encoderCreateNote;
@property(nonatomic, strong) NSError *streamError;
- (instancetype)initWithWidth:(NSUInteger)width height:(NSUInteger)height refresh:(NSUInteger)refresh targetInputFrames:(NSUInteger)targetInputFrames;
- (BOOL)createHEVCEncoderWithBitrateMbps:(NSUInteger)bitrateMbps;
- (void)finishEncoding;
- (void)invalidateEncoder;
- (BOOL)reachedTarget;
- (void)handleCompressionOutputWithStatus:(OSStatus)status infoFlags:(VTEncodeInfoFlags)infoFlags sampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (NSString *)summaryWithBitrateMbps:(NSUInteger)bitrateMbps;
- (NSString *)oneLineSummary;
@end

@implementation EncodeProbe

- (instancetype)initWithWidth:(NSUInteger)width height:(NSUInteger)height refresh:(NSUInteger)refresh targetInputFrames:(NSUInteger)targetInputFrames {
    self = [super init];
    if (self) {
        _expectedWidth = width;
        _expectedHeight = height;
        _refresh = refresh;
        _targetInputFrames = targetInputFrames;
        _dimensionsMatched = YES;
        _startDate = [NSDate date];
        _csv = [NSMutableString stringWithString:@"output_index,status,flags,bytes,wall_seconds,key_frame\n"];
    }
    return self;
}

- (BOOL)createHEVCEncoderWithBitrateMbps:(NSUInteger)bitrateMbps {
    NSDictionary *sourceAttributes = @{
        (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (__bridge NSString *)kCVPixelBufferWidthKey: @(self.expectedWidth),
        (__bridge NSString *)kCVPixelBufferHeightKey: @(self.expectedHeight),
        (__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{}
    };
    NSDictionary *lowLatencySpec = @{
        (__bridge NSString *)kVTVideoEncoderSpecification_EnableLowLatencyRateControl: @YES
    };

    OSStatus status = VTCompressionSessionCreate(NULL,
                                                 (int32_t)self.expectedWidth,
                                                 (int32_t)self.expectedHeight,
                                                 kCMVideoCodecType_HEVC,
                                                 (__bridge CFDictionaryRef)lowLatencySpec,
                                                 (__bridge CFDictionaryRef)sourceAttributes,
                                                 NULL,
                                                 compressionOutputCallback,
                                                 (__bridge void *)self,
                                                 &_compressionSession);
    self.encoderCreateNote = [NSString stringWithFormat:@"low-latency create status: %d", status];
    if (status != noErr || !_compressionSession) {
        _compressionSession = NULL;
        status = VTCompressionSessionCreate(NULL,
                                            (int32_t)self.expectedWidth,
                                            (int32_t)self.expectedHeight,
                                            kCMVideoCodecType_HEVC,
                                            NULL,
                                            (__bridge CFDictionaryRef)sourceAttributes,
                                            NULL,
                                            compressionOutputCallback,
                                            (__bridge void *)self,
                                            &_compressionSession);
        self.encoderCreateNote = [self.encoderCreateNote stringByAppendingFormat:@"; fallback create status: %d", status];
    }
    if (status != noErr || !_compressionSession) {
        return NO;
    }

    setVTBool(_compressionSession, kVTCompressionPropertyKey_RealTime, YES);
    setVTBool(_compressionSession, kVTCompressionPropertyKey_AllowFrameReordering, NO);
    setVTBool(_compressionSession, kVTCompressionPropertyKey_PrioritizeEncodingSpeedOverQuality, YES);
    setVTInt(_compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, (int32_t)self.refresh);
    setVTInt(_compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (int32_t)self.refresh);
    setVTInt(_compressionSession, kVTCompressionPropertyKey_AverageBitRate, (int32_t)(bitrateMbps * 1000 * 1000));
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_HEVC_Main_AutoLevel);

    status = VTCompressionSessionPrepareToEncodeFrames(_compressionSession);
    self.encoderCreateNote = [self.encoderCreateNote stringByAppendingFormat:@"; prepare status: %d", status];
    return status == noErr;
}

- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(SCStreamOutputType)type {
    if (type != SCStreamOutputTypeScreen || !sampleBuffer || !_compressionSession) {
        return;
    }

    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    NSInteger frameStatus = -1;
    CFArrayRef attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
    if (attachmentsArray && CFArrayGetCount(attachmentsArray) > 0) {
        NSDictionary *attachments = (__bridge NSDictionary *)CFArrayGetValueAtIndex(attachmentsArray, 0);
        NSNumber *statusNumber = attachments[SCStreamFrameInfoStatus];
        if (statusNumber) {
            frameStatus = statusNumber.integerValue;
        }
    }
    if (frameStatus != SCFrameStatusComplete || !imageBuffer) {
        @synchronized (self) {
            self.callbackCount += 1;
        }
        return;
    }

    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    IOSurfaceRef surface = CVPixelBufferGetIOSurface(imageBuffer);
    NSTimeInterval wallSeconds = -[self.startDate timeIntervalSinceNow];

    NSUInteger frameNumber;
    @synchronized (self) {
        self.callbackCount += 1;
        self.completeInputFrames += 1;
        if (self.completeInputFrames == 1) {
            self.firstInputWallTime = wallSeconds;
            self.firstWidth = width;
            self.firstHeight = height;
        }
        self.lastInputWallTime = wallSeconds;
        self.lastWidth = width;
        self.lastHeight = height;
        self.sawIOSurface = self.sawIOSurface || surface != NULL;
        self.dimensionsMatched = self.dimensionsMatched && (width == self.expectedWidth && height == self.expectedHeight);
        if (self.submittedFrames >= self.targetInputFrames) {
            return;
        }
        frameNumber = self.submittedFrames;
        self.submittedFrames += 1;
    }

    CMTime pts = CMTimeMake((int64_t)frameNumber, (int32_t)self.refresh);
    CMTime duration = CMTimeMake(1, (int32_t)self.refresh);
    VTEncodeInfoFlags flags = 0;
    OSStatus status = VTCompressionSessionEncodeFrame(_compressionSession,
                                                      imageBuffer,
                                                      pts,
                                                      duration,
                                                      NULL,
                                                      (void *)(uintptr_t)frameNumber,
                                                      &flags);
    @synchronized (self) {
        if (status != noErr) {
            self.encodeCallErrors += 1;
        }
        if ((flags & kVTEncodeInfo_FrameDropped) != 0) {
            self.encodeCallDroppedFlags += 1;
        }
    }
}

- (void)stream:(SCStream *)stream didStopWithError:(NSError *)error {
    @synchronized (self) {
        self.streamError = error;
    }
}

- (void)handleCompressionOutputWithStatus:(OSStatus)status infoFlags:(VTEncodeInfoFlags)infoFlags sampleBuffer:(CMSampleBufferRef)sampleBuffer {
    NSTimeInterval wallSeconds = -[self.startDate timeIntervalSinceNow];
    size_t bytes = sampleBuffer ? CMSampleBufferGetTotalSampleSize(sampleBuffer) : 0;
    BOOL dropped = (infoFlags & kVTEncodeInfo_FrameDropped) != 0;
    BOOL keyFrame = NO;
    if (sampleBuffer) {
        keyFrame = YES;
        CFArrayRef attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
        if (attachmentsArray && CFArrayGetCount(attachmentsArray) > 0) {
            NSDictionary *attachments = (__bridge NSDictionary *)CFArrayGetValueAtIndex(attachmentsArray, 0);
            NSNumber *notSync = attachments[(__bridge NSString *)kCMSampleAttachmentKey_NotSync];
            keyFrame = notSync ? !notSync.boolValue : YES;
        }
    }

    @synchronized (self) {
        self.outputCallbacks += 1;
        if (self.outputCallbacks == 1) {
            self.firstOutputWallTime = wallSeconds;
        }
        self.lastOutputWallTime = wallSeconds;
        if (status != noErr) {
            self.outputErrors += 1;
        }
        if (dropped) {
            self.outputDroppedFrames += 1;
        }
        if (sampleBuffer && status == noErr && !dropped) {
            self.encodedFrames += 1;
            self.totalEncodedBytes += bytes;
            if (keyFrame) {
                self.keyFrames += 1;
            }
        }
        [self.csv appendFormat:@"%lu,%d,%u,%zu,%.6f,%@\n",
         (unsigned long)self.outputCallbacks,
         status,
         infoFlags,
         bytes,
         wallSeconds,
         keyFrame ? @"yes" : @"no"];
    }
}

- (BOOL)reachedTarget {
    @synchronized (self) {
        return self.submittedFrames >= self.targetInputFrames;
    }
}

- (void)finishEncoding {
    if (_compressionSession) {
        VTCompressionSessionCompleteFrames(_compressionSession, kCMTimeInvalid);
    }
}

- (void)invalidateEncoder {
    if (_compressionSession) {
        VTCompressionSessionInvalidate(_compressionSession);
        CFRelease(_compressionSession);
        _compressionSession = NULL;
    }
}

- (NSString *)summaryWithBitrateMbps:(NSUInteger)bitrateMbps {
    @synchronized (self) {
        double inputSpan = MAX(0.001, self.lastInputWallTime - self.firstInputWallTime);
        double outputSpan = MAX(0.001, self.lastOutputWallTime - self.firstOutputWallTime);
        double submittedFPS = self.submittedFrames > 1 ? (double)(self.submittedFrames - 1) / inputSpan : 0.0;
        double encodedFPS = self.encodedFrames > 1 ? (double)(self.encodedFrames - 1) / outputSpan : 0.0;
        double observedMbps = outputSpan > 0.0 ? ((double)self.totalEncodedBytes * 8.0 / outputSpan / 1000000.0) : 0.0;
        double rawBytes = (double)self.encodedFrames * (double)self.expectedWidth * (double)self.expectedHeight * 4.0;
        double compressionRatio = self.totalEncodedBytes > 0 ? rawBytes / (double)self.totalEncodedBytes : 0.0;

        NSMutableString *summary = [NSMutableString string];
        [summary appendString:@"# Experiment 004 Result: Local HEVC Encode\n\n"];
        [summary appendFormat:@"Codec: HEVC\n"];
        [summary appendFormat:@"Expected frame size: %lux%lu\n", (unsigned long)self.expectedWidth, (unsigned long)self.expectedHeight];
        [summary appendFormat:@"Target bitrate: %lu Mbps\n", (unsigned long)bitrateMbps];
        [summary appendFormat:@"Encoder setup: %@\n", self.encoderCreateNote ?: @"unknown"];
        [summary appendFormat:@"Input callbacks: %lu\n", (unsigned long)self.callbackCount];
        [summary appendFormat:@"Complete input frames: %lu\n", (unsigned long)self.completeInputFrames];
        [summary appendFormat:@"Submitted to encoder: %lu\n", (unsigned long)self.submittedFrames];
        [summary appendFormat:@"Encode call errors: %lu\n", (unsigned long)self.encodeCallErrors];
        [summary appendFormat:@"Encode call dropped flags: %lu\n", (unsigned long)self.encodeCallDroppedFlags];
        [summary appendFormat:@"Encoder output callbacks: %lu\n", (unsigned long)self.outputCallbacks];
        [summary appendFormat:@"Encoded frames: %lu\n", (unsigned long)self.encodedFrames];
        [summary appendFormat:@"Output errors: %lu\n", (unsigned long)self.outputErrors];
        [summary appendFormat:@"Output dropped frames: %lu\n", (unsigned long)self.outputDroppedFrames];
        [summary appendFormat:@"Key frames: %lu\n", (unsigned long)self.keyFrames];
        [summary appendFormat:@"Total encoded bytes: %lu\n", (unsigned long)self.totalEncodedBytes];
        [summary appendFormat:@"Observed submit FPS: %.2f\n", submittedFPS];
        [summary appendFormat:@"Observed encoded FPS: %.2f\n", encodedFPS];
        [summary appendFormat:@"Observed encoded bitrate: %.2f Mbps\n", observedMbps];
        [summary appendFormat:@"Raw-to-encoded ratio: %.2f:1\n", compressionRatio];
        [summary appendFormat:@"Saw IOSurface-backed input buffers: %@\n", self.sawIOSurface ? @"yes" : @"no"];
        [summary appendFormat:@"All input dimensions matched expected: %@\n", self.dimensionsMatched ? @"yes" : @"no"];
        [summary appendFormat:@"Stream error: %@\n", self.streamError ? self.streamError.localizedDescription : @"none"];
        [summary appendString:@"\n## Encoder Output CSV\n\n"];
        [summary appendString:@"```csv\n"];
        [summary appendString:self.csv];
        [summary appendString:@"```\n"];
        return summary;
    }
}

- (NSString *)oneLineSummary {
    @synchronized (self) {
        return [NSString stringWithFormat:@"submitted=%lu encoded=%lu errors=%lu dropped=%lu bytes=%lu",
                (unsigned long)self.submittedFrames,
                (unsigned long)self.encodedFrames,
                (unsigned long)(self.encodeCallErrors + self.outputErrors),
                (unsigned long)(self.encodeCallDroppedFlags + self.outputDroppedFrames),
                (unsigned long)self.totalEncodedBytes];
    }
}

@end

static void compressionOutputCallback(void *outputCallbackRefCon,
                                      void *sourceFrameRefCon,
                                      OSStatus status,
                                      VTEncodeInfoFlags infoFlags,
                                      CMSampleBufferRef sampleBuffer) {
    EncodeProbe *probe = (__bridge EncodeProbe *)outputCallbackRefCon;
    [probe handleCompressionOutputWithStatus:status infoFlags:infoFlags sampleBuffer:sampleBuffer];
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

        Class descriptorClass = NSClassFromString(@"CGVirtualDisplayDescriptor");
        Class displayClass = NSClassFromString(@"CGVirtualDisplay");
        Class settingsClass = NSClassFromString(@"CGVirtualDisplaySettings");
        Class modeClass = NSClassFromString(@"CGVirtualDisplayMode");
        if (!descriptorClass || !displayClass || !settingsClass || !modeClass) {
            fprintf(stderr, "Missing private CoreGraphics virtual-display classes.\n");
            return 2;
        }

        NSUInteger backingWidth = integerArgument(argc, argv, "width", 5120);
        NSUInteger backingHeight = integerArgument(argc, argv, "height", 2880);
        NSUInteger refresh = integerArgument(argc, argv, "refresh", 60);
        NSUInteger seconds = integerArgument(argc, argv, "seconds", 8);
        NSUInteger targetFrames = integerArgument(argc, argv, "frames", 180);
        NSUInteger bitrateMbps = integerArgument(argc, argv, "bitrate-mbps", 120);
        BOOL hiDPI = integerArgument(argc, argv, "hidpi", 1) != 0;
        NSUInteger modeWidth = integerArgument(argc, argv, "mode-width", hiDPI ? backingWidth / 2 : backingWidth);
        NSUInteger modeHeight = integerArgument(argc, argv, "mode-height", hiDPI ? backingHeight / 2 : backingHeight);
        NSString *defaultOutput = @"/Users/peterrichards/dev/MacRemoteKVM/results/004-videotoolbox-hevc-encode/hevc-encode-result.md";
        NSString *outputPath = stringArgument(argc, argv, "output", defaultOutput);

        CGVirtualDisplayDescriptor *descriptor = [[descriptorClass alloc] init];
        descriptor.name = @"MacRemoteKVM Virtual 5K HEVC Probe";
        descriptor.maxPixelsWide = (unsigned int)backingWidth;
        descriptor.maxPixelsHigh = (unsigned int)backingHeight;
        descriptor.sizeInMillimeters = CGSizeMake(597, 336);
        descriptor.vendorID = 0x4D52;
        descriptor.productID = 0x5D5D;
        descriptor.serialNum = 0x0004;
        descriptor.queue = dispatch_get_main_queue();

        CGVirtualDisplay *virtualDisplay = [[displayClass alloc] initWithDescriptor:descriptor];
        if (!virtualDisplay) {
            fprintf(stderr, "CGVirtualDisplay initWithDescriptor returned nil.\n");
            return 3;
        }

        CGVirtualDisplaySettings *settings = [[settingsClass alloc] init];
        settings.hiDPI = hiDPI ? 1 : 0;
        settings.modes = @[
            [[modeClass alloc] initWithWidth:modeWidth height:modeHeight refreshRate:(double)refresh],
            [[modeClass alloc] initWithWidth:3840 height:2160 refreshRate:60.0],
            [[modeClass alloc] initWithWidth:2560 height:1440 refreshRate:60.0],
            [[modeClass alloc] initWithWidth:1920 height:1080 refreshRate:60.0],
        ];
        BOOL applied = [virtualDisplay applySettings:settings];
        printf("Created virtual display id=%u backingLimit=%zux%zu mode=%zux%zu@%zu hiDPI=%s applySettings=%s\n",
               virtualDisplay.displayID,
               backingWidth,
               backingHeight,
               modeWidth,
               modeHeight,
               refresh,
               hiDPI ? "yes" : "no",
               applied ? "true" : "false");
        fflush(stdout);

        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];

        CGRect displayBounds = CGDisplayBounds(virtualDisplay.displayID);
        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSRectFromCGRect(displayBounds)
                                                      styleMask:NSWindowStyleMaskBorderless
                                                        backing:NSBackingStoreBuffered
                                                          defer:NO];
        window.releasedWhenClosed = NO;
        window.level = NSNormalWindowLevel;
        window.opaque = YES;
        window.backgroundColor = NSColor.blackColor;
        AnimatedProbeView *probeView = [[AnimatedProbeView alloc] initWithFrame:NSMakeRect(0, 0, displayBounds.size.width, displayBounds.size.height)];
        window.contentView = probeView;
        [window orderFrontRegardless];
        [probeView startAnimatingAtFPS:refresh];

        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];

        dispatch_semaphore_t contentSemaphore = dispatch_semaphore_create(0);
        __block SCShareableContent *shareableContent = nil;
        __block NSError *shareableError = nil;
        [SCShareableContent getShareableContentExcludingDesktopWindows:NO
                                                    onScreenWindowsOnly:NO
                                                      completionHandler:^(SCShareableContent *_Nullable content, NSError *_Nullable error) {
            shareableContent = content;
            shareableError = error;
            dispatch_semaphore_signal(contentSemaphore);
        }];
        if (!waitForSemaphore(contentSemaphore, 10.0) || shareableError) {
            fprintf(stderr, "ScreenCaptureKit shareable content error: %s\n", shareableError.localizedDescription.UTF8String ?: "timeout");
            return 4;
        }

        SCDisplay *targetDisplay = nil;
        for (SCDisplay *display in shareableContent.displays) {
            if (display.displayID == virtualDisplay.displayID) {
                targetDisplay = display;
            }
        }
        if (!targetDisplay) {
            fprintf(stderr, "ScreenCaptureKit did not enumerate the virtual display id=%u.\n", virtualDisplay.displayID);
            return 5;
        }

        EncodeProbe *probe = [[EncodeProbe alloc] initWithWidth:backingWidth height:backingHeight refresh:refresh targetInputFrames:targetFrames];
        if (![probe createHEVCEncoderWithBitrateMbps:bitrateMbps]) {
            fprintf(stderr, "Could not create or prepare HEVC encoder.\n");
            return 6;
        }

        SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:targetDisplay excludingWindows:@[]];
        SCStreamConfiguration *config = [[SCStreamConfiguration alloc] init];
        config.width = backingWidth;
        config.height = backingHeight;
        config.minimumFrameInterval = CMTimeMake(1, (int32_t)refresh);
        config.pixelFormat = kCVPixelFormatType_32BGRA;
        config.showsCursor = NO;
        config.capturesAudio = NO;
        config.captureResolution = SCCaptureResolutionBest;
        config.queueDepth = 8;

        SCStream *stream = [[SCStream alloc] initWithFilter:filter configuration:config delegate:probe];
        dispatch_queue_t sampleQueue = dispatch_queue_create("dev.macremotekvm.hevc-probe.samples", DISPATCH_QUEUE_SERIAL);
        NSError *outputError = nil;
        if (![stream addStreamOutput:probe type:SCStreamOutputTypeScreen sampleHandlerQueue:sampleQueue error:&outputError]) {
            fprintf(stderr, "addStreamOutput failed: %s\n", outputError.localizedDescription.UTF8String);
            return 7;
        }

        dispatch_semaphore_t startSemaphore = dispatch_semaphore_create(0);
        __block NSError *startError = nil;
        [stream startCaptureWithCompletionHandler:^(NSError *_Nullable error) {
            startError = error;
            dispatch_semaphore_signal(startSemaphore);
        }];
        if (!waitForSemaphore(startSemaphore, 10.0) || startError) {
            fprintf(stderr, "SCStream startCapture error: %s\n", startError.localizedDescription.UTF8String ?: "timeout");
            return 8;
        }

        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval)seconds];
        while ([deadline timeIntervalSinceNow] > 0 && ![probe reachedTarget]) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        }

        dispatch_semaphore_t stopSemaphore = dispatch_semaphore_create(0);
        [stream stopCaptureWithCompletionHandler:^(NSError *_Nullable error) {
            dispatch_semaphore_signal(stopSemaphore);
        }];
        waitForSemaphore(stopSemaphore, 5.0);

        [probe finishEncoding];
        [probeView stopAnimating];
        [window close];

        NSString *summary = [probe summaryWithBitrateMbps:bitrateMbps];
        NSError *writeError = nil;
        BOOL wrote = [summary writeToFile:outputPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
        [probe invalidateEncoder];
        if (!wrote) {
            fprintf(stderr, "Could not write result file: %s\n", writeError.localizedDescription.UTF8String);
            return 9;
        }

        printf("%s\n", [probe oneLineSummary].UTF8String);
        printf("Wrote result: %s\n", outputPath.UTF8String);
        fflush(stdout);
        NSLog(@"Releasing virtual display id=%u and exiting.", virtualDisplay.displayID);
    }
    return 0;
}
