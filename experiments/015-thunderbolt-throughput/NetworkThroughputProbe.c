#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <libkern/OSByteOrder.h>
#include <mach/mach_time.h>
#include <netdb.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

enum {
    MRKV015_MAGIC_PREFLIGHT = 0x4d545031,
    MRKV015_MAGIC_ACK = 0x4d544131,
    MRKV015_MAGIC_CONFIG = 0x4d544331,
    MRKV015_MAGIC_DONE = 0x4d544431,
    MRKV015_VERSION = 1
};

typedef struct __attribute__((packed)) {
    uint32_t magic;
    uint16_t version;
    uint16_t header_bytes;
    uint32_t case_index;
    uint32_t block_bytes;
    uint32_t duration_ms;
    uint32_t reserved;
} ControlHeader;

typedef struct __attribute__((packed)) {
    uint32_t magic;
    uint16_t version;
    uint16_t header_bytes;
    uint32_t case_index;
    uint32_t reserved;
    uint64_t bytes;
    uint64_t operations;
    uint64_t wall_nanos;
} DoneHeader;

typedef struct {
    int case_index;
    size_t block_bytes;
    double duration_seconds;
} ThroughputCase;

typedef struct {
    bool success;
    char failure[256];
    int case_index;
    size_t block_bytes;
    double duration_seconds;
    double preflight_ms;
    uint64_t bytes;
    uint64_t operations;
    double wall_seconds;
    uint64_t peer_bytes;
    uint64_t peer_operations;
    double peer_wall_seconds;
} ThroughputResult;

static uint64_t now_nanos(void) {
    static mach_timebase_info_data_t timebase;
    static bool initialized = false;
    if (!initialized) {
        mach_timebase_info(&timebase);
        initialized = true;
    }
    __uint128_t ticks = mach_absolute_time();
    ticks *= timebase.numer;
    ticks /= timebase.denom;
    return (uint64_t)ticks;
}

static double nanos_to_seconds(uint64_t nanos) {
    return (double)nanos / 1000000000.0;
}

static double nanos_to_ms(uint64_t nanos) {
    return (double)nanos / 1000000.0;
}

static void set_failure(ThroughputResult *result, const char *message) {
    if (!result) {
        return;
    }
    snprintf(result->failure, sizeof(result->failure), "%s", message);
}

static void sysctl_string(const char *name, char *buffer, size_t buffer_size) {
    if (!buffer || buffer_size == 0) {
        return;
    }
    snprintf(buffer, buffer_size, "unavailable");
    size_t size = 0;
    if (sysctlbyname(name, NULL, &size, NULL, 0) != 0 || size == 0) {
        return;
    }
    char *value = calloc(1, size);
    if (!value) {
        return;
    }
    if (sysctlbyname(name, value, &size, NULL, 0) == 0) {
        snprintf(buffer, buffer_size, "%s", value);
    }
    free(value);
}

static void mkdir_p(const char *path) {
    if (!path || path[0] == '\0') {
        return;
    }
    char copy[4096];
    snprintf(copy, sizeof(copy), "%s", path);
    size_t length = strlen(copy);
    if (length == 0) {
        return;
    }
    if (copy[length - 1] == '/') {
        copy[length - 1] = '\0';
    }
    for (char *cursor = copy + 1; *cursor; cursor++) {
        if (*cursor == '/') {
            *cursor = '\0';
            mkdir(copy, 0755);
            *cursor = '/';
        }
    }
    mkdir(copy, 0755);
}

static void mkdir_parent(const char *file_path) {
    char copy[4096];
    snprintf(copy, sizeof(copy), "%s", file_path);
    char *slash = strrchr(copy, '/');
    if (!slash) {
        return;
    }
    *slash = '\0';
    mkdir_p(copy);
}

static bool write_full(int fd, const void *bytes, size_t length) {
    const uint8_t *cursor = (const uint8_t *)bytes;
    size_t remaining = length;
    while (remaining > 0) {
        ssize_t wrote = write(fd, cursor, remaining);
        if (wrote < 0) {
            if (errno == EINTR) {
                continue;
            }
            return false;
        }
        if (wrote == 0) {
            return false;
        }
        cursor += (size_t)wrote;
        remaining -= (size_t)wrote;
    }
    return true;
}

