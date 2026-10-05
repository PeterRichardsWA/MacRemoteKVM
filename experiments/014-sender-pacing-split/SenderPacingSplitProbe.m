#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>
#import <IOSurface/IOSurface.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <VideoToolbox/VideoToolbox.h>
#import <mach/mach_time.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <unistd.h>

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

static uint64_t nowNanos(void) {
    static mach_timebase_info_data_t timebase;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info(&timebase);
    });
    __uint128_t ticks = mach_absolute_time();
    ticks *= timebase.numer;
    ticks /= timebase.denom;
    return (uint64_t)ticks;
}

static void sleepUntilNanos(uint64_t targetNanos) {
    uint64_t now = nowNanos();
    if (targetNanos <= now) {
        return;
    }
    uint64_t delta = targetNanos - now;
    struct timespec request = {
        .tv_sec = (time_t)(delta / 1000000000ULL),
        .tv_nsec = (long)(delta % 1000000000ULL)
    };
    while (nanosleep(&request, &request) == -1 && errno == EINTR) {
    }
}

static double nanosToSeconds(uint64_t nanos) {
    return (double)nanos / 1000000000.0;
}

static double nanosToMS(uint64_t nanos) {
    return (double)nanos / 1000000.0;
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

static NSString *yesNo(BOOL value) {
    return value ? @"yes" : @"no";
}

static NSString *fourCC(OSType code) {
    char chars[5] = {
        (char)((code >> 24) & 0xff),
        (char)((code >> 16) & 0xff),
        (char)((code >> 8) & 0xff),
        (char)(code & 0xff),
        0
    };
    return [NSString stringWithUTF8String:chars];
}

static NSString *sysctlString(const char *name) {
    size_t size = 0;
    if (sysctlbyname(name, NULL, &size, NULL, 0) != 0 || size == 0) {
        return @"unavailable";
    }
    char *buffer = calloc(1, size);
    if (!buffer) {
        return @"unavailable";
    }
    NSString *result = @"unavailable";
    if (sysctlbyname(name, buffer, &size, NULL, 0) == 0) {
        result = [NSString stringWithUTF8String:buffer] ?: @"unavailable";
    }
    free(buffer);
    return result;
}

static void createDirectory(NSString *path) {
    [[NSFileManager defaultManager] createDirectoryAtPath:path
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
}

static void createOutputDirectory(NSString *filePath) {
    NSString *directory = [filePath stringByDeletingLastPathComponent];
    if (directory.length > 0) {
        createDirectory(directory);
    }
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

static NSUInteger integerArgument(int argc, const char *argv[], const char *name, NSUInteger defaultValue) {
    NSString *value = stringArgument(argc, argv, name, nil);
    return value.length > 0 ? (NSUInteger)MAX(0, value.integerValue) : defaultValue;
}

static NSTimeInterval doubleArgument(int argc, const char *argv[], const char *name, NSTimeInterval defaultValue) {
    NSString *value = stringArgument(argc, argv, name, nil);
    return value.length > 0 ? MAX(0.0, value.doubleValue) : defaultValue;
}

static void setVTBool(VTCompressionSessionRef session, CFStringRef key, BOOL value) {
    VTSessionSetProperty(session, key, value ? kCFBooleanTrue : kCFBooleanFalse);
}

static void setVTInt(VTCompressionSessionRef session, CFStringRef key, int32_t value) {
    CFNumberRef number = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &value);
    VTSessionSetProperty(session, key, number);
    CFRelease(number);
}

@interface AnimatedProbeView : NSView
@property(nonatomic) NSUInteger frameIndex;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, copy) NSString *label;
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
    [[NSColor colorWithCalibratedRed:0.035 green:0.045 blue:0.055 alpha:1.0] setFill];
    NSRectFill(bounds);

    CGFloat t = (CGFloat)self.frameIndex;
    CGFloat stripe = 108.0;
    for (NSInteger i = -2; i < 60; i++) {
        CGFloat x = fmod((CGFloat)i * stripe + t * 9.0, bounds.size.width + stripe) - stripe;
        NSColor *color = (i % 3 == 0)
            ? [NSColor colorWithCalibratedRed:0.08 green:0.44 blue:0.90 alpha:1.0]
            : (i % 3 == 1)
                ? [NSColor colorWithCalibratedRed:0.06 green:0.68 blue:0.48 alpha:1.0]
                : [NSColor colorWithCalibratedRed:0.86 green:0.30 blue:0.28 alpha:1.0];
        [color setFill];
        NSBezierPath *path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(x, 0)];
        [path lineToPoint:NSMakePoint(x + stripe * 0.45, 0)];
        [path lineToPoint:NSMakePoint(x + stripe * 1.15, bounds.size.height)];
        [path lineToPoint:NSMakePoint(x + stripe * 0.70, bounds.size.height)];
        [path closePath];
        [path fill];
    }

    CGFloat boxSize = 210.0;
    CGFloat travelX = MAX(1.0, bounds.size.width - boxSize - 100.0);
    CGFloat travelY = MAX(1.0, bounds.size.height - boxSize - 180.0);
    CGFloat x = 50.0 + fmod(t * 23.0, travelX);
    CGFloat y = 120.0 + fmod(t * 13.0, travelY);
    [[NSColor colorWithCalibratedRed:1.0 green:0.86 blue:0.18 alpha:1.0] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(x, y, boxSize, boxSize) xRadius:18.0 yRadius:18.0] fill];

    NSDictionary *titleAttributes = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:38.0 weight:NSFontWeightBold],
        NSForegroundColorAttributeName: NSColor.whiteColor
    };
    NSDictionary *smallAttributes = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:22.0 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: [NSColor colorWithWhite:0.92 alpha:1.0]
    };

    [@"MacRemoteKVM Experiment 014" drawAtPoint:NSMakePoint(48.0, 38.0) withAttributes:titleAttributes];
    [[NSString stringWithFormat:@"%@ - live frame %lu", self.label ?: @"Capture", (unsigned long)self.frameIndex]
        drawAtPoint:NSMakePoint(52.0, 88.0) withAttributes:smallAttributes];
}

