# Security Fixes Summary

This document summarizes the security vulnerabilities identified and fixed in the Refractometry IoT MVP project.

## Fixed Vulnerabilities

### 1. API Key Timing Attack (CRITICAL)
**Location**: `backend/app/middleware/auth.py`

**Issue**: API key comparison used `!=` operator, which is vulnerable to timing attacks. An attacker could determine the correct API key by measuring response times.

**Fix**: Replaced with constant-time comparison using `hmac.compare_digest()`.

**Before**:
```python
if not x_api_key or x_api_key != expected_key:
```

**After**:
```python
if not x_api_key or not constant_time_compare(x_api_key, expected_key):
```

### 2. Buffer Overflow Risks (HIGH)
**Location**: `device/c-client/src/main.c`, `device/c-client/src/http_client.c`

**Issue**: `snprintf()` return values were not checked, potentially allowing buffer overflows if inputs exceed buffer size.

**Fix**: Added return value checks and buffer overflow protection:
- Check `snprintf()` return value
- Validate buffer size before use
- Return error if buffer would overflow

**Example Fix**:
```c
int written = snprintf(buffer, buffer_size, ...);
if (written < 0 || (size_t)written >= buffer_size) {
    return -1; // Buffer overflow prevented
}
```

### 3. JSON Injection via device_id (HIGH)
**Location**: `device/c-client/src/main.c`

**Issue**: `device_id` parameter was used directly in JSON formatting without validation, allowing potential JSON injection attacks.

**Fix**: Added `validate_device_id()` function that:
- Checks length (max 255 characters)
- Rejects dangerous characters: `"`, `\`, `\n`, `\r`, `\t`
- Validates before JSON formatting

### 4. Queue File Race Condition (MEDIUM)
**Location**: `device/c-client/src/queue.c`

**Issue**: `queue_pop()` function had a race condition where it would:
1. Open file for reading
2. Close file
3. Open file for writing
4. Reopen file for reading again

This could cause data loss or corruption if multiple processes access the queue simultaneously.

**Fix**: Implemented atomic file operations using temporary file:
1. Read first line
2. Write remaining lines to temporary file
3. Atomically replace queue file with `rename()` (atomic on POSIX systems)

### 5. Missing TLS/SSL Verification (MEDIUM)
**Location**: `device/c-client/src/http_client.c`

**Issue**: C client did not enable SSL certificate verification, making HTTPS connections vulnerable to man-in-the-middle attacks.

**Fix**: Added SSL verification options:
```c
curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1L);
curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 2L);
```

**Note**: For production, always use HTTPS URLs. The client now verifies certificates when HTTPS is used.

### 6. Overly Permissive CORS Configuration (MEDIUM)
**Location**: `backend/app/main.py`

**Issue**: CORS middleware allowed all methods (`allow_methods=["*"]`) and all headers (`allow_headers=["*"]`), which is overly permissive.

**Fix**: Restricted to specific methods and headers:
```python
allow_methods=["GET", "POST"],  # Only necessary methods
allow_headers=["Content-Type", "X-API-Key"],  # Only necessary headers
```

## Security Best Practices Implemented

1. **Input Validation**: All user inputs are validated before processing
2. **Constant-Time Comparisons**: Sensitive comparisons use constant-time algorithms
3. **Buffer Overflow Protection**: All string operations check buffer sizes
4. **Atomic Operations**: File operations use atomic replacements
5. **TLS Verification**: SSL certificates are verified for HTTPS connections
6. **Principle of Least Privilege**: CORS restricted to minimum necessary permissions

## Remaining Considerations

### For Production Deployment

1. **Rate Limiting**: Consider adding rate limiting to API endpoints to prevent abuse
2. **HTTPS Only**: Ensure all production deployments use HTTPS (not HTTP)
3. **API Key Rotation**: Implement API key rotation mechanism
4. **Logging and Monitoring**: Add security event logging for failed authentication attempts
5. **Input Sanitization**: Additional validation for edge cases may be needed
6. **Queue Encryption**: Consider encrypting queue files if they contain sensitive data
7. **Certificate Pinning**: For mobile apps, consider certificate pinning

### Code Quality

- All fixes maintain backward compatibility
- Error handling improved throughout
- Code compiles without warnings (where dependencies are available)

## Testing Recommendations

1. **Penetration Testing**: Conduct security testing of API endpoints
2. **Fuzzing**: Test C client with malformed inputs
3. **Load Testing**: Verify queue operations under concurrent access
4. **TLS Testing**: Verify SSL certificate validation works correctly

## References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE-208: Observable Timing Discrepancy](https://cwe.mitre.org/data/definitions/208.html)
- [CWE-120: Buffer Copy without Checking Size](https://cwe.mitre.org/data/definitions/120.html)
- [CWE-79: Cross-site Scripting](https://cwe.mitre.org/data/definitions/79.html)
