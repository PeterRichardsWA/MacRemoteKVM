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

#ifndef DEFAULT_INPUT_PATH
#define DEFAULT_INPUT_PATH "media/h264-5k60-high-3s.mp4"
#endif

#ifndef DEFAULT_OUTPUT_PATH
#define DEFAULT_OUTPUT_PATH "../../results/006-receiver-decode-render/h264-decode-render-result.md"
#endif

#ifndef DEFAULT_REPORT_TITLE
#define DEFAULT_REPORT_TITLE "Experiment 006 Result: H.264 Receiver Decode/Render Baseline"
#endif

#ifndef DEFAULT_CODEC_NAME
#define DEFAULT_CODEC_NAME "H.264"
#endif

#ifndef DEFAULT_WINDOW_TITLE
#define DEFAULT_WINDOW_TITLE "MacRemoteKVM Experiment 006"
#endif

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

@class DecodeRenderBenchmark;
static void decompressionOutputCallback(void *decompressionOutputRefCon,
                                        void *sourceFrameRefCon,
                                        OSStatus status,
                                        VTDecodeInfoFlags infoFlags,
                                        CVImageBufferRef imageBuffer,
                                        CMTime presentationTimeStamp,
                                        CMTime presentationDuration);

@interface DecodeRenderBenchmark : NSObject {
    VTDecompressionSessionRef _decompressionSession;
}
@property(nonatomic, strong) MetalPresenter *presenter;
@property(nonatomic, strong) NSURL *inputURL;
@property(nonatomic, strong) NSString *outputPath;
@property(nonatomic, strong) NSString *reportTitle;
@property(nonatomic, strong) NSString *codecDisplayName;
@property(nonatomic) NSUInteger inflightLimit;
@property(nonatomic) BOOL requireHardwareDecoder;
@property(nonatomic) NSUInteger sampleCount;
@property(nonatomic) NSUInteger compressedFrameSamples;
@property(nonatomic) NSUInteger skippedEmptySampleBuffers;
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
@property(nonatomic) NSTimeInterval decodeRenderSeconds;
@property(nonatomic) NSTimeInterval firstOutputWallSeconds;
@property(nonatomic) NSTimeInterval lastOutputWallSeconds;
@property(nonatomic) OSStatus sessionCreateStatus;
@property(nonatomic) OSStatus fallbackSessionCreateStatus;
@property(nonatomic, strong) NSDate *benchmarkStartDate;
@property(nonatomic, strong) NSString *setupFailure;
@property(nonatomic, strong) NSString *readerFailure;
@property(nonatomic, strong) NSString *sessionNote;
@property(nonatomic, strong) NSMutableArray<NSString *> *decodeCallErrorLines;
@property(nonatomic, strong) NSMutableArray<NSString *> *decodeOutputErrorLines;
@property(nonatomic) CMVideoDimensions formatDimensions;
@property(nonatomic) OSType formatCodec;
@property(nonatomic) Float64 assetDurationSeconds;
@property(nonatomic) Float32 assetNominalFPS;
@property(nonatomic) float assetEstimatedDataRate;
@property(nonatomic) unsigned long long inputFileBytes;
@property(nonatomic, strong) dispatch_semaphore_t inflightSemaphore;
- (BOOL)run;
- (void)handleDecodedImageBuffer:(CVImageBufferRef)imageBuffer status:(OSStatus)status infoFlags:(VTDecodeInfoFlags)infoFlags presentationTimeStamp:(CMTime)pts;
@end

@implementation DecodeRenderBenchmark

- (instancetype)init {
    self = [super init];
    if (self) {
        _decodeCallErrorLines = [NSMutableArray array];
        _decodeOutputErrorLines = [NSMutableArray array];
        _sessionCreateStatus = INT32_MIN;
        _fallbackSessionCreateStatus = INT32_MIN;
        _firstDecodedPixelFormat = 0;
        _requireHardwareDecoder = YES;
        _inflightLimit = 3;
        _reportTitle = @"Experiment 006 Result: H.264 Receiver Decode/Render Baseline";
        _codecDisplayName = @"H.264";
    }
    return self;
}

