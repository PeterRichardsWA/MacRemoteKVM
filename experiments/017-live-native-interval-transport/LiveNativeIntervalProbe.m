// Experiment 017 reuses our Experiment 013 live transport and Experiment 006 renderer.
// All runtime support is kept here so this directory can run independently.

#import <AppKit/AppKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <VideoToolbox/VideoToolbox.h>
#import <sys/sysctl.h>


#import <mach/mach_time.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <netinet/in.h>
#import <netinet/tcp.h>
#import <sys/socket.h>
#import <unistd.h>
#import <IOSurface/IOSurface.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>


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
    NSString *needle = [NSString stringWithFormat:@"--%s=", name];
    for (int i = 1; i < argc; i++) {
        NSString *argument = [NSString stringWithUTF8String:argv[i]];
        if ([argument hasPrefix:needle]) {
            return (NSUInteger)MAX(0, [[argument substringFromIndex:needle.length] integerValue]);
        }
    }
    return defaultValue;
}

static BOOL boolArgument(int argc, const char *argv[], const char *name, BOOL defaultValue) {
    NSString *needle = [NSString stringWithFormat:@"--%s=", name];
    for (int i = 1; i < argc; i++) {
        NSString *argument = [NSString stringWithUTF8String:argv[i]];
        if ([argument hasPrefix:needle]) {
            NSString *value = [[argument substringFromIndex:needle.length] lowercaseString];
            return [@[@"1", @"true", @"yes", @"on"] containsObject:value];
        }
    }
    return defaultValue;
}

static NSString *sysctlString(const char *name) {
    size_t size = 0;
    if (sysctlbyname(name, NULL, &size, NULL, 0) != 0 || size == 0) {
        return @"unavailable";
    }
    char *buffer = calloc(size, 1);
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

static NSString *fourCC(OSType value) {
    char chars[5] = {
        (char)((value >> 24) & 0xff),
        (char)((value >> 16) & 0xff),
        (char)((value >> 8) & 0xff),
        (char)(value & 0xff),
        0
    };
    for (NSUInteger i = 0; i < 4; i++) {
        if (chars[i] < 32 || chars[i] > 126) {
            return [NSString stringWithFormat:@"0x%08x", value];
        }
    }
    return [NSString stringWithUTF8String:chars] ?: @"????";
}

static NSString *yesNo(BOOL value) {
    return value ? @"yes" : @"no";
}

static NSString *cmTimeString(CMTime time) {
    if (!CMTIME_IS_NUMERIC(time)) {
        return @"unavailable";
    }
    return [NSString stringWithFormat:@"%.3f", CMTimeGetSeconds(time)];
}

static NSString *vtStatusName(OSStatus status) {
    switch (status) {
        case noErr: return @"noErr";
        case kVTCouldNotFindVideoDecoderErr: return @"kVTCouldNotFindVideoDecoderErr";
        case kVTCouldNotCreateInstanceErr: return @"kVTCouldNotCreateInstanceErr";
        case kVTCouldNotFindVideoEncoderErr: return @"kVTCouldNotFindVideoEncoderErr";
        case kVTVideoDecoderBadDataErr: return @"kVTVideoDecoderBadDataErr";
        case kVTVideoDecoderUnsupportedDataFormatErr: return @"kVTVideoDecoderUnsupportedDataFormatErr";
        case kVTVideoDecoderMalfunctionErr: return @"kVTVideoDecoderMalfunctionErr";
        case kVTVideoDecoderNotAvailableNowErr: return @"kVTVideoDecoderNotAvailableNowErr";
        case kVTVideoDecoderAuthorizationErr: return @"kVTVideoDecoderAuthorizationErr";
        case kVTVideoDecoderRemovedErr: return @"kVTVideoDecoderRemovedErr";
        case kVTVideoDecoderNeedsRosettaErr: return @"kVTVideoDecoderNeedsRosettaErr";
        case kVTVideoDecoderReferenceMissingErr: return @"kVTVideoDecoderReferenceMissingErr";
        case kVTVideoDecoderCallbackMessagingErr: return @"kVTVideoDecoderCallbackMessagingErr";
        case kVTVideoDecoderUnknownErr: return @"kVTVideoDecoderUnknownErr";
        default: return @"unknown";
    }
}

static void createOutputDirectory(NSString *outputPath) {
    NSString *directory = outputPath.stringByDeletingLastPathComponent;
    if (directory.length > 0) {
        [NSFileManager.defaultManager createDirectoryAtPath:directory
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:nil];
    }
}

@interface MetalPresenter : NSObject
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) NSView *view;
@property(nonatomic, strong) CAMetalLayer *metalLayer;
@property(nonatomic, strong) id<MTLDevice> device;
@property(nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property(nonatomic, strong) CIContext *ciContext;
@property(nonatomic) NSUInteger renderedFrames;
@property(nonatomic) NSUInteger renderFailures;
@property(nonatomic) NSTimeInterval totalRenderSeconds;
@property(nonatomic) CGSize drawableSize;
@property(nonatomic) CGFloat backingScaleFactor;
- (instancetype)initFullscreen:(BOOL)fullscreen title:(NSString *)title expectedWidth:(NSUInteger)expectedWidth expectedHeight:(NSUInteger)expectedHeight;
- (BOOL)renderPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)close;
@end

@implementation MetalPresenter

- (instancetype)initFullscreen:(BOOL)fullscreen title:(NSString *)title expectedWidth:(NSUInteger)expectedWidth expectedHeight:(NSUInteger)expectedHeight {
    self = [super init];
    if (!self) {
        return nil;
    }

    _device = MTLCreateSystemDefaultDevice();
    if (!_device) {
        return nil;
    }
    _commandQueue = [_device newCommandQueue];
    if (!_commandQueue) {
        return nil;
    }
    _ciContext = [CIContext contextWithMTLDevice:_device options:@{
        kCIContextWorkingColorSpace: [NSNull null],
        kCIContextOutputColorSpace: [NSNull null]
    }];

    NSScreen *screen = NSScreen.mainScreen;
    NSRect frame = fullscreen ? screen.frame : NSMakeRect(80.0, 80.0, 1280.0, 720.0);
    NSWindowStyleMask style = fullscreen ? NSWindowStyleMaskBorderless : (NSWindowStyleMaskTitled | NSWindowStyleMaskClosable);
    _window = [[NSWindow alloc] initWithContentRect:frame
                                         styleMask:style
                                           backing:NSBackingStoreBuffered
                                             defer:NO
                                            screen:screen];
    _window.title = title;
    _window.opaque = YES;
    _window.backgroundColor = NSColor.blackColor;
    _window.releasedWhenClosed = NO;
    if (fullscreen) {
        _window.level = NSStatusWindowLevel;
        _window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
    }

    _view = [[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, frame.size.width, frame.size.height)];
    _view.wantsLayer = YES;
    _view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    _metalLayer = [CAMetalLayer layer];
    _metalLayer.device = _device;
    _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    _metalLayer.framebufferOnly = NO;
    _metalLayer.opaque = YES;
    _metalLayer.frame = _view.bounds;
    _metalLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
    _view.layer = _metalLayer;

    _window.contentView = _view;
    [_window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [_window displayIfNeeded];

    _backingScaleFactor = _window.backingScaleFactor;
    NSRect backingRect = [_view convertRectToBacking:_view.bounds];
    if (backingRect.size.width <= 0.0 || backingRect.size.height <= 0.0) {
        backingRect.size = CGSizeMake(expectedWidth, expectedHeight);
    }
    _drawableSize = backingRect.size;
    _metalLayer.contentsScale = _backingScaleFactor;
    _metalLayer.drawableSize = _drawableSize;

    return self;
}

- (BOOL)renderPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (!pixelBuffer) {
        self.renderFailures += 1;
        return NO;
    }

    NSDate *start = [NSDate date];
    @autoreleasepool {
        id<CAMetalDrawable> drawable = [self.metalLayer nextDrawable];
        if (!drawable) {
            self.renderFailures += 1;
            return NO;
        }

        CGSize targetSize = self.metalLayer.drawableSize;
        CIImage *image = [CIImage imageWithCVPixelBuffer:pixelBuffer];
        CGRect sourceExtent = image.extent;
        CGFloat sx = targetSize.width / MAX(1.0, sourceExtent.size.width);
        CGFloat sy = targetSize.height / MAX(1.0, sourceExtent.size.height);
        CIImage *scaledImage = [image imageByApplyingTransform:CGAffineTransformMakeScale(sx, sy)];

        id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
        if (!commandBuffer) {
            self.renderFailures += 1;
            return NO;
        }

        CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        [self.ciContext render:scaledImage
                  toMTLTexture:drawable.texture
                 commandBuffer:commandBuffer
                        bounds:CGRectMake(0.0, 0.0, targetSize.width, targetSize.height)
                    colorSpace:colorSpace];
        if (colorSpace) {
            CGColorSpaceRelease(colorSpace);
        }

        [commandBuffer presentDrawable:drawable];
        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];

        if (commandBuffer.status == MTLCommandBufferStatusCompleted) {
            self.renderedFrames += 1;
            self.totalRenderSeconds += -[start timeIntervalSinceNow];
            return YES;
        }

        self.renderFailures += 1;
        return NO;
    }
}

- (void)close {
    [self.window close];
}

@end


static NSTimeInterval doubleArgumentLocal(int argc, const char *argv[], const char *name, NSTimeInterval defaultValue) {
    NSString *needle = [NSString stringWithFormat:@"--%s=", name];
    for (int i = 1; i < argc; i++) {
        NSString *argument = [NSString stringWithUTF8String:argv[i]];
        if ([argument hasPrefix:needle]) {
            return MAX(0.0, [[argument substringFromIndex:needle.length] doubleValue]);
        }
    }
    return defaultValue;
}

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

static double nanosToMS(uint64_t nanos) {
    return (double)nanos / 1000000.0;
}

static BOOL writeFull(int fd, const void *bytes, size_t length) {
    const uint8_t *cursor = bytes;
    size_t remaining = length;
    while (remaining > 0) {
        ssize_t wrote = write(fd, cursor, remaining);
        if (wrote < 0) {
            if (errno == EINTR) {
                continue;
            }
            return NO;
        }
        if (wrote == 0) {
            return NO;
        }
        cursor += (size_t)wrote;
        remaining -= (size_t)wrote;
    }
    return YES;
}

