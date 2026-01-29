#include "queue.h"
#include "config.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

static const char *queue_path = QUEUE_FILE;

int queue_append(const char *json_line) {
    FILE *fp = fopen(queue_path, "a");
    if (!fp) {
        fprintf(stderr, "Error opening queue file: %s\n", strerror(errno));
        return -1;
    }
    
    fprintf(fp, "%s\n", json_line);
    fclose(fp);
    return 0;
}

int queue_pop(char *buffer, size_t buffer_size) {
    // Use temporary file to avoid race conditions
    char temp_path[512];
    snprintf(temp_path, sizeof(temp_path), "%s.tmp", queue_path);
    
    FILE *fp = fopen(queue_path, "r");
    if (!fp) {
        if (errno == ENOENT) {
            return 0; // Queue file doesn't exist = empty queue
        }
        fprintf(stderr, "Error opening queue file: %s\n", strerror(errno));
        return -1;
    }
    
    // Read first line
    if (fgets(buffer, buffer_size, fp) == NULL) {
        fclose(fp);
        return 0; // Empty file
    }
    
    // Remove newline if present
    size_t len = strlen(buffer);
    if (len > 0 && buffer[len - 1] == '\n') {
        buffer[len - 1] = '\0';
        len--;
    }
    
    // Read remaining lines into temporary file
    FILE *fp_write = fopen(temp_path, "w");
    if (!fp_write) {
        fclose(fp);
        fprintf(stderr, "Error creating temporary queue file: %s\n", strerror(errno));
        return -1;
    }
    
    char line[MAX_LINE_LENGTH];
    int first = 1;
    while (fgets(line, sizeof(line), fp)) {
        if (first) {
            first = 0;
            continue; // Skip first line (already read into buffer)
        }
        fputs(line, fp_write);
    }
    
    fclose(fp);
    fclose(fp_write);
    
    // Atomically replace queue file with temporary file
    if (rename(temp_path, queue_path) != 0) {
        fprintf(stderr, "Error replacing queue file: %s\n", strerror(errno));
        unlink(temp_path); // Clean up temp file
        return -1;
    }
    
    return len;
}

int queue_has_entries(void) {
    FILE *fp = fopen(queue_path, "r");
    if (!fp) {
        if (errno == ENOENT) {
            return 0; // File doesn't exist = empty
        }
        return -1;
    }
    
    int has_data = (fgetc(fp) != EOF);
    fclose(fp);
    return has_data ? 1 : 0;
}

int queue_count(void) {
    FILE *fp = fopen(queue_path, "r");
    if (!fp) {
        if (errno == ENOENT) {
            return 0;
        }
        return -1;
    }
    
    int count = 0;
    char line[MAX_LINE_LENGTH];
    while (fgets(line, sizeof(line), fp)) {
        count++;
    }
    fclose(fp);
    return count;
}

int queue_clear(void) {
    if (unlink(queue_path) == 0) {
        return 0;
    }
    if (errno == ENOENT) {
        return 0; // File doesn't exist, already cleared
    }
    return -1;
}