- (NSArray *)loadCompressedSamplesWithFormatDescription:(CMFormatDescriptionRef *)formatDescriptionOut {
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:self.inputURL.path error:nil];
    self.inputFileBytes = attributes.fileSize;

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:self.inputURL options:@{AVURLAssetPreferPreciseDurationAndTimingKey: @YES}];
    NSArray<AVAssetTrack *> *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *track = tracks.firstObject;
    if (!track) {
        self.readerFailure = @"input asset has no video track";
        return @[];
    }

    self.assetDurationSeconds = CMTimeGetSeconds(asset.duration);
    self.assetNominalFPS = track.nominalFrameRate;
    self.assetEstimatedDataRate = track.estimatedDataRate;

    NSError *readerError = nil;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&readerError];
    if (!reader || readerError) {
        self.readerFailure = [NSString stringWithFormat:@"could not create AVAssetReader: %@", readerError.localizedDescription ?: @"unknown"];
        return @[];
    }

    AVAssetReaderTrackOutput *output = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:nil];
    output.alwaysCopiesSampleData = NO;
    if (![reader canAddOutput:output]) {
        self.readerFailure = @"could not add compressed track output";
        return @[];
    }
    [reader addOutput:output];

    if (![reader startReading]) {
        self.readerFailure = [NSString stringWithFormat:@"AVAssetReader failed to start: %@", reader.error.localizedDescription ?: @"unknown"];
        return @[];
    }

    NSMutableArray *samples = [NSMutableArray array];
    CMSampleBufferRef sample = NULL;
    while ((sample = [output copyNextSampleBuffer])) {
        self.compressedFrameSamples += CMSampleBufferGetNumSamples(sample);
        if (!*formatDescriptionOut) {
            CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sample);
            if (formatDescription) {
                CFRetain(formatDescription);
                *formatDescriptionOut = formatDescription;
                self.formatCodec = CMFormatDescriptionGetMediaSubType(formatDescription);
                self.formatDimensions = CMVideoFormatDescriptionGetDimensions(formatDescription);
            }
        }
        [samples addObject:CFBridgingRelease(sample)];
    }

    if (reader.status != AVAssetReaderStatusCompleted) {
        self.readerFailure = [NSString stringWithFormat:@"AVAssetReader ended with status %ld: %@",
                              (long)reader.status,
                              reader.error.localizedDescription ?: @"none"];
    }

    self.sampleCount = samples.count;
    return samples;
}

- (BOOL)createDecompressionSessionWithFormatDescription:(CMFormatDescriptionRef)formatDescription {
    VTDecompressionOutputCallbackRecord callback = {
        .decompressionOutputCallback = decompressionOutputCallback,
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
                                                            formatDescription,
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
                                                                    formatDescription,
                                                                    NULL,
                                                                    (__bridge CFDictionaryRef)destinationAttributes,
                                                                    &callback,
                                                                    &fallbackSession);
    if (fallbackSession) {
        VTDecompressionSessionInvalidate(fallbackSession);
        CFRelease(fallbackSession);
    }
    self.sessionNote = @"hardware-required VideoToolbox session could not be created";
    return NO;
}