@end

@interface CaptureOnlyCase : NSObject <SCStreamOutput, SCStreamDelegate>
@property(nonatomic, copy) NSString *caseName;
@property(nonatomic, copy) NSString *outputPath;
@property(nonatomic) NSUInteger width;
@property(nonatomic) NSUInteger height;
@property(nonatomic) NSUInteger refresh;
@property(nonatomic) NSUInteger backingWidth;
@property(nonatomic) NSUInteger backingHeight;
@property(nonatomic) NSTimeInterval requestedDurationSeconds;
@property(nonatomic) BOOL success;
@property(nonatomic, copy) NSString *failure;
@property(nonatomic, strong) NSError *streamError;
@property(nonatomic) CGDirectDisplayID virtualDisplayID;
@property(nonatomic) NSUInteger streamCallbacks;
@property(nonatomic) NSUInteger warmupCallbacks;
@property(nonatomic) NSUInteger completeFrames;
@property(nonatomic) NSUInteger incompleteFrames;
@property(nonatomic) NSUInteger firstFrameWidth;
@property(nonatomic) NSUInteger firstFrameHeight;
@property(nonatomic) NSUInteger lastFrameWidth;
@property(nonatomic) NSUInteger lastFrameHeight;
@property(nonatomic) BOOL sawIOSurface;
@property(nonatomic) BOOL dimensionsMatched;
@property(nonatomic) uint64_t startNanos;
@property(nonatomic) BOOL acceptingFrames;
@property(nonatomic) NSTimeInterval captureWallSeconds;
@property(nonatomic) NSTimeInterval firstFrameWallSeconds;
@property(nonatomic) NSTimeInterval lastFrameWallSeconds;
@property(nonatomic) double interarrivalSumMS;
@property(nonatomic) double interarrivalMinMS;
@property(nonatomic) double interarrivalMaxMS;
@property(nonatomic) uint64_t lastFrameNanos;
- (BOOL)run;
- (void)writeReport;
@end

@implementation CaptureOnlyCase

- (instancetype)init {
    self = [super init];
    if (self) {
        _refresh = 60;
        _requestedDurationSeconds = 10.0;
        _backingWidth = 5120;
        _backingHeight = 2880;
        _dimensionsMatched = YES;
        _interarrivalMinMS = DBL_MAX;
    }
    return self;
}

- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(SCStreamOutputType)type {
    if (type != SCStreamOutputTypeScreen || !sampleBuffer) {
        return;
    }

    @synchronized (self) {
        if (!self.acceptingFrames) {
            self.warmupCallbacks += 1;
            return;
        }
        self.streamCallbacks += 1;
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

    uint64_t now = nowNanos();
    if (frameStatus != SCFrameStatusComplete || !imageBuffer) {
        @synchronized (self) {
            self.incompleteFrames += 1;
        }
        return;
    }

    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    IOSurfaceRef surface = CVPixelBufferGetIOSurface(imageBuffer);
    NSTimeInterval wallSeconds = nanosToSeconds(now - self.startNanos);

    @synchronized (self) {
        if (self.completeFrames == 0) {
            self.firstFrameWallSeconds = wallSeconds;
            self.firstFrameWidth = width;
            self.firstFrameHeight = height;
        }
        if (self.lastFrameNanos > 0) {
            double interarrivalMS = nanosToMS(now - self.lastFrameNanos);
            self.interarrivalSumMS += interarrivalMS;
            self.interarrivalMinMS = MIN(self.interarrivalMinMS, interarrivalMS);
            self.interarrivalMaxMS = MAX(self.interarrivalMaxMS, interarrivalMS);
        }
        self.lastFrameNanos = now;
        self.lastFrameWallSeconds = wallSeconds;
        self.lastFrameWidth = width;
        self.lastFrameHeight = height;
        self.sawIOSurface = self.sawIOSurface || surface != NULL;
        self.dimensionsMatched = self.dimensionsMatched && (width == self.width && height == self.height);
        self.completeFrames += 1;
    }
}

- (void)stream:(SCStream *)stream didStopWithError:(NSError *)error {
    @synchronized (self) {
        self.streamError = error;
    }
}

- (BOOL)run {
    Class descriptorClass = NSClassFromString(@"CGVirtualDisplayDescriptor");
    Class displayClass = NSClassFromString(@"CGVirtualDisplay");
    Class settingsClass = NSClassFromString(@"CGVirtualDisplaySettings");
    Class modeClass = NSClassFromString(@"CGVirtualDisplayMode");
    if (!descriptorClass || !displayClass || !settingsClass || !modeClass) {
        self.failure = @"missing private CoreGraphics virtual-display classes";
        [self writeReport];
        return NO;
    }

    CGVirtualDisplayDescriptor *descriptor = [[descriptorClass alloc] init];
    descriptor.name = [NSString stringWithFormat:@"MacRemoteKVM Capture %@", self.caseName ?: @"Probe"];
    descriptor.maxPixelsWide = (unsigned int)self.backingWidth;
    descriptor.maxPixelsHigh = (unsigned int)self.backingHeight;
    descriptor.sizeInMillimeters = CGSizeMake(597, 336);
    descriptor.vendorID = 0x4D52;
    descriptor.productID = 0x5D61;
    descriptor.serialNum = (unsigned int)(0x1400 + self.width / 10 + self.height / 10);
    descriptor.queue = dispatch_get_main_queue();

    CGVirtualDisplay *virtualDisplay = [[displayClass alloc] initWithDescriptor:descriptor];
    if (!virtualDisplay) {
        self.failure = @"CGVirtualDisplay initWithDescriptor returned nil";
        [self writeReport];
        return NO;
    }
    self.virtualDisplayID = virtualDisplay.displayID;

    CGVirtualDisplaySettings *settings = [[settingsClass alloc] init];
    settings.hiDPI = 1;
    settings.modes = @[
        [[modeClass alloc] initWithWidth:self.backingWidth / 2 height:self.backingHeight / 2 refreshRate:(double)self.refresh],
        [[modeClass alloc] initWithWidth:3840 height:2160 refreshRate:60.0],
        [[modeClass alloc] initWithWidth:2560 height:1440 refreshRate:60.0],
        [[modeClass alloc] initWithWidth:1920 height:1080 refreshRate:60.0],
    ];
    if (![virtualDisplay applySettings:settings]) {
        self.failure = @"virtual display applySettings returned false";
        [self writeReport];
        return NO;
    }

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
    probeView.label = self.caseName;
    window.contentView = probeView;
    [window orderFrontRegardless];
    [probeView startAnimatingAtFPS:self.refresh];

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
        self.failure = [NSString stringWithFormat:@"ScreenCaptureKit shareable content error: %@", shareableError.localizedDescription ?: @"timeout"];
        [probeView stopAnimating];
        [window close];
        [self writeReport];
        return NO;
    }

    SCDisplay *targetDisplay = nil;
    for (SCDisplay *display in shareableContent.displays) {
        if (display.displayID == virtualDisplay.displayID) {
            targetDisplay = display;
            break;
        }
    }
    if (!targetDisplay) {
        self.failure = [NSString stringWithFormat:@"ScreenCaptureKit did not enumerate virtual display id=%u", virtualDisplay.displayID];
        [probeView stopAnimating];
        [window close];
        [self writeReport];
        return NO;
    }

    SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:targetDisplay excludingWindows:@[]];
    SCStreamConfiguration *config = [[SCStreamConfiguration alloc] init];
    config.width = self.width;
    config.height = self.height;
    config.minimumFrameInterval = CMTimeMake(1, (int32_t)self.refresh);
    config.pixelFormat = kCVPixelFormatType_32BGRA;
    config.showsCursor = NO;
    config.capturesAudio = NO;
    config.captureResolution = SCCaptureResolutionBest;
    config.queueDepth = 8;

    SCStream *stream = [[SCStream alloc] initWithFilter:filter configuration:config delegate:self];
    dispatch_queue_t sampleQueue = dispatch_queue_create("dev.macremotekvm.sender-pacing.capture", DISPATCH_QUEUE_SERIAL);
    NSError *outputError = nil;
    if (![stream addStreamOutput:self type:SCStreamOutputTypeScreen sampleHandlerQueue:sampleQueue error:&outputError]) {
        self.failure = [NSString stringWithFormat:@"addStreamOutput failed: %@", outputError.localizedDescription ?: @"unknown"];
        [probeView stopAnimating];
        [window close];
        [self writeReport];
        return NO;
    }

    dispatch_semaphore_t startSemaphore = dispatch_semaphore_create(0);
    __block NSError *startError = nil;
    [stream startCaptureWithCompletionHandler:^(NSError *_Nullable error) {
        startError = error;
        dispatch_semaphore_signal(startSemaphore);
    }];
    if (!waitForSemaphore(startSemaphore, 10.0) || startError) {
        self.failure = [NSString stringWithFormat:@"SCStream startCapture error: %@", startError.localizedDescription ?: @"timeout"];
        [probeView stopAnimating];
        [window close];
        [self writeReport];
        return NO;
    }

    @synchronized (self) {
        self.startNanos = nowNanos();
        self.acceptingFrames = YES;
    }
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:self.requestedDurationSeconds];
    while ([deadline timeIntervalSinceNow] > 0 && !self.streamError) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    self.captureWallSeconds = nanosToSeconds(nowNanos() - self.startNanos);

    dispatch_semaphore_t stopSemaphore = dispatch_semaphore_create(0);
    [stream stopCaptureWithCompletionHandler:^(NSError *_Nullable error) {
        dispatch_semaphore_signal(stopSemaphore);
    }];
    waitForSemaphore(stopSemaphore, 5.0);

    [probeView stopAnimating];
    [window close];

    self.success = self.failure == nil && self.streamError == nil && self.completeFrames > 0 && self.dimensionsMatched;
    [self writeReport];
    return self.success;
}

