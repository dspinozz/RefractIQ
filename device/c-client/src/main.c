/**
 * Refractometry IoT Device Client
 * 
 * Minimal C client demonstrating:
 * - HTTPS POST to ingest endpoint
 * - Offline queue management
 * - Store-and-forward behavior
 * 
 * Positioned as "reference connectivity client" / "connectivity harness"
 * rather than full firmware implementation.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <getopt.h>
#include <curl/curl.h>
#include "config.h"
#include "http_client.h"
#include "queue.h"

/* Initialize curl globally */
static void init_curl(void) {
    curl_global_init(CURL_GLOBAL_DEFAULT);
}

static void cleanup_curl(void) {
    curl_global_cleanup();
}

/* Validate and sanitize device_id to prevent JSON injection */
static int validate_device_id(const char *device_id) {
    if (!device_id) {
        return 0;
    }
    // Check length (reasonable limit)
    if (strlen(device_id) > 255) {
        return 0;
    }
    // Check for dangerous characters that could break JSON
    const char *dangerous = "\"\\\n\r\t";
    for (const char *p = device_id; *p; p++) {
        if (strchr(dangerous, *p) != NULL) {
            return 0;
        }
    }
    return 1;
}

/* Generate a reading JSON payload with buffer overflow protection */
static int create_reading_json(char *buffer, size_t buffer_size,
                               const char *device_id, double value, const char *unit,
                               double temperature_c) {
    // Validate inputs
    if (!validate_device_id(device_id)) {
        return -1;
    }
    
    if (strcmp(unit, "RI") != 0 && strcmp(unit, "Brix") != 0) {
        return -1;
    }
    
    time_t now = time(NULL);
    char timestamp[64];
    struct tm *tm_info = gmtime(&now);
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%dT%H:%M:%SZ", tm_info);
    
    int written = snprintf(buffer, buffer_size,
                    "{\"device_id\":\"%s\",\"ts\":\"%s\",\"value\":%.4f,\"unit\":\"%s\",\"temperature_c\":%.2f}",
                    device_id, timestamp, value, unit, temperature_c);
    
    // Check for buffer overflow
    if (written < 0 || (size_t)written >= buffer_size) {
        return -1;
    }
    
    return written;
}

/* Flush queued readings */
static int flush_queue(const char *server_url) {
    int flushed = 0;
    char queued_json[MAX_LINE_LENGTH];
    
    printf("Flushing queued readings...\n");
    
    while (queue_has_entries() == 1) {
        int len = queue_pop(queued_json, sizeof(queued_json));
        if (len <= 0) {
            break;
        }
        
        printf("Sending queued reading: %s\n", queued_json);
        
        if (http_post_reading(server_url, API_ENDPOINT, queued_json) == 0) {
            flushed++;
            printf("Successfully sent queued reading\n");
        } else {
            // Failed to send - put it back at front of queue
            // (Simplified: in production, use a proper queue with retry logic)
            fprintf(stderr, "Failed to send queued reading, will retry later\n");
            queue_append(queued_json);
            break;
        }
    }
    
    if (flushed > 0) {
        printf("Flushed %d queued reading(s)\n", flushed);
    }
    
    return flushed;
}

/* Send a single reading */
static int send_reading(const char *server_url, const char *device_id,
                        double value, const char *unit, double temperature_c) {
    char json_payload[512];
    int result = create_reading_json(json_payload, sizeof(json_payload), device_id, value, unit, temperature_c);
    
    if (result < 0) {
        fprintf(stderr, "Error: Failed to create JSON payload (buffer overflow or invalid input)\n");
        return -1;
    }
    
    printf("Sending reading: %s\n", json_payload);
    
    if (http_post_reading(server_url, API_ENDPOINT, json_payload) == 0) {
        printf("Successfully sent reading\n");
        return 0;
    } else {
        printf("Failed to send reading, queuing for later\n");
        queue_append(json_payload);
        return -1;
    }
}

static void print_usage(const char *prog_name) {
    printf("Usage: %s [OPTIONS]\n", prog_name);
    printf("\n");
    printf("Options:\n");
    printf("  -d, --device-id ID     Device identifier (required)\n");
    printf("  -v, --value VALUE      Reading value (required)\n");
    printf("  -u, --unit UNIT        Unit: 'RI' or 'Brix' (required)\n");
    printf("  -t, --temp TEMP        Temperature in Celsius (optional)\n");
    printf("  -s, --server URL       Server URL (default: %s)\n", DEFAULT_SERVER_URL);
    printf("  -f, --flush            Flush queued readings only\n");
    printf("  -h, --help             Show this help\n");
    printf("\n");
    printf("Example:\n");
    printf("  %s -d DEV001 -v 1.3330 -u RI -t 25.0\n", prog_name);
}

int main(int argc, char *argv[]) {
    const char *device_id = NULL;
    double value = 0.0;
    const char *unit = NULL;
    double temperature_c = 25.0; // Default
    const char *server_url = DEFAULT_SERVER_URL;
    int flush_only = 0;
    
    static struct option long_options[] = {
        {"device-id", required_argument, 0, 'd'},
        {"value", required_argument, 0, 'v'},
        {"unit", required_argument, 0, 'u'},
        {"temp", required_argument, 0, 't'},
        {"server", required_argument, 0, 's'},
        {"flush", no_argument, 0, 'f'},
        {"help", no_argument, 0, 'h'},
        {0, 0, 0, 0}
    };
    
    int opt;
    while ((opt = getopt_long(argc, argv, "d:v:u:t:s:fh", long_options, NULL)) != -1) {
        switch (opt) {
            case 'd':
                device_id = optarg;
                break;
            case 'v':
                value = atof(optarg);
                break;
            case 'u':
                unit = optarg;
                break;
            case 't':
                temperature_c = atof(optarg);
                break;
            case 's':
                server_url = optarg;
                break;
            case 'f':
                flush_only = 1;
                break;
            case 'h':
                print_usage(argv[0]);
                return 0;
            default:
                print_usage(argv[0]);
                return 1;
        }
    }
    
    init_curl();
    
    if (flush_only) {
        int flushed = flush_queue(server_url);
        cleanup_curl();
        return (flushed >= 0) ? 0 : 1;
    }
    
    // Validate required arguments
    if (!device_id || !unit) {
        fprintf(stderr, "Error: device-id and unit are required\n");
        print_usage(argv[0]);
        cleanup_curl();
        return 1;
    }
    
    // Validate device_id format (prevent injection)
    if (!validate_device_id(device_id)) {
        fprintf(stderr, "Error: device-id contains invalid characters or is too long\n");
        cleanup_curl();
        return 1;
    }
    
    if (strcmp(unit, "RI") != 0 && strcmp(unit, "Brix") != 0) {
        fprintf(stderr, "Error: unit must be 'RI' or 'Brix'\n");
        cleanup_curl();
        return 1;
    }
    
    // First, try to flush any queued readings
    flush_queue(server_url);
    
    // Then send current reading
    int result = send_reading(server_url, device_id, value, unit, temperature_c);
    
    cleanup_curl();
    return (result == 0) ? 0 : 1;
}
