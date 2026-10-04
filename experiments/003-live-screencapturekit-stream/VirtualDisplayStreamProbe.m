#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>
#import <IOSurface/IOSurface.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <dispatch/dispatch.h>

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

@interface AnimatedProbeView : NSView
@property(nonatomic) NSUInteger frameIndex;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, strong) NSDate *startDate;
- (void)startAnimatingAtFPS:(NSUInteger)fps;
- (void)stopAnimating;
@end

@implementation AnimatedProbeView

- (BOOL)isFlipped {
    return YES;
}

- (void)startAnimatingAtFPS:(NSUInteger)fps {
    self.startDate = [NSDate date];
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
    [[NSColor colorWithCalibratedRed:0.05 green:0.06 blue:0.07 alpha:1.0] setFill];
    NSRectFill(bounds);

    CGFloat t = self.frameIndex;
    CGFloat stripeWidth = 96.0;
    for (NSInteger i = -1; i < 40; i++) {
        CGFloat x = fmod((CGFloat)i * stripeWidth + t * 8.0, bounds.size.width + stripeWidth) - stripeWidth;
        NSColor *color = (i % 2 == 0)
            ? [NSColor colorWithCalibratedRed:0.12 green:0.22 blue:0.72 alpha:1.0]
            : [NSColor colorWithCalibratedRed:0.05 green:0.62 blue:0.48 alpha:1.0];
        [color setFill];
        NSBezierPath *path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(x, 0)];
        [path lineToPoint:NSMakePoint(x + stripeWidth * 0.52, 0)];
        [path lineToPoint:NSMakePoint(x + stripeWidth * 1.25, bounds.size.height)];
        [path lineToPoint:NSMakePoint(x + stripeWidth * 0.73, bounds.size.height)];
        [path closePath];
        [path fill];
    }

    CGFloat boxSize = 180.0;
    CGFloat travelX = MAX(1.0, bounds.size.width - boxSize - 80.0);
    CGFloat travelY = MAX(1.0, bounds.size.height - boxSize - 140.0);
    CGFloat x = 40.0 + fmod(t * 17.0, travelX);
    CGFloat y = 90.0 + fmod(t * 9.0, travelY);
    [[NSColor colorWithCalibratedRed:1.0 green:0.84 blue:0.20 alpha:1.0] setFill];
    NSBezierPath *box = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(x, y, boxSize, boxSize) xRadius:16.0 yRadius:16.0];
    [box fill];

    NSDictionary *titleAttributes = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:38.0 weight:NSFontWeightBold],
        NSForegroundColorAttributeName: NSColor.whiteColor
    };
    NSDictionary *smallAttributes = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:22.0 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: [NSColor colorWithWhite:0.9 alpha:1.0]
    };

    NSString *title = @"MacRemoteKVM Experiment 003";
    NSString *subtitle = [NSString stringWithFormat:@"Animated virtual 5K display - view frame %lu", (unsigned long)self.frameIndex];
    [title drawAtPoint:NSMakePoint(48.0, 38.0) withAttributes:titleAttributes];
    [subtitle drawAtPoint:NSMakePoint(52.0, 88.0) withAttributes:smallAttributes];
}

@end

@interface StreamStats : NSObject <SCStreamOutput, SCStreamDelegate>
@property(nonatomic) NSUInteger targetCompleteFrames;
@property(nonatomic) NSUInteger callbackCount;
@property(nonatomic) NSUInteger completeCount;
@property(nonatomic) NSUInteger idleCount;
@property(nonatomic) NSUInteger blankCount;
@property(nonatomic) NSUInteger suspendedCount;
@property(nonatomic) NSUInteger startedCount;
@property(nonatomic) NSUInteger stoppedCount;
@property(nonatomic) NSUInteger otherCount;
@property(nonatomic) NSUInteger firstWidth;
@property(nonatomic) NSUInteger firstHeight;
@property(nonatomic) NSUInteger lastWidth;
@property(nonatomic) NSUInteger lastHeight;
@property(nonatomic) NSUInteger expectedWidth;
@property(nonatomic) NSUInteger expectedHeight;
@property(nonatomic) BOOL sawIOSurface;
@property(nonatomic) BOOL dimensionsMatched;
@property(nonatomic) NSTimeInterval firstWallTime;
@property(nonatomic) NSTimeInterval lastWallTime;
@property(nonatomic, strong) NSDate *startDate;
@property(nonatomic, strong) NSMutableString *csv;
@property(nonatomic, strong) NSError *streamError;
- (instancetype)initWithTargetCompleteFrames:(NSUInteger)targetCompleteFrames expectedWidth:(NSUInteger)expectedWidth expectedHeight:(NSUInteger)expectedHeight;
- (BOOL)reachedTarget;
- (NSString *)summaryWithExpectedWidth:(NSUInteger)expectedWidth expectedHeight:(NSUInteger)expectedHeight;
@end

