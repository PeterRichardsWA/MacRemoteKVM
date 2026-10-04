#import <mach/mach_time.h>
#import <netinet/in.h>
#import <netinet/tcp.h>
#import <sys/socket.h>
#import <unistd.h>

#define main receiver_decode_render_single_pass_main
#include "../006-receiver-decode-render/ReceiverDecodeRenderProbe.m"
#undef main

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

static int createLoopbackListener(uint16_t *portOut) {
    int listener = socket(AF_INET, SOCK_STREAM, 0);
    if (listener < 0) {
        return -1;
    }

    int yes = 1;
    setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));

    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = 0;

    if (bind(listener, (struct sockaddr *)&address, sizeof(address)) != 0) {
        close(listener);
        return -1;
    }
    if (listen(listener, 1) != 0) {
        close(listener);
        return -1;
    }

    socklen_t length = sizeof(address);
    if (getsockname(listener, (struct sockaddr *)&address, &length) != 0) {
        close(listener);
        return -1;
    }

    *portOut = ntohs(address.sin_port);
    return listener;
}

static int connectLoopback(uint16_t port) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) {
        return -1;
    }

    int yes = 1;
    setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &yes, sizeof(yes));

    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = htons(port);

    if (connect(fd, (struct sockaddr *)&address, sizeof(address)) != 0) {
        close(fd);
        return -1;
    }
    return fd;
}

enum {
    MRKVFrameMagic = 0x4d524b56
};

typedef struct __attribute__((packed)) {
    uint32_t magic;
    uint32_t headerBytes;
    uint64_t sequence;
    uint64_t payloadBytes;
    int64_t ptsValue;
    int32_t ptsTimescale;
    uint32_t ptsFlags;
    int64_t durationValue;
    int32_t durationTimescale;
    uint32_t durationFlags;
    uint64_t sendNanos;
} MRKVFrameHeader;

typedef struct {
    uint64_t sequence;
    uint64_t sendNanos;
    uint64_t receiveCompleteNanos;
} FrameTimingRefCon;

@interface EncodedFrame : NSObject
@property(nonatomic, strong) NSData *payload;
@property(nonatomic) CMSampleTimingInfo timing;
@property(nonatomic) size_t sampleSize;
@end

@implementation EncodedFrame
@end

@interface TransportInput : NSObject {
    CMFormatDescriptionRef _formatDescription;
}
@property(nonatomic, strong) NSArray<EncodedFrame *> *frames;
@property(nonatomic, strong) NSURL *inputURL;
@property(nonatomic) CMVideoDimensions formatDimensions;
@property(nonatomic) OSType formatCodec;
@property(nonatomic) Float64 assetDurationSeconds;
@property(nonatomic) Float32 assetNominalFPS;
@property(nonatomic) float assetEstimatedDataRate;
@property(nonatomic) unsigned long long inputFileBytes;
@property(nonatomic) NSUInteger compressedSampleBuffers;
@property(nonatomic) NSUInteger skippedEmptySampleBuffers;
@property(nonatomic, strong) NSString *readerFailure;
@property(nonatomic) CMFormatDescriptionRef formatDescription;
@end

@implementation TransportInput

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