static bool read_full(int fd, void *bytes, size_t length) {
    uint8_t *cursor = (uint8_t *)bytes;
    size_t remaining = length;
    while (remaining > 0) {
        ssize_t got = read(fd, cursor, remaining);
        if (got < 0) {
            if (errno == EINTR) {
                continue;
            }
            return false;
        }
        if (got == 0) {
            return false;
        }
        cursor += (size_t)got;
        remaining -= (size_t)got;
    }
    return true;
}

static ControlHeader control_to_wire(ControlHeader header) {
    header.magic = OSSwapHostToBigInt32(header.magic);
    header.version = OSSwapHostToBigInt16(header.version);
    header.header_bytes = OSSwapHostToBigInt16(header.header_bytes);
    header.case_index = OSSwapHostToBigInt32(header.case_index);
    header.block_bytes = OSSwapHostToBigInt32(header.block_bytes);
    header.duration_ms = OSSwapHostToBigInt32(header.duration_ms);
    header.reserved = OSSwapHostToBigInt32(header.reserved);
    return header;
}

static ControlHeader control_from_wire(ControlHeader header) {
    header.magic = OSSwapBigToHostInt32(header.magic);
    header.version = OSSwapBigToHostInt16(header.version);
    header.header_bytes = OSSwapBigToHostInt16(header.header_bytes);
    header.case_index = OSSwapBigToHostInt32(header.case_index);
    header.block_bytes = OSSwapBigToHostInt32(header.block_bytes);
    header.duration_ms = OSSwapBigToHostInt32(header.duration_ms);
    header.reserved = OSSwapBigToHostInt32(header.reserved);
    return header;
}

static DoneHeader done_to_wire(DoneHeader header) {
    header.magic = OSSwapHostToBigInt32(header.magic);
    header.version = OSSwapHostToBigInt16(header.version);
    header.header_bytes = OSSwapHostToBigInt16(header.header_bytes);
    header.case_index = OSSwapHostToBigInt32(header.case_index);
    header.reserved = OSSwapHostToBigInt32(header.reserved);
    header.bytes = OSSwapHostToBigInt64(header.bytes);
    header.operations = OSSwapHostToBigInt64(header.operations);
    header.wall_nanos = OSSwapHostToBigInt64(header.wall_nanos);
    return header;
}

static DoneHeader done_from_wire(DoneHeader header) {
    header.magic = OSSwapBigToHostInt32(header.magic);
    header.version = OSSwapBigToHostInt16(header.version);
    header.header_bytes = OSSwapBigToHostInt16(header.header_bytes);
    header.case_index = OSSwapBigToHostInt32(header.case_index);
    header.reserved = OSSwapBigToHostInt32(header.reserved);
    header.bytes = OSSwapBigToHostInt64(header.bytes);
    header.operations = OSSwapBigToHostInt64(header.operations);
    header.wall_nanos = OSSwapBigToHostInt64(header.wall_nanos);
    return header;
}

static bool write_control(int fd, uint32_t magic, ThroughputCase test_case) {
    ControlHeader header;
    memset(&header, 0, sizeof(header));
    header.magic = magic;
    header.version = MRKV015_VERSION;
    header.header_bytes = sizeof(header);
    header.case_index = (uint32_t)test_case.case_index;
    header.block_bytes = (uint32_t)test_case.block_bytes;
    header.duration_ms = (uint32_t)(test_case.duration_seconds * 1000.0 + 0.5);
    ControlHeader wire = control_to_wire(header);
    return write_full(fd, &wire, sizeof(wire));
}

static bool read_control(int fd, uint32_t expected_magic, ControlHeader *out) {
    ControlHeader wire;
    if (!read_full(fd, &wire, sizeof(wire))) {
        return false;
    }
    ControlHeader header = control_from_wire(wire);
    if (header.magic != expected_magic ||
        header.version != MRKV015_VERSION ||
        header.header_bytes != sizeof(ControlHeader)) {
        return false;
    }
    if (out) {
        *out = header;
    }
    return true;
}