- (void)writeReport {
    createOutputDirectory(self.outputPath);
    double completeFPSByWindow = self.captureWallSeconds > 0.0 ? (double)self.completeFrames / self.captureWallSeconds : 0.0;
    double completeFPSByFrames = (self.lastFrameWallSeconds - self.firstFrameWallSeconds) > 0.0 && self.completeFrames > 1
        ? (double)(self.completeFrames - 1) / (self.lastFrameWallSeconds - self.firstFrameWallSeconds)
        : 0.0;
    double averageInterarrivalMS = self.completeFrames > 1 ? self.interarrivalSumMS / (double)(self.completeFrames - 1) : 0.0;
    double minInterarrivalMS = self.interarrivalMinMS == DBL_MAX ? 0.0 : self.interarrivalMinMS;

    NSMutableString *report = [NSMutableString string];
    [report appendFormat:@"# Experiment 014 Capture-Only Result: %@\n\n", self.caseName ?: @"Capture"];
    [report appendString:@"## Machine\n\n"];
    NSProcessInfo *processInfo = NSProcessInfo.processInfo;
    [report appendFormat:@"- Host name: %@\n", processInfo.hostName];
    [report appendFormat:@"- macOS: %@\n", processInfo.operatingSystemVersionString];
    [report appendFormat:@"- Hardware model: %@\n", sysctlString("hw.model")];
    [report appendFormat:@"- CPU brand: %@\n", sysctlString("machdep.cpu.brand_string")];

    [report appendString:@"\n## Capture Settings\n\n"];
    [report appendFormat:@"- Requested duration: %.1f seconds\n", self.requestedDurationSeconds];
    [report appendString:@"- Source: software 5K virtual display with animated AppKit content\n"];
    [report appendFormat:@"- Virtual display id: %u\n", self.virtualDisplayID];
    [report appendFormat:@"- Virtual display backing size: %lu x %lu\n", (unsigned long)self.backingWidth, (unsigned long)self.backingHeight];
    [report appendFormat:@"- Capture dimensions: %lu x %lu\n", (unsigned long)self.width, (unsigned long)self.height];
    [report appendFormat:@"- Capture FPS target: %lu\n", (unsigned long)self.refresh];
    [report appendString:@"- Encode/network work: none\n"];

    [report appendString:@"\n## Capture Result\n\n"];
    [report appendFormat:@"- Success: %@\n", yesNo(self.success)];
    if (self.failure) {
        [report appendFormat:@"- Failure: %@\n", self.failure];
    }
    [report appendFormat:@"- Stream error: %@\n", self.streamError ? self.streamError.localizedDescription : @"none"];
    [report appendFormat:@"- Warmup callbacks ignored before measured window: %lu\n", (unsigned long)self.warmupCallbacks];
    [report appendFormat:@"- Stream callbacks: %lu\n", (unsigned long)self.streamCallbacks];
    [report appendFormat:@"- Complete frames: %lu\n", (unsigned long)self.completeFrames];
    [report appendFormat:@"- Incomplete/non-frame callbacks: %lu\n", (unsigned long)self.incompleteFrames];
    [report appendFormat:@"- First frame: %lu x %lu\n", (unsigned long)self.firstFrameWidth, (unsigned long)self.firstFrameHeight];
    [report appendFormat:@"- Last frame: %lu x %lu\n", (unsigned long)self.lastFrameWidth, (unsigned long)self.lastFrameHeight];
    [report appendFormat:@"- Saw IOSurface-backed buffers: %@\n", yesNo(self.sawIOSurface)];
    [report appendFormat:@"- All frame dimensions matched expected: %@\n", yesNo(self.dimensionsMatched)];
    [report appendFormat:@"- Capture wall time: %.3f seconds\n", self.captureWallSeconds];
    [report appendFormat:@"- Complete FPS by capture window: %.2f\n", completeFPSByWindow];
    [report appendFormat:@"- Complete FPS by first/last frame: %.2f\n", completeFPSByFrames];
    [report appendFormat:@"- Average complete-frame interarrival: %.3f ms\n", averageInterarrivalMS];
    [report appendFormat:@"- Min complete-frame interarrival: %.3f ms\n", minInterarrivalMS];
    [report appendFormat:@"- Max complete-frame interarrival: %.3f ms\n", self.interarrivalMaxMS];

    [report appendString:@"\n## Interpretation\n\n"];
    if (self.success && completeFPSByFrames >= (double)self.refresh * 0.95) {
        [report appendString:@"ScreenCaptureKit capture stayed inside the current 95% pass band for this shape without encode or network work.\n"];
    } else if (self.success) {
        [report appendString:@"Capture completed cleanly but did not hold the current 95% pass band before encode or network work was added.\n"];
    } else {
        [report appendString:@"Capture did not complete cleanly for this shape.\n"];
    }

    NSError *error = nil;
    if (![report writeToFile:self.outputPath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        fprintf(stderr, "Could not write capture report: %s\n", error.localizedDescription.UTF8String);
    } else {
        printf("Wrote capture report: %s\n", self.outputPath.UTF8String);
    }
}

@end

@class EncodeOnlyCase;
static void encodeOnlyOutputCallback(void *outputCallbackRefCon,
                                     void *sourceFrameRefCon,
                                     OSStatus status,
                                     VTEncodeInfoFlags infoFlags,
                                     CMSampleBufferRef sampleBuffer);

@interface EncodeOnlyCase : NSObject {
    VTCompressionSessionRef _compressionSession;
    CVPixelBufferPoolRef _pixelBufferPool;
}
@property(nonatomic, copy) NSString *caseName;
@property(nonatomic, copy) NSString *outputPath;
@property(nonatomic) OSType codec;
@property(nonatomic, copy) NSString *codecDisplayName;
@property(nonatomic) NSUInteger width;
@property(nonatomic) NSUInteger height;
@property(nonatomic) NSUInteger refresh;
@property(nonatomic) NSUInteger bitrateMbps;
@property(nonatomic) NSUInteger ringSize;
@property(nonatomic) NSTimeInterval requestedDurationSeconds;
@property(nonatomic) BOOL success;
@property(nonatomic, copy) NSString *failure;
@property(nonatomic, copy) NSString *encoderNote;
@property(nonatomic) NSUInteger submittedFrames;
@property(nonatomic) NSUInteger encodeCallErrors;
@property(nonatomic) NSUInteger encodeCallDroppedFlags;
@property(nonatomic) NSUInteger outputCallbacks;
@property(nonatomic) NSUInteger outputErrors;
@property(nonatomic) NSUInteger outputDroppedFrames;
@property(nonatomic) NSUInteger keyFrames;
@property(nonatomic) unsigned long long encodedBytes;
@property(nonatomic) NSTimeInterval submissionWallSeconds;
@property(nonatomic) NSTimeInterval totalWallSeconds;
@property(nonatomic) NSTimeInterval drainWallSeconds;
@property(nonatomic) NSTimeInterval firstOutputWallSeconds;
@property(nonatomic) NSTimeInterval lastOutputWallSeconds;
@property(nonatomic) uint64_t startNanos;
- (BOOL)run;
- (void)handleCompressionOutputWithStatus:(OSStatus)status infoFlags:(VTEncodeInfoFlags)infoFlags sampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)writeReport;
@end

@implementation EncodeOnlyCase

- (instancetype)init {
    self = [super init];
    if (self) {
        _refresh = 60;
        _requestedDurationSeconds = 10.0;
        _ringSize = 4;
    }
    return self;
}