- (BOOL)run {
    CMFormatDescriptionRef formatDescription = NULL;
    NSArray *samples = [self loadCompressedSamplesWithFormatDescription:&formatDescription];
    if (self.readerFailure || samples.count == 0 || !formatDescription) {
        if (!self.readerFailure) {
            self.readerFailure = @"no compressed samples were read";
        }
        [self writeReport];
        if (formatDescription) {
            CFRelease(formatDescription);
        }
        return NO;
    }

    BOOL sessionCreated = [self createDecompressionSessionWithFormatDescription:formatDescription];
    CFRelease(formatDescription);
    if (!sessionCreated) {
        [self writeReport];
        return NO;
    }

    self.inflightSemaphore = dispatch_semaphore_create((long)MAX((NSUInteger)1, self.inflightLimit));
    self.benchmarkStartDate = [NSDate date];

    for (id sampleObject in samples) {
        CMSampleBufferRef sample = (__bridge CMSampleBufferRef)sampleObject;
        if (CMSampleBufferGetNumSamples(sample) == 0) {
            @synchronized (self) {
                self.skippedEmptySampleBuffers += 1;
            }
            continue;
        }

        dispatch_semaphore_wait(self.inflightSemaphore, DISPATCH_TIME_FOREVER);

        @synchronized (self) {
            self.submittedFrames += 1;
        }

        VTDecodeFrameFlags flags = kVTDecodeFrame_EnableAsynchronousDecompression;
        VTDecodeInfoFlags infoFlags = 0;
        OSStatus status = VTDecompressionSessionDecodeFrame(_decompressionSession,
                                                            sample,
                                                            flags,
                                                            NULL,
                                                            &infoFlags);
        if (status != noErr) {
            @synchronized (self) {
                self.decodeCallErrors += 1;
                if (self.decodeCallErrorLines.count < 12) {
                    [self.decodeCallErrorLines addObject:[NSString stringWithFormat:@"decode call %lu returned %d",
                                                          (unsigned long)self.submittedFrames,
                                                          status]];
                }
            }
            dispatch_semaphore_signal(self.inflightSemaphore);
        }
    }

    VTDecompressionSessionWaitForAsynchronousFrames(_decompressionSession);

    NSDate *waitDeadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
    while ([waitDeadline timeIntervalSinceNow] > 0) {
        @synchronized (self) {
            if (self.decodedFrames + self.decodeOutputErrors + self.decodeCallErrors >= self.submittedFrames) {
                break;
            }
        }
        [NSThread sleepForTimeInterval:0.01];
    }

    self.decodeRenderSeconds = -[self.benchmarkStartDate timeIntervalSinceNow];

    if (_decompressionSession) {
        VTDecompressionSessionInvalidate(_decompressionSession);
        CFRelease(_decompressionSession);
        _decompressionSession = NULL;
    }

    [self writeReport];
    return self.decodeCallErrors == 0 && self.decodeOutputErrors == 0 && self.renderFailures == 0 && self.renderedFrames > 0;
}

- (void)handleDecodedImageBuffer:(CVImageBufferRef)imageBuffer status:(OSStatus)status infoFlags:(VTDecodeInfoFlags)infoFlags presentationTimeStamp:(CMTime)pts {
    NSTimeInterval wallSeconds = -[self.benchmarkStartDate timeIntervalSinceNow];
    if (status != noErr || !imageBuffer) {
        @synchronized (self) {
            self.decodeOutputErrors += 1;
            if (self.decodeOutputErrorLines.count < 12) {
                [self.decodeOutputErrorLines addObject:[NSString stringWithFormat:@"output status %d at pts %@", status, cmTimeString(pts)]];
            }
        }
        dispatch_semaphore_signal(self.inflightSemaphore);
        return;
    }

    if (infoFlags & kVTDecodeInfo_FrameDropped) {
        @synchronized (self) {
            self.droppedFrameFlags += 1;
        }
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

    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer);
    CVPixelBufferRelease(imageBuffer);

    @synchronized (self) {
        self.decodedFrames += 1;
        self.firstOutputWallSeconds = self.firstOutputWallSeconds > 0.0 ? self.firstOutputWallSeconds : wallSeconds;
        self.lastOutputWallSeconds = wallSeconds;
        if (self.firstDecodedWidth == 0) {
            self.firstDecodedWidth = width;
            self.firstDecodedHeight = height;
            self.firstDecodedPixelFormat = pixelFormat;
        }
        if (rendered) {
            self.renderedFrames += 1;
        } else {
            self.renderFailures += 1;
        }
    }

    dispatch_semaphore_signal(self.inflightSemaphore);
}