static BOOL readFull(int fd, void *bytes, size_t length) {
    uint8_t *cursor = bytes;
    size_t remaining = length;
    while (remaining > 0) {
        ssize_t got = read(fd, cursor, remaining);
        if (got < 0) {
            if (errno == EINTR) {
                continue;
            }
            return NO;
        }
        if (got == 0) {
            return NO;
        }
        cursor += (size_t)got;
        remaining -= (size_t)got;
    }
    return YES;
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


enum {
    MRKV011StreamMagic = 0x4d4b5331,
    MRKV011FrameMagic = 0x4d4b4631,
    MRKV011PreflightMagic = 0x4d4b5031,
    MRKV011PreflightAckMagic = 0x4d4b4131,
    MRKV011Version = 1
};

typedef struct __attribute__((packed)) {
    uint32_t magic;
    uint16_t version;
    uint16_t headerBytes;
    uint32_t flags;
    uint32_t reserved;
} MRKV011PreflightHeader;

typedef struct __attribute__((packed)) {
    uint32_t magic;
    uint16_t version;
    uint16_t headerBytes;
    uint32_t codecFourCC;
    uint32_t width;
    uint32_t height;
    uint32_t nalUnitHeaderLength;
    uint32_t parameterSetCount;
    uint64_t parameterSetBytes;
    uint32_t nominalFPS1000;
    uint32_t reserved;
} MRKV011StreamHeader;

typedef struct __attribute__((packed)) {
    uint32_t magic;
    uint16_t version;
    uint16_t headerBytes;
    uint64_t sequence;
    uint64_t payloadBytes;
    int64_t ptsValue;
    int32_t ptsTimescale;
    uint32_t ptsFlags;
    int64_t durationValue;
    int32_t durationTimescale;
    uint32_t durationFlags;
    uint64_t senderNanos;
} MRKV011FrameHeader;

typedef struct {
    uint64_t sequence;
    uint64_t receiveCompleteNanos;
} NetworkFrameTimingRefCon;

static uint64_t hostToBig64(uint64_t value) {
    return CFSwapInt64HostToBig(value);
}

static uint64_t bigToHost64(uint64_t value) {
    return CFSwapInt64BigToHost(value);
}

static int64_t hostToBigS64(int64_t value) {
    return (int64_t)hostToBig64((uint64_t)value);
}

static int64_t bigToHostS64(int64_t value) {
    return (int64_t)bigToHost64((uint64_t)value);
}

static int32_t hostToBigS32(int32_t value) {
    return (int32_t)CFSwapInt32HostToBig((uint32_t)value);
}

static int32_t bigToHostS32(int32_t value) {
    return (int32_t)CFSwapInt32BigToHost((uint32_t)value);
}

static MRKV011PreflightHeader preflightHeaderToWire(MRKV011PreflightHeader header) {
    header.magic = CFSwapInt32HostToBig(header.magic);
    header.version = CFSwapInt16HostToBig(header.version);
    header.headerBytes = CFSwapInt16HostToBig(header.headerBytes);
    header.flags = CFSwapInt32HostToBig(header.flags);
    header.reserved = CFSwapInt32HostToBig(header.reserved);
    return header;
}

static MRKV011PreflightHeader preflightHeaderFromWire(MRKV011PreflightHeader header) {
    header.magic = CFSwapInt32BigToHost(header.magic);
    header.version = CFSwapInt16BigToHost(header.version);
    header.headerBytes = CFSwapInt16BigToHost(header.headerBytes);
    header.flags = CFSwapInt32BigToHost(header.flags);
    header.reserved = CFSwapInt32BigToHost(header.reserved);
    return header;
}

static MRKV011StreamHeader streamHeaderToWire(MRKV011StreamHeader header) {
    header.magic = CFSwapInt32HostToBig(header.magic);
    header.version = CFSwapInt16HostToBig(header.version);
    header.headerBytes = CFSwapInt16HostToBig(header.headerBytes);
    header.codecFourCC = CFSwapInt32HostToBig(header.codecFourCC);
    header.width = CFSwapInt32HostToBig(header.width);
    header.height = CFSwapInt32HostToBig(header.height);
    header.nalUnitHeaderLength = CFSwapInt32HostToBig(header.nalUnitHeaderLength);
    header.parameterSetCount = CFSwapInt32HostToBig(header.parameterSetCount);
    header.parameterSetBytes = hostToBig64(header.parameterSetBytes);
    header.nominalFPS1000 = CFSwapInt32HostToBig(header.nominalFPS1000);
    header.reserved = CFSwapInt32HostToBig(header.reserved);
    return header;
}

static MRKV011StreamHeader streamHeaderFromWire(MRKV011StreamHeader header) {
    header.magic = CFSwapInt32BigToHost(header.magic);
    header.version = CFSwapInt16BigToHost(header.version);
    header.headerBytes = CFSwapInt16BigToHost(header.headerBytes);
    header.codecFourCC = CFSwapInt32BigToHost(header.codecFourCC);
    header.width = CFSwapInt32BigToHost(header.width);
    header.height = CFSwapInt32BigToHost(header.height);
    header.nalUnitHeaderLength = CFSwapInt32BigToHost(header.nalUnitHeaderLength);
    header.parameterSetCount = CFSwapInt32BigToHost(header.parameterSetCount);
    header.parameterSetBytes = bigToHost64(header.parameterSetBytes);
    header.nominalFPS1000 = CFSwapInt32BigToHost(header.nominalFPS1000);
    header.reserved = CFSwapInt32BigToHost(header.reserved);
    return header;
}

static MRKV011FrameHeader frameHeaderToWire(MRKV011FrameHeader header) {
    header.magic = CFSwapInt32HostToBig(header.magic);
    header.version = CFSwapInt16HostToBig(header.version);
    header.headerBytes = CFSwapInt16HostToBig(header.headerBytes);
    header.sequence = hostToBig64(header.sequence);
    header.payloadBytes = hostToBig64(header.payloadBytes);
    header.ptsValue = hostToBigS64(header.ptsValue);
    header.ptsTimescale = hostToBigS32(header.ptsTimescale);
    header.ptsFlags = CFSwapInt32HostToBig(header.ptsFlags);
    header.durationValue = hostToBigS64(header.durationValue);
    header.durationTimescale = hostToBigS32(header.durationTimescale);
    header.durationFlags = CFSwapInt32HostToBig(header.durationFlags);
    header.senderNanos = hostToBig64(header.senderNanos);
    return header;
}

static MRKV011FrameHeader frameHeaderFromWire(MRKV011FrameHeader header) {
    header.magic = CFSwapInt32BigToHost(header.magic);
    header.version = CFSwapInt16BigToHost(header.version);
    header.headerBytes = CFSwapInt16BigToHost(header.headerBytes);
    header.sequence = bigToHost64(header.sequence);
    header.payloadBytes = bigToHost64(header.payloadBytes);
    header.ptsValue = bigToHostS64(header.ptsValue);
    header.ptsTimescale = bigToHostS32(header.ptsTimescale);
    header.ptsFlags = CFSwapInt32BigToHost(header.ptsFlags);
    header.durationValue = bigToHostS64(header.durationValue);
    header.durationTimescale = bigToHostS32(header.durationTimescale);
    header.durationFlags = CFSwapInt32BigToHost(header.durationFlags);
    header.senderNanos = bigToHost64(header.senderNanos);
    return header;
}

static BOOL writeBig32(int fd, uint32_t value) {
    uint32_t wire = CFSwapInt32HostToBig(value);
    return writeFull(fd, &wire, sizeof(wire));
}

static BOOL readBig32(int fd, uint32_t *value) {
    uint32_t wire = 0;
    if (!readFull(fd, &wire, sizeof(wire))) {
        return NO;
    }
    *value = CFSwapInt32BigToHost(wire);
    return YES;
}

static BOOL writePreflightHeader(int fd, uint32_t magic, NSString **errorOut) {
    MRKV011PreflightHeader header;
    memset(&header, 0, sizeof(header));
    header.magic = magic;
    header.version = MRKV011Version;
    header.headerBytes = sizeof(header);

    MRKV011PreflightHeader wireHeader = preflightHeaderToWire(header);
    if (!writeFull(fd, &wireHeader, sizeof(wireHeader))) {
        if (errorOut) {
            *errorOut = [NSString stringWithFormat:@"could not write network preflight packet: errno %d", errno];
        }
        return NO;
    }
    return YES;
}

static BOOL readPreflightHeader(int fd, uint32_t expectedMagic, NSString **errorOut) {
    MRKV011PreflightHeader wireHeader;
    if (!readFull(fd, &wireHeader, sizeof(wireHeader))) {
        if (errorOut) {
            *errorOut = [NSString stringWithFormat:@"could not read network preflight packet: errno %d", errno];
        }
        return NO;
    }

    MRKV011PreflightHeader header = preflightHeaderFromWire(wireHeader);
    if (header.magic != expectedMagic ||
        header.version != MRKV011Version ||
        header.headerBytes != sizeof(MRKV011PreflightHeader)) {
        if (errorOut) {
            *errorOut = @"invalid network preflight packet";
        }
        return NO;
    }
    return YES;
}

static BOOL performSenderPreflight(int fd, double *roundTripMSOut, NSString **errorOut) {
    uint64_t start = nowNanos();
    if (!writePreflightHeader(fd, MRKV011PreflightMagic, errorOut)) {
        return NO;
    }
    if (!readPreflightHeader(fd, MRKV011PreflightAckMagic, errorOut)) {
        return NO;
    }
    if (roundTripMSOut) {
        *roundTripMSOut = nanosToMS(nowNanos() - start);
    }
    return YES;
}

static BOOL performReceiverPreflight(int fd, double *handlingMSOut, NSString **errorOut) {
    uint64_t start = nowNanos();
    if (!readPreflightHeader(fd, MRKV011PreflightMagic, errorOut)) {
        return NO;
    }
    if (!writePreflightHeader(fd, MRKV011PreflightAckMagic, errorOut)) {
        return NO;
    }
    if (handlingMSOut) {
        *handlingMSOut = nanosToMS(nowNanos() - start);
    }
    return YES;
}

static NSString *modeArgument(int argc, const char *argv[], NSString *defaultValue) {
    NSString *mode = stringArgument(argc, argv, "mode", nil);
    if (mode.length > 0) {
        return mode;
    }
    for (int i = 1; i < argc; i++) {
        NSString *argument = [NSString stringWithUTF8String:argv[i]];
        if (![argument hasPrefix:@"--"]) {
            return argument;
        }
    }
    return defaultValue;
}

static NSString *positionalArgument(int argc, const char *argv[], NSUInteger index, NSString *defaultValue) {
    NSUInteger seen = 0;
    for (int i = 1; i < argc; i++) {
        NSString *argument = [NSString stringWithUTF8String:argv[i]];
        if ([argument hasPrefix:@"--"]) {
            continue;
        }
        if (seen == index) {
            return argument;
        }
        seen += 1;
    }
    return defaultValue;
}

static int createNetworkListener(uint16_t port) {
    int listener = socket(AF_INET, SOCK_STREAM, 0);
    if (listener < 0) {
        return -1;
    }

    int yes = 1;
    setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));

    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_ANY);
    address.sin_port = htons(port);

    if (bind(listener, (struct sockaddr *)&address, sizeof(address)) != 0) {
        close(listener);
        return -1;
    }
    if (listen(listener, 4) != 0) {
        close(listener);
        return -1;
    }
    return listener;
}

static int connectToHost(NSString *host, uint16_t port) {
    struct addrinfo hints;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;

    NSString *portString = [NSString stringWithFormat:@"%u", port];
    struct addrinfo *results = NULL;
    int lookup = getaddrinfo(host.UTF8String, portString.UTF8String, &hints, &results);
    if (lookup != 0) {
        return -1;
    }

    int fd = -1;
    for (struct addrinfo *cursor = results; cursor; cursor = cursor->ai_next) {
        fd = socket(cursor->ai_family, cursor->ai_socktype, cursor->ai_protocol);
        if (fd < 0) {
            continue;
        }
        int yes = 1;
        setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &yes, sizeof(yes));
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof(yes));
        if (connect(fd, cursor->ai_addr, cursor->ai_addrlen) == 0) {
            break;
        }
        close(fd);
        fd = -1;
    }
    freeaddrinfo(results);
    return fd;
}