@implementation StreamStats

- (instancetype)initWithTargetCompleteFrames:(NSUInteger)targetCompleteFrames expectedWidth:(NSUInteger)expectedWidth expectedHeight:(NSUInteger)expectedHeight {
    self = [super init];
    if (self) {
        _targetCompleteFrames = targetCompleteFrames;
        _expectedWidth = expectedWidth;
        _expectedHeight = expectedHeight;
        _dimensionsMatched = YES;
        _startDate = [NSDate date];
        _csv = [NSMutableString stringWithString:@"callback,status,width,height,bytes_per_row,iosurface_id,presentation_seconds,wall_seconds,dirty_rects\n"];
    }
    return self;
}

- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(SCStreamOutputType)type {
    if (type != SCStreamOutputTypeScreen || !sampleBuffer) {
        return;
    }

    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    size_t width = imageBuffer ? CVPixelBufferGetWidth(imageBuffer) : 0;
    size_t height = imageBuffer ? CVPixelBufferGetHeight(imageBuffer) : 0;
    size_t bytesPerRow = imageBuffer ? CVPixelBufferGetBytesPerRow(imageBuffer) : 0;
    IOSurfaceRef surface = imageBuffer ? CVPixelBufferGetIOSurface(imageBuffer) : NULL;
    uint32_t surfaceID = surface ? IOSurfaceGetID(surface) : 0;

    NSInteger status = -1;
    NSUInteger dirtyCount = 0;
    CFArrayRef attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
    if (attachmentsArray && CFArrayGetCount(attachmentsArray) > 0) {
        NSDictionary *attachments = (__bridge NSDictionary *)CFArrayGetValueAtIndex(attachmentsArray, 0);
        NSNumber *statusNumber = attachments[SCStreamFrameInfoStatus];
        if (statusNumber) {
            status = statusNumber.integerValue;
        }
        NSArray *dirtyRects = attachments[SCStreamFrameInfoDirtyRects];
        dirtyCount = dirtyRects.count;
    }

    CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    Float64 presentationSeconds = CMTIME_IS_NUMERIC(presentationTime) ? CMTimeGetSeconds(presentationTime) : -1.0;
    NSTimeInterval wallSeconds = -[self.startDate timeIntervalSinceNow];

    @synchronized (self) {
        self.callbackCount += 1;
        switch (status) {
            case SCFrameStatusComplete: self.completeCount += 1; break;
            case SCFrameStatusIdle: self.idleCount += 1; break;
            case SCFrameStatusBlank: self.blankCount += 1; break;
            case SCFrameStatusSuspended: self.suspendedCount += 1; break;
            case SCFrameStatusStarted: self.startedCount += 1; break;
            case SCFrameStatusStopped: self.stoppedCount += 1; break;
            default: self.otherCount += 1; break;
        }

        if (self.callbackCount == 1) {
            self.firstWallTime = wallSeconds;
        }

        if (imageBuffer && self.firstWidth == 0 && self.firstHeight == 0) {
            self.firstWidth = width;
            self.firstHeight = height;
        }
        if (imageBuffer) {
            self.lastWidth = width;
            self.lastHeight = height;
            self.sawIOSurface = self.sawIOSurface || surface != NULL;
            self.dimensionsMatched = self.dimensionsMatched && (width == self.expectedWidth && height == self.expectedHeight);
        }
        self.lastWallTime = wallSeconds;

        [self.csv appendFormat:@"%lu,%@,%zu,%zu,%zu,%u,%.6f,%.6f,%lu\n",
         (unsigned long)self.callbackCount,
         statusName(status),
         width,
         height,
         bytesPerRow,
         surfaceID,
         presentationSeconds,
         wallSeconds,
         (unsigned long)dirtyCount];
    }
}

