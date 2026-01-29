#ifndef CONFIG_H
#define CONFIG_H

/* Server configuration */
#define DEFAULT_SERVER_URL "http://localhost:8000"
#define API_ENDPOINT "/api/v1/readings"

/* Queue configuration */
#define QUEUE_FILE "queue.log"
#define MAX_QUEUE_SIZE 1000
#define MAX_LINE_LENGTH 1024

/* HTTP configuration */
#define HTTP_TIMEOUT_SECONDS 10
#define USER_AGENT "RefractIoT-Client/1.0"

#endif /* CONFIG_H */
