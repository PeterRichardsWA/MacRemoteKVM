#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <sys/sysctl.h>

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

static NSString *fourCC(CMVideoCodecType codec) {
    char chars[5] = {
        (char)((codec >> 24) & 0xff),
        (char)((codec >> 16) & 0xff),
        (char)((codec >> 8) & 0xff),
        (char)(codec & 0xff),
        0
    };
    for (NSUInteger i = 0; i < 4; i++) {
        if (chars[i] < 32 || chars[i] > 126) {
            return [NSString stringWithFormat:@"0x%08x", codec];
        }
    }
    return [NSString stringWithUTF8String:chars] ?: @"????";
}

static NSString *yesNo(BOOL value) {
    return value ? @"yes" : @"no";
}

static void appendDecodeLine(NSMutableString *report, NSString *name, CMVideoCodecType codec) {
    Boolean supported = VTIsHardwareDecodeSupported(codec);
    [report appendFormat:@"| %@ | `%@` | %@ |\n", name, fourCC(codec), yesNo(supported)];
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *defaultOutput = @"/Users/peterrichards/dev/MacRemoteKVM/results/005-receiver-codec-capability/receiver-codec-capability.md";
        NSString *outputPath = stringArgument(argc, argv, "output", defaultOutput);

        NSProcessInfo *processInfo = NSProcessInfo.processInfo;
        NSMutableString *report = [NSMutableString string];
        [report appendString:@"# Experiment 005 Result: Receiver Codec Capability\n\n"];
        [report appendString:@"## Machine\n\n"];
        [report appendFormat:@"- Host name: %@\n", processInfo.hostName];
        [report appendFormat:@"- macOS: %@\n", processInfo.operatingSystemVersionString];
        [report appendFormat:@"- Hardware model: %@\n", sysctlString("hw.model")];
        [report appendFormat:@"- CPU brand: %@\n", sysctlString("machdep.cpu.brand_string")];
        [report appendFormat:@"- Processor count: %lu\n", (unsigned long)processInfo.processorCount];
        [report appendFormat:@"- Active processor count: %lu\n", (unsigned long)processInfo.activeProcessorCount];
        [report appendFormat:@"- Physical memory: %.2f GB\n", (double)processInfo.physicalMemory / 1024.0 / 1024.0 / 1024.0];

        [report appendString:@"\n## Hardware Decode Support\n\n"];
        [report appendString:@"| Codec | FourCC | Hardware Decode Supported |\n"];
        [report appendString:@"| --- | --- | --- |\n"];
        appendDecodeLine(report, @"H.264 / AVC", kCMVideoCodecType_H264);
        appendDecodeLine(report, @"HEVC / H.265", kCMVideoCodecType_HEVC);
        appendDecodeLine(report, @"HEVC with Alpha", kCMVideoCodecType_HEVCWithAlpha);
        appendDecodeLine(report, @"Apple ProRes 422 Proxy", kCMVideoCodecType_AppleProRes422Proxy);
        appendDecodeLine(report, @"Apple ProRes 422 LT", kCMVideoCodecType_AppleProRes422LT);
        appendDecodeLine(report, @"Apple ProRes 422", kCMVideoCodecType_AppleProRes422);
        appendDecodeLine(report, @"Apple ProRes 422 HQ", kCMVideoCodecType_AppleProRes422HQ);
        appendDecodeLine(report, @"JPEG", kCMVideoCodecType_JPEG);
        appendDecodeLine(report, @"AV1", kCMVideoCodecType_AV1);

        [report appendString:@"\n## Available VideoToolbox Encoders\n\n"];
        [report appendString:@"| Codec | FourCC | Encoder | Hardware |\n"];
        [report appendString:@"| --- | --- | --- | --- |\n"];
        CFArrayRef encoderList = NULL;
        OSStatus status = VTCopyVideoEncoderList(NULL, &encoderList);
        if (status == noErr && encoderList) {
            NSArray *encoders = CFBridgingRelease(encoderList);
            for (NSDictionary *encoder in encoders) {
                NSNumber *codecNumber = encoder[(__bridge NSString *)kVTVideoEncoderList_CodecType];
                NSString *name = encoder[(__bridge NSString *)kVTVideoEncoderList_EncoderName] ?: @"unknown";
                NSNumber *hardware = encoder[(__bridge NSString *)kVTVideoEncoderList_IsHardwareAccelerated];
                CMVideoCodecType codec = codecNumber ? codecNumber.unsignedIntValue : 0;
                [report appendFormat:@"| %@ | `%@` | %@ | %@ |\n",
                 fourCC(codec),
                 fourCC(codec),
                 name,
                 yesNo(hardware.boolValue)];
            }
        } else {
            [report appendFormat:@"\nCould not copy encoder list. Status: %d\n", status];
        }

        [report appendString:@"\n## Interpretation\n\n"];
        [report appendString:@"Run this probe on the actual Viewer iMac. Codec choices should be filtered by hardware decode support on that machine, not by sender-side encode speed alone.\n"];

        NSError *writeError = nil;
        BOOL wrote = [report writeToFile:outputPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
        if (!wrote) {
            fprintf(stderr, "Could not write report: %s\n", writeError.localizedDescription.UTF8String);
            return 1;
        }
        printf("Wrote report: %s\n", outputPath.UTF8String);
    }
    return 0;
}