static TransportInput *loadTransportInput(NSURL *inputURL) {
    TransportInput *input = [[TransportInput alloc] init];
    input.inputURL = inputURL;

    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:inputURL.path error:nil];
    input.inputFileBytes = attributes.fileSize;

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:inputURL options:@{AVURLAssetPreferPreciseDurationAndTimingKey: @YES}];
    NSArray<AVAssetTrack *> *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *track = tracks.firstObject;
    if (!track) {
        input.readerFailure = @"input asset has no video track";
        return input;
    }

    input.assetDurationSeconds = CMTimeGetSeconds(asset.duration);
    input.assetNominalFPS = track.nominalFrameRate;
    input.assetEstimatedDataRate = track.estimatedDataRate;

    NSError *readerError = nil;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&readerError];
    if (!reader || readerError) {
        input.readerFailure = [NSString stringWithFormat:@"could not create AVAssetReader: %@", readerError.localizedDescription ?: @"unknown"];
        return input;
    }

    AVAssetReaderTrackOutput *output = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:nil];
    output.alwaysCopiesSampleData = NO;
    if (![reader canAddOutput:output]) {
        input.readerFailure = @"could not add compressed track output";
        return input;
    }
    [reader addOutput:output];

    if (![reader startReading]) {
        input.readerFailure = [NSString stringWithFormat:@"AVAssetReader failed to start: %@", reader.error.localizedDescription ?: @"unknown"];
        return input;
    }

    NSMutableArray<EncodedFrame *> *frames = [NSMutableArray array];
    CMSampleBufferRef sample = NULL;
    while ((sample = [output copyNextSampleBuffer])) {
        input.compressedSampleBuffers += 1;
        if (CMSampleBufferGetNumSamples(sample) == 0) {
            input.skippedEmptySampleBuffers += 1;
            CFRelease(sample);
            continue;
        }

        if (!input.formatDescription) {
            CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sample);
            if (formatDescription) {
                input.formatDescription = formatDescription;
                input.formatCodec = CMFormatDescriptionGetMediaSubType(formatDescription);
                input.formatDimensions = CMVideoFormatDescriptionGetDimensions(formatDescription);
            }
        }

        CMBlockBufferRef block = CMSampleBufferGetDataBuffer(sample);
        size_t length = block ? CMBlockBufferGetDataLength(block) : 0;
        if (length == 0) {
            input.skippedEmptySampleBuffers += 1;
            CFRelease(sample);
            continue;
        }

        NSMutableData *payload = [NSMutableData dataWithLength:length];
        OSStatus copyStatus = CMBlockBufferCopyDataBytes(block, 0, length, payload.mutableBytes);
        if (copyStatus != noErr) {
            input.readerFailure = [NSString stringWithFormat:@"could not copy compressed sample bytes: %d", copyStatus];
            CFRelease(sample);
            return input;
        }

        CMSampleTimingInfo timing;
        OSStatus timingStatus = CMSampleBufferGetSampleTimingInfo(sample, 0, &timing);
        if (timingStatus != noErr) {
            timing.duration = CMTimeMake(1, (int32_t)MAX(1.0f, input.assetNominalFPS));
            timing.presentationTimeStamp = CMTimeMake((int64_t)frames.count, (int32_t)MAX(1.0f, input.assetNominalFPS));
            timing.decodeTimeStamp = kCMTimeInvalid;
        }

        EncodedFrame *frame = [[EncodedFrame alloc] init];
        frame.payload = payload;
        frame.timing = timing;
        frame.sampleSize = CMSampleBufferGetSampleSize(sample, 0);
        if (frame.sampleSize == 0 || frame.sampleSize == (size_t)-1) {
            frame.sampleSize = length;
        }
        [frames addObject:frame];

        CFRelease(sample);
    }

    if (reader.status != AVAssetReaderStatusCompleted) {
        input.readerFailure = [NSString stringWithFormat:@"AVAssetReader ended with status %ld: %@",
                               (long)reader.status,
                               reader.error.localizedDescription ?: @"none"];
    }
    input.frames = frames;
    return input;
}

@class LoopbackTransportBenchmark;
static void transportOutputCallback(void *decompressionOutputRefCon,
                                    void *sourceFrameRefCon,
                                    OSStatus status,
                                    VTDecodeInfoFlags infoFlags,
                                    CVImageBufferRef imageBuffer,
                                    CMTime presentationTimeStamp,
                                    CMTime presentationDuration);