static NSArray<NSData *> *parameterSetsForFormatDescription(CMFormatDescriptionRef formatDescription,
                                                            OSType codec,
                                                            int *nalUnitHeaderLengthOut,
                                                            NSString **errorOut) {
    size_t parameterSetCount = 0;
    int nalUnitHeaderLength = 0;
    OSStatus status = noErr;

    if (codec == kCMVideoCodecType_H264) {
        status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription,
                                                                    0,
                                                                    NULL,
                                                                    NULL,
                                                                    &parameterSetCount,
                                                                    &nalUnitHeaderLength);
    } else if (codec == kCMVideoCodecType_HEVC) {
        status = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(formatDescription,
                                                                    0,
                                                                    NULL,
                                                                    NULL,
                                                                    &parameterSetCount,
                                                                    &nalUnitHeaderLength);
    } else {
        if (errorOut) {
            *errorOut = [NSString stringWithFormat:@"unsupported codec for parameter-set serialization: %@", fourCC(codec)];
        }
        return @[];
    }

    if (status != noErr || parameterSetCount == 0) {
        if (errorOut) {
            *errorOut = [NSString stringWithFormat:@"could not query parameter-set count: %d", status];
        }
        return @[];
    }

    NSMutableArray<NSData *> *sets = [NSMutableArray arrayWithCapacity:parameterSetCount];
    for (size_t index = 0; index < parameterSetCount; index++) {
        const uint8_t *pointer = NULL;
        size_t size = 0;
        if (codec == kCMVideoCodecType_H264) {
            status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription,
                                                                        index,
                                                                        &pointer,
                                                                        &size,
                                                                        NULL,
                                                                        NULL);
        } else {
            status = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(formatDescription,
                                                                        index,
                                                                        &pointer,
                                                                        &size,
                                                                        NULL,
                                                                        NULL);
        }
        if (status != noErr || !pointer || size == 0) {
            if (errorOut) {
                *errorOut = [NSString stringWithFormat:@"could not read parameter set %zu: %d", index, status];
            }
            return @[];
        }
        [sets addObject:[NSData dataWithBytes:pointer length:size]];
    }

    if (nalUnitHeaderLengthOut) {
        *nalUnitHeaderLengthOut = nalUnitHeaderLength;
    }
    return sets;
}

static CMFormatDescriptionRef createFormatDescriptionFromParameterSets(OSType codec,
                                                                       NSArray<NSData *> *parameterSets,
                                                                       int nalUnitHeaderLength,
                                                                       NSString **errorOut) {
    if (parameterSets.count == 0) {
        if (errorOut) {
            *errorOut = @"missing parameter sets";
        }
        return NULL;
    }

    const uint8_t **pointers = calloc(parameterSets.count, sizeof(uint8_t *));
    size_t *sizes = calloc(parameterSets.count, sizeof(size_t));
    if (!pointers || !sizes) {
        free(pointers);
        free(sizes);
        if (errorOut) {
            *errorOut = @"could not allocate parameter-set pointer arrays";
        }
        return NULL;
    }

    for (NSUInteger i = 0; i < parameterSets.count; i++) {
        NSData *data = parameterSets[i];
        pointers[i] = data.bytes;
        sizes[i] = data.length;
    }

    CMFormatDescriptionRef formatDescription = NULL;
    OSStatus status = noErr;
    if (codec == kCMVideoCodecType_H264) {
        status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                     parameterSets.count,
                                                                     pointers,
                                                                     sizes,
                                                                     nalUnitHeaderLength,
                                                                     &formatDescription);
    } else if (codec == kCMVideoCodecType_HEVC) {
        status = CMVideoFormatDescriptionCreateFromHEVCParameterSets(kCFAllocatorDefault,
                                                                     parameterSets.count,
                                                                     pointers,
                                                                     sizes,
                                                                     nalUnitHeaderLength,
                                                                     NULL,
                                                                     &formatDescription);
    } else {
        status = kCMFormatDescriptionError_InvalidParameter;
    }

    free(pointers);
    free(sizes);

    if (status != noErr || !formatDescription) {
        if (errorOut) {
            *errorOut = [NSString stringWithFormat:@"could not create format description from parameter sets: %d", status];
        }
        return NULL;
    }
    return formatDescription;
}

static BOOL sendStreamHeaderForFormatDescription(int fd,
                                                 CMFormatDescriptionRef formatDescription,
                                                 OSType codec,
                                                 CMVideoDimensions dimensions,
                                                 Float32 nominalFPS,
                                                 NSString **errorOut) {
    int nalUnitHeaderLength = 0;
    NSString *parameterError = nil;
    NSArray<NSData *> *parameterSets = parameterSetsForFormatDescription(formatDescription,
                                                                         codec,
                                                                         &nalUnitHeaderLength,
                                                                         &parameterError);
    if (parameterSets.count == 0) {
        if (errorOut) {
            *errorOut = parameterError ?: @"no parameter sets found";
        }
        return NO;
    }

    uint64_t totalParameterBytes = 0;
    for (NSData *data in parameterSets) {
        totalParameterBytes += data.length;
    }

    MRKV011StreamHeader header;
    memset(&header, 0, sizeof(header));
    header.magic = MRKV011StreamMagic;
    header.version = MRKV011Version;
    header.headerBytes = sizeof(header);
    header.codecFourCC = codec;
    header.width = (uint32_t)MAX(0, dimensions.width);
    header.height = (uint32_t)MAX(0, dimensions.height);
    header.nalUnitHeaderLength = (uint32_t)nalUnitHeaderLength;
    header.parameterSetCount = (uint32_t)parameterSets.count;
    header.parameterSetBytes = totalParameterBytes;
    header.nominalFPS1000 = (uint32_t)llround(MAX(0.0f, nominalFPS) * 1000.0);

    MRKV011StreamHeader wireHeader = streamHeaderToWire(header);
    if (!writeFull(fd, &wireHeader, sizeof(wireHeader))) {
        if (errorOut) {
            *errorOut = [NSString stringWithFormat:@"could not write stream header: errno %d", errno];
        }
        return NO;
    }

    for (NSData *data in parameterSets) {
        if (data.length > UINT32_MAX || !writeBig32(fd, (uint32_t)data.length) || !writeFull(fd, data.bytes, data.length)) {
            if (errorOut) {
                *errorOut = [NSString stringWithFormat:@"could not write parameter set: errno %d", errno];
            }
            return NO;
        }
    }
    return YES;
}


@interface NetworkStreamConfig : NSObject {
    CMFormatDescriptionRef _formatDescription;
}
@property(nonatomic) OSType codec;
@property(nonatomic) CMVideoDimensions dimensions;
@property(nonatomic) Float32 nominalFPS;
@property(nonatomic) int nalUnitHeaderLength;
@property(nonatomic) NSUInteger parameterSetCount;
@property(nonatomic) unsigned long long parameterSetBytes;
@property(nonatomic) CMFormatDescriptionRef formatDescription;
@end

@implementation NetworkStreamConfig

- (void)setFormatDescription:(CMFormatDescriptionRef)formatDescription {
    if (_formatDescription) {
        CFRelease(_formatDescription);
        _formatDescription = NULL;
    }
    if (formatDescription) {
        _formatDescription = (CMFormatDescriptionRef)CFRetain(formatDescription);
    }
}

- (CMFormatDescriptionRef)formatDescription {
    return _formatDescription;
}

- (void)dealloc {
    if (_formatDescription) {
        CFRelease(_formatDescription);
    }
}

@end

static NetworkStreamConfig *readStreamConfig(int fd, NSString **errorOut) {
    MRKV011StreamHeader wireHeader;
    if (!readFull(fd, &wireHeader, sizeof(wireHeader))) {
        if (errorOut) {
            *errorOut = @"could not read stream header";
        }
        return nil;
    }

    MRKV011StreamHeader header = streamHeaderFromWire(wireHeader);
    if (header.magic != MRKV011StreamMagic ||
        header.version != MRKV011Version ||
        header.headerBytes != sizeof(MRKV011StreamHeader)) {
        if (errorOut) {
            *errorOut = @"invalid stream header";
        }
        return nil;
    }
    if (header.parameterSetCount == 0 || header.parameterSetCount > 16 || header.parameterSetBytes > 1024ULL * 1024ULL) {
        if (errorOut) {
            *errorOut = @"invalid parameter-set section";
        }
        return nil;
    }

    NSMutableArray<NSData *> *parameterSets = [NSMutableArray arrayWithCapacity:header.parameterSetCount];
    for (uint32_t i = 0; i < header.parameterSetCount; i++) {
        uint32_t length = 0;
        if (!readBig32(fd, &length) || length == 0 || length > 1024 * 1024) {
            if (errorOut) {
                *errorOut = @"could not read parameter-set length";
            }
            return nil;
        }
        NSMutableData *data = [NSMutableData dataWithLength:length];
        if (!readFull(fd, data.mutableBytes, data.length)) {
            if (errorOut) {
                *errorOut = @"could not read parameter-set bytes";
            }
            return nil;
        }
        [parameterSets addObject:data];
    }

    NSString *formatError = nil;
    CMFormatDescriptionRef formatDescription = createFormatDescriptionFromParameterSets(header.codecFourCC,
                                                                                       parameterSets,
                                                                                       (int)header.nalUnitHeaderLength,
                                                                                       &formatError);
    if (!formatDescription) {
        if (errorOut) {
            *errorOut = formatError ?: @"could not rebuild format description";
        }
        return nil;
    }

    NetworkStreamConfig *config = [[NetworkStreamConfig alloc] init];
    config.codec = header.codecFourCC;
    config.dimensions = (CMVideoDimensions){(int32_t)header.width, (int32_t)header.height};
    config.nominalFPS = header.nominalFPS1000 > 0 ? (Float32)header.nominalFPS1000 / 1000.0f : 60.0f;
    config.nalUnitHeaderLength = (int)header.nalUnitHeaderLength;
    config.parameterSetCount = header.parameterSetCount;
    config.parameterSetBytes = header.parameterSetBytes;
    config.formatDescription = formatDescription;
    CFRelease(formatDescription);
    return config;
}


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

static void setVTBoolLocal(VTCompressionSessionRef session, CFStringRef key, BOOL value) {
    VTSessionSetProperty(session, key, value ? kCFBooleanTrue : kCFBooleanFalse);
}

static void setVTIntLocal(VTCompressionSessionRef session, CFStringRef key, int32_t value) {
    CFNumberRef number = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &value);
    VTSessionSetProperty(session, key, number);
    CFRelease(number);
}

@interface LiveAnimatedProbeView : NSView
@property(nonatomic) NSUInteger frameIndex;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, copy) NSString *label;
- (void)startAnimatingAtFPS:(NSUInteger)fps;
- (void)stopAnimating;
@end

@implementation LiveAnimatedProbeView

- (BOOL)isFlipped {
    return YES;
}