static bool write_done(int fd, ThroughputResult result) {
    DoneHeader header;
    memset(&header, 0, sizeof(header));
    header.magic = MRKV015_MAGIC_DONE;
    header.version = MRKV015_VERSION;
    header.header_bytes = sizeof(header);
    header.case_index = (uint32_t)result.case_index;
    header.bytes = result.bytes;
    header.operations = result.operations;
    header.wall_nanos = (uint64_t)(result.wall_seconds * 1000000000.0);
    DoneHeader wire = done_to_wire(header);
    return write_full(fd, &wire, sizeof(wire));
}

static bool read_done(int fd, DoneHeader *out) {
    DoneHeader wire;
    if (!read_full(fd, &wire, sizeof(wire))) {
        return false;
    }
    DoneHeader header = done_from_wire(wire);
    if (header.magic != MRKV015_MAGIC_DONE ||
        header.version != MRKV015_VERSION ||
        header.header_bytes != sizeof(DoneHeader)) {
        return false;
    }
    if (out) {
        *out = header;
    }
    return true;
}

static int create_listener(uint16_t port) {
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
    if (listen(listener, 8) != 0) {
        close(listener);
        return -1;
    }
    return listener;
}

static int connect_to_host(const char *host, uint16_t port) {
    struct addrinfo hints;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;

    char port_string[16];
    snprintf(port_string, sizeof(port_string), "%u", port);
    struct addrinfo *results = NULL;
    int lookup = getaddrinfo(host, port_string, &hints, &results);
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

static void fill_payload(uint8_t *payload, size_t length, int case_index) {
    for (size_t i = 0; i < length; i++) {
        payload[i] = (uint8_t)((i * 31 + case_index * 17) & 0xff);
    }
}

static const char *case_slug(size_t block_bytes) {
    if (block_bytes == 64 * 1024) {
        return "64k";
    }
    if (block_bytes == 256 * 1024) {
        return "256k";
    }
    if (block_bytes == 1024 * 1024) {
        return "1m";
    }
    return "custom";
}

static void machine_report(FILE *file) {
    char hostname[256] = "unavailable";
    gethostname(hostname, sizeof(hostname));
    char model[256];
    char cpu[256];
    sysctl_string("hw.model", model, sizeof(model));
    sysctl_string("machdep.cpu.brand_string", cpu, sizeof(cpu));
    fprintf(file, "- Host name: %s\n", hostname);
    fprintf(file, "- Hardware model: %s\n", model);
    fprintf(file, "- CPU brand: %s\n", cpu);
}

static void write_sender_report(const char *output_dir, const char *host, uint16_t port, ThroughputResult result) {
    char path[4096];
    snprintf(path, sizeof(path), "%s/sender-throughput-%s.md", output_dir, case_slug(result.block_bytes));
    mkdir_parent(path);
    FILE *file = fopen(path, "w");
    if (!file) {
        fprintf(stderr, "Could not write sender report %s: errno %d\n", path, errno);
        return;
    }

    double mbps = result.wall_seconds > 0.0 ? (double)result.bytes * 8.0 / result.wall_seconds / 1000000.0 : 0.0;
    double mibps = result.wall_seconds > 0.0 ? (double)result.bytes / result.wall_seconds / 1048576.0 : 0.0;
    double peer_mbps = result.peer_wall_seconds > 0.0 ? (double)result.peer_bytes * 8.0 / result.peer_wall_seconds / 1000000.0 : 0.0;
    fprintf(file, "# Experiment 015 Sender Throughput Result: %s blocks\n\n", case_slug(result.block_bytes));
    fprintf(file, "## Machine\n\n");
    machine_report(file);
    fprintf(file, "\n## Sender Settings\n\n");
    fprintf(file, "- Destination: %s:%u\n", host, port);
    fprintf(file, "- Case index: %d\n", result.case_index);
    fprintf(file, "- Block size: %zu bytes\n", result.block_bytes);
    fprintf(file, "- Requested duration: %.3f seconds\n", result.duration_seconds);
    fprintf(file, "- Transport: single TCP stream\n");
    fprintf(file, "- Network preflight: %s\n", result.preflight_ms > 0.0 ? "passed before timed payload window" : "not completed");
    fprintf(file, "- Network preflight round trip: %.3f ms\n", result.preflight_ms);
    fprintf(file, "\n## Sender Result\n\n");
    fprintf(file, "- Success: %s\n", result.success ? "yes" : "no");
    if (result.failure[0]) {
        fprintf(file, "- Failure: %s\n", result.failure);
    }
    fprintf(file, "- Bytes sent: %llu\n", (unsigned long long)result.bytes);
    fprintf(file, "- Write operations: %llu\n", (unsigned long long)result.operations);
    fprintf(file, "- Sender wall time: %.6f seconds\n", result.wall_seconds);
    fprintf(file, "- Sender throughput: %.2f Mbps\n", mbps);
    fprintf(file, "- Sender throughput: %.2f MiB/s\n", mibps);
    fprintf(file, "- Receiver-confirmed bytes: %llu\n", (unsigned long long)result.peer_bytes);
    fprintf(file, "- Receiver read operations: %llu\n", (unsigned long long)result.peer_operations);
    fprintf(file, "- Receiver wall time: %.6f seconds\n", result.peer_wall_seconds);
    fprintf(file, "- Receiver-confirmed throughput: %.2f Mbps\n", peer_mbps);
    fprintf(file, "\n## Interpretation\n\n");
    fprintf(file, "This is raw single-stream TCP payload throughput after the network preflight handshake. It excludes Little Snitch or macOS permission time from the measured payload window.\n");
    fclose(file);
    printf("Wrote sender report: %s\n", path);
}

static void write_receiver_report(const char *output_dir, uint16_t port, ThroughputResult result) {
    char path[4096];
    snprintf(path, sizeof(path), "%s/receiver-throughput-%s.md", output_dir, case_slug(result.block_bytes));
    mkdir_parent(path);
    FILE *file = fopen(path, "w");
    if (!file) {
        fprintf(stderr, "Could not write receiver report %s: errno %d\n", path, errno);
        return;
    }

    double mbps = result.wall_seconds > 0.0 ? (double)result.bytes * 8.0 / result.wall_seconds / 1000000.0 : 0.0;
    double mibps = result.wall_seconds > 0.0 ? (double)result.bytes / result.wall_seconds / 1048576.0 : 0.0;
    fprintf(file, "# Experiment 015 Receiver Throughput Result: %s blocks\n\n", case_slug(result.block_bytes));
    fprintf(file, "## Machine\n\n");
    machine_report(file);
    fprintf(file, "\n## Receiver Settings\n\n");
    fprintf(file, "- Listen port: %u\n", port);
    fprintf(file, "- Case index: %d\n", result.case_index);
    fprintf(file, "- Block size: %zu bytes\n", result.block_bytes);
    fprintf(file, "- Requested sender duration: %.3f seconds\n", result.duration_seconds);
    fprintf(file, "- Transport: single TCP stream\n");
    fprintf(file, "- Network preflight: %s\n", result.preflight_ms > 0.0 ? "passed before timed payload window" : "not completed");
    fprintf(file, "- Network preflight handling time: %.3f ms\n", result.preflight_ms);
    fprintf(file, "\n## Receiver Result\n\n");
    fprintf(file, "- Success: %s\n", result.success ? "yes" : "no");
    if (result.failure[0]) {
        fprintf(file, "- Failure: %s\n", result.failure);
    }
    fprintf(file, "- Bytes received: %llu\n", (unsigned long long)result.bytes);
    fprintf(file, "- Read operations: %llu\n", (unsigned long long)result.operations);
    fprintf(file, "- Receiver wall time: %.6f seconds\n", result.wall_seconds);
    fprintf(file, "- Receiver throughput: %.2f Mbps\n", mbps);
    fprintf(file, "- Receiver throughput: %.2f MiB/s\n", mibps);
    fprintf(file, "\n## Interpretation\n\n");
    fprintf(file, "This is raw single-stream TCP payload throughput measured from the first payload read through EOF. It excludes the network preflight handshake from the measured payload window.\n");
    fclose(file);
    printf("Wrote receiver report: %s\n", path);
}

static void write_sender_summary(const char *output_dir, ThroughputResult *results, int count) {
    char path[4096];
    snprintf(path, sizeof(path), "%s/sender-summary.md", output_dir);
    mkdir_parent(path);
    FILE *file = fopen(path, "w");
    if (!file) {
        return;
    }
    fprintf(file, "# Experiment 015 Sender Throughput Summary\n\n");
    fprintf(file, "| Case | Block size | Sent bytes | Sender Mbps | Receiver Mbps | Preflight |\n");
    fprintf(file, "| --- | ---: | ---: | ---: | ---: | ---: |\n");
    for (int i = 0; i < count; i++) {
        double mbps = results[i].wall_seconds > 0.0 ? (double)results[i].bytes * 8.0 / results[i].wall_seconds / 1000000.0 : 0.0;
        double peer_mbps = results[i].peer_wall_seconds > 0.0 ? (double)results[i].peer_bytes * 8.0 / results[i].peer_wall_seconds / 1000000.0 : 0.0;
        fprintf(file, "| %s | %zu | %llu | %.2f | %.2f | %.3f ms |\n",
                case_slug(results[i].block_bytes),
                results[i].block_bytes,
                (unsigned long long)results[i].bytes,
                mbps,
                peer_mbps,
                results[i].preflight_ms);
    }
    fclose(file);
    printf("Wrote sender summary: %s\n", path);
}

static void write_receiver_summary(const char *output_dir, ThroughputResult *results, int count) {
    char path[4096];
    snprintf(path, sizeof(path), "%s/receiver-summary.md", output_dir);
    mkdir_parent(path);
    FILE *file = fopen(path, "w");
    if (!file) {
        return;
    }
    fprintf(file, "# Experiment 015 Receiver Throughput Summary\n\n");
    fprintf(file, "| Case | Block size | Received bytes | Receiver Mbps | Receiver MiB/s | Preflight |\n");
    fprintf(file, "| --- | ---: | ---: | ---: | ---: | ---: |\n");
    for (int i = 0; i < count; i++) {
        double mbps = results[i].wall_seconds > 0.0 ? (double)results[i].bytes * 8.0 / results[i].wall_seconds / 1000000.0 : 0.0;
        double mibps = results[i].wall_seconds > 0.0 ? (double)results[i].bytes / results[i].wall_seconds / 1048576.0 : 0.0;
        fprintf(file, "| %s | %zu | %llu | %.2f | %.2f | %.3f ms |\n",
                case_slug(results[i].block_bytes),
                results[i].block_bytes,
                (unsigned long long)results[i].bytes,
                mbps,
                mibps,
                results[i].preflight_ms);
    }
    fclose(file);
    printf("Wrote receiver summary: %s\n", path);
}

static bool sender_preflight(int fd, ThroughputResult *result) {
    ThroughputCase empty_case = {0};
    uint64_t start = now_nanos();
    if (!write_control(fd, MRKV015_MAGIC_PREFLIGHT, empty_case)) {
        set_failure(result, "could not write preflight packet");
        return false;
    }
    ControlHeader ack;
    if (!read_control(fd, MRKV015_MAGIC_ACK, &ack)) {
        set_failure(result, "could not read preflight ack");
        return false;
    }
    result->preflight_ms = nanos_to_ms(now_nanos() - start);
    return true;
}

static bool receiver_preflight(int fd, ThroughputResult *result) {
    uint64_t start = now_nanos();
    ControlHeader preflight;
    if (!read_control(fd, MRKV015_MAGIC_PREFLIGHT, &preflight)) {
        set_failure(result, "could not read preflight packet");
        return false;
    }
    ThroughputCase empty_case = {0};
    if (!write_control(fd, MRKV015_MAGIC_ACK, empty_case)) {
        set_failure(result, "could not write preflight ack");
        return false;
    }
    result->preflight_ms = nanos_to_ms(now_nanos() - start);
    return true;
}

static ThroughputResult run_sender_case(const char *host, uint16_t port, ThroughputCase test_case) {
    ThroughputResult result;
    memset(&result, 0, sizeof(result));
    result.case_index = test_case.case_index;
    result.block_bytes = test_case.block_bytes;
    result.duration_seconds = test_case.duration_seconds;

    int fd = connect_to_host(host, port);
    if (fd < 0) {
        snprintf(result.failure, sizeof(result.failure), "could not connect to %s:%u: errno %d", host, port, errno);
        return result;
    }

    if (!sender_preflight(fd, &result)) {
        close(fd);
        return result;
    }
    if (!write_control(fd, MRKV015_MAGIC_CONFIG, test_case)) {
        set_failure(&result, "could not write test config");
        close(fd);
        return result;
    }
    ControlHeader ready;
    if (!read_control(fd, MRKV015_MAGIC_ACK, &ready)) {
        set_failure(&result, "could not read ready ack");
        close(fd);
        return result;
    }

    uint8_t *payload = malloc(test_case.block_bytes);
    if (!payload) {
        set_failure(&result, "could not allocate payload buffer");
        close(fd);
        return result;
    }
    fill_payload(payload, test_case.block_bytes, test_case.case_index);

    uint64_t start = now_nanos();
    uint64_t deadline = start + (uint64_t)(test_case.duration_seconds * 1000000000.0);
    while (now_nanos() < deadline) {
        if (!write_full(fd, payload, test_case.block_bytes)) {
            snprintf(result.failure, sizeof(result.failure), "payload write failed: errno %d", errno);
            break;
        }
        result.bytes += test_case.block_bytes;
        result.operations += 1;
    }
    result.wall_seconds = nanos_to_seconds(now_nanos() - start);
    free(payload);

    shutdown(fd, SHUT_WR);
    DoneHeader done;
    if (read_done(fd, &done)) {
        result.peer_bytes = done.bytes;
        result.peer_operations = done.operations;
        result.peer_wall_seconds = nanos_to_seconds(done.wall_nanos);
    }
    close(fd);
    result.success = result.failure[0] == '\0' && result.bytes > 0 && result.peer_bytes == result.bytes;
    return result;
}

static ThroughputResult run_receiver_case(int accepted) {
    ThroughputResult result;
    memset(&result, 0, sizeof(result));
    if (!receiver_preflight(accepted, &result)) {
        return result;
    }

    ControlHeader config;
    if (!read_control(accepted, MRKV015_MAGIC_CONFIG, &config)) {
        set_failure(&result, "could not read test config");
        return result;
    }
    result.case_index = (int)config.case_index;
    result.block_bytes = config.block_bytes;
    result.duration_seconds = (double)config.duration_ms / 1000.0;

    ThroughputCase ack_case = {
        .case_index = result.case_index,
        .block_bytes = result.block_bytes,
        .duration_seconds = result.duration_seconds
    };
    if (!write_control(accepted, MRKV015_MAGIC_ACK, ack_case)) {
        set_failure(&result, "could not write ready ack");
        return result;
    }

    uint8_t *buffer = malloc(result.block_bytes);
    if (!buffer) {
        set_failure(&result, "could not allocate receive buffer");
        return result;
    }

    uint64_t start = 0;
    uint64_t end = 0;
    while (true) {
        ssize_t got = read(accepted, buffer, result.block_bytes);
        if (got < 0) {
            if (errno == EINTR) {
                continue;
            }
            snprintf(result.failure, sizeof(result.failure), "payload read failed: errno %d", errno);
            break;
        }
        if (got == 0) {
            end = now_nanos();
            break;
        }
        if (start == 0) {
            start = now_nanos();
        }
        result.bytes += (uint64_t)got;
        result.operations += 1;
    }
    free(buffer);
    if (start > 0 && end >= start) {
        result.wall_seconds = nanos_to_seconds(end - start);
    }
    result.success = result.failure[0] == '\0' && result.bytes > 0;
    write_done(accepted, result);
    return result;
}

static uint16_t uint16_option(int argc, const char *argv[], const char *name, uint16_t default_value) {
    char prefix[64];
    snprintf(prefix, sizeof(prefix), "--%s=", name);
    for (int i = 1; i < argc; i++) {
        if (strncmp(argv[i], prefix, strlen(prefix)) == 0) {
            long value = strtol(argv[i] + strlen(prefix), NULL, 10);
            if (value > 0 && value <= 65535) {
                return (uint16_t)value;
            }
        }
    }
    return default_value;
}

static int int_option(int argc, const char *argv[], const char *name, int default_value) {
    char prefix[64];
    snprintf(prefix, sizeof(prefix), "--%s=", name);
    for (int i = 1; i < argc; i++) {
        if (strncmp(argv[i], prefix, strlen(prefix)) == 0) {
            return (int)strtol(argv[i] + strlen(prefix), NULL, 10);
        }
    }
    return default_value;
}

static double double_option(int argc, const char *argv[], const char *name, double default_value) {
    char prefix[64];
    snprintf(prefix, sizeof(prefix), "--%s=", name);
    for (int i = 1; i < argc; i++) {
        if (strncmp(argv[i], prefix, strlen(prefix)) == 0) {
            return strtod(argv[i] + strlen(prefix), NULL);
        }
    }
    return default_value;
}

static const char *string_option(int argc, const char *argv[], const char *name, const char *default_value) {
    char prefix[64];
    snprintf(prefix, sizeof(prefix), "--%s=", name);
    for (int i = 1; i < argc; i++) {
        if (strncmp(argv[i], prefix, strlen(prefix)) == 0) {
            return argv[i] + strlen(prefix);
        }
    }
    return default_value;
}

static ThroughputCase case_for_index(int index, double duration) {
    size_t blocks[] = {64 * 1024, 256 * 1024, 1024 * 1024};
    size_t block = blocks[(index - 1) % 3];
    ThroughputCase test_case = {
        .case_index = index,
        .block_bytes = block,
        .duration_seconds = duration
    };
    return test_case;
}

static int run_sender(int argc, const char *argv[]) {
    const char *host = argc > 2 ? argv[2] : "";
    if (!host || host[0] == '\0') {
        fprintf(stderr, "sender mode needs a receiver host/IP\n");
        return 1;
    }
    uint16_t port = uint16_option(argc, argv, "port", 49330);
    int cases = int_option(argc, argv, "cases", 3);
    double duration = double_option(argc, argv, "duration", 10.0);
    const char *output_dir = string_option(argc, argv, "output-dir", "results/sender");
    mkdir_p(output_dir);

    ThroughputResult *results = calloc((size_t)cases, sizeof(ThroughputResult));
    bool all_ok = true;
    for (int i = 0; i < cases; i++) {
        ThroughputCase test_case = case_for_index(i + 1, duration);
        printf("Running sender case %d/%d: %s blocks for %.1fs...\n", i + 1, cases, case_slug(test_case.block_bytes), duration);
        results[i] = run_sender_case(host, port, test_case);
        write_sender_report(output_dir, host, port, results[i]);
        all_ok = all_ok && results[i].success;
    }
    write_sender_summary(output_dir, results, cases);
    free(results);
    return all_ok ? 0 : 2;
}

static int run_receiver(int argc, const char *argv[]) {
    uint16_t port = uint16_option(argc, argv, "port", 49330);
    int cases = int_option(argc, argv, "cases", 3);
    const char *output_dir = string_option(argc, argv, "output-dir", "results/receiver");
    mkdir_p(output_dir);

    int listener = create_listener(port);
    if (listener < 0) {
        fprintf(stderr, "Could not listen on port %u: errno %d\n", port, errno);
        return 1;
    }
    printf("Receiver listening on port %u for %d throughput case(s).\n", port, cases);

    ThroughputResult *results = calloc((size_t)cases, sizeof(ThroughputResult));
    bool all_ok = true;
    for (int i = 0; i < cases; i++) {
        printf("Waiting for throughput case %d/%d...\n", i + 1, cases);
        int accepted = accept(listener, NULL, NULL);
        if (accepted < 0) {
            fprintf(stderr, "Accept failed: errno %d\n", errno);
            all_ok = false;
            break;
        }
        int yes = 1;
        setsockopt(accepted, IPPROTO_TCP, TCP_NODELAY, &yes, sizeof(yes));
        setsockopt(accepted, SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof(yes));
        results[i] = run_receiver_case(accepted);
        write_receiver_report(output_dir, port, results[i]);
        close(accepted);
        all_ok = all_ok && results[i].success;
    }
    close(listener);
    write_receiver_summary(output_dir, results, cases);
    free(results);
    return all_ok ? 0 : 2;
}

int main(int argc, const char *argv[]) {
    const char *mode = argc > 1 ? argv[1] : "usage";
    if (strcmp(mode, "receiver") == 0 || strcmp(mode, "receive") == 0) {
        return run_receiver(argc, argv);
    }
    if (strcmp(mode, "sender") == 0 || strcmp(mode, "send") == 0) {
        return run_sender(argc, argv);
    }
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, "  NetworkThroughputProbe receiver --port=49330 --cases=3 --output-dir=results/receiver\n");
    fprintf(stderr, "  NetworkThroughputProbe sender <receiver-host-or-ip> --port=49330 --cases=3 --duration=10 --output-dir=results/sender\n");
    return 1;
}