@interface LoopbackTransportBenchmark : NSObject {
    VTDecompressionSessionRef _decompressionSession;
}
@property(nonatomic, strong) TransportInput *input;
@property(nonatomic, strong) MetalPresenter *presenter;
@property(nonatomic, strong) NSString *outputPath;
@property(nonatomic, strong) NSString *reportTitle;
@property(nonatomic, strong) NSString *codecDisplayName;
@property(nonatomic) NSTimeInterval requestedDurationSeconds;
@property(nonatomic) NSUInteger inflightLimit;
@property(nonatomic) BOOL requireHardwareDecoder;
@property(nonatomic) BOOL realtimePacing;
@property(nonatomic) uint16_t listenerPort;
@property(nonatomic) OSStatus sessionCreateStatus;
@property(nonatomic) OSStatus fallbackSessionCreateStatus;
@property(nonatomic, strong) NSString *setupFailure;
@property(nonatomic, strong) NSString *transportFailure;
@property(nonatomic, strong) NSString *sessionNote;
@property(nonatomic) NSUInteger sourceLoopsCompleted;
@property(nonatomic) NSUInteger senderFramesSent;
@property(nonatomic) unsigned long long senderBytesSent;
@property(nonatomic) NSTimeInterval senderWallSeconds;
@property(nonatomic) NSUInteger receiverFramesReceived;
@property(nonatomic) unsigned long long receiverBytesReceived;
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
@property(nonatomic) NSTimeInterval receiverWallSeconds;
@property(nonatomic) NSTimeInterval firstOutputWallSeconds;
@property(nonatomic) NSTimeInterval lastOutputWallSeconds;
@property(nonatomic) uint64_t receiverStartNanos;
@property(nonatomic) double transportLatencySumMS;
@property(nonatomic) double transportLatencyMinMS;
@property(nonatomic) double transportLatencyMaxMS;
@property(nonatomic) double endToEndLatencySumMS;
@property(nonatomic) double endToEndLatencyMinMS;
@property(nonatomic) double endToEndLatencyMaxMS;
@property(nonatomic, strong) dispatch_semaphore_t inflightSemaphore;
@property(nonatomic, strong) NSMutableArray<NSString *> *decodeCallErrorLines;
@property(nonatomic, strong) NSMutableArray<NSString *> *decodeOutputErrorLines;
- (BOOL)run;
- (void)handleDecodedImageBuffer:(CVImageBufferRef)imageBuffer status:(OSStatus)status infoFlags:(VTDecodeInfoFlags)infoFlags frameTiming:(FrameTimingRefCon *)frameTiming;
@end

@implementation LoopbackTransportBenchmark

- (instancetype)init {
    self = [super init];
    if (self) {
        _sessionCreateStatus = INT32_MIN;
        _fallbackSessionCreateStatus = INT32_MIN;
        _inflightLimit = 3;
        _requireHardwareDecoder = YES;
        _realtimePacing = YES;
        _requestedDurationSeconds = 30.0;
        _transportLatencyMinMS = DBL_MAX;
        _endToEndLatencyMinMS = DBL_MAX;
        _decodeCallErrorLines = [NSMutableArray array];
        _decodeOutputErrorLines = [NSMutableArray array];
    }
    return self;
}