- (void)startAnimatingAtFPS:(NSUInteger)fps {
    NSTimeInterval interval = 1.0 / (NSTimeInterval)MAX((NSUInteger)1, fps);
    __weak LiveAnimatedProbeView *weakSelf = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(NSTimer *timer) {
        LiveAnimatedProbeView *view = weakSelf;
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

    NSMutableDictionary *titleAttributes = [@{
        NSForegroundColorAttributeName: NSColor.whiteColor
    } mutableCopy];
    NSMutableDictionary *smallAttributes = [@{
        NSForegroundColorAttributeName: [NSColor colorWithWhite:0.92 alpha:1.0]
    } mutableCopy];
    NSFont *titleFont = [NSFont monospacedSystemFontOfSize:38.0 weight:NSFontWeightBold]
        ?: [NSFont systemFontOfSize:38.0 weight:NSFontWeightBold];
    NSFont *smallFont = [NSFont monospacedSystemFontOfSize:22.0 weight:NSFontWeightRegular]
        ?: [NSFont systemFontOfSize:22.0 weight:NSFontWeightRegular];
    if (titleFont) {
        titleAttributes[NSFontAttributeName] = titleFont;
    }
    if (smallFont) {
        smallAttributes[NSFontAttributeName] = smallFont;
    }

    [@"MacRemoteKVM Experiment 017" drawAtPoint:NSMakePoint(48.0, 38.0) withAttributes:titleAttributes];
    [[NSString stringWithFormat:@"%@ - live frame %lu", self.label ?: @"Live capture", (unsigned long)self.frameIndex]
        drawAtPoint:NSMakePoint(52.0, 88.0) withAttributes:smallAttributes];
}

@end

@class LiveCaptureSenderCase;
static void liveCompressionOutputCallback(void *outputCallbackRefCon,
                                          void *sourceFrameRefCon,
                                          OSStatus status,
                                          VTEncodeInfoFlags infoFlags,
                                          CMSampleBufferRef sampleBuffer);

@interface LiveCaptureSenderCase : NSObject <SCStreamOutput, SCStreamDelegate> {
    VTCompressionSessionRef _compressionSession;
    int _fd;
}
@property(nonatomic, strong) NSString *host;
@property(nonatomic) uint16_t port;
@property(nonatomic, strong) NSString *outputPath;
@property(nonatomic, strong) NSString *caseName;
@property(nonatomic, strong) NSString *codecDisplayName;
@property(nonatomic) OSType codec;
@property(nonatomic) NSUInteger width;
@property(nonatomic) NSUInteger height;
@property(nonatomic) NSUInteger refresh;
@property(nonatomic) NSUInteger bitrateMbps;
@property(nonatomic) NSUInteger backingWidth;
@property(nonatomic) NSUInteger backingHeight;
@property(nonatomic) NSTimeInterval requestedDurationSeconds;
@property(nonatomic) BOOL success;
@property(nonatomic, strong) NSString *failure;
@property(nonatomic, strong) NSString *encoderNote;
@property(nonatomic, strong) NSError *streamError;
@property(nonatomic) CGDirectDisplayID virtualDisplayID;
@property(nonatomic) NSUInteger streamCallbacks;
@property(nonatomic) NSUInteger completeInputFrames;
@property(nonatomic) NSUInteger submittedFrames;
@property(nonatomic) NSUInteger encodeCallErrors;
@property(nonatomic) NSUInteger encodeCallDroppedFlags;
@property(nonatomic) NSUInteger outputCallbacks;
@property(nonatomic) NSUInteger encodedFrames;
@property(nonatomic) NSUInteger outputErrors;
@property(nonatomic) NSUInteger outputDroppedFrames;
@property(nonatomic) NSUInteger keyFrames;
@property(nonatomic) NSUInteger framesSent;
@property(nonatomic) unsigned long long bytesSent;
@property(nonatomic) NSUInteger firstInputWidth;
@property(nonatomic) NSUInteger firstInputHeight;
@property(nonatomic) NSUInteger lastInputWidth;
@property(nonatomic) NSUInteger lastInputHeight;
@property(nonatomic) BOOL sawIOSurface;
@property(nonatomic) BOOL dimensionsMatched;
@property(nonatomic) BOOL sentStreamHeader;
@property(nonatomic) NSUInteger sequence;
@property(nonatomic) NSTimeInterval firstInputWallTime;
@property(nonatomic) NSTimeInterval lastInputWallTime;
@property(nonatomic) NSTimeInterval firstOutputWallTime;
@property(nonatomic) NSTimeInterval lastOutputWallTime;
@property(nonatomic) NSTimeInterval senderWallSeconds;
@property(nonatomic, strong) NSDate *startDate;
@property(nonatomic) BOOL preflightOK;
@property(nonatomic) double preflightRoundTripMS;
- (BOOL)run;
- (BOOL)createEncoder;
- (void)handleCompressionOutputWithStatus:(OSStatus)status infoFlags:(VTEncodeInfoFlags)infoFlags sampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)writeReport;
@end

@implementation LiveCaptureSenderCase

- (instancetype)init {
    self = [super init];
    if (self) {
        _refresh = 60;
        _requestedDurationSeconds = 30.0;
        _backingWidth = 5120;
        _backingHeight = 2880;
        _dimensionsMatched = YES;
        _fd = -1;
    }
    return self;
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
                                                 liveCompressionOutputCallback,
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
                                            liveCompressionOutputCallback,
                                            (__bridge void *)self,
                                            &_compressionSession);
        self.encoderNote = [self.encoderNote stringByAppendingFormat:@"; fallback create status: %d", status];
    }
    if (status != noErr || !_compressionSession) {
        return NO;
    }

    setVTBoolLocal(_compressionSession, kVTCompressionPropertyKey_RealTime, YES);
    setVTBoolLocal(_compressionSession, kVTCompressionPropertyKey_AllowFrameReordering, NO);
    setVTBoolLocal(_compressionSession, kVTCompressionPropertyKey_PrioritizeEncodingSpeedOverQuality, YES);
    setVTIntLocal(_compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, (int32_t)self.refresh);
    setVTIntLocal(_compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (int32_t)self.refresh);
    setVTIntLocal(_compressionSession, kVTCompressionPropertyKey_AverageBitRate, (int32_t)(self.bitrateMbps * 1000 * 1000));
    if (self.codec == kCMVideoCodecType_H264) {
        VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_High_AutoLevel);
    } else if (self.codec == kCMVideoCodecType_HEVC) {
        VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_HEVC_Main_AutoLevel);
    }

    status = VTCompressionSessionPrepareToEncodeFrames(_compressionSession);
    self.encoderNote = [self.encoderNote stringByAppendingFormat:@"; prepare status: %d", status];
    return status == noErr;
}

- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(SCStreamOutputType)type {
    if (type != SCStreamOutputTypeScreen || !sampleBuffer || !_compressionSession || self.failure) {
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

    @synchronized (self) {
        self.streamCallbacks += 1;
    }

    if (frameStatus != SCFrameStatusComplete || !imageBuffer) {
        return;
    }

    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    IOSurfaceRef surface = CVPixelBufferGetIOSurface(imageBuffer);
    NSTimeInterval wallSeconds = -[self.startDate timeIntervalSinceNow];

    NSUInteger frameNumber = 0;
    @synchronized (self) {
        self.completeInputFrames += 1;
        if (self.completeInputFrames == 1) {
            self.firstInputWallTime = wallSeconds;
            self.firstInputWidth = width;
            self.firstInputHeight = height;
        }
        self.lastInputWallTime = wallSeconds;
        self.lastInputWidth = width;
        self.lastInputHeight = height;
        self.sawIOSurface = self.sawIOSurface || surface != NULL;
        self.dimensionsMatched = self.dimensionsMatched && (width == self.width && height == self.height);
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
    }

    if (status != noErr || dropped || !sampleBuffer || self.failure) {
        return;
    }

    CMBlockBufferRef block = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t payloadLength = block ? CMBlockBufferGetDataLength(block) : 0;
    if (payloadLength == 0) {
        return;
    }
    NSMutableData *payload = [NSMutableData dataWithLength:payloadLength];
    OSStatus copyStatus = CMBlockBufferCopyDataBytes(block, 0, payloadLength, payload.mutableBytes);
    if (copyStatus != noErr) {
        @synchronized (self) {
            self.failure = [NSString stringWithFormat:@"could not copy compressed sample bytes: %d", copyStatus];
        }
        return;
    }

    CMSampleTimingInfo timing;
    OSStatus timingStatus = CMSampleBufferGetSampleTimingInfo(sampleBuffer, 0, &timing);
    if (timingStatus != noErr) {
        timing.presentationTimeStamp = CMTimeMake((int64_t)self.sequence, (int32_t)self.refresh);
        timing.duration = CMTimeMake(1, (int32_t)self.refresh);
        timing.decodeTimeStamp = kCMTimeInvalid;
    }

    @synchronized (self) {
        if (!self.sentStreamHeader) {
            CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
            NSString *headerError = nil;
            CMVideoDimensions dimensions = {(int32_t)self.width, (int32_t)self.height};
            if (!formatDescription ||
                !sendStreamHeaderForFormatDescription(_fd,
                                                      formatDescription,
                                                      self.codec,
                                                      dimensions,
                                                      (Float32)self.refresh,
                                                      &headerError)) {
                self.failure = headerError ?: @"could not send stream header from live encoder output";
                return;
            }
            self.sentStreamHeader = YES;
        }

        MRKV011FrameHeader header;
        memset(&header, 0, sizeof(header));
        header.magic = MRKV011FrameMagic;
        header.version = MRKV011Version;
        header.headerBytes = sizeof(header);
        header.sequence = self.sequence;
        header.payloadBytes = payload.length;
        header.ptsValue = timing.presentationTimeStamp.value;
        header.ptsTimescale = timing.presentationTimeStamp.timescale;
        header.ptsFlags = timing.presentationTimeStamp.flags;
        header.durationValue = timing.duration.value;
        header.durationTimescale = timing.duration.timescale;
        header.durationFlags = timing.duration.flags;
        header.senderNanos = nowNanos();

        MRKV011FrameHeader wireHeader = frameHeaderToWire(header);
        if (!writeFull(_fd, &wireHeader, sizeof(wireHeader)) || !writeFull(_fd, payload.bytes, payload.length)) {
            self.failure = [NSString stringWithFormat:@"sender write failed at frame %lu: errno %d", (unsigned long)self.sequence, errno];
            return;
        }

        self.sequence += 1;
        self.framesSent += 1;
        self.bytesSent += sizeof(header) + payload.length;
        self.encodedFrames += 1;
        if (keyFrame) {
            self.keyFrames += 1;
        }
    }
}

- (BOOL)run {
    _fd = -1;
    Class descriptorClass = NSClassFromString(@"CGVirtualDisplayDescriptor");
    Class displayClass = NSClassFromString(@"CGVirtualDisplay");
    Class settingsClass = NSClassFromString(@"CGVirtualDisplaySettings");
    Class modeClass = NSClassFromString(@"CGVirtualDisplayMode");
    if (!descriptorClass || !displayClass || !settingsClass || !modeClass) {
        self.failure = @"missing private CoreGraphics virtual-display classes";
        if (_fd >= 0) {
            close(_fd);
            _fd = -1;
        }
        [self writeReport];
        return NO;
    }

    CGVirtualDisplayDescriptor *descriptor = [[descriptorClass alloc] init];
    descriptor.name = [NSString stringWithFormat:@"MacRemoteKVM Live %@ Probe", self.codecDisplayName ?: @"Video"];
    descriptor.maxPixelsWide = (unsigned int)self.backingWidth;
    descriptor.maxPixelsHigh = (unsigned int)self.backingHeight;
    descriptor.sizeInMillimeters = CGSizeMake(597, 336);
    descriptor.vendorID = 0x4D52;
    descriptor.productID = 0x5D60;
    descriptor.serialNum = (self.codec == kCMVideoCodecType_H264) ? 0x0012 : 0x0013;
    descriptor.queue = dispatch_get_main_queue();

    CGVirtualDisplay *virtualDisplay = [[displayClass alloc] initWithDescriptor:descriptor];
    if (!virtualDisplay) {
        self.failure = @"CGVirtualDisplay initWithDescriptor returned nil";
        if (_fd >= 0) {
            close(_fd);
            _fd = -1;
        }
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
    BOOL applied = [virtualDisplay applySettings:settings];
    if (!applied) {
        self.failure = @"virtual display applySettings returned false";
        if (_fd >= 0) {
            close(_fd);
            _fd = -1;
        }
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
    LiveAnimatedProbeView *probeView = [[LiveAnimatedProbeView alloc] initWithFrame:NSMakeRect(0, 0, displayBounds.size.width, displayBounds.size.height)];
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
        if (_fd >= 0) {
            close(_fd);
            _fd = -1;
        }
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
        if (_fd >= 0) {
            close(_fd);
            _fd = -1;
        }
        [self writeReport];
        return NO;
    }

    if (![self createEncoder]) {
        self.failure = @"could not create or prepare VideoToolbox encoder";
        [probeView stopAnimating];
        [window close];
        if (_fd >= 0) {
            close(_fd);
            _fd = -1;
        }
        [self writeReport];
        return NO;
    }

    SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:targetDisplay excludingWindows:@[]];
    SCStreamConfiguration *config = [[SCStreamConfiguration alloc] init];
    config.width = self.width;
    config.height = self.height;
    config.minimumFrameInterval = kCMTimeZero;
    config.pixelFormat = kCVPixelFormatType_32BGRA;
    config.showsCursor = NO;
    config.capturesAudio = NO;
    config.captureResolution = SCCaptureResolutionBest;
    config.queueDepth = 8;

    SCStream *stream = [[SCStream alloc] initWithFilter:filter configuration:config delegate:self];
    dispatch_queue_t sampleQueue = dispatch_queue_create("dev.macremotekvm.live-capture.samples", DISPATCH_QUEUE_SERIAL);
    NSError *outputError = nil;
    if (![stream addStreamOutput:self type:SCStreamOutputTypeScreen sampleHandlerQueue:sampleQueue error:&outputError]) {
        self.failure = [NSString stringWithFormat:@"addStreamOutput failed: %@", outputError.localizedDescription ?: @"unknown"];
        [probeView stopAnimating];
        [window close];
        VTCompressionSessionInvalidate(_compressionSession);
        CFRelease(_compressionSession);
        _compressionSession = NULL;
        if (_fd >= 0) {
            close(_fd);
            _fd = -1;
        }
        [self writeReport];
        return NO;
    }

    printf("Connecting to %s:%u. Approve network prompts now; measurement has not started.\n", self.host.UTF8String, self.port);
    _fd = connectToHost(self.host, self.port);
    if (_fd < 0) {
        self.failure = [NSString stringWithFormat:@"could not connect to %@:%u: errno %d", self.host, self.port, errno];
        [probeView stopAnimating];
        [window close];
        VTCompressionSessionInvalidate(_compressionSession);
        CFRelease(_compressionSession);
        _compressionSession = NULL;
        [self writeReport];
        return NO;
    }

    NSString *preflightError = nil;
    double preflightRoundTripMS = 0.0;
    if (!performSenderPreflight(_fd, &preflightRoundTripMS, &preflightError)) {
        self.failure = preflightError ?: @"network preflight failed";
        [probeView stopAnimating];
        [window close];
        VTCompressionSessionInvalidate(_compressionSession);
        CFRelease(_compressionSession);
        _compressionSession = NULL;
        close(_fd);
        _fd = -1;
        [self writeReport];
        return NO;
    }
    self.preflightOK = YES;
    self.preflightRoundTripMS = preflightRoundTripMS;
    printf("Network preflight passed in %.3f ms; starting capture.\n", preflightRoundTripMS);

    uint64_t startNanos = nowNanos();
    self.startDate = [NSDate date];
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
        VTCompressionSessionInvalidate(_compressionSession);
        CFRelease(_compressionSession);
        _compressionSession = NULL;
        if (_fd >= 0) {
            close(_fd);
            _fd = -1;
        }
        [self writeReport];
        return NO;
    }

    printf("Live capture running for %.1f seconds.\n", self.requestedDurationSeconds);
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:self.requestedDurationSeconds];
    while ([deadline timeIntervalSinceNow] > 0 && !self.failure) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }

    dispatch_semaphore_t stopSemaphore = dispatch_semaphore_create(0);
    [stream stopCaptureWithCompletionHandler:^(NSError *_Nullable error) {
        dispatch_semaphore_signal(stopSemaphore);
    }];
    if (!waitForSemaphore(stopSemaphore, 5.0)) {
        self.failure = self.failure ?: @"ScreenCaptureKit stop timed out";
    }
    dispatch_sync(sampleQueue, ^{});
    printf("Capture finished; draining the encoder.\n");

    VTCompressionSessionCompleteFrames(_compressionSession, kCMTimeInvalid);
    self.senderWallSeconds = (double)(nowNanos() - startNanos) / 1000000000.0;

    [probeView stopAnimating];
    [window close];
    VTCompressionSessionInvalidate(_compressionSession);
    CFRelease(_compressionSession);
    _compressionSession = NULL;
    shutdown(_fd, SHUT_WR);
    close(_fd);
    _fd = -1;

    self.success = self.failure == nil && self.streamError == nil && self.dimensionsMatched && self.sentStreamHeader && self.framesSent > 0 && self.encodeCallErrors == 0 && self.outputErrors == 0 && self.outputDroppedFrames == 0 && self.encodeCallDroppedFlags == 0 && self.framesSent == self.completeInputFrames;
    [self writeReport];
    return self.success;
}

