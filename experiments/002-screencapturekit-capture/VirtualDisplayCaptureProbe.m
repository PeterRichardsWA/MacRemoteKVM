#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
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

static BOOL writePNG(CGImageRef image, NSURL *url, NSError **error) {
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)url,
                                                                       (__bridge CFStringRef)UTTypePNG.identifier,
                                                                       1,
                                                                       NULL);
    if (!destination) {
        if (error) {
            *error = [NSError errorWithDomain:@"VirtualDisplayCaptureProbe"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Could not create PNG destination."}];
        }
        return NO;
    }

    CGImageDestinationAddImage(destination, image, NULL);
    BOOL ok = CGImageDestinationFinalize(destination);
    CFRelease(destination);

    if (!ok && error) {
        *error = [NSError errorWithDomain:@"VirtualDisplayCaptureProbe"
                                     code:2
                                 userInfo:@{NSLocalizedDescriptionKey: @"Could not finalize PNG file."}];
    }

    return ok;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
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
        BOOL hiDPI = integerArgument(argc, argv, "hidpi", 1) != 0;
        NSUInteger modeWidth = integerArgument(argc, argv, "mode-width", hiDPI ? backingWidth / 2 : backingWidth);
        NSUInteger modeHeight = integerArgument(argc, argv, "mode-height", hiDPI ? backingHeight / 2 : backingHeight);

        NSString *defaultOutput = @"/Users/peterrichards/dev/MacRemoteKVM/results/002-screencapturekit-capture/virtual-display-capture-probe.png";
        NSString *outputPath = stringArgument(argc, argv, "output", defaultOutput);
        NSURL *outputURL = [NSURL fileURLWithPath:outputPath];

        CGVirtualDisplayDescriptor *descriptor = [[descriptorClass alloc] init];
        descriptor.name = @"Codex Virtual 5K Capture Probe";
        descriptor.maxPixelsWide = (unsigned int)backingWidth;
        descriptor.maxPixelsHigh = (unsigned int)backingHeight;
        descriptor.sizeInMillimeters = CGSizeMake(597, 336);
        descriptor.vendorID = 0x4344;
        descriptor.productID = 0x5B5B;
        descriptor.serialNum = 0x0002;
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

        // Give WindowServer a moment to publish the new display to ScreenCaptureKit.
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

        while (dispatch_semaphore_wait(contentSemaphore, dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC)) != 0) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        }

        if (shareableError) {
            fprintf(stderr, "ScreenCaptureKit shareable content error: %s\n", shareableError.localizedDescription.UTF8String);
            fprintf(stderr, "If this is a Screen Recording permission failure, grant permission to the launching app and rerun.\n");
            return 4;
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
            return 5;
        }

        SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:targetDisplay excludingWindows:@[]];
        SCStreamConfiguration *config = [[SCStreamConfiguration alloc] init];
        config.width = backingWidth;
        config.height = backingHeight;
        config.pixelFormat = kCVPixelFormatType_32BGRA;
        config.showsCursor = NO;
        config.capturesAudio = NO;
        config.captureResolution = SCCaptureResolutionBest;
        config.queueDepth = 1;

        dispatch_semaphore_t captureSemaphore = dispatch_semaphore_create(0);
        __block CGImageRef capturedImage = NULL;
        __block NSError *captureError = nil;

        [SCScreenshotManager captureImageWithFilter:filter
                                      configuration:config
                                  completionHandler:^(CGImageRef _Nullable image, NSError *_Nullable error) {
            if (image) {
                capturedImage = CGImageRetain(image);
            }
            captureError = error;
            dispatch_semaphore_signal(captureSemaphore);
        }];

        while (dispatch_semaphore_wait(captureSemaphore, dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC)) != 0) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        }

        if (captureError) {
            fprintf(stderr, "ScreenCaptureKit capture error: %s\n", captureError.localizedDescription.UTF8String);
            return 6;
        }

        if (!capturedImage) {
            fprintf(stderr, "ScreenCaptureKit returned no image and no error.\n");
            return 7;
        }

        size_t imageWidth = CGImageGetWidth(capturedImage);
        size_t imageHeight = CGImageGetHeight(capturedImage);
        size_t bitsPerPixel = CGImageGetBitsPerPixel(capturedImage);
        size_t bytesPerRow = CGImageGetBytesPerRow(capturedImage);

        NSError *writeError = nil;
        BOOL wrote = writePNG(capturedImage, outputURL, &writeError);
        CGImageRelease(capturedImage);

        if (!wrote) {
            fprintf(stderr, "PNG write error: %s\n", writeError.localizedDescription.UTF8String);
            return 8;
        }

        printf("Captured image: %zux%zu bitsPerPixel=%zu bytesPerRow=%zu\n",
               imageWidth,
               imageHeight,
               bitsPerPixel,
               bytesPerRow);
        printf("Wrote PNG: %s\n", outputPath.UTF8String);
        fflush(stdout);

        // Keep the private display object alive until all capture work is complete.
        NSLog(@"Releasing virtual display id=%u and exiting.", virtualDisplay.displayID);
    }

    return 0;
}