- (BOOL)createDecompressionSession {
    VTDecompressionOutputCallbackRecord callback = {
        .decompressionOutputCallback = transportOutputCallback,
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
                                                            self.input.formatDescription,
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
                                                                    self.input.formatDescription,
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

- (BOOL)sendFramesToSocket:(int)fd {
    uint64_t start = nowNanos();
    uint64_t deadline = start + (uint64_t)(self.requestedDurationSeconds * 1000000000.0);
    double nominalFPS = self.input.assetNominalFPS > 0.0 ? self.input.assetNominalFPS : 60.0;
    uint64_t frameInterval = (uint64_t)(1000000000.0 / nominalFPS);
    uint64_t nextSend = start;
    NSUInteger sequence = 0;

    while (nowNanos() < deadline) {
        BOOL sentInLoop = NO;
        BOOL completedLoop = YES;
        for (EncodedFrame *frame in self.input.frames) {
            if (nowNanos() >= deadline) {
                completedLoop = NO;
                break;
            }
            if (self.realtimePacing) {
                sleepUntilNanos(nextSend);
            }

            MRKVFrameHeader header;
            memset(&header, 0, sizeof(header));
            header.magic = MRKVFrameMagic;
            header.headerBytes = sizeof(header);
            header.sequence = sequence;
            header.payloadBytes = frame.payload.length;
            header.ptsValue = frame.timing.presentationTimeStamp.value;
            header.ptsTimescale = frame.timing.presentationTimeStamp.timescale;
            header.ptsFlags = frame.timing.presentationTimeStamp.flags;
            header.durationValue = frame.timing.duration.value;
            header.durationTimescale = frame.timing.duration.timescale;
            header.durationFlags = frame.timing.duration.flags;
            header.sendNanos = nowNanos();

            if (!writeFull(fd, &header, sizeof(header)) ||
                !writeFull(fd, frame.payload.bytes, frame.payload.length)) {
                @synchronized (self) {
                    self.transportFailure = [NSString stringWithFormat:@"sender write failed at frame %lu: errno %d", (unsigned long)sequence, errno];
                }
                return NO;
            }

            @synchronized (self) {
                self.senderFramesSent += 1;
                self.senderBytesSent += frame.payload.length + sizeof(header);
            }
            sentInLoop = YES;
            sequence += 1;
            nextSend += frameInterval;
        }
        if (!sentInLoop) {
            break;
        }
        if (completedLoop) {
            @synchronized (self) {
                self.sourceLoopsCompleted += 1;
            }
        }
    }

    shutdown(fd, SHUT_WR);
    close(fd);
    self.senderWallSeconds = (double)(nowNanos() - start) / 1000000000.0;
    return YES;
}

- (CMSampleBufferRef)copySampleBufferFromPayload:(NSData *)payload header:(MRKVFrameHeader)header {
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
                                       self.input.formatDescription,
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

- (BOOL)receiveFramesFromSocket:(int)fd {
    self.inflightSemaphore = dispatch_semaphore_create((long)MAX((NSUInteger)1, self.inflightLimit));
    self.receiverStartNanos = nowNanos();

    while (YES) {
        MRKVFrameHeader header;
        ssize_t firstRead = read(fd, &header, sizeof(header));
        if (firstRead == 0) {
            break;
        }
        if (firstRead < 0) {
            if (errno == EINTR) {
                continue;
            }
            self.transportFailure = [NSString stringWithFormat:@"receiver read failed: errno %d", errno];
            break;
        }
        if ((size_t)firstRead < sizeof(header) && !readFull(fd, ((uint8_t *)&header) + firstRead, sizeof(header) - (size_t)firstRead)) {
            self.transportFailure = @"receiver could not read a complete frame header";
            break;
        }
        if (header.magic != MRKVFrameMagic || header.headerBytes != sizeof(header)) {
            self.transportFailure = @"receiver saw an invalid frame header";
            break;
        }
        if (header.payloadBytes == 0 || header.payloadBytes > 64ULL * 1024ULL * 1024ULL) {
            self.transportFailure = [NSString stringWithFormat:@"receiver saw invalid payload length %llu", header.payloadBytes];
            break;
        }

        NSMutableData *payload = [NSMutableData dataWithLength:(NSUInteger)header.payloadBytes];
        if (!readFull(fd, payload.mutableBytes, payload.length)) {
            self.transportFailure = @"receiver could not read a complete payload";
            break;
        }
        uint64_t receiveCompleteNanos = nowNanos();

        CMSampleBufferRef sample = [self copySampleBufferFromPayload:payload header:header];
        if (!sample) {
            self.transportFailure = @"receiver could not rebuild CMSampleBuffer from payload";
            break;
        }

        FrameTimingRefCon *frameTiming = calloc(1, sizeof(FrameTimingRefCon));
        frameTiming->sequence = header.sequence;
        frameTiming->sendNanos = header.sendNanos;
        frameTiming->receiveCompleteNanos = receiveCompleteNanos;

        dispatch_semaphore_wait(self.inflightSemaphore, DISPATCH_TIME_FOREVER);
        @synchronized (self) {
            self.receiverFramesReceived += 1;
            self.receiverBytesReceived += payload.length + sizeof(header);
            self.submittedFrames += 1;
        }

        VTDecodeInfoFlags infoFlags = 0;
        OSStatus status = VTDecompressionSessionDecodeFrame(_decompressionSession,
                                                            sample,
                                                            kVTDecodeFrame_EnableAsynchronousDecompression,
                                                            frameTiming,
                                                            &infoFlags);
        CFRelease(sample);
        if (status != noErr) {
            @synchronized (self) {
                self.decodeCallErrors += 1;
                if (self.decodeCallErrorLines.count < 12) {
                    [self.decodeCallErrorLines addObject:[NSString stringWithFormat:@"decode call %lu returned %d",
                                                          (unsigned long)self.submittedFrames,
                                                          status]];
                }
            }
            free(frameTiming);
            dispatch_semaphore_signal(self.inflightSemaphore);
        }
    }

    close(fd);
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

    self.receiverWallSeconds = (double)(nowNanos() - self.receiverStartNanos) / 1000000000.0;
    return self.transportFailure == nil;
}

- (BOOL)run {
    if (self.input.readerFailure || self.input.frames.count == 0 || !self.input.formatDescription) {
        self.setupFailure = self.input.readerFailure ?: @"input did not provide compressed frames and format description";
        [self writeReport];
        return NO;
    }

    if (![self createDecompressionSession]) {
        [self writeReport];
        return NO;
    }

    uint16_t port = 0;
    int listener = createLoopbackListener(&port);
    if (listener < 0) {
        self.transportFailure = [NSString stringWithFormat:@"could not create loopback listener: errno %d", errno];
        [self writeReport];
        return NO;
    }
    self.listenerPort = port;

    dispatch_group_t group = dispatch_group_create();
    __block BOOL receiverOK = NO;
    __block BOOL senderOK = NO;

    dispatch_group_enter(group);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        int accepted = accept(listener, NULL, NULL);
        close(listener);
        if (accepted < 0) {
            @synchronized (self) {
                self.transportFailure = [NSString stringWithFormat:@"accept failed: errno %d", errno];
            }
        } else {
            int yes = 1;
            setsockopt(accepted, IPPROTO_TCP, TCP_NODELAY, &yes, sizeof(yes));
            receiverOK = [self receiveFramesFromSocket:accepted];
        }
        dispatch_group_leave(group);
    });

    dispatch_group_enter(group);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        int sender = connectLoopback(port);
        if (sender < 0) {
            @synchronized (self) {
                self.transportFailure = [NSString stringWithFormat:@"sender connect failed: errno %d", errno];
            }
        } else {
            senderOK = [self sendFramesToSocket:sender];
        }
        dispatch_group_leave(group);
    });

    while (dispatch_group_wait(group, DISPATCH_TIME_NOW) != 0) {
        @autoreleasepool {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                     beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        }
    }

    if (_decompressionSession) {
        VTDecompressionSessionInvalidate(_decompressionSession);
        CFRelease(_decompressionSession);
        _decompressionSession = NULL;
    }

    [self writeReport];
    return senderOK && receiverOK && self.decodeCallErrors == 0 && self.decodeOutputErrors == 0 && self.renderFailures == 0 && self.renderedFrames > 0;
}