- (void)writeReport {
    createOutputDirectory(self.outputPath);
    double sentFPS = self.senderWallSeconds > 0.0 ? (double)self.framesSent / self.senderWallSeconds : 0.0;
    double inputFPS = (self.lastInputWallTime - self.firstInputWallTime) > 0.0 && self.completeInputFrames > 1
        ? (double)(self.completeInputFrames - 1) / (self.lastInputWallTime - self.firstInputWallTime)
        : 0.0;
    double outputFPS = (self.lastOutputWallTime - self.firstOutputWallTime) > 0.0 && self.encodedFrames > 1
        ? (double)(self.encodedFrames - 1) / (self.lastOutputWallTime - self.firstOutputWallTime)
        : 0.0;
    double transportMbps = self.senderWallSeconds > 0.0 ? ((double)self.bytesSent * 8.0 / self.senderWallSeconds / 1000000.0) : 0.0;

    NSMutableString *report = [NSMutableString string];
    [report appendFormat:@"# Experiment 017 Live Sender Result: %@\n\n", self.caseName ?: @"Live HEVC Native Interval"];
    [report appendString:@"## Machine\n\n"];
    NSProcessInfo *processInfo = NSProcessInfo.processInfo;
    [report appendFormat:@"- Host name: %@\n", processInfo.hostName];
    [report appendFormat:@"- macOS: %@\n", processInfo.operatingSystemVersionString];
    [report appendFormat:@"- Hardware model: %@\n", sysctlString("hw.model")];
    [report appendFormat:@"- CPU brand: %@\n", sysctlString("machdep.cpu.brand_string")];

    [report appendString:@"\n## Sender Settings\n\n"];
    [report appendFormat:@"- Destination: %@:%u\n", self.host ?: @"unavailable", self.port];
    [report appendFormat:@"- Requested duration: %.1f seconds\n", self.requestedDurationSeconds];
    [report appendFormat:@"- Source: software 5K virtual display captured through ScreenCaptureKit\n"];
    [report appendFormat:@"- Virtual display id: %u\n", self.virtualDisplayID];
    [report appendFormat:@"- Virtual display backing size: %lu x %lu\n", (unsigned long)self.backingWidth, (unsigned long)self.backingHeight];
    [report appendFormat:@"- Capture/encode dimensions: %lu x %lu\n", (unsigned long)self.width, (unsigned long)self.height];
    [report appendFormat:@"- Virtual display refresh: %lu Hz\n", (unsigned long)self.refresh];
    [report appendString:@"- Minimum frame interval: native display refresh (kCMTimeZero)\n"];
    [report appendString:@"- Capture resolution: Best\n"];
    [report appendString:@"- Capture pixel format: BGRA\n"];
    [report appendString:@"- Queue depth: 8\n"];
    [report appendFormat:@"- Codec FourCC: `%@`\n", fourCC(self.codec)];
    [report appendFormat:@"- Codec name: %@\n", self.codecDisplayName ?: @"unavailable"];
    [report appendFormat:@"- Target bitrate: %lu Mbps\n", (unsigned long)self.bitrateMbps];
    [report appendFormat:@"- Encoder setup: %@\n", self.encoderNote ?: @"unavailable"];
    [report appendFormat:@"- Network preflight: %@\n", self.preflightOK ? @"passed before capture/timed sender window" : @"not completed"];
    [report appendFormat:@"- Network preflight round trip: %.3f ms\n", self.preflightRoundTripMS];
    [report appendString:@"- Transport: TCP over configured network path\n"];
    [report appendString:@"- Header encoding: big-endian network headers\n"];
    [report appendString:@"- Decoder config: serialized H.264/HEVC parameter sets from live encoder output\n"];

    [report appendString:@"\n## Capture Result\n\n"];
    [report appendFormat:@"- Stream callbacks: %lu\n", (unsigned long)self.streamCallbacks];
    [report appendFormat:@"- Complete input frames: %lu\n", (unsigned long)self.completeInputFrames];
    [report appendFormat:@"- Submitted to encoder: %lu\n", (unsigned long)self.submittedFrames];
    [report appendFormat:@"- First input frame: %lu x %lu\n", (unsigned long)self.firstInputWidth, (unsigned long)self.firstInputHeight];
    [report appendFormat:@"- Last input frame: %lu x %lu\n", (unsigned long)self.lastInputWidth, (unsigned long)self.lastInputHeight];
    [report appendFormat:@"- Observed complete-input FPS: %.2f\n", inputFPS];
    [report appendFormat:@"- Saw IOSurface-backed input buffers: %@\n", yesNo(self.sawIOSurface)];
    [report appendFormat:@"- All input dimensions matched expected: %@\n", yesNo(self.dimensionsMatched)];
    [report appendFormat:@"- Stream error: %@\n", self.streamError ? self.streamError.localizedDescription : @"none"];

    [report appendString:@"\n## Encode/Send Result\n\n"];
    [report appendFormat:@"- Success: %@\n", yesNo(self.success)];
    if (self.failure) {
        [report appendFormat:@"- Failure: %@\n", self.failure];
    }
    [report appendFormat:@"- Encode call errors: %lu\n", (unsigned long)self.encodeCallErrors];
    [report appendFormat:@"- Encode call dropped flags: %lu\n", (unsigned long)self.encodeCallDroppedFlags];
    [report appendFormat:@"- Encoder output callbacks: %lu\n", (unsigned long)self.outputCallbacks];
    [report appendFormat:@"- Encoded frames sent: %lu\n", (unsigned long)self.encodedFrames];
    [report appendFormat:@"- Output errors: %lu\n", (unsigned long)self.outputErrors];
    [report appendFormat:@"- Output dropped frames: %lu\n", (unsigned long)self.outputDroppedFrames];
    [report appendFormat:@"- Key frames: %lu\n", (unsigned long)self.keyFrames];
    [report appendFormat:@"- Frames sent: %lu\n", (unsigned long)self.framesSent];
    [report appendFormat:@"- Bytes sent: %llu\n", self.bytesSent];
    [report appendFormat:@"- Sender wall time: %.3f seconds\n", self.senderWallSeconds];
    [report appendString:@"- Sender timing boundary: after network preflight, before startCapture, through encoder drain\n"];
    [report appendFormat:@"- Sender frame rate: %.2f FPS\n", sentFPS];
    [report appendFormat:@"- Observed encoded FPS: %.2f\n", outputFPS];
    [report appendFormat:@"- Realtime multiple vs %lu FPS target: %.2fx\n", (unsigned long)self.refresh, self.refresh > 0 ? sentFPS / (double)self.refresh : 0.0];
    [report appendFormat:@"- Measured sender bitrate: %.2f Mbps\n", transportMbps];

    [report appendString:@"\n## Interpretation\n\n"];
    [report appendString:@"The existing pass band is 95% of 60 Hz (57 FPS); it does not demonstrate sustained 60 FPS. Compare measured capture, send, and render rates and frame counts.\n\n"];
    if (self.success && sentFPS >= (double)self.refresh * 0.95) {
        [report appendString:@"The live ScreenCaptureKit -> VideoToolbox -> TCP sender path stayed inside the current pass band for this stream.\n"];
    } else if (self.success) {
        [report appendString:@"The live sender path completed but did not hold the target frame rate. Inspect capture and encoder pacing before productizing this stream shape.\n"];
    } else {
        [report appendString:@"The live sender path did not complete cleanly for this stream.\n"];
    }

    NSError *error = nil;
    if (![report writeToFile:self.outputPath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        fprintf(stderr, "Could not write live sender report: %s\n", error.localizedDescription.UTF8String);
    } else {
        printf("Wrote live sender report: %s\n", self.outputPath.UTF8String);
    }
}

- (void)dealloc {
    if (_compressionSession) {
        VTCompressionSessionInvalidate(_compressionSession);
        CFRelease(_compressionSession);
        _compressionSession = NULL;
    }
    if (_fd >= 0) {
        close(_fd);
        _fd = -1;
    }
}

@end

static void liveCompressionOutputCallback(void *outputCallbackRefCon,
                                          void *sourceFrameRefCon,
                                          OSStatus status,
                                          VTEncodeInfoFlags infoFlags,
                                          CMSampleBufferRef sampleBuffer) {
    LiveCaptureSenderCase *sender = (__bridge LiveCaptureSenderCase *)outputCallbackRefCon;
    [sender handleCompressionOutputWithStatus:status infoFlags:infoFlags sampleBuffer:sampleBuffer];
}

@class NetworkReceiverCase;
static void networkOutputCallback(void *decompressionOutputRefCon,
                                  void *sourceFrameRefCon,
                                  OSStatus status,
                                  VTDecodeInfoFlags infoFlags,
                                  CVImageBufferRef imageBuffer,
                                  CMTime presentationTimeStamp,
                                  CMTime presentationDuration);

@interface NetworkReceiverCase : NSObject {
    VTDecompressionSessionRef _decompressionSession;
}
@property(nonatomic, strong) NetworkStreamConfig *config;
@property(nonatomic, strong) MetalPresenter *presenter;
@property(nonatomic, strong) NSString *outputPath;
@property(nonatomic, strong) NSString *caseName;
@property(nonatomic) NSUInteger caseIndex;
@property(nonatomic) NSUInteger inflightLimit;
@property(nonatomic) BOOL requireHardwareDecoder;
@property(nonatomic) OSStatus sessionCreateStatus;
@property(nonatomic) OSStatus fallbackSessionCreateStatus;
@property(nonatomic, strong) NSString *sessionNote;
@property(nonatomic, strong) NSString *failure;
@property(nonatomic) NSUInteger framesReceived;
@property(nonatomic) unsigned long long bytesReceived;
@property(nonatomic) NSUInteger submittedFrames;
@property(nonatomic) NSUInteger decodeCallErrors;
@property(nonatomic) NSUInteger decodedFrames;
@property(nonatomic) NSUInteger decodeOutputErrors;
@property(nonatomic) NSUInteger droppedFrameFlags;
@property(nonatomic) NSUInteger renderedFrames;
@property(nonatomic) NSUInteger renderFailures;
@property(nonatomic) NSUInteger firstDecodedWidth;
@property(nonatomic) NSUInteger firstDecodedHeight;
@property(nonatomic) OSType firstDecodedPixelFormat;
@property(nonatomic) uint64_t receiverStartNanos;
@property(nonatomic) NSTimeInterval receiverWallSeconds;
@property(nonatomic) NSTimeInterval firstOutputWallSeconds;
@property(nonatomic) NSTimeInterval lastOutputWallSeconds;
@property(nonatomic) double receiveToRenderSumMS;
@property(nonatomic) double receiveToRenderMinMS;
@property(nonatomic) double receiveToRenderMaxMS;
@property(nonatomic) double interarrivalSumMS;
@property(nonatomic) double interarrivalMinMS;
@property(nonatomic) double interarrivalMaxMS;
@property(nonatomic) uint64_t lastReceiveNanos;
@property(nonatomic) BOOL preflightOK;
@property(nonatomic) double preflightHandlingMS;
@property(nonatomic, strong) dispatch_semaphore_t inflightSemaphore;
@property(nonatomic, strong) NSMutableArray<NSString *> *decodeCallErrorLines;
@property(nonatomic, strong) NSMutableArray<NSString *> *decodeOutputErrorLines;
- (BOOL)runWithSocket:(int)fd;
- (void)handleDecodedImageBuffer:(CVImageBufferRef)imageBuffer status:(OSStatus)status infoFlags:(VTDecodeInfoFlags)infoFlags frameTiming:(NetworkFrameTimingRefCon *)frameTiming;
- (void)writeReport;
@end

@implementation NetworkReceiverCase

- (instancetype)init {
    self = [super init];
    if (self) {
        _sessionCreateStatus = INT32_MIN;
        _fallbackSessionCreateStatus = INT32_MIN;
        _inflightLimit = 3;
        _requireHardwareDecoder = YES;
        _receiveToRenderMinMS = DBL_MAX;
        _interarrivalMinMS = DBL_MAX;
        _decodeCallErrorLines = [NSMutableArray array];
        _decodeOutputErrorLines = [NSMutableArray array];
    }
    return self;
}

- (BOOL)createDecompressionSession {
    VTDecompressionOutputCallbackRecord callback = {
        .decompressionOutputCallback = networkOutputCallback,
        .decompressionOutputRefCon = (__bridge void *)self
    };

    NSDictionary *destinationAttributes = @{
        (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
        (__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{}
    };
    NSDictionary *requiredHardwareSpec = @{
        (__bridge NSString *)kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder: @YES
    };

    self.sessionCreateStatus = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                                            self.config.formatDescription,
                                                            self.requireHardwareDecoder ? (__bridge CFDictionaryRef)requiredHardwareSpec : NULL,
                                                            (__bridge CFDictionaryRef)destinationAttributes,
                                                            &callback,
                                                            &_decompressionSession);
    if (self.sessionCreateStatus == noErr && _decompressionSession) {
        self.sessionNote = self.requireHardwareDecoder ? @"created with required hardware decoder" : @"created without hardware requirement";
        return YES;
    }

    VTDecompressionSessionRef fallbackSession = NULL;
    self.fallbackSessionCreateStatus = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                                                    self.config.formatDescription,
                                                                    NULL,
                                                                    (__bridge CFDictionaryRef)destinationAttributes,
                                                                    &callback,
                                                                    &fallbackSession);
    if (fallbackSession) {
        VTDecompressionSessionInvalidate(fallbackSession);
        CFRelease(fallbackSession);
    }
    self.sessionNote = @"required hardware VideoToolbox session could not be created";
    return NO;
}

- (CMSampleBufferRef)copySampleBufferFromPayload:(NSData *)payload header:(MRKV011FrameHeader)header {
    CMBlockBufferRef block = NULL;
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                         NULL,
                                                         payload.length,
                                                         kCFAllocatorDefault,
                                                         NULL,
                                                         0,
                                                         payload.length,
                                                         0,
                                                         &block);
    if (status != noErr || !block) {
        return NULL;
    }
    status = CMBlockBufferReplaceDataBytes(payload.bytes, block, 0, payload.length);
    if (status != noErr) {
        CFRelease(block);
        return NULL;
    }

    CMSampleTimingInfo timing;
    timing.presentationTimeStamp = CMTimeMake(header.ptsValue, header.ptsTimescale > 0 ? header.ptsTimescale : 600);
    timing.presentationTimeStamp.flags = header.ptsFlags;
    timing.decodeTimeStamp = kCMTimeInvalid;
    timing.duration = CMTimeMake(header.durationValue, header.durationTimescale > 0 ? header.durationTimescale : 600);
    timing.duration.flags = header.durationFlags;

    size_t sampleSize = payload.length;
    CMSampleBufferRef sample = NULL;
    status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                       block,
                                       self.config.formatDescription,
                                       1,
                                       1,
                                       &timing,
                                       1,
                                       &sampleSize,
                                       &sample);
    CFRelease(block);
    if (status != noErr) {
        return NULL;
    }
    return sample;
}