- (void)stream:(SCStream *)stream didStopWithError:(NSError *)error {
    @synchronized (self) {
        self.streamError = error;
    }
}

- (BOOL)reachedTarget {
    @synchronized (self) {
        return self.targetCompleteFrames > 0 && self.completeCount >= self.targetCompleteFrames;
    }
}

- (NSString *)summaryWithExpectedWidth:(NSUInteger)expectedWidth expectedHeight:(NSUInteger)expectedHeight {
    @synchronized (self) {
        NSTimeInterval span = MAX(0.001, self.lastWallTime - self.firstWallTime);
        double callbackFPS = self.callbackCount > 1 ? (double)(self.callbackCount - 1) / span : 0.0;
        double completeFPS = self.completeCount > 1 ? (double)(self.completeCount - 1) / span : 0.0;
        BOOL finalDimensionsMatched = self.dimensionsMatched && self.lastWidth == expectedWidth && self.lastHeight == expectedHeight;

        NSMutableString *summary = [NSMutableString string];
        [summary appendString:@"# Experiment 003 Result: Live ScreenCaptureKit Stream\n\n"];
        [summary appendFormat:@"Expected frame size: %lux%lu\n", (unsigned long)expectedWidth, (unsigned long)expectedHeight];
        [summary appendFormat:@"First frame size: %lux%lu\n", (unsigned long)self.firstWidth, (unsigned long)self.firstHeight];
        [summary appendFormat:@"Last frame size: %lux%lu\n", (unsigned long)self.lastWidth, (unsigned long)self.lastHeight];
        [summary appendFormat:@"Callbacks: %lu\n", (unsigned long)self.callbackCount];
        [summary appendFormat:@"Complete frames: %lu\n", (unsigned long)self.completeCount];
        [summary appendFormat:@"Idle frames: %lu\n", (unsigned long)self.idleCount];
        [summary appendFormat:@"Blank frames: %lu\n", (unsigned long)self.blankCount];
        [summary appendFormat:@"Suspended frames: %lu\n", (unsigned long)self.suspendedCount];
        [summary appendFormat:@"Started frames: %lu\n", (unsigned long)self.startedCount];
        [summary appendFormat:@"Stopped frames: %lu\n", (unsigned long)self.stoppedCount];
        [summary appendFormat:@"Other frames: %lu\n", (unsigned long)self.otherCount];
        [summary appendFormat:@"Observed callback FPS: %.2f\n", callbackFPS];
        [summary appendFormat:@"Observed complete-frame FPS: %.2f\n", completeFPS];
        [summary appendFormat:@"Saw IOSurface-backed buffers: %@\n", self.sawIOSurface ? @"yes" : @"no"];
        [summary appendFormat:@"All image-buffer dimensions matched expected: %@\n", finalDimensionsMatched ? @"yes" : @"no"];
        if (self.streamError) {
            [summary appendFormat:@"Stream error: %@\n", self.streamError.localizedDescription];
        } else {
            [summary appendString:@"Stream error: none\n"];
        }
        [summary appendString:@"\n## CSV\n\n"];
        [summary appendString:@"```csv\n"];
        [summary appendString:self.csv];
        [summary appendString:@"```\n"];
        return summary;
    }
}

