#import <mach/mach.h>
#import <sys/resource.h>

#define main receiver_decode_render_single_pass_main
#include "../006-receiver-decode-render/ReceiverDecodeRenderProbe.m"
#undef main

static NSTimeInterval doubleArgument(int argc, const char *argv[], const char *name, NSTimeInterval defaultValue) {
    NSString *needle = [NSString stringWithFormat:@"--%s=", name];
    for (int i = 1; i < argc; i++) {
        NSString *argument = [NSString stringWithUTF8String:argv[i]];
        if ([argument hasPrefix:needle]) {
            return MAX(0.0, [[argument substringFromIndex:needle.length] doubleValue]);
        }
    }
    return defaultValue;
}

static NSString *thermalStateString(NSProcessInfoThermalState state) {
    switch (state) {
        case NSProcessInfoThermalStateNominal: return @"nominal";
        case NSProcessInfoThermalStateFair: return @"fair";
        case NSProcessInfoThermalStateSerious: return @"serious";
        case NSProcessInfoThermalStateCritical: return @"critical";
        default: return @"unknown";
    }
}

static double secondsFromTimeval(struct timeval value) {
    return (double)value.tv_sec + ((double)value.tv_usec / 1000000.0);
}

static void readProcessCPUSeconds(double *userSeconds, double *systemSeconds) {
    struct rusage usage;
    if (getrusage(RUSAGE_SELF, &usage) == 0) {
        *userSeconds = secondsFromTimeval(usage.ru_utime);
        *systemSeconds = secondsFromTimeval(usage.ru_stime);
    } else {
        *userSeconds = 0.0;
        *systemSeconds = 0.0;
    }
}

static double residentMemoryMB(void) {
    mach_task_basic_info_data_t info;
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    kern_return_t status = task_info(mach_task_self(),
                                     MACH_TASK_BASIC_INFO,
                                     (task_info_t)&info,
                                     &count);
    if (status != KERN_SUCCESS) {
        return 0.0;
    }
    return (double)info.resident_size / 1024.0 / 1024.0;
}

@interface DecodeRenderBenchmark (StressHarnessAccess)
- (NSArray *)loadCompressedSamplesWithFormatDescription:(CMFormatDescriptionRef *)formatDescriptionOut;
- (BOOL)createDecompressionSessionWithFormatDescription:(CMFormatDescriptionRef)formatDescription;
@end

@interface CandidateStressBenchmark : DecodeRenderBenchmark
@property(nonatomic) NSTimeInterval requestedDurationSeconds;
@property(nonatomic) NSUInteger maxSubmittedFrames;
@property(nonatomic) NSUInteger completedLoops;
@property(nonatomic) NSUInteger requestedInflightLimit;
@property(nonatomic, strong) NSDate *stressStartedAt;
@property(nonatomic, strong) NSDate *stressEndedAt;
@property(nonatomic) NSProcessInfoThermalState thermalStart;
@property(nonatomic) NSProcessInfoThermalState thermalEnd;
@property(nonatomic) double userCPUStart;
@property(nonatomic) double systemCPUStart;
@property(nonatomic) double userCPUEnd;
@property(nonatomic) double systemCPUEnd;
@property(nonatomic) double residentMemoryStartMB;
@property(nonatomic) double residentMemoryEndMB;
- (BOOL)run;
- (void)writeStressReport;
@end

@implementation CandidateStressBenchmark

- (BOOL)shouldStopBeforeSubmittingWithDeadline:(NSDate *)deadline {
    if (self.maxSubmittedFrames > 0 && self.submittedFrames >= self.maxSubmittedFrames) {
        return YES;
    }
    if (self.requestedDurationSeconds > 0.0 && deadline && [deadline timeIntervalSinceNow] <= 0.0) {
        return YES;
    }
    return NO;
}