- (BOOL)runWithSocket:(int)fd {
    NSString *preflightError = nil;
    double preflightHandlingMS = 0.0;
    if (!performReceiverPreflight(fd, &preflightHandlingMS, &preflightError)) {
        self.failure = preflightError ?: @"network preflight failed";
        [self writeReport];
        close(fd);
        return NO;
    }
    self.preflightOK = YES;
    self.preflightHandlingMS = preflightHandlingMS;

    NSString *configError = nil;
    self.config = readStreamConfig(fd, &configError);
    if (!self.config) {
        self.failure = configError ?: @"could not read stream config";
        [self writeReport];
        close(fd);
        return NO;
    }

    if (![self createDecompressionSession]) {
        [self writeReport];
        close(fd);
        return NO;
    }

    self.caseName = [NSString stringWithFormat:@"%@ %dx%d @ %.2f",
                     fourCC(self.config.codec),
                     self.config.dimensions.width,
                     self.config.dimensions.height,
                     self.config.nominalFPS];
    self.inflightSemaphore = dispatch_semaphore_create((long)MAX((NSUInteger)1, self.inflightLimit));
    self.receiverStartNanos = nowNanos();

    while (YES) {
        MRKV011FrameHeader wireHeader;
        ssize_t firstRead = read(fd, &wireHeader, sizeof(wireHeader));
        if (firstRead == 0) {
            break;
        }
        if (firstRead < 0) {
            if (errno == EINTR) {
                continue;
            }
            self.failure = [NSString stringWithFormat:@"receiver read failed: errno %d", errno];
            break;
        }
        if ((size_t)firstRead < sizeof(wireHeader) && !readFull(fd, ((uint8_t *)&wireHeader) + firstRead, sizeof(wireHeader) - (size_t)firstRead)) {
            self.failure = @"receiver could not read complete frame header";
            break;
        }
        MRKV011FrameHeader header = frameHeaderFromWire(wireHeader);
        if (header.magic != MRKV011FrameMagic || header.version != MRKV011Version || header.headerBytes != sizeof(MRKV011FrameHeader)) {
            self.failure = @"receiver saw invalid frame header";
            break;
        }
        if (header.payloadBytes == 0 || header.payloadBytes > 64ULL * 1024ULL * 1024ULL) {
            self.failure = [NSString stringWithFormat:@"receiver saw invalid payload length %llu", header.payloadBytes];
            break;
        }

        NSMutableData *payload = [NSMutableData dataWithLength:(NSUInteger)header.payloadBytes];
        if (!readFull(fd, payload.mutableBytes, payload.length)) {
            self.failure = @"receiver could not read payload";
            break;
        }
        uint64_t receiveCompleteNanos = nowNanos();
        if (self.lastReceiveNanos > 0) {
            double interarrivalMS = nanosToMS(receiveCompleteNanos - self.lastReceiveNanos);
            self.interarrivalSumMS += interarrivalMS;
            self.interarrivalMinMS = MIN(self.interarrivalMinMS, interarrivalMS);
            self.interarrivalMaxMS = MAX(self.interarrivalMaxMS, interarrivalMS);
        }
        self.lastReceiveNanos = receiveCompleteNanos;

        CMSampleBufferRef sample = [self copySampleBufferFromPayload:payload header:header];
        if (!sample) {
            self.failure = @"receiver could not rebuild sample buffer";
            break;
        }

        NetworkFrameTimingRefCon *timing = calloc(1, sizeof(NetworkFrameTimingRefCon));
        timing->sequence = header.sequence;
        timing->receiveCompleteNanos = receiveCompleteNanos;

        dispatch_semaphore_wait(self.inflightSemaphore, DISPATCH_TIME_FOREVER);
        self.framesReceived += 1;
        self.bytesReceived += payload.length + sizeof(header);
        self.submittedFrames += 1;

        VTDecodeInfoFlags infoFlags = 0;
        OSStatus status = VTDecompressionSessionDecodeFrame(_decompressionSession,
                                                            sample,
                                                            kVTDecodeFrame_EnableAsynchronousDecompression,
                                                            timing,
                                                            &infoFlags);
        CFRelease(sample);
        if (status != noErr) {
            self.decodeCallErrors += 1;
            if (self.decodeCallErrorLines.count < 12) {
                [self.decodeCallErrorLines addObject:[NSString stringWithFormat:@"decode call %lu returned %d",
                                                      (unsigned long)self.submittedFrames,
                                                      status]];
            }
            free(timing);
            dispatch_semaphore_signal(self.inflightSemaphore);
        }
    }

    close(fd);
    VTDecompressionSessionWaitForAsynchronousFrames(_decompressionSession);
    NSDate *waitDeadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
    while ([waitDeadline timeIntervalSinceNow] > 0) {
        if (self.decodedFrames + self.decodeOutputErrors + self.decodeCallErrors >= self.submittedFrames) {
            break;
        }
        [NSThread sleepForTimeInterval:0.01];
    }
    self.receiverWallSeconds = (double)(nowNanos() - self.receiverStartNanos) / 1000000000.0;

    if (_decompressionSession) {
        VTDecompressionSessionInvalidate(_decompressionSession);
        CFRelease(_decompressionSession);
        _decompressionSession = NULL;
    }

    [self writeReport];
    return self.failure == nil && self.decodeCallErrors == 0 && self.decodeOutputErrors == 0 && self.renderFailures == 0 && self.renderedFrames > 0;
}

