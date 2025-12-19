# Token Management API Documentation

## Overview

The Token Management API provides endpoints for managing a pool of 100 pre-generated UUID tokens. The system ensures a maximum of 100 active tokens at any time, automatically releases tokens after 2 minutes of use, and maintains a complete usage history.

## Base URL

```
http://localhost:4000/api
```

## Authentication

Currently, the API does not require authentication. In production, you should add authentication middleware.

## Endpoints

### 1. Activate Token

Activates a token for use by a user. If 100 tokens are already active, the oldest active token is automatically released before activating a new one.

**Endpoint:** `POST /api/tokens/activate`

**Request Body:**
```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Success Response:** `200 OK`
```json
{
  "token_id": "c1ab147f-6908-496b-894f-2fa877022f56",
  "user_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Error Responses:**

- `400 Bad Request` - Invalid user_id format
```json
{
  "status": "bad_request",
  "message": "Invalid user_id format. Must be a valid UUID."
}
```

- `400 Bad Request` - Missing user_id
```json
{
  "status": "bad_request",
  "message": "Missing required parameter: user_id"
}
```

- `500 Internal Server Error` - No available tokens (should not happen)
```json
{
  "status": "internal_server_error",
  "message": "No available tokens. This should not happen."
}
```

**cURL Example:**
```bash
curl -X POST http://localhost:4000/api/tokens/activate \
  -H "Content-Type: application/json" \
  -d '{"user_id": "550e8400-e29b-41d4-a716-446655440000"}'
```

---

### 2. List Tokens

Retrieves a list of all tokens with optional state filtering.

**Endpoint:** `GET /api/tokens`

**Query Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `state` | string | No | `all` | Filter by state: `available`, `active`, or `all` |

**Success Response:** `200 OK`
```json
{
  "tokens": [
    {
      "token_id": "020e9a75-d971-41d3-b1f6-b9598aea463d",
      "state": "available",
      "current_user_id": null,
      "activated_at": null,
      "released_at": null
    },
    {
      "token_id": "c1ab147f-6908-496b-894f-2fa877022f56",
      "state": "active",
      "current_user_id": "550e8400-e29b-41d4-a716-446655440000",
      "activated_at": "2025-12-19T15:12:02Z",
      "released_at": null
    }
  ]
}
```

**Error Responses:**

- `400 Bad Request` - Invalid state filter
```json
{
  "status": "bad_request",
  "message": "Invalid state filter. Must be 'available', 'active', or 'all'."
}
```

**cURL Examples:**
```bash
# Get all tokens
curl http://localhost:4000/api/tokens

# Get only available tokens
curl http://localhost:4000/api/tokens?state=available

# Get only active tokens
curl http://localhost:4000/api/tokens?state=active
```

---

### 3. Get Token by ID

Retrieves detailed information about a specific token, including its usage count.

**Endpoint:** `GET /api/tokens/:token_id`

**Path Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `token_id` | UUID | Yes | The UUID of the token |

**Success Response:** `200 OK`
```json
{
  "token_id": "c1ab147f-6908-496b-894f-2fa877022f56",
  "state": "active",
  "current_user_id": "550e8400-e29b-41d4-a716-446655440000",
  "activated_at": "2025-12-19T15:12:02Z",
  "released_at": null,
  "usage_count": 5
}
```

**Error Responses:**

- `404 Not Found` - Token not found
```json
{
  "status": "not_found",
  "message": "Token not found"
}
```

**cURL Example:**
```bash
curl http://localhost:4000/api/tokens/c1ab147f-6908-496b-894f-2fa877022f56
```

---

### 4. Get Token Usage History

Retrieves the complete usage history for a specific token, showing all users who have used it.

**Endpoint:** `GET /api/tokens/:token_id/usages`

**Path Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `token_id` | UUID | Yes | The UUID of the token |

**Success Response:** `200 OK`
```json
{
  "token_id": "c1ab147f-6908-496b-894f-2fa877022f56",
  "usages": [
    {
      "user_id": "550e8400-e29b-41d4-a716-446655440000",
      "started_at": "2025-12-19T15:12:02Z",
      "ended_at": "2025-12-19T15:14:02Z"
    },
    {
      "user_id": "660e8400-e29b-41d4-a716-446655440001",
      "started_at": "2025-12-19T15:15:00Z",
      "ended_at": null
    }
  ]
}
```

**Note:** 
- History is ordered by `started_at` descending (most recent first)
- `ended_at` is `null` for currently active usages

**Error Responses:**

- `404 Not Found` - Token not found
```json
{
  "status": "not_found",
  "message": "Token not found"
}
```

**cURL Example:**
```bash
curl http://localhost:4000/api/tokens/c1ab147f-6908-496b-894f-2fa877022f56/usages
```

---

### 5. Clear Active Tokens

Releases all currently active tokens, making them available for use again.

**Endpoint:** `DELETE /api/tokens/active`

**Success Response:** `200 OK`
```json
{
  "cleared_count": 42,
  "status": "ok"
}
```

**Error Responses:**

- `500 Internal Server Error` - Failed to clear tokens
```json
{
  "status": "internal_server_error",
  "message": "Failed to process request: <reason>"
}
```

**cURL Example:**
```bash
curl -X DELETE http://localhost:4000/api/tokens/active
```

---

## Data Models

### Token Object

```json
{
  "token_id": "uuid-string",
  "state": "available|active",
  "current_user_id": "uuid-string|null",
  "activated_at": "ISO8601-datetime|null",
  "released_at": "ISO8601-datetime|null",
  "usage_count": 0
}
```

**Fields:**
- `token_id` (UUID, required): The unique identifier of the token
- `state` (string, required): Current state - `"available"` or `"active"`
- `current_user_id` (UUID, nullable): The user currently using the token (null if available)
- `activated_at` (datetime, nullable): When the token was last activated (ISO8601 format)
- `released_at` (datetime, nullable): When the token was last released (ISO8601 format)
- `usage_count` (integer, optional): Total number of times the token has been used

### Usage Object

```json
{
  "user_id": "uuid-string",
  "started_at": "ISO8601-datetime",
  "ended_at": "ISO8601-datetime|null"
}
```

**Fields:**
- `user_id` (UUID, required): The user who used the token
- `started_at` (datetime, required): When the usage started (ISO8601 format)
- `ended_at` (datetime, nullable): When the usage ended (ISO8601 format, null if still active)

### Error Object

```json
{
  "status": "error-code",
  "message": "Human-readable error message"
}
```

**Common Status Codes:**
- `bad_request`: Invalid input parameters
- `not_found`: Resource not found
- `internal_server_error`: Server error

---

## System Behavior

### Token Activation Rules

1. **Maximum Active Tokens**: The system maintains a maximum of 100 active tokens
2. **Automatic Release**: If 100 tokens are active and a new activation is requested:
   - The oldest active token (by `activated_at`) is automatically released
   - Then a new token is activated for the requesting user
3. **Token Lifetime**: Tokens are automatically released after 2 minutes of activation
4. **One User Per Token**: Only one user can actively use a token at a time

### Automatic Expiration

- Tokens are automatically released after **2 minutes** of activation
- A background process checks for expired tokens every **30 seconds**
- Expired tokens are released and returned to the available pool
- Usage history records are automatically closed when tokens expire

### Usage History

- Every token activation creates a usage record
- Usage records track: `user_id`, `started_at`, `ended_at`
- `ended_at` is `null` while the token is active
- `ended_at` is set when the token is released (manually or automatically)
- History is preserved even after tokens are released

---

## Error Handling

### HTTP Status Codes

| Code | Meaning | When It Occurs |
|------|---------|----------------|
| `200` | OK | Successful request |
| `400` | Bad Request | Invalid parameters or missing required fields |
| `404` | Not Found | Token not found |
| `500` | Internal Server Error | System error or unexpected failure |

### Error Response Format

All errors follow this structure:
```json
{
  "status": "error-code",
  "message": "Human-readable error message"
}
```

### Common Errors

#### Invalid UUID Format
```json
{
  "status": "bad_request",
  "message": "Invalid user_id format. Must be a valid UUID."
}
```

#### Missing Required Parameter
```json
{
  "status": "bad_request",
  "message": "Missing required parameter: user_id"
}
```

#### Token Not Found
```json
{
  "status": "not_found",
  "message": "Token not found"
}
```

#### Invalid State Filter
```json
{
  "status": "bad_request",
  "message": "Invalid state filter. Must be 'available', 'active', or 'all'."
}
```

---

## Examples

### Complete Workflow Example

```bash
# 1. Activate a token for a user
curl -X POST http://localhost:4000/api/tokens/activate \
  -H "Content-Type: application/json" \
  -d '{"user_id": "550e8400-e29b-41d4-a716-446655440000"}'

# Response:
# {
#   "token_id": "c1ab147f-6908-496b-894f-2fa877022f56",
#   "user_id": "550e8400-e29b-41d4-a716-446655440000"
# }

# 2. Get the token details
curl http://localhost:4000/api/tokens/c1ab147f-6908-496b-894f-2fa877022f56

# Response:
# {
#   "token_id": "c1ab147f-6908-496b-894f-2fa877022f56",
#   "state": "active",
#   "current_user_id": "550e8400-e29b-41d4-a716-446655440000",
#   "activated_at": "2025-12-19T15:12:02Z",
#   "released_at": null,
#   "usage_count": 1
# }

# 3. Get usage history
curl http://localhost:4000/api/tokens/c1ab147f-6908-496b-894f-2fa877022f56/usages

# Response:
# {
#   "token_id": "c1ab147f-6908-496b-894f-2fa877022f56",
#   "usages": [
#     {
#       "user_id": "550e8400-e29b-41d4-a716-446655440000",
#       "started_at": "2025-12-19T15:12:02Z",
#       "ended_at": null
#     }
#   ]
# }

# 4. List all active tokens
curl http://localhost:4000/api/tokens?state=active

# 5. Clear all active tokens (admin operation)
curl -X DELETE http://localhost:4000/api/tokens/active
```

### Error Handling Examples

```bash
# Invalid UUID format
curl -X POST http://localhost:4000/api/tokens/activate \
  -H "Content-Type: application/json" \
  -d '{"user_id": "invalid-uuid"}'

# Response: 400 Bad Request
# {
#   "status": "bad_request",
#   "message": "Invalid user_id format. Must be a valid UUID."
# }

# Missing user_id
curl -X POST http://localhost:4000/api/tokens/activate \
  -H "Content-Type: application/json" \
  -d '{}'

# Response: 400 Bad Request
# {
#   "status": "bad_request",
#   "message": "Missing required parameter: user_id"
# }

# Token not found
curl http://localhost:4000/api/tokens/00000000-0000-0000-0000-000000000000

# Response: 404 Not Found
# {
#   "status": "not_found",
#   "message": "Token not found"
# }
```

---

## Rate Limiting

Currently, there is no rate limiting implemented. In production, consider adding:
- Rate limiting per user/IP
- Request throttling
- API key authentication

---

## Best Practices

### 1. UUID Validation
- Always validate UUIDs on the client side before sending requests
- Use proper UUID v4 format: `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`

### 2. Error Handling
- Always check HTTP status codes
- Parse error messages for user-friendly display
- Handle network errors gracefully

### 3. Token Lifecycle
- Tokens automatically expire after 2 minutes
- Don't assume a token will remain active indefinitely
- Implement retry logic if a token becomes unavailable

### 4. Concurrent Requests
- The system handles concurrent activation requests safely
- Uses database-level locking to prevent race conditions
- Multiple users can request tokens simultaneously

### 5. Usage History
- History is preserved permanently
- Use history endpoints for auditing and analytics
- History shows all users who have used a token, not just the current one

---

## System Limits

- **Total Tokens**: 100 (fixed, pre-generated)
- **Maximum Active Tokens**: 100
- **Token Lifetime**: 2 minutes (automatic release)
- **Expiration Check Interval**: 30 seconds
- **Concurrent Users**: Up to 100 (one per token)

---

## Changelog

### Version 1.0.0 (Current)
- Initial API release
- All 5 endpoints implemented
- Automatic token expiration
- Usage history tracking
- RESTful endpoint naming

---

## Support

For issues or questions:
1. Check error messages for specific guidance
2. Verify UUID formats are correct
3. Ensure request body matches the expected format
4. Check system logs for detailed error information

---

## Future Enhancements

Potential improvements for future versions:
- Authentication and authorization
- Rate limiting per user
- Webhook notifications for token events
- Real-time status updates via WebSocket
- Pagination for large result sets
- Advanced filtering and sorting options
- Token reservation system
- Metrics and analytics endpoints