- (BOOL)createPixelBufferPool {
    NSDictionary *attributes = @{
        (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (__bridge NSString *)kCVPixelBufferWidthKey: @(self.width),
        (__bridge NSString *)kCVPixelBufferHeightKey: @(self.height),
        (__bridge NSString *)kCVPixelBufferBytesPerRowAlignmentKey: @(64),
        (__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{}
    };
    CVReturn result = CVPixelBufferPoolCreate(NULL, NULL, (__bridge CFDictionaryRef)attributes, &_pixelBufferPool);
    if (result != kCVReturnSuccess || !_pixelBufferPool) {
        self.failure = [NSString stringWithFormat:@"CVPixelBufferPoolCreate failed: %d", result];
        return NO;
    }
    return YES;
}

- (BOOL)createEncoder {
    NSDictionary *sourceAttributes = @{
        (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (__bridge NSString *)kCVPixelBufferWidthKey: @(self.width),
        (__bridge NSString *)kCVPixelBufferHeightKey: @(self.height),
        (__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{}
    };
    NSDictionary *lowLatencySpec = @{
        (__bridge NSString *)kVTVideoEncoderSpecification_EnableLowLatencyRateControl: @YES
    };

    OSStatus status = VTCompressionSessionCreate(NULL,
                                                 (int32_t)self.width,
                                                 (int32_t)self.height,
                                                 self.codec,
                                                 (__bridge CFDictionaryRef)lowLatencySpec,
                                                 (__bridge CFDictionaryRef)sourceAttributes,
                                                 NULL,
                                                 encodeOnlyOutputCallback,
                                                 (__bridge void *)self,
                                                 &_compressionSession);
    self.encoderNote = [NSString stringWithFormat:@"low-latency create status: %d", status];
    if (status != noErr || !_compressionSession) {
        _compressionSession = NULL;
        status = VTCompressionSessionCreate(NULL,
                                            (int32_t)self.width,
                                            (int32_t)self.height,
                                            self.codec,
                                            NULL,
                                            (__bridge CFDictionaryRef)sourceAttributes,
                                            NULL,
                                            encodeOnlyOutputCallback,
                                            (__bridge void *)self,
                                            &_compressionSession);
        self.encoderNote = [self.encoderNote stringByAppendingFormat:@"; fallback create status: %d", status];
    }
    if (status != noErr || !_compressionSession) {
        return NO;
    }

    setVTBool(_compressionSession, kVTCompressionPropertyKey_RealTime, YES);
    setVTBool(_compressionSession, kVTCompressionPropertyKey_AllowFrameReordering, NO);
    setVTBool(_compressionSession, kVTCompressionPropertyKey_PrioritizeEncodingSpeedOverQuality, YES);
    setVTInt(_compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, (int32_t)self.refresh);
    setVTInt(_compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (int32_t)self.refresh);
    setVTInt(_compressionSession, kVTCompressionPropertyKey_AverageBitRate, (int32_t)(self.bitrateMbps * 1000 * 1000));
    if (self.codec == kCMVideoCodecType_H264) {
        VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_High_AutoLevel);
    } else if (self.codec == kCMVideoCodecType_HEVC) {
        VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_HEVC_Main_AutoLevel);
    }

    status = VTCompressionSessionPrepareToEncodeFrames(_compressionSession);
    self.encoderNote = [self.encoderNote stringByAppendingFormat:@"; prepare status: %d", status];
    return status == noErr;
}

- (BOOL)fillPixelBuffer:(CVPixelBufferRef)buffer index:(NSUInteger)index {
    CVReturn result = CVPixelBufferLockBaseAddress(buffer, 0);
    if (result != kCVReturnSuccess) {
        return NO;
    }
    uint8_t *base = CVPixelBufferGetBaseAddress(buffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
    size_t width = CVPixelBufferGetWidth(buffer);
    size_t height = CVPixelBufferGetHeight(buffer);
    uint8_t blue = (uint8_t)((index * 37) & 0xff);
    uint8_t green = (uint8_t)(90 + ((index * 17) & 0x7f));
    uint8_t red = (uint8_t)(170 - ((index * 11) & 0x7f));

    for (size_t y = 0; y < height; y++) {
        uint32_t *row = (uint32_t *)(base + y * bytesPerRow);
        for (size_t x = 0; x < width; x++) {
            BOOL stripe = ((x / 96 + y / 96 + index) % 3) == 0;
            uint8_t r = stripe ? red : (uint8_t)(red / 2);
            uint8_t g = stripe ? green : (uint8_t)(green / 2);
            uint8_t b = stripe ? blue : (uint8_t)(blue / 2 + 32);
            row[x] = ((uint32_t)0xff << 24) | ((uint32_t)r << 16) | ((uint32_t)g << 8) | b;
        }
    }
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    return YES;
}

- (NSArray *)createSyntheticBuffers {
    if (![self createPixelBufferPool]) {
        return @[];
    }

    NSMutableArray *buffers = [NSMutableArray arrayWithCapacity:self.ringSize];
    for (NSUInteger i = 0; i < self.ringSize; i++) {
        CVPixelBufferRef buffer = NULL;
        CVReturn result = CVPixelBufferPoolCreatePixelBuffer(NULL, _pixelBufferPool, &buffer);
        if (result != kCVReturnSuccess || !buffer) {
            self.failure = [NSString stringWithFormat:@"CVPixelBufferPoolCreatePixelBuffer failed at buffer %lu: %d", (unsigned long)i, result];
            break;
        }
        if (![self fillPixelBuffer:buffer index:i]) {
            self.failure = [NSString stringWithFormat:@"could not fill synthetic buffer %lu", (unsigned long)i];
            CVPixelBufferRelease(buffer);
            break;
        }
        [buffers addObject:(__bridge id)buffer];
        CVPixelBufferRelease(buffer);
    }
    return buffers;
}

- (BOOL)run {
    NSArray *buffers = [self createSyntheticBuffers];
    if (buffers.count == 0 || self.failure) {
        [self writeReport];
        return NO;
    }
    if (![self createEncoder]) {
        self.failure = @"could not create or prepare VideoToolbox encoder";
        [self writeReport];
        return NO;
    }

    self.startNanos = nowNanos();
    uint64_t start = self.startNanos;
    uint64_t deadline = start + (uint64_t)(self.requestedDurationSeconds * 1000000000.0);
    uint64_t frameInterval = (uint64_t)(1000000000.0 / (double)MAX((NSUInteger)1, self.refresh));
    uint64_t nextSubmit = start;
    NSUInteger sequence = 0;
    while (nowNanos() < deadline) {
        sleepUntilNanos(nextSubmit);
        if (nowNanos() >= deadline) {
            break;
        }

        CVPixelBufferRef buffer = (__bridge CVPixelBufferRef)buffers[sequence % buffers.count];
        CMTime pts = CMTimeMake((int64_t)sequence, (int32_t)MAX((NSUInteger)1, self.refresh));
        CMTime duration = CMTimeMake(1, (int32_t)MAX((NSUInteger)1, self.refresh));
        VTEncodeInfoFlags flags = 0;
        OSStatus status = VTCompressionSessionEncodeFrame(_compressionSession,
                                                          buffer,
                                                          pts,
                                                          duration,
                                                          NULL,
                                                          (void *)(uintptr_t)sequence,
                                                          &flags);
        @synchronized (self) {
            self.submittedFrames += 1;
            if (status != noErr) {
                self.encodeCallErrors += 1;
            }
            if ((flags & kVTEncodeInfo_FrameDropped) != 0) {
                self.encodeCallDroppedFlags += 1;
            }
        }
        sequence += 1;
        nextSubmit += frameInterval;
    }
    self.submissionWallSeconds = nanosToSeconds(nowNanos() - start);

    uint64_t drainStart = nowNanos();
    VTCompressionSessionCompleteFrames(_compressionSession, kCMTimeInvalid);
    self.drainWallSeconds = nanosToSeconds(nowNanos() - drainStart);
    self.totalWallSeconds = nanosToSeconds(nowNanos() - start);

    VTCompressionSessionInvalidate(_compressionSession);
    CFRelease(_compressionSession);
    _compressionSession = NULL;
    if (_pixelBufferPool) {
        CVPixelBufferPoolRelease(_pixelBufferPool);
        _pixelBufferPool = NULL;
    }

    self.success = self.failure == nil && self.encodeCallErrors == 0 && self.outputErrors == 0 && self.outputCallbacks == self.submittedFrames;
    [self writeReport];
    return self.success;
}

- (void)handleCompressionOutputWithStatus:(OSStatus)status infoFlags:(VTEncodeInfoFlags)infoFlags sampleBuffer:(CMSampleBufferRef)sampleBuffer {
    uint64_t now = nowNanos();
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

    size_t payloadLength = 0;
    CMBlockBufferRef block = sampleBuffer ? CMSampleBufferGetDataBuffer(sampleBuffer) : NULL;
    if (block) {
        payloadLength = CMBlockBufferGetDataLength(block);
    }

    @synchronized (self) {
        self.outputCallbacks += 1;
        if (self.outputCallbacks == 1) {
            self.firstOutputWallSeconds = nanosToSeconds(now - self.startNanos);
        }
        self.lastOutputWallSeconds = nanosToSeconds(now - self.startNanos);
        if (status != noErr) {
            self.outputErrors += 1;
        }
        if (dropped) {
            self.outputDroppedFrames += 1;
        }
        if (keyFrame) {
            self.keyFrames += 1;
        }
        self.encodedBytes += payloadLength;
    }
}

- (void)writeReport {
    createOutputDirectory(self.outputPath);
    double submittedFPS = self.submissionWallSeconds > 0.0 ? (double)self.submittedFrames / self.submissionWallSeconds : 0.0;
    double totalOutputFPS = self.totalWallSeconds > 0.0 ? (double)self.outputCallbacks / self.totalWallSeconds : 0.0;
    double callbackFPS = (self.lastOutputWallSeconds - self.firstOutputWallSeconds) > 0.0 && self.outputCallbacks > 1
        ? (double)(self.outputCallbacks - 1) / (self.lastOutputWallSeconds - self.firstOutputWallSeconds)
        : 0.0;
    double encodedMbps = self.totalWallSeconds > 0.0 ? ((double)self.encodedBytes * 8.0 / self.totalWallSeconds / 1000000.0) : 0.0;

    NSMutableString *report = [NSMutableString string];
    [report appendFormat:@"# Experiment 014 Encode-Only Result: %@\n\n", self.caseName ?: @"Encode"];
    [report appendString:@"## Machine\n\n"];
    NSProcessInfo *processInfo = NSProcessInfo.processInfo;
    [report appendFormat:@"- Host name: %@\n", processInfo.hostName];
    [report appendFormat:@"- macOS: %@\n", processInfo.operatingSystemVersionString];
    [report appendFormat:@"- Hardware model: %@\n", sysctlString("hw.model")];
    [report appendFormat:@"- CPU brand: %@\n", sysctlString("machdep.cpu.brand_string")];

    [report appendString:@"\n## Encode Settings\n\n"];
    [report appendFormat:@"- Requested duration: %.1f seconds\n", self.requestedDurationSeconds];
    [report appendString:@"- Source: preallocated IOSurface-backed BGRA synthetic pixel buffers\n"];
    [report appendFormat:@"- Synthetic buffer ring size: %lu\n", (unsigned long)self.ringSize];
    [report appendFormat:@"- Codec FourCC: `%@`\n", fourCC(self.codec)];
    [report appendFormat:@"- Codec name: %@\n", self.codecDisplayName ?: @"unavailable"];
    [report appendFormat:@"- Encode dimensions: %lu x %lu\n", (unsigned long)self.width, (unsigned long)self.height];
    [report appendFormat:@"- FPS target: %lu\n", (unsigned long)self.refresh];
    [report appendFormat:@"- Target bitrate: %lu Mbps\n", (unsigned long)self.bitrateMbps];
    [report appendFormat:@"- Encoder setup: %@\n", self.encoderNote ?: @"unavailable"];
    [report appendString:@"- Capture/network work: none\n"];
    [report appendString:@"- Submission pacing: real-time 60 Hz sleepUntil schedule\n"];

    [report appendString:@"\n## Encode Result\n\n"];
    [report appendFormat:@"- Success: %@\n", yesNo(self.success)];
    if (self.failure) {
        [report appendFormat:@"- Failure: %@\n", self.failure];
    }
    [report appendFormat:@"- Submitted frames: %lu\n", (unsigned long)self.submittedFrames];
    [report appendFormat:@"- Encode call errors: %lu\n", (unsigned long)self.encodeCallErrors];
    [report appendFormat:@"- Encode call dropped flags: %lu\n", (unsigned long)self.encodeCallDroppedFlags];
    [report appendFormat:@"- Encoder output callbacks: %lu\n", (unsigned long)self.outputCallbacks];
    [report appendFormat:@"- Output errors: %lu\n", (unsigned long)self.outputErrors];
    [report appendFormat:@"- Output dropped frames: %lu\n", (unsigned long)self.outputDroppedFrames];
    [report appendFormat:@"- Key frames: %lu\n", (unsigned long)self.keyFrames];
    [report appendFormat:@"- Encoded bytes: %llu\n", self.encodedBytes];
    [report appendFormat:@"- Submission wall time: %.3f seconds\n", self.submissionWallSeconds];
    [report appendFormat:@"- Drain wall time: %.3f seconds\n", self.drainWallSeconds];
    [report appendFormat:@"- Total wall time: %.3f seconds\n", self.totalWallSeconds];
    [report appendFormat:@"- Submitted FPS: %.2f\n", submittedFPS];
    [report appendFormat:@"- Output FPS by total wall: %.2f\n", totalOutputFPS];
    [report appendFormat:@"- Output FPS by first/last callback: %.2f\n", callbackFPS];
    [report appendFormat:@"- Measured encoded bitrate: %.2f Mbps\n", encodedMbps];
    [report appendFormat:@"- First output callback wall time: %.3f seconds\n", self.firstOutputWallSeconds];
    [report appendFormat:@"- Last output callback wall time: %.3f seconds\n", self.lastOutputWallSeconds];

    [report appendString:@"\n## Interpretation\n\n"];
    if (self.success && totalOutputFPS >= (double)self.refresh * 0.95) {
        [report appendString:@"VideoToolbox encode-only pacing stayed inside the current 95% pass band for this synthetic stream.\n"];
    } else if (self.success) {
        [report appendString:@"Encode-only completed cleanly but did not hold the current 95% pass band for this synthetic stream.\n"];
    } else {
        [report appendString:@"Encode-only did not complete cleanly for this synthetic stream.\n"];
    }

    NSError *error = nil;
    if (![report writeToFile:self.outputPath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        fprintf(stderr, "Could not write encode report: %s\n", error.localizedDescription.UTF8String);
    } else {
        printf("Wrote encode report: %s\n", self.outputPath.UTF8String);
    }
}

@end

static void encodeOnlyOutputCallback(void *outputCallbackRefCon,
                                     void *sourceFrameRefCon,
                                     OSStatus status,
                                     VTEncodeInfoFlags infoFlags,
                                     CMSampleBufferRef sampleBuffer) {
    EncodeOnlyCase *encoder = (__bridge EncodeOnlyCase *)outputCallbackRefCon;
    [encoder handleCompressionOutputWithStatus:status infoFlags:infoFlags sampleBuffer:sampleBuffer];
}

static NSString *slug(NSString *prefix, OSType codec, NSUInteger width, NSUInteger height) {
    NSString *codecSlug = codec == 0 ? @"" : (codec == kCMVideoCodecType_H264 ? @"h264-" : (codec == kCMVideoCodecType_HEVC ? @"hevc-" : [[fourCC(codec) lowercaseString] stringByAppendingString:@"-"]));
    return [NSString stringWithFormat:@"%@%@%lux%lu-60", prefix, codecSlug, (unsigned long)width, (unsigned long)height];
}

static NSString *extractLine(NSString *contents, NSString *label) {
    NSRange range = [contents rangeOfString:[NSString stringWithFormat:@"- %@: ", label]];
    if (range.location == NSNotFound) {
        return @"unavailable";
    }
    NSUInteger start = range.location + range.length;
    NSRange rest = NSMakeRange(start, contents.length - start);
    NSRange newline = [contents rangeOfString:@"\n" options:0 range:rest];
    NSUInteger end = newline.location == NSNotFound ? contents.length : newline.location;
    return [contents substringWithRange:NSMakeRange(start, end - start)];
}

static void writeSummary(NSString *outputDir, NSString *title, NSArray<NSString *> *paths, BOOL capture) {
    NSMutableString *summary = [NSMutableString string];
    [summary appendFormat:@"# %@\n\n", title];
    if (capture) {
        [summary appendString:@"| Case | Complete frames | FPS window | FPS first/last | Avg interarrival | Result file |\n"];
        [summary appendString:@"| --- | ---: | ---: | ---: | ---: | --- |\n"];
    } else {
        [summary appendString:@"| Case | Submitted | Output callbacks | Output FPS total | Callback FPS | Drain | Result file |\n"];
        [summary appendString:@"| --- | ---: | ---: | ---: | ---: | ---: | --- |\n"];
    }
    for (NSString *path in paths) {
        NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] ?: @"";
        NSString *caseName = [[path lastPathComponent] stringByDeletingPathExtension];
        if (capture) {
            [summary appendFormat:@"| %@ | %@ | %@ | %@ | %@ | `%@` |\n",
             caseName,
             extractLine(contents, @"Complete frames"),
             extractLine(contents, @"Complete FPS by capture window"),
             extractLine(contents, @"Complete FPS by first/last frame"),
             extractLine(contents, @"Average complete-frame interarrival"),
             path.lastPathComponent];
        } else {
            [summary appendFormat:@"| %@ | %@ | %@ | %@ | %@ | %@ | `%@` |\n",
             caseName,
             extractLine(contents, @"Submitted frames"),
             extractLine(contents, @"Encoder output callbacks"),
             extractLine(contents, @"Output FPS by total wall"),
             extractLine(contents, @"Output FPS by first/last callback"),
             extractLine(contents, @"Drain wall time"),
             path.lastPathComponent];
        }
    }
    NSString *summaryPath = [outputDir stringByAppendingPathComponent:capture ? @"capture-summary.md" : @"encode-summary.md"];
    createOutputDirectory(summaryPath);
    [summary writeToFile:summaryPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    printf("Wrote summary: %s\n", summaryPath.UTF8String);
}

static int runCaptureMode(NSString *outputDir, NSTimeInterval duration) {
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    createDirectory(outputDir);

    NSArray<NSDictionary *> *cases = @[
        @{@"name": @"capture 3200x1800 at 60 fps", @"width": @3200, @"height": @1800},
        @{@"name": @"capture 3840x2160 at 60 fps", @"width": @3840, @"height": @2160},
        @{@"name": @"capture 5120x2880 at 60 fps", @"width": @5120, @"height": @2880},
    ];

    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    BOOL allOK = YES;
    for (NSDictionary *entry in cases) {
        @autoreleasepool {
            CaptureOnlyCase *capture = [[CaptureOnlyCase alloc] init];
            capture.caseName = entry[@"name"];
            capture.width = [entry[@"width"] unsignedIntegerValue];
            capture.height = [entry[@"height"] unsignedIntegerValue];
            capture.requestedDurationSeconds = duration;
            NSString *path = [outputDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.md", slug(@"capture-", 0, capture.width, capture.height)]];
            capture.outputPath = path;
            printf("Running %s for %.1fs...\n", capture.caseName.UTF8String, duration);
            BOOL ok = [capture run];
            [paths addObject:path];
            allOK = allOK && ok;
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        }
    }
    writeSummary(outputDir, @"Experiment 014 Capture-Only Summary", paths, YES);
    return allOK ? 0 : 2;
}

static int runEncodeMode(NSString *outputDir, NSTimeInterval duration) {
    createDirectory(outputDir);
    NSArray<NSDictionary *> *cases = @[
        @{@"name": @"H.264 3200x1800 at 60 fps encode-only", @"codec": @(kCMVideoCodecType_H264), @"codecName": @"H.264", @"width": @3200, @"height": @1800, @"bitrate": @24},
        @{@"name": @"H.264 3840x2160 at 60 fps encode-only", @"codec": @(kCMVideoCodecType_H264), @"codecName": @"H.264", @"width": @3840, @"height": @2160, @"bitrate": @40},
        @{@"name": @"HEVC 3200x1800 at 60 fps encode-only", @"codec": @(kCMVideoCodecType_HEVC), @"codecName": @"HEVC/H.265", @"width": @3200, @"height": @1800, @"bitrate": @24},
    ];

    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    BOOL allOK = YES;
    for (NSDictionary *entry in cases) {
        @autoreleasepool {
            EncodeOnlyCase *encoder = [[EncodeOnlyCase alloc] init];
            encoder.caseName = entry[@"name"];
            encoder.codec = [entry[@"codec"] unsignedIntValue];
            encoder.codecDisplayName = entry[@"codecName"];
            encoder.width = [entry[@"width"] unsignedIntegerValue];
            encoder.height = [entry[@"height"] unsignedIntegerValue];
            encoder.bitrateMbps = [entry[@"bitrate"] unsignedIntegerValue];
            encoder.requestedDurationSeconds = duration;
            NSString *path = [outputDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.md", slug(@"encode-", encoder.codec, encoder.width, encoder.height)]];
            encoder.outputPath = path;
            printf("Running %s for %.1fs...\n", encoder.caseName.UTF8String, duration);
            BOOL ok = [encoder run];
            [paths addObject:path];
            allOK = allOK && ok;
        }
    }
    writeSummary(outputDir, @"Experiment 014 Encode-Only Summary", paths, NO);
    return allOK ? 0 : 2;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *mode = argc > 1 ? [[NSString stringWithUTF8String:argv[1]] lowercaseString] : @"usage";
        NSString *outputDir = stringArgument(argc, argv, "output-dir", @"results");
        NSTimeInterval duration = doubleArgument(argc, argv, "duration", 10.0);

        if ([mode isEqualToString:@"capture"]) {
            return runCaptureMode(outputDir, duration);
        }
        if ([mode isEqualToString:@"encode"]) {
            return runEncodeMode(outputDir, duration);
        }
        if ([mode isEqualToString:@"all"]) {
            int captureStatus = runCaptureMode([outputDir stringByAppendingPathComponent:@"capture"], duration);
            int encodeStatus = runEncodeMode([outputDir stringByAppendingPathComponent:@"encode"], duration);
            return captureStatus == 0 && encodeStatus == 0 ? 0 : 2;
        }

        fprintf(stderr, "Usage:\n");
        fprintf(stderr, "  SenderPacingSplitProbe all --duration=10 --output-dir=results/default\n");
        fprintf(stderr, "  SenderPacingSplitProbe capture --duration=10 --output-dir=results/default/capture\n");
        fprintf(stderr, "  SenderPacingSplitProbe encode --duration=10 --output-dir=results/default/encode\n");
        return 1;
    }
}