- (void)handleDecodedImageBuffer:(CVImageBufferRef)imageBuffer status:(OSStatus)status infoFlags:(VTDecodeInfoFlags)infoFlags frameTiming:(NetworkFrameTimingRefCon *)frameTiming {
    uint64_t callbackNanos = nowNanos();
    if (status != noErr || !imageBuffer) {
        self.decodeOutputErrors += 1;
        if (self.decodeOutputErrorLines.count < 12) {
            [self.decodeOutputErrorLines addObject:[NSString stringWithFormat:@"output status %d at frame %llu",
                                                    status,
                                                    frameTiming ? frameTiming->sequence : 0]];
        }
        if (frameTiming) {
            free(frameTiming);
        }
        dispatch_semaphore_signal(self.inflightSemaphore);
        return;
    }

    if (infoFlags & kVTDecodeInfo_FrameDropped) {
        self.droppedFrameFlags += 1;
    }

    CVPixelBufferRetain(imageBuffer);
    __block BOOL rendered = NO;
    if ([NSThread isMainThread]) {
        rendered = [self.presenter renderPixelBuffer:imageBuffer];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            rendered = [self.presenter renderPixelBuffer:imageBuffer];
        });
    }
    uint64_t renderDoneNanos = nowNanos();

    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer);
    CVPixelBufferRelease(imageBuffer);

    self.decodedFrames += 1;
    self.firstOutputWallSeconds = self.firstOutputWallSeconds > 0.0 ? self.firstOutputWallSeconds : (double)(callbackNanos - self.receiverStartNanos) / 1000000000.0;
    self.lastOutputWallSeconds = (double)(callbackNanos - self.receiverStartNanos) / 1000000000.0;
    if (self.firstDecodedWidth == 0) {
        self.firstDecodedWidth = width;
        self.firstDecodedHeight = height;
        self.firstDecodedPixelFormat = pixelFormat;
    }
    if (rendered) {
        self.renderedFrames += 1;
        if (frameTiming) {
            double receiveToRenderMS = nanosToMS(renderDoneNanos - frameTiming->receiveCompleteNanos);
            self.receiveToRenderSumMS += receiveToRenderMS;
            self.receiveToRenderMinMS = MIN(self.receiveToRenderMinMS, receiveToRenderMS);
            self.receiveToRenderMaxMS = MAX(self.receiveToRenderMaxMS, receiveToRenderMS);
        }
    } else {
        self.renderFailures += 1;
    }

    if (frameTiming) {
        free(frameTiming);
    }
    dispatch_semaphore_signal(self.inflightSemaphore);
}