@end

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
        NSUInteger seconds = integerArgument(argc, argv, "seconds", 5);
        NSUInteger targetFrames = integerArgument(argc, argv, "frames", 180);
        BOOL hiDPI = integerArgument(argc, argv, "hidpi", 1) != 0;
        NSUInteger modeWidth = integerArgument(argc, argv, "mode-width", hiDPI ? backingWidth / 2 : backingWidth);
        NSUInteger modeHeight = integerArgument(argc, argv, "mode-height", hiDPI ? backingHeight / 2 : backingHeight);

        NSString *defaultOutput = @"/Users/peterrichards/dev/MacRemoteKVM/results/003-live-screencapturekit-stream/stream-probe-result.md";
        NSString *outputPath = stringArgument(argc, argv, "output", defaultOutput);

        CGVirtualDisplayDescriptor *descriptor = [[descriptorClass alloc] init];
        descriptor.name = @"MacRemoteKVM Virtual 5K Stream Probe";
        descriptor.maxPixelsWide = (unsigned int)backingWidth;
        descriptor.maxPixelsHigh = (unsigned int)backingHeight;
        descriptor.sizeInMillimeters = CGSizeMake(597, 336);
        descriptor.vendorID = 0x4D52;
        descriptor.productID = 0x5C5C;
        descriptor.serialNum = 0x0003;
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

        if (!waitForSemaphore(contentSemaphore, 10.0)) {
            fprintf(stderr, "Timed out waiting for ScreenCaptureKit shareable content.\n");
            return 4;
        }
        if (shareableError) {
            fprintf(stderr, "ScreenCaptureKit shareable content error: %s\n", shareableError.localizedDescription.UTF8String);
            return 5;
        }

        SCDisplay *targetDisplay = nil;
        printf("ScreenCaptureKit displays:\n");
        for (SCDisplay *display in shareableContent.displays) {
            printf("  displayID=%u width=%ld height=%ld frame=%.0fx%.0f+%.0f+%.0f%s\n",
                   display.displayID,
                   (long)display.width,
                   (long)display.height,
                   display.frame.size.width,
                   display.frame.size.height,
                   display.frame.origin.x,
                   display.frame.origin.y,
                   display.displayID == virtualDisplay.displayID ? "  <-- target" : "");
            if (display.displayID == virtualDisplay.displayID) {
                targetDisplay = display;
            }
        }
        fflush(stdout);

        if (!targetDisplay) {
            fprintf(stderr, "ScreenCaptureKit did not enumerate the virtual display id=%u.\n", virtualDisplay.displayID);
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

        StreamStats *stats = [[StreamStats alloc] initWithTargetCompleteFrames:targetFrames expectedWidth:backingWidth expectedHeight:backingHeight];
        SCStream *stream = [[SCStream alloc] initWithFilter:filter configuration:config delegate:stats];
        dispatch_queue_t sampleQueue = dispatch_queue_create("dev.macremotekvm.stream-probe.samples", DISPATCH_QUEUE_SERIAL);
        NSError *outputError = nil;
        if (![stream addStreamOutput:stats type:SCStreamOutputTypeScreen sampleHandlerQueue:sampleQueue error:&outputError]) {
            fprintf(stderr, "addStreamOutput failed: %s\n", outputError.localizedDescription.UTF8String);
            return 7;
        }

        dispatch_semaphore_t startSemaphore = dispatch_semaphore_create(0);
        __block NSError *startError = nil;
        [stream startCaptureWithCompletionHandler:^(NSError *_Nullable error) {
            startError = error;
            dispatch_semaphore_signal(startSemaphore);
        }];
        if (!waitForSemaphore(startSemaphore, 10.0)) {
            fprintf(stderr, "Timed out waiting for SCStream startCapture.\n");
            return 8;
        }
        if (startError) {
            fprintf(stderr, "SCStream startCapture error: %s\n", startError.localizedDescription.UTF8String);
            return 9;
        }

        printf("Started SCStream for up to %zu seconds or %zu complete frames.\n", seconds, targetFrames);
        fflush(stdout);

        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval)seconds];
        while ([deadline timeIntervalSinceNow] > 0 && ![stats reachedTarget]) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        }

        dispatch_semaphore_t stopSemaphore = dispatch_semaphore_create(0);
        __block NSError *stopError = nil;
        [stream stopCaptureWithCompletionHandler:^(NSError *_Nullable error) {
            stopError = error;
            dispatch_semaphore_signal(stopSemaphore);
        }];
        waitForSemaphore(stopSemaphore, 5.0);
        if (stopError) {
            fprintf(stderr, "SCStream stopCapture error: %s\n", stopError.localizedDescription.UTF8String);
        }

        [probeView stopAnimating];
        [window close];

        NSString *summary = [stats summaryWithExpectedWidth:backingWidth expectedHeight:backingHeight];
        NSError *writeError = nil;
        BOOL wrote = [summary writeToFile:outputPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
        if (!wrote) {
            fprintf(stderr, "Could not write result file: %s\n", writeError.localizedDescription.UTF8String);
            return 10;
        }

        printf("%s\n", summary.UTF8String);
        printf("Wrote result: %s\n", outputPath.UTF8String);
        fflush(stdout);

        // Keep local objects strongly referenced through teardown.
        NSLog(@"Releasing virtual display id=%u and exiting.", virtualDisplay.displayID);
    }
    return 0;
}