- (void)handleDecodedImageBuffer:(CVImageBufferRef)imageBuffer status:(OSStatus)status infoFlags:(VTDecodeInfoFlags)infoFlags frameTiming:(FrameTimingRefCon *)frameTiming {
    uint64_t callbackNanos = nowNanos();
    if (status != noErr || !imageBuffer) {
        @synchronized (self) {
            self.decodeOutputErrors += 1;
            if (self.decodeOutputErrorLines.count < 12) {
                [self.decodeOutputErrorLines addObject:[NSString stringWithFormat:@"output status %d at frame %llu",
                                                        status,
                                                        frameTiming ? frameTiming->sequence : 0]];
            }
        }
        if (frameTiming) {
            free(frameTiming);
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
    uint64_t renderDoneNanos = nowNanos();

    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer);
    CVPixelBufferRelease(imageBuffer);

    double transportMS = 0.0;
    double endToEndMS = 0.0;
    if (frameTiming) {
        transportMS = nanosToMS(frameTiming->receiveCompleteNanos - frameTiming->sendNanos);
        endToEndMS = nanosToMS(renderDoneNanos - frameTiming->sendNanos);
    }

    @synchronized (self) {
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
            self.transportLatencySumMS += transportMS;
            self.transportLatencyMinMS = MIN(self.transportLatencyMinMS, transportMS);
            self.transportLatencyMaxMS = MAX(self.transportLatencyMaxMS, transportMS);
            self.endToEndLatencySumMS += endToEndMS;
            self.endToEndLatencyMinMS = MIN(self.endToEndLatencyMinMS, endToEndMS);
            self.endToEndLatencyMaxMS = MAX(self.endToEndLatencyMaxMS, endToEndMS);
        } else {
            self.renderFailures += 1;
        }
    }

    if (frameTiming) {
        free(frameTiming);
    }
    dispatch_semaphore_signal(self.inflightSemaphore);
}