- (void)writeReport {
    createOutputDirectory(self.outputPath);

    double throughputFPS = self.decodeRenderSeconds > 0.0 ? (double)self.renderedFrames / self.decodeRenderSeconds : 0.0;
    double nominalFPS = self.assetNominalFPS > 0.0 ? self.assetNominalFPS : 60.0;
    double realtimeMultiple = nominalFPS > 0.0 ? throughputFPS / nominalFPS : 0.0;
    double fileMB = (double)self.inputFileBytes / 1024.0 / 1024.0;
    double bitrateMbps = self.assetEstimatedDataRate > 0.0 ? (double)self.assetEstimatedDataRate / 1000000.0 : 0.0;
    double averageRenderMS = self.presenter.renderedFrames > 0 ? (self.presenter.totalRenderSeconds * 1000.0 / (double)self.presenter.renderedFrames) : 0.0;
    NSString *codecName = self.codecDisplayName ?: @"codec";

    NSMutableString *report = [NSMutableString string];
    [report appendFormat:@"# %@\n\n", self.reportTitle ?: @"Receiver Decode/Render Result"];

    [report appendString:@"## Machine\n\n"];
    NSProcessInfo *processInfo = NSProcessInfo.processInfo;
    [report appendFormat:@"- Host name: %@\n", processInfo.hostName];
    [report appendFormat:@"- macOS: %@\n", processInfo.operatingSystemVersionString];
    [report appendFormat:@"- Hardware model: %@\n", sysctlString("hw.model")];
    [report appendFormat:@"- CPU brand: %@\n", sysctlString("machdep.cpu.brand_string")];
    [report appendFormat:@"- Processor count: %lu\n", (unsigned long)processInfo.processorCount];
    [report appendFormat:@"- Physical memory: %.2f GB\n", (double)processInfo.physicalMemory / 1024.0 / 1024.0 / 1024.0];

    [report appendString:@"\n## Input Stream\n\n"];
    [report appendFormat:@"- Path: `%@`\n", self.inputURL.path];
    [report appendFormat:@"- File size: %.2f MB\n", fileMB];
    [report appendFormat:@"- Codec FourCC: `%@`\n", self.formatCodec ? fourCC(self.formatCodec) : @"unavailable"];
    [report appendFormat:@"- Format dimensions: %d x %d\n", self.formatDimensions.width, self.formatDimensions.height];
    [report appendFormat:@"- Duration: %.3f seconds\n", self.assetDurationSeconds];
    [report appendFormat:@"- Nominal FPS: %.2f\n", self.assetNominalFPS];
    [report appendFormat:@"- Estimated bitrate: %.2f Mbps\n", bitrateMbps];
    [report appendFormat:@"- Compressed sample buffers read: %lu\n", (unsigned long)self.sampleCount];
    [report appendFormat:@"- Compressed frame samples read: %lu\n", (unsigned long)self.compressedFrameSamples];
    [report appendFormat:@"- Empty sample buffers skipped before decode: %lu\n", (unsigned long)self.skippedEmptySampleBuffers];

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
    if (self.readerFailure) {
        [report appendFormat:@"- Reader failure: %@\n", self.readerFailure];
    }
    if (self.setupFailure) {
        [report appendFormat:@"- Setup failure: %@\n", self.setupFailure];
    }

    [report appendString:@"\n## Render Target\n\n"];
    [report appendString:@"- Renderer: Metal CAMetalLayer with Core Image CVPixelBuffer render\n"];
    [report appendFormat:@"- Window backing scale: %.2f\n", self.presenter.backingScaleFactor];
    [report appendFormat:@"- Drawable size: %.0f x %.0f\n", self.presenter.drawableSize.width, self.presenter.drawableSize.height];

    [report appendString:@"\n## Decode/Render Result\n\n"];
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
    [report appendFormat:@"- Decode/render wall time: %.3f seconds\n", self.decodeRenderSeconds];
    [report appendFormat:@"- Throughput: %.2f rendered FPS\n", throughputFPS];
    [report appendFormat:@"- Realtime multiple vs %.2f FPS input: %.2fx\n", nominalFPS, realtimeMultiple];
    [report appendFormat:@"- Average synchronous render time: %.3f ms\n", averageRenderMS];
    [report appendFormat:@"- First output callback wall time: %.3f seconds\n", self.firstOutputWallSeconds];
    [report appendFormat:@"- Last output callback wall time: %.3f seconds\n", self.lastOutputWallSeconds];

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
    if (self.sessionCreateStatus != noErr) {
        [report appendFormat:@"The required hardware %@ decoder session could not be created for this 5K stream. %@ should not be treated as viable for the first 5K transport path until this is explained or a different stream shape is tested.\n",
         codecName,
         codecName];
    } else if (throughputFPS >= 60.0 && self.renderFailures == 0 && self.decodeOutputErrors == 0 && self.decodeCallErrors == 0) {
        [report appendFormat:@"This machine sustained at least 60 rendered FPS for the local 5K %@ decode/render path. %@ remains viable for the first receiver transport prototype.\n",
         codecName,
         codecName];
    } else {
        [report appendFormat:@"This machine did not sustain 60 rendered FPS in this local 5K %@ decode/render probe. Compare against other candidate codecs before choosing the first transport codec.\n",
         codecName];
    }

    NSError *writeError = nil;
    BOOL wrote = [report writeToFile:self.outputPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
    if (!wrote) {
        fprintf(stderr, "Could not write report: %s\n", writeError.localizedDescription.UTF8String);
    } else {
        printf("Wrote report: %s\n", self.outputPath.UTF8String);
    }
}

@end

static void decompressionOutputCallback(void *decompressionOutputRefCon,
                                        void *sourceFrameRefCon,
                                        OSStatus status,
                                        VTDecodeInfoFlags infoFlags,
                                        CVImageBufferRef imageBuffer,
                                        CMTime presentationTimeStamp,
                                        CMTime presentationDuration) {
    DecodeRenderBenchmark *benchmark = (__bridge DecodeRenderBenchmark *)decompressionOutputRefCon;
    [benchmark handleDecodedImageBuffer:imageBuffer
                                 status:status
                              infoFlags:infoFlags
                  presentationTimeStamp:presentationTimeStamp];
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *inputPath = stringArgument(argc, argv, "input", [NSString stringWithUTF8String:DEFAULT_INPUT_PATH]);
        NSString *outputPath = stringArgument(argc, argv, "output", [NSString stringWithUTF8String:DEFAULT_OUTPUT_PATH]);
        NSString *reportTitle = stringArgument(argc, argv, "report-title", [NSString stringWithUTF8String:DEFAULT_REPORT_TITLE]);
        NSString *codecName = stringArgument(argc, argv, "codec-name", [NSString stringWithUTF8String:DEFAULT_CODEC_NAME]);
        NSString *windowTitle = stringArgument(argc, argv, "window-title", [NSString stringWithUTF8String:DEFAULT_WINDOW_TITLE]);
        NSUInteger inflight = integerArgument(argc, argv, "inflight", 3);
        BOOL fullscreen = boolArgument(argc, argv, "fullscreen", YES);
        BOOL requireHardware = boolArgument(argc, argv, "require-hardware", YES);

        NSURL *inputURL = [NSURL fileURLWithPath:inputPath];
        if (![NSFileManager.defaultManager fileExistsAtPath:inputURL.path]) {
            fprintf(stderr, "Input stream not found: %s\n", inputURL.path.UTF8String);
            return 1;
        }

        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

        MetalPresenter *presenter = [[MetalPresenter alloc] initFullscreen:fullscreen
                                                                      title:windowTitle
                                                              expectedWidth:5120
                                                             expectedHeight:2880];

        if (!presenter) {
            fprintf(stderr, "Could not create Metal presenter.\n");
            return 1;
        }

        DecodeRenderBenchmark *benchmark = [[DecodeRenderBenchmark alloc] init];
        benchmark.presenter = presenter;
        benchmark.inputURL = inputURL;
        benchmark.outputPath = outputPath;
        benchmark.reportTitle = reportTitle;
        benchmark.codecDisplayName = codecName;
        benchmark.inflightLimit = MAX((NSUInteger)1, inflight);
        benchmark.requireHardwareDecoder = requireHardware;

        __block BOOL done = NO;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            @autoreleasepool {
                [benchmark run];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [presenter close];
                done = YES;
            });
        });

        while (!done) {
            @autoreleasepool {
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                         beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
            }
        }

        return 0;
    }
}