- (BOOL)run {
    self.stressStartedAt = [NSDate date];
    self.thermalStart = NSProcessInfo.processInfo.thermalState;
    self.residentMemoryStartMB = residentMemoryMB();
    readProcessCPUSeconds(&_userCPUStart, &_systemCPUStart);

    CMFormatDescriptionRef formatDescription = NULL;
    NSArray *samples = [self loadCompressedSamplesWithFormatDescription:&formatDescription];
    if (self.readerFailure || samples.count == 0 || !formatDescription) {
        if (!self.readerFailure) {
            self.readerFailure = @"no compressed samples were read";
        }
        self.stressEndedAt = [NSDate date];
        self.thermalEnd = NSProcessInfo.processInfo.thermalState;
        self.residentMemoryEndMB = residentMemoryMB();
        readProcessCPUSeconds(&_userCPUEnd, &_systemCPUEnd);
        [self writeStressReport];
        if (formatDescription) {
            CFRelease(formatDescription);
        }
        return NO;
    }

    BOOL sessionCreated = [self createDecompressionSessionWithFormatDescription:formatDescription];
    CFRelease(formatDescription);
    if (!sessionCreated) {
        self.stressEndedAt = [NSDate date];
        self.thermalEnd = NSProcessInfo.processInfo.thermalState;
        self.residentMemoryEndMB = residentMemoryMB();
        readProcessCPUSeconds(&_userCPUEnd, &_systemCPUEnd);
        [self writeStressReport];
        return NO;
    }

    self.inflightSemaphore = dispatch_semaphore_create((long)MAX((NSUInteger)1, self.inflightLimit));
    self.benchmarkStartDate = [NSDate date];
    NSDate *deadline = self.requestedDurationSeconds > 0.0 ? [NSDate dateWithTimeIntervalSinceNow:self.requestedDurationSeconds] : nil;

    while (![self shouldStopBeforeSubmittingWithDeadline:deadline]) {
        BOOL submittedInLoop = NO;

        for (id sampleObject in samples) {
            if ([self shouldStopBeforeSubmittingWithDeadline:deadline]) {
                break;
            }

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
            submittedInLoop = YES;

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

        if (!submittedInLoop) {
            break;
        }

        @synchronized (self) {
            self.completedLoops += 1;
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

    self.stressEndedAt = [NSDate date];
    self.decodeRenderSeconds = [self.stressEndedAt timeIntervalSinceDate:self.benchmarkStartDate];
    self.thermalEnd = NSProcessInfo.processInfo.thermalState;
    self.residentMemoryEndMB = residentMemoryMB();
    readProcessCPUSeconds(&_userCPUEnd, &_systemCPUEnd);

    if (_decompressionSession) {
        VTDecompressionSessionInvalidate(_decompressionSession);
        CFRelease(_decompressionSession);
        _decompressionSession = NULL;
    }

    [self writeStressReport];
    return self.decodeCallErrors == 0 && self.decodeOutputErrors == 0 && self.renderFailures == 0 && self.renderedFrames > 0;
}

- (void)writeStressReport {
    createOutputDirectory(self.outputPath);

    double throughputFPS = self.decodeRenderSeconds > 0.0 ? (double)self.renderedFrames / self.decodeRenderSeconds : 0.0;
    double nominalFPS = self.assetNominalFPS > 0.0 ? self.assetNominalFPS : 60.0;
    double realtimeMultiple = nominalFPS > 0.0 ? throughputFPS / nominalFPS : 0.0;
    double fileMB = (double)self.inputFileBytes / 1024.0 / 1024.0;
    double bitrateMbps = self.assetEstimatedDataRate > 0.0 ? (double)self.assetEstimatedDataRate / 1000000.0 : 0.0;
    double averageRenderMS = self.presenter.renderedFrames > 0 ? (self.presenter.totalRenderSeconds * 1000.0 / (double)self.presenter.renderedFrames) : 0.0;
    double userCPU = MAX(0.0, self.userCPUEnd - self.userCPUStart);
    double systemCPU = MAX(0.0, self.systemCPUEnd - self.systemCPUStart);
    double totalCPU = userCPU + systemCPU;
    double cpuRealtimeMultiple = self.decodeRenderSeconds > 0.0 ? totalCPU / self.decodeRenderSeconds : 0.0;
    double representedVideoSeconds = nominalFPS > 0.0 ? (double)self.submittedFrames / nominalFPS : 0.0;
    NSString *codecName = self.codecDisplayName ?: @"codec";

    NSMutableString *report = [NSMutableString string];
    [report appendFormat:@"# %@\n\n", self.reportTitle ?: @"Receiver Candidate Stress Result"];

    [report appendString:@"## Machine\n\n"];
    NSProcessInfo *processInfo = NSProcessInfo.processInfo;
    [report appendFormat:@"- Host name: %@\n", processInfo.hostName];
    [report appendFormat:@"- macOS: %@\n", processInfo.operatingSystemVersionString];
    [report appendFormat:@"- Hardware model: %@\n", sysctlString("hw.model")];
    [report appendFormat:@"- CPU brand: %@\n", sysctlString("machdep.cpu.brand_string")];
    [report appendFormat:@"- Processor count: %lu\n", (unsigned long)processInfo.processorCount];
    [report appendFormat:@"- Physical memory: %.2f GB\n", (double)processInfo.physicalMemory / 1024.0 / 1024.0 / 1024.0];

    [report appendString:@"\n## Stress Settings\n\n"];
    [report appendFormat:@"- Requested duration: %.1f seconds\n", self.requestedDurationSeconds];
    [report appendFormat:@"- Max submitted frames: %@\n", self.maxSubmittedFrames > 0 ? [NSString stringWithFormat:@"%lu", (unsigned long)self.maxSubmittedFrames] : @"unlimited"];
    [report appendFormat:@"- Completed source loops: %lu\n", (unsigned long)self.completedLoops];
    [report appendFormat:@"- In-flight decode limit: %lu\n", (unsigned long)self.requestedInflightLimit];
    [report appendFormat:@"- Required hardware decoder: %@\n", yesNo(self.requireHardwareDecoder)];

    [report appendString:@"\n## Input Stream\n\n"];
    [report appendFormat:@"- Path: `%@`\n", self.inputURL.path];
    [report appendFormat:@"- File size: %.2f MB\n", fileMB];
    [report appendFormat:@"- Codec FourCC: `%@`\n", self.formatCodec ? fourCC(self.formatCodec) : @"unavailable"];
    [report appendFormat:@"- Format dimensions: %d x %d\n", self.formatDimensions.width, self.formatDimensions.height];
    [report appendFormat:@"- Duration: %.3f seconds\n", self.assetDurationSeconds];
    [report appendFormat:@"- Nominal FPS: %.2f\n", self.assetNominalFPS];
    [report appendFormat:@"- Estimated bitrate: %.2f Mbps\n", bitrateMbps];
    [report appendFormat:@"- Compressed sample buffers read: %lu\n", (unsigned long)self.sampleCount];
    [report appendFormat:@"- Compressed frame samples read per source loop: %lu\n", (unsigned long)self.compressedFrameSamples];

    [report appendString:@"\n## Decoder Setup\n\n"];
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

    [report appendString:@"\n## Stress Result\n\n"];
    [report appendFormat:@"- Submitted frames: %lu\n", (unsigned long)self.submittedFrames];
    [report appendFormat:@"- Represented source-video duration: %.3f seconds\n", representedVideoSeconds];
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

    [report appendString:@"\n## Runtime Health\n\n"];
    [report appendFormat:@"- Thermal state start: %@\n", thermalStateString(self.thermalStart)];
    [report appendFormat:@"- Thermal state end: %@\n", thermalStateString(self.thermalEnd)];
    [report appendFormat:@"- Process user CPU time: %.3f seconds\n", userCPU];
    [report appendFormat:@"- Process system CPU time: %.3f seconds\n", systemCPU];
    [report appendFormat:@"- Process CPU realtime multiple: %.2fx\n", cpuRealtimeMultiple];
    [report appendFormat:@"- Resident memory start: %.2f MB\n", self.residentMemoryStartMB];
    [report appendFormat:@"- Resident memory end: %.2f MB\n", self.residentMemoryEndMB];

    [report appendString:@"\n## Latency Proxy\n\n"];
    [report appendString:@"This experiment does not include network transport, sender capture, or cursor input, so it cannot measure end-to-end KVM latency yet. It records decoder startup and synchronous render cost as the current local receiver latency proxy.\n\n"];
    [report appendFormat:@"- Decoder startup to first output callback: %.3f seconds\n", self.firstOutputWallSeconds];
    [report appendFormat:@"- Average synchronous render cost: %.3f ms\n", averageRenderMS];

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

    [report appendString:@"\n## Observer Notes\n\n"];
    [report appendString:@"- Add any visible stutter, tearing, color, or scaling observations after the run.\n"];

    [report appendString:@"\n## Interpretation\n\n"];
    if (self.sessionCreateStatus != noErr) {
        [report appendFormat:@"The required hardware %@ decoder session could not be created for this candidate. This candidate is not viable for the first receiver prototype in this form.\n",
         codecName];
    } else if (realtimeMultiple >= 0.95 && self.renderFailures == 0 && self.decodeOutputErrors == 0 && self.decodeCallErrors == 0) {
        [report appendFormat:@"This candidate stayed inside the current pass band for the local %@ decode/render stress run. It remains viable for the first receiver prototype.\n",
         codecName];
    } else {
        [report appendFormat:@"This candidate created a hardware %@ decoder session but did not stay inside the current pass band for this stress run. Compare against the other candidate before choosing the first transport path.\n",
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

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *inputPath = stringArgument(argc, argv, "input", @"../008-receiver-decode-envelope/media/h264-3840x2160-60-high-3s.mp4");
        NSString *outputPath = stringArgument(argc, argv, "output", @"../../results/009-receiver-candidate-stress/h264-3840x2160-60-stress.md");
        NSString *reportTitle = stringArgument(argc, argv, "report-title", @"Experiment 009 Result: Receiver Candidate Stress");
        NSString *codecName = stringArgument(argc, argv, "codec-name", @"H.264");
        NSString *windowTitle = stringArgument(argc, argv, "window-title", @"MacRemoteKVM Experiment 009");
        NSUInteger inflight = integerArgument(argc, argv, "inflight", 3);
        BOOL fullscreen = boolArgument(argc, argv, "fullscreen", YES);
        BOOL requireHardware = boolArgument(argc, argv, "require-hardware", YES);
        NSTimeInterval duration = doubleArgument(argc, argv, "duration", 120.0);
        NSUInteger maxFrames = integerArgument(argc, argv, "max-frames", 0);

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

        CandidateStressBenchmark *benchmark = [[CandidateStressBenchmark alloc] init];
        benchmark.presenter = presenter;
        benchmark.inputURL = inputURL;
        benchmark.outputPath = outputPath;
        benchmark.reportTitle = reportTitle;
        benchmark.codecDisplayName = codecName;
        benchmark.inflightLimit = MAX((NSUInteger)1, inflight);
        benchmark.requestedInflightLimit = benchmark.inflightLimit;
        benchmark.requireHardwareDecoder = requireHardware;
        benchmark.requestedDurationSeconds = duration;
        benchmark.maxSubmittedFrames = maxFrames;

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