- (void)writeReport {
    createOutputDirectory(self.outputPath);

    double nominalFPS = self.input.assetNominalFPS > 0.0 ? self.input.assetNominalFPS : 60.0;
    double renderedFPS = self.receiverWallSeconds > 0.0 ? (double)self.renderedFrames / self.receiverWallSeconds : 0.0;
    double realtimeMultiple = nominalFPS > 0.0 ? renderedFPS / nominalFPS : 0.0;
    double sourceBitrateMbps = self.input.assetEstimatedDataRate > 0.0 ? (double)self.input.assetEstimatedDataRate / 1000000.0 : 0.0;
    double transportMbps = self.senderWallSeconds > 0.0 ? ((double)self.senderBytesSent * 8.0 / self.senderWallSeconds / 1000000.0) : 0.0;
    double fileMB = (double)self.input.inputFileBytes / 1024.0 / 1024.0;
    double averageTransportMS = self.renderedFrames > 0 ? self.transportLatencySumMS / (double)self.renderedFrames : 0.0;
    double averageEndToEndMS = self.renderedFrames > 0 ? self.endToEndLatencySumMS / (double)self.renderedFrames : 0.0;
    double minTransportMS = self.transportLatencyMinMS == DBL_MAX ? 0.0 : self.transportLatencyMinMS;
    double minEndToEndMS = self.endToEndLatencyMinMS == DBL_MAX ? 0.0 : self.endToEndLatencyMinMS;
    double averageRenderMS = self.presenter.renderedFrames > 0 ? (self.presenter.totalRenderSeconds * 1000.0 / (double)self.presenter.renderedFrames) : 0.0;
    NSString *codecName = self.codecDisplayName ?: @"codec";

    NSMutableString *report = [NSMutableString string];
    [report appendFormat:@"# %@\n\n", self.reportTitle ?: @"Experiment 010 Result: Loopback Transport Prototype"];

    [report appendString:@"## Machine\n\n"];
    NSProcessInfo *processInfo = NSProcessInfo.processInfo;
    [report appendFormat:@"- Host name: %@\n", processInfo.hostName];
    [report appendFormat:@"- macOS: %@\n", processInfo.operatingSystemVersionString];
    [report appendFormat:@"- Hardware model: %@\n", sysctlString("hw.model")];
    [report appendFormat:@"- CPU brand: %@\n", sysctlString("machdep.cpu.brand_string")];
    [report appendFormat:@"- Processor count: %lu\n", (unsigned long)processInfo.processorCount];
    [report appendFormat:@"- Physical memory: %.2f GB\n", (double)processInfo.physicalMemory / 1024.0 / 1024.0 / 1024.0];

    [report appendString:@"\n## Transport Settings\n\n"];
    [report appendString:@"- Transport: local TCP loopback, one sender thread, one receiver thread\n"];
    [report appendString:@"- Payload format: compressed sample payload per frame\n"];
    [report appendString:@"- Decoder config: shared in process from local asset format description\n"];
    [report appendString:@"- Header encoding: native-endian prototype frame header\n"];
    [report appendFormat:@"- Requested duration: %.1f seconds\n", self.requestedDurationSeconds];
    [report appendFormat:@"- Realtime pacing: %@\n", yesNo(self.realtimePacing)];
    [report appendFormat:@"- In-flight decode limit: %lu\n", (unsigned long)self.inflightLimit];
    [report appendFormat:@"- Loopback listener port: %u\n", self.listenerPort];

    [report appendString:@"\n## Input Stream\n\n"];
    [report appendFormat:@"- Path: `%@`\n", self.input.inputURL.path];
    [report appendFormat:@"- File size: %.2f MB\n", fileMB];
    [report appendFormat:@"- Codec FourCC: `%@`\n", self.input.formatCodec ? fourCC(self.input.formatCodec) : @"unavailable"];
    [report appendFormat:@"- Format dimensions: %d x %d\n", self.input.formatDimensions.width, self.input.formatDimensions.height];
    [report appendFormat:@"- Duration: %.3f seconds\n", self.input.assetDurationSeconds];
    [report appendFormat:@"- Nominal FPS: %.2f\n", self.input.assetNominalFPS];
    [report appendFormat:@"- Estimated source bitrate: %.2f Mbps\n", sourceBitrateMbps];
    [report appendFormat:@"- Compressed sample buffers read: %lu\n", (unsigned long)self.input.compressedSampleBuffers];
    [report appendFormat:@"- Empty sample buffers skipped: %lu\n", (unsigned long)self.input.skippedEmptySampleBuffers];
    [report appendFormat:@"- Transportable frame payloads: %lu\n", (unsigned long)self.input.frames.count];

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
    if (self.setupFailure) {
        [report appendFormat:@"- Setup failure: %@\n", self.setupFailure];
    }
    if (self.transportFailure) {
        [report appendFormat:@"- Transport failure: %@\n", self.transportFailure];
    }

    [report appendString:@"\n## Render Target\n\n"];
    [report appendString:@"- Renderer: Metal CAMetalLayer with Core Image CVPixelBuffer render\n"];
    [report appendFormat:@"- Window backing scale: %.2f\n", self.presenter.backingScaleFactor];
    [report appendFormat:@"- Drawable size: %.0f x %.0f\n", self.presenter.drawableSize.width, self.presenter.drawableSize.height];

    [report appendString:@"\n## Transport Result\n\n"];
    [report appendFormat:@"- Sender frames sent: %lu\n", (unsigned long)self.senderFramesSent];
    [report appendFormat:@"- Sender bytes sent: %llu\n", self.senderBytesSent];
    [report appendFormat:@"- Source loops completed: %lu\n", (unsigned long)self.sourceLoopsCompleted];
    [report appendFormat:@"- Sender wall time: %.3f seconds\n", self.senderWallSeconds];
    [report appendFormat:@"- Measured transport bitrate: %.2f Mbps\n", transportMbps];
    [report appendFormat:@"- Receiver frames received: %lu\n", (unsigned long)self.receiverFramesReceived];
    [report appendFormat:@"- Receiver bytes received: %llu\n", self.receiverBytesReceived];

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
    [report appendFormat:@"- Receiver wall time: %.3f seconds\n", self.receiverWallSeconds];
    [report appendFormat:@"- Throughput: %.2f rendered FPS\n", renderedFPS];
    [report appendFormat:@"- Realtime multiple vs %.2f FPS input: %.2fx\n", nominalFPS, realtimeMultiple];
    [report appendFormat:@"- Average synchronous render time: %.3f ms\n", averageRenderMS];
    [report appendFormat:@"- First output callback wall time: %.3f seconds\n", self.firstOutputWallSeconds];
    [report appendFormat:@"- Last output callback wall time: %.3f seconds\n", self.lastOutputWallSeconds];

    [report appendString:@"\n## Latency Proxy\n\n"];
    [report appendString:@"This is a local loopback transport result. It measures sender write time to receiver payload completion and sender write time to rendered frame on the same Mac. It does not yet include real network jitter, sender capture, live encode, cross-machine clock sync, or input/cursor round trip.\n\n"];
    [report appendFormat:@"- Average sender-to-receiver payload latency: %.3f ms\n", averageTransportMS];
    [report appendFormat:@"- Min sender-to-receiver payload latency: %.3f ms\n", minTransportMS];
    [report appendFormat:@"- Max sender-to-receiver payload latency: %.3f ms\n", self.transportLatencyMaxMS];
    [report appendFormat:@"- Average sender-to-rendered-frame latency: %.3f ms\n", averageEndToEndMS];
    [report appendFormat:@"- Min sender-to-rendered-frame latency: %.3f ms\n", minEndToEndMS];
    [report appendFormat:@"- Max sender-to-rendered-frame latency: %.3f ms\n", self.endToEndLatencyMaxMS];

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
    if (self.sessionCreateStatus != noErr || self.transportFailure) {
        [report appendFormat:@"The local loopback transport path did not complete for %@. Fix this before attempting a two-Mac transport run.\n", codecName];
    } else if (realtimeMultiple >= 0.95 && self.decodeCallErrors == 0 && self.decodeOutputErrors == 0 && self.renderFailures == 0 && self.senderFramesSent == self.renderedFrames) {
        [report appendFormat:@"The local loopback transport path stayed inside the current pass band for %@. This candidate is ready for a two-Mac transport test.\n", codecName];
    } else {
        [report appendFormat:@"The local loopback transport path completed for %@ but did not stay inside the current pass band. Inspect frame counts, pacing, and latency before moving to a two-Mac run.\n", codecName];
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

static void transportOutputCallback(void *decompressionOutputRefCon,
                                    void *sourceFrameRefCon,
                                    OSStatus status,
                                    VTDecodeInfoFlags infoFlags,
                                    CVImageBufferRef imageBuffer,
                                    CMTime presentationTimeStamp,
                                    CMTime presentationDuration) {
    LoopbackTransportBenchmark *benchmark = (__bridge LoopbackTransportBenchmark *)decompressionOutputRefCon;
    [benchmark handleDecodedImageBuffer:imageBuffer
                                 status:status
                              infoFlags:infoFlags
                            frameTiming:(FrameTimingRefCon *)sourceFrameRefCon];
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *inputPath = stringArgument(argc, argv, "input", @"media/h264-3840x2160-60-high-3s.mp4");
        NSString *outputPath = stringArgument(argc, argv, "output", @"../../results/010-loopback-transport-prototype/h264-3840x2160-60-loopback.md");
        NSString *reportTitle = stringArgument(argc, argv, "report-title", @"Experiment 010 Result: Loopback Transport Prototype");
        NSString *codecName = stringArgument(argc, argv, "codec-name", @"H.264");
        NSString *windowTitle = stringArgument(argc, argv, "window-title", @"MacRemoteKVM Experiment 010");
        NSUInteger inflight = integerArgument(argc, argv, "inflight", 3);
        BOOL fullscreen = boolArgument(argc, argv, "fullscreen", YES);
        BOOL requireHardware = boolArgument(argc, argv, "require-hardware", YES);
        BOOL realtimePacing = boolArgument(argc, argv, "realtime-pacing", YES);
        NSTimeInterval duration = doubleArgumentLocal(argc, argv, "duration", 30.0);

        NSURL *inputURL = [NSURL fileURLWithPath:inputPath];
        if (![NSFileManager.defaultManager fileExistsAtPath:inputURL.path]) {
            fprintf(stderr, "Input stream not found: %s\n", inputURL.path.UTF8String);
            return 1;
        }

        TransportInput *input = loadTransportInput(inputURL);
        if (input.readerFailure) {
            fprintf(stderr, "Could not load input: %s\n", input.readerFailure.UTF8String);
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

        LoopbackTransportBenchmark *benchmark = [[LoopbackTransportBenchmark alloc] init];
        benchmark.input = input;
        benchmark.presenter = presenter;
        benchmark.outputPath = outputPath;
        benchmark.reportTitle = reportTitle;
        benchmark.codecDisplayName = codecName;
        benchmark.inflightLimit = MAX((NSUInteger)1, inflight);
        benchmark.requireHardwareDecoder = requireHardware;
        benchmark.realtimePacing = realtimePacing;
        benchmark.requestedDurationSeconds = duration;

        BOOL ok = [benchmark run];
        [presenter close];
        return ok ? 0 : 2;
    }
}
