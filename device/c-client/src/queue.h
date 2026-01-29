#ifndef QUEUE_H
#define QUEUE_H

#include <stddef.h>

/**
 * Queue management for offline readings.
 * 
 * Stores JSON lines to disk when device is offline,
 * flushes queued readings when connection is restored.
 */

/**
 * Append a reading JSON line to the queue file.
 * 
 * @param json_line JSON-formatted reading (must be valid JSON)
 * @return 0 on success, -1 on error
 */
int queue_append(const char *json_line);

/**
 * Read and remove the oldest queued reading.
 * 
 * @param buffer Output buffer for JSON line
 * @param buffer_size Size of buffer
 * @return Number of bytes read, 0 if queue empty, -1 on error
 */
int queue_pop(char *buffer, size_t buffer_size);

/**
 * Check if queue has any entries.
 * 
 * @return 1 if queue has entries, 0 if empty, -1 on error
 */
int queue_has_entries(void);

/**
 * Get count of queued entries.
 * 
 * @return Number of queued entries, -1 on error
 */
int queue_count(void);

/**
 * Clear the queue file.
 * 
 * @return 0 on success, -1 on error
 */
int queue_clear(void);

#endif /* QUEUE_H */