- (void)writeReport {
    createOutputDirectory(self.outputPath);
    double renderedFPS = self.receiverWallSeconds > 0.0 ? (double)self.renderedFrames / self.receiverWallSeconds : 0.0;
    double nominalFPS = self.config.nominalFPS > 0.0 ? self.config.nominalFPS : 60.0;
    double bitrateMbps = self.receiverWallSeconds > 0.0 ? ((double)self.bytesReceived * 8.0 / self.receiverWallSeconds / 1000000.0) : 0.0;
    double averageRenderMS = self.presenter.renderedFrames > 0 ? (self.presenter.totalRenderSeconds * 1000.0 / (double)self.presenter.renderedFrames) : 0.0;
    double averageReceiveToRenderMS = self.renderedFrames > 0 ? self.receiveToRenderSumMS / (double)self.renderedFrames : 0.0;
    double minReceiveToRenderMS = self.receiveToRenderMinMS == DBL_MAX ? 0.0 : self.receiveToRenderMinMS;
    double averageInterarrivalMS = self.framesReceived > 1 ? self.interarrivalSumMS / (double)(self.framesReceived - 1) : 0.0;
    double minInterarrivalMS = self.interarrivalMinMS == DBL_MAX ? 0.0 : self.interarrivalMinMS;

    NSMutableString *report = [NSMutableString string];
    [report appendFormat:@"# Experiment 017 Receiver Result: Case %lu\n\n", (unsigned long)self.caseIndex];
    [report appendString:@"## Machine\n\n"];
    NSProcessInfo *processInfo = NSProcessInfo.processInfo;
    [report appendFormat:@"- Host name: %@\n", processInfo.hostName];
    [report appendFormat:@"- macOS: %@\n", processInfo.operatingSystemVersionString];
    [report appendFormat:@"- Hardware model: %@\n", sysctlString("hw.model")];
    [report appendFormat:@"- CPU brand: %@\n", sysctlString("machdep.cpu.brand_string")];

    [report appendString:@"\n## Stream Config\n\n"];
    [report appendFormat:@"- Codec FourCC: `%@`\n", self.config.codec ? fourCC(self.config.codec) : @"unavailable"];
    [report appendFormat:@"- Format dimensions: %d x %d\n", self.config.dimensions.width, self.config.dimensions.height];
    [report appendFormat:@"- Nominal FPS: %.2f\n", nominalFPS];
    [report appendFormat:@"- NAL unit header length: %d\n", self.config.nalUnitHeaderLength];
    [report appendFormat:@"- Serialized parameter sets: %lu\n", (unsigned long)self.config.parameterSetCount];
    [report appendFormat:@"- Serialized parameter-set bytes: %llu\n", self.config.parameterSetBytes];

    [report appendString:@"\n## Decoder Setup\n\n"];
    [report appendFormat:@"- Required hardware decoder: %@\n", yesNo(self.requireHardwareDecoder)];
    [report appendFormat:@"- Hardware-required session create status: %d (%@)\n",
     self.sessionCreateStatus,
     vtStatusName(self.sessionCreateStatus)];
    if (self.fallbackSessionCreateStatus != INT32_MIN) {
        [report appendFormat:@"- Fallback session create status without hardware requirement: %d (%@)\n",
         self.fallbackSessionCreateStatus,
         vtStatusName(self.fallbackSessionCreateStatus)];
    }
    [report appendFormat:@"- Session note: %@\n", self.sessionNote ?: @"unavailable"];
    if (self.failure) {
        [report appendFormat:@"- Failure: %@\n", self.failure];
    }

    [report appendString:@"\n## Network Preflight\n\n"];
    [report appendFormat:@"- Preflight handshake: %@\n", self.preflightOK ? @"passed before stream config and receiver timing" : @"not completed"];
    [report appendFormat:@"- Preflight handling time: %.3f ms\n", self.preflightHandlingMS];

    [report appendString:@"\n## Render Target\n\n"];
    [report appendString:@"- Renderer: Metal CAMetalLayer with Core Image CVPixelBuffer render\n"];
    [report appendFormat:@"- Window backing scale: %.2f\n", self.presenter.backingScaleFactor];
    [report appendFormat:@"- Drawable size: %.0f x %.0f\n", self.presenter.drawableSize.width, self.presenter.drawableSize.height];

    [report appendString:@"\n## Receiver Result\n\n"];
    [report appendFormat:@"- Frames received: %lu\n", (unsigned long)self.framesReceived];
    [report appendFormat:@"- Bytes received: %llu\n", self.bytesReceived];
    [report appendFormat:@"- Measured receiver bitrate: %.2f Mbps\n", bitrateMbps];
    [report appendFormat:@"- Submitted frames: %lu\n", (unsigned long)self.submittedFrames];
    [report appendFormat:@"- Decode call errors: %lu\n", (unsigned long)self.decodeCallErrors];
    [report appendFormat:@"- Decode output callbacks: %lu\n", (unsigned long)self.decodedFrames];
    [report appendFormat:@"- Decode output errors: %lu\n", (unsigned long)self.decodeOutputErrors];
    [report appendFormat:@"- VideoToolbox dropped-frame flags: %lu\n", (unsigned long)self.droppedFrameFlags];
    [report appendFormat:@"- Rendered frames: %lu\n", (unsigned long)self.renderedFrames];
    [report appendFormat:@"- Render failures: %lu\n", (unsigned long)self.renderFailures];
    [report appendFormat:@"- First decoded frame: %lu x %lu `%@`\n",
     (unsigned long)self.firstDecodedWidth,
     (unsigned long)self.firstDecodedHeight,
     self.firstDecodedPixelFormat ? fourCC(self.firstDecodedPixelFormat) : @"unavailable"];
    [report appendFormat:@"- Receiver wall time: %.3f seconds\n", self.receiverWallSeconds];
    [report appendFormat:@"- Throughput: %.2f rendered FPS\n", renderedFPS];
    [report appendFormat:@"- Realtime multiple vs %.2f FPS input: %.2fx\n", nominalFPS, nominalFPS > 0.0 ? renderedFPS / nominalFPS : 0.0];
    [report appendFormat:@"- Average synchronous render time: %.3f ms\n", averageRenderMS];
    [report appendFormat:@"- First output callback wall time: %.3f seconds\n", self.firstOutputWallSeconds];
    [report appendFormat:@"- Last output callback wall time: %.3f seconds\n", self.lastOutputWallSeconds];

    [report appendString:@"\n## Receiver Latency Proxy\n\n"];
    [report appendString:@"Sender and receiver clocks are not synchronized in the two-Mac case, so this report does not claim one-way sender-to-render latency. It reports receiver-side payload-complete to rendered-frame latency and frame interarrival timing.\n\n"];
    [report appendFormat:@"- Average receive-complete-to-render latency: %.3f ms\n", averageReceiveToRenderMS];
    [report appendFormat:@"- Min receive-complete-to-render latency: %.3f ms\n", minReceiveToRenderMS];
    [report appendFormat:@"- Max receive-complete-to-render latency: %.3f ms\n", self.receiveToRenderMaxMS];
    [report appendFormat:@"- Average frame interarrival: %.3f ms\n", averageInterarrivalMS];
    [report appendFormat:@"- Min frame interarrival: %.3f ms\n", minInterarrivalMS];
    [report appendFormat:@"- Max frame interarrival: %.3f ms\n", self.interarrivalMaxMS];

    if (self.decodeCallErrorLines.count > 0) {
        [report appendString:@"\n## Decode Call Errors\n\n"];
        for (NSString *line in self.decodeCallErrorLines) {
            [report appendFormat:@"- %@\n", line];
        }
    }
    if (self.decodeOutputErrorLines.count > 0) {
        [report appendString:@"\n## Decode Output Errors\n\n"];
        for (NSString *line in self.decodeOutputErrorLines) {
            [report appendFormat:@"- %@\n", line];
        }
    }

    [report appendString:@"\n## Interpretation\n\n"];
    if (self.sessionCreateStatus != noErr || self.failure) {
        [report appendString:@"The network receiver path did not complete cleanly for this stream.\n"];
    } else if (self.renderedFrames == self.framesReceived && renderedFPS >= nominalFPS * 0.95 && self.decodeCallErrors == 0 && self.decodeOutputErrors == 0 && self.renderFailures == 0) {
        [report appendString:@"The network receiver path stayed inside the current pass band for this stream.\n"];
    } else {
        [report appendString:@"The network receiver path completed but did not stay inside the current pass band. Inspect pacing, dropped frames, and receive-to-render latency.\n"];
    }

    NSError *error = nil;
    if (![report writeToFile:self.outputPath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        fprintf(stderr, "Could not write receiver report: %s\n", error.localizedDescription.UTF8String);
    } else {
        printf("Wrote receiver report: %s\n", self.outputPath.UTF8String);
    }
}

@end

static void networkOutputCallback(void *decompressionOutputRefCon,
                                  void *sourceFrameRefCon,
                                  OSStatus status,
                                  VTDecodeInfoFlags infoFlags,
                                  CVImageBufferRef imageBuffer,
                                  CMTime presentationTimeStamp,
                                  CMTime presentationDuration) {
    NetworkReceiverCase *receiverCase = (__bridge NetworkReceiverCase *)decompressionOutputRefCon;
    [receiverCase handleDecodedImageBuffer:imageBuffer
                                    status:status
                                 infoFlags:infoFlags
                               frameTiming:(NetworkFrameTimingRefCon *)sourceFrameRefCon];
}

static NSString *slugForCodec(OSType codec, CMVideoDimensions dimensions) {
    NSString *codecSlug = codec == kCMVideoCodecType_H264 ? @"h264" : (codec == kCMVideoCodecType_HEVC ? @"hevc" : [fourCC(codec) lowercaseString]);
    return [NSString stringWithFormat:@"%@-%dx%d-60", codecSlug, dimensions.width, dimensions.height];
}

static void writeReceiverSummary(NSString *outputDir, NSArray<NSString *> *caseFiles) {
    NSMutableString *summary = [NSMutableString string];
    [summary appendString:@"# Experiment 017 Result: Live HEVC Native Interval Receiver Summary\n\n"];
    [summary appendString:@"| Case | Hardware session | Received | Rendered | Throughput | Receiver bitrate | Avg receive->render | Result file |\n"];
    [summary appendString:@"| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |\n"];
    for (NSString *path in caseFiles) {
        NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] ?: @"";
        NSString *(^extract)(NSString *) = ^NSString *(NSString *label) {
            NSRange range = [contents rangeOfString:[NSString stringWithFormat:@"- %@: ", label]];
            if (range.location == NSNotFound) {
                return @"unavailable";
            }
            NSUInteger start = range.location + range.length;
            NSRange rest = NSMakeRange(start, contents.length - start);
            NSRange newline = [contents rangeOfString:@"\n" options:0 range:rest];
            NSUInteger end = newline.location == NSNotFound ? contents.length : newline.location;
            return [contents substringWithRange:NSMakeRange(start, end - start)];
        };
        NSString *caseName = [[path lastPathComponent] stringByDeletingPathExtension];
        [summary appendFormat:@"| %@ | %@ | %@ | %@ | %@ | %@ | %@ | `%@` |\n",
         caseName,
         extract(@"Hardware-required session create status"),
         extract(@"Frames received"),
         extract(@"Rendered frames"),
         extract(@"Throughput"),
         extract(@"Measured receiver bitrate"),
         extract(@"Average receive-complete-to-render latency"),
         path.lastPathComponent];
    }
    NSString *summaryPath = [outputDir stringByAppendingPathComponent:@"receiver-summary.md"];
    createOutputDirectory(summaryPath);
    [summary writeToFile:summaryPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    printf("Wrote receiver summary: %s\n", summaryPath.UTF8String);
}

static int runReceiverMode(int argc, const char *argv[]) {
    uint16_t port = (uint16_t)integerArgument(argc, argv, "port", 49324);
    NSUInteger cases = integerArgument(argc, argv, "cases", 1);
    NSUInteger inflight = integerArgument(argc, argv, "inflight", 3);
    BOOL fullscreen = boolArgument(argc, argv, "fullscreen", YES);
    BOOL requireHardware = boolArgument(argc, argv, "require-hardware", YES);
    NSString *outputDir = stringArgument(argc, argv, "output-dir", @"results");

    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    MetalPresenter *presenter = [[MetalPresenter alloc] initFullscreen:fullscreen
                                                                  title:@"MacRemoteKVM Experiment 017 Receiver"
                                                          expectedWidth:5120
                                                         expectedHeight:2880];
    if (!presenter) {
        fprintf(stderr, "Could not create Metal presenter.\n");
        return 1;
    }

    int listener = createNetworkListener(port);
    if (listener < 0) {
        fprintf(stderr, "Could not listen on port %u: errno %d\n", port, errno);
        [presenter close];
        return 1;
    }
    printf("Receiver listening on port %u for %lu stream(s).\n", port, (unsigned long)cases);

    NSMutableArray<NSString *> *caseFiles = [NSMutableArray array];
    BOOL allOK = YES;
    for (NSUInteger caseIndex = 1; caseIndex <= cases; caseIndex++) {
        printf("Waiting for stream %lu of %lu...\n", (unsigned long)caseIndex, (unsigned long)cases);
        int accepted = accept(listener, NULL, NULL);
        if (accepted < 0) {
            fprintf(stderr, "Accept failed: errno %d\n", errno);
            allOK = NO;
            break;
        }
        int yes = 1;
        setsockopt(accepted, IPPROTO_TCP, TCP_NODELAY, &yes, sizeof(yes));

        NetworkReceiverCase *receiverCase = [[NetworkReceiverCase alloc] init];
        receiverCase.presenter = presenter;
        receiverCase.caseIndex = caseIndex;
        receiverCase.inflightLimit = MAX((NSUInteger)1, inflight);
        receiverCase.requireHardwareDecoder = requireHardware;
        NSString *provisionalOutput = [outputDir stringByAppendingPathComponent:[NSString stringWithFormat:@"receiver-case-%lu.md", (unsigned long)caseIndex]];
        receiverCase.outputPath = provisionalOutput;
        __block BOOL done = NO;
        __block BOOL ok = NO;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            @autoreleasepool {
                ok = [receiverCase runWithSocket:accepted];
            }
            done = YES;
        });
        while (!done) {
            @autoreleasepool {
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                         beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
            }
        }

        if (receiverCase.config) {
            NSString *slug = slugForCodec(receiverCase.config.codec, receiverCase.config.dimensions);
            NSString *finalOutput = [outputDir stringByAppendingPathComponent:[NSString stringWithFormat:@"receiver-%@.md", slug]];
            if (![finalOutput isEqualToString:provisionalOutput]) {
                [[NSFileManager defaultManager] removeItemAtPath:finalOutput error:nil];
                [[NSFileManager defaultManager] moveItemAtPath:provisionalOutput toPath:finalOutput error:nil];
                receiverCase.outputPath = finalOutput;
            }
        }
        [caseFiles addObject:receiverCase.outputPath];
        allOK = allOK && ok;
    }

    close(listener);
    [presenter close];
    writeReceiverSummary(outputDir, caseFiles);
    return allOK ? 0 : 2;
}


static int runOneLiveSenderCase(NSString *host,
                                uint16_t port,
                                NSString *caseName,
                                NSString *codecName,
                                OSType codec,
                                NSUInteger width,
                                NSUInteger height,
                                NSUInteger bitrateMbps,
                                NSString *outputPath,
                                NSTimeInterval duration) {
    LiveCaptureSenderCase *sender = [[LiveCaptureSenderCase alloc] init];
    sender.host = host;
    sender.port = port;
    sender.caseName = caseName;
    sender.codecDisplayName = codecName;
    sender.codec = codec;
    sender.width = width;
    sender.height = height;
    sender.bitrateMbps = bitrateMbps;
    sender.outputPath = outputPath;
    sender.requestedDurationSeconds = duration;
    return [sender run] ? 0 : 2;
}

static int runLiveSenderMode(int argc, const char *argv[]) {
    NSString *host = stringArgument(argc, argv, "host", nil);
    if (host.length == 0) {
        host = positionalArgument(argc, argv, 1, @"");
    }
    if (host.length == 0) {
        fprintf(stderr, "Live sender mode needs a receiver host/IP. Example: ./test.sh sender 192.168.1.25\n");
        return 1;
    }

    uint16_t port = (uint16_t)integerArgument(argc, argv, "port", 49324);
    NSTimeInterval duration = doubleArgumentLocal(argc, argv, "duration", 30.0);
    NSString *outputDir = stringArgument(argc, argv, "output-dir", @"results");
    NSUInteger hevcBitrate = integerArgument(argc, argv, "hevc-bitrate-mbps", 24);

    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    return runOneLiveSenderCase(host,
                                port,
                                @"HEVC 3200x1800 native-interval live capture (60 Hz display)",
                                @"HEVC/H.265",
                                kCMVideoCodecType_HEVC,
                                3200,
                                1800,
                                hevcBitrate,
                                [outputDir stringByAppendingPathComponent:@"sender-live-hevc-3200x1800-60.md"],
                                duration);
}

int main(int argc, const char *argv[]) {
    setvbuf(stdout, NULL, _IOLBF, 0);
    @autoreleasepool {
        NSString *mode = [modeArgument(argc, argv, @"usage") lowercaseString];
        if ([mode isEqualToString:@"receiver"] || [mode isEqualToString:@"receive"]) {
            return runReceiverMode(argc, argv);
        }
        if ([mode isEqualToString:@"sender"] || [mode isEqualToString:@"send"]) {
            return runLiveSenderMode(argc, argv);
        }
        fprintf(stderr, "Usage:\n");
        fprintf(stderr, "  ./test.sh receiver\n");
        fprintf(stderr, "  ./test.sh sender <receiver-host-or-ip>\n");
        fprintf(stderr, "\n");
        fprintf(stderr, "Optional env vars handled by test.sh: MACRKVM_PORT, MACRKVM_TRANSPORT_SECONDS, MACRKVM_FULLSCREEN, MACRKVM_HEVC_BITRATE_MBPS.\n");
        return 1;
    }
}
