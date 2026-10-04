#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
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

static void printOnlineDisplays(NSString *label) {
    uint32_t count = 0;
    CGError countError = CGGetOnlineDisplayList(0, NULL, &count);
    if (countError != kCGErrorSuccess) {
        fprintf(stderr, "CGGetOnlineDisplayList count failed: %d\n", countError);
        return;
    }

    CGDirectDisplayID *displays = calloc(count, sizeof(CGDirectDisplayID));
    if (displays == NULL) {
        fprintf(stderr, "Could not allocate display list.\n");
        return;
    }

    CGError listError = CGGetOnlineDisplayList(count, displays, &count);
    if (listError != kCGErrorSuccess) {
        fprintf(stderr, "CGGetOnlineDisplayList failed: %d\n", listError);
        free(displays);
        return;
    }

    printf("\n%s (%u online display%s)\n", label.UTF8String, count, count == 1 ? "" : "s");
    for (uint32_t i = 0; i < count; i++) {
        CGDirectDisplayID displayID = displays[i];
        CGRect bounds = CGDisplayBounds(displayID);
        CGDisplayModeRef activeMode = CGDisplayCopyDisplayMode(displayID);
        size_t modeWidth = activeMode ? CGDisplayModeGetWidth(activeMode) : 0;
        size_t modeHeight = activeMode ? CGDisplayModeGetHeight(activeMode) : 0;
        size_t pixelWidth = activeMode ? CGDisplayModeGetPixelWidth(activeMode) : 0;
        size_t pixelHeight = activeMode ? CGDisplayModeGetPixelHeight(activeMode) : 0;
        CFStringRef encoding = activeMode ? CGDisplayModeCopyPixelEncoding(activeMode) : NULL;

        printf("  id=%u cgPixels=%zux%zu bounds=%.0fx%.0f+%.0f+%.0f mode=%zux%zu pixelMode=%zux%zu vendor=0x%x product=0x%x serial=0x%x %s%s",
               displayID,
               CGDisplayPixelsWide(displayID),
               CGDisplayPixelsHigh(displayID),
               bounds.size.width,
               bounds.size.height,
               bounds.origin.x,
               bounds.origin.y,
               modeWidth,
               modeHeight,
               pixelWidth,
               pixelHeight,
               CGDisplayVendorNumber(displayID),
               CGDisplayModelNumber(displayID),
               CGDisplaySerialNumber(displayID),
               CGDisplayIsMain(displayID) ? "main " : "",
               CGDisplayIsBuiltin(displayID) ? "builtin" : "");
        if (encoding) {
            char encodingBuffer[128] = {0};
            if (CFStringGetCString(encoding, encodingBuffer, sizeof(encodingBuffer), kCFStringEncodingUTF8)) {
                printf(" encoding=%s", encodingBuffer);
            }
            CFRelease(encoding);
        }
        printf("\n");

        if (activeMode) {
            CFRelease(activeMode);
        }
    }

    free(displays);
}

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

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        Class descriptorClass = NSClassFromString(@"CGVirtualDisplayDescriptor");
        Class displayClass = NSClassFromString(@"CGVirtualDisplay");
        Class settingsClass = NSClassFromString(@"CGVirtualDisplaySettings");
        Class modeClass = NSClassFromString(@"CGVirtualDisplayMode");

        if (!descriptorClass || !displayClass || !settingsClass || !modeClass) {
            fprintf(stderr, "Missing private CoreGraphics virtual-display classes:\n");
            fprintf(stderr, "  CGVirtualDisplayDescriptor: %s\n", descriptorClass ? "present" : "missing");
            fprintf(stderr, "  CGVirtualDisplay:           %s\n", displayClass ? "present" : "missing");
            fprintf(stderr, "  CGVirtualDisplaySettings:   %s\n", settingsClass ? "present" : "missing");
            fprintf(stderr, "  CGVirtualDisplayMode:       %s\n", modeClass ? "present" : "missing");
            return 2;
        }

        NSUInteger backingWidth = integerArgument(argc, argv, "width", 5120);
        NSUInteger backingHeight = integerArgument(argc, argv, "height", 2880);
        NSUInteger seconds = integerArgument(argc, argv, "seconds", 120);
        NSUInteger refresh = integerArgument(argc, argv, "refresh", 60);
        BOOL hiDPI = integerArgument(argc, argv, "hidpi", 1) != 0;
        NSUInteger modeWidth = integerArgument(argc, argv, "mode-width", hiDPI ? backingWidth / 2 : backingWidth);
        NSUInteger modeHeight = integerArgument(argc, argv, "mode-height", hiDPI ? backingHeight / 2 : backingHeight);

        printOnlineDisplays(@"Before");

        CGVirtualDisplayDescriptor *descriptor = [[descriptorClass alloc] init];
        descriptor.name = @"Codex Virtual 5K Probe";
        descriptor.maxPixelsWide = (unsigned int)backingWidth;
        descriptor.maxPixelsHigh = (unsigned int)backingHeight;
        descriptor.sizeInMillimeters = CGSizeMake(597, 336);
        descriptor.vendorID = 0x4344;  // "CD"
        descriptor.productID = 0x5A5A;
        descriptor.serialNum = 0x0001;
        descriptor.queue = dispatch_get_main_queue();

        CGVirtualDisplay *display = [[displayClass alloc] initWithDescriptor:descriptor];
        if (!display) {
            fprintf(stderr, "CGVirtualDisplay initWithDescriptor returned nil.\n");
            fprintf(stderr, "If an earlier probe process is still alive, quit it and try again.\n");
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

        BOOL applied = [display applySettings:settings];
        printf("\nCreated virtual display id=%u backingLimit=%zux%zu mode=%zux%zu@%zu hiDPI=%s applySettings=%s\n",
               display.displayID,
               backingWidth,
               backingHeight,
               modeWidth,
               modeHeight,
               refresh,
               hiDPI ? "yes" : "no",
               applied ? "true" : "false");

        printOnlineDisplays(@"After");

        printf("\nHolding the display for %zu seconds. Open System Settings > Displays now.\n", seconds);
        printf("The virtual display should disappear when this process exits.\n");
        fflush(stdout);

        NSDate *until = [NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval)seconds];
        while ([until timeIntervalSinceNow] > 0) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
        }

        // Keep a strong reference live until after the hold period.
        NSLog(@"Releasing virtual display id=%u and exiting.", display.displayID);
    }

    return 0;
}
