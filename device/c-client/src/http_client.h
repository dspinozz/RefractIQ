#ifndef HTTP_CLIENT_H
#define HTTP_CLIENT_H

/**
 * HTTP client for posting readings to server.
 * 
 * Uses libcurl for HTTP requests.
 * For prototype: uses HTTP (TLS/HTTPS in production).
 */

/**
 * POST a JSON reading to the server.
 * 
 * @param server_url Base URL (e.g., "http://localhost:8000")
 * @param endpoint API endpoint (e.g., "/api/v1/readings")
 * @param json_body JSON payload
 * @return 0 on success (HTTP 201), -1 on error
 */
int http_post_reading(const char *server_url, const char *endpoint, const char *json_body);

#endif /* HTTP_CLIENT_H */
