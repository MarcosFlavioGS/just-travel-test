# Token Management System - Architecture Plan

## Overview
A robust token management system that maintains exactly 100 pre-generated UUID tokens, with a maximum of 100 active tokens at any time, automatic release after 2 minutes, and automatic oldest-token release when the limit is reached.

## Requirements Summary

1. **100 Unique Tokens**: Pre-generated UUIDs stored in database
2. **Activation Limit**: Maximum 100 active tokens simultaneously
3. **Lifetime**: Tokens auto-release after 2 minutes of activation
4. **Availability Management**: When limit reached, oldest active token is released
5. **Token Usage**: Only 1 active utilizer (UUID) per token at a time
6. **Auto-release Mechanisms**:
   - Supervised process for 2-minute timeout monitoring
   - Periodic job to release oldest token when limit reached

## Architecture Layers

### 1. Database Layer

#### Schema: `Token`
```elixir
- id: UUID (primary key, the token itself)
- state: :available | :active (atom)
- utilizer_uuid: UUID (nullable, tracks current active user)
- activated_at: DateTime (nullable, timestamp when token was activated)
- released_at: DateTime (nullable, timestamp when token was released)
- inserted_at: DateTime
- updated_at: DateTime
```

#### Schema: `TokenUsage` (History Tracking)
```elixir
- id: UUID (primary key)
- token_id: UUID (foreign key to tokens)
- user_id: UUID (the user who used the token)
- started_at: DateTime (when token was activated for this user)
- ended_at: DateTime (nullable, when token was released for this user)
- inserted_at: DateTime
- updated_at: DateTime
```

#### Migration Strategy
- Create `tokens` table with above fields
- Create `token_usages` table with above fields
- Add indexes:
  - `tokens.state` - for quick filtering
  - `tokens.activated_at` - for finding oldest active token
  - `token_usages.token_id` - for querying history by token
  - `token_usages.user_id` - for querying history by user
  - `token_usages.started_at` - for ordering history chronologically
  - Unique constraint on `tokens.id` (UUID)

#### Seeds
- Generate 100 UUID tokens
- Insert all with `state: :available`

### 2. Context Layer (`JustTravelTest.Tokens`)

#### Core Functions

**Token Activation:**
- `register_token_usage(user_id)` - Main entry point (renamed from activate_token)
  - Checks if available tokens exist
  - If limit reached (100 active), releases oldest token first
  - Activates token with user_id and timestamp
  - Creates a new `TokenUsage` record with `started_at` (ended_at is null while active)
  - Returns `{:ok, %{token_id: uuid, user_id: uuid}}` or `{:error, reason}`

**Token Release:**
- `release_token(token_id)` - Manual release
  - Sets token state to `:available`
  - Updates the active `TokenUsage` record with `ended_at` timestamp
- `release_token_by_user(user_id)` - Release token by user
- `release_oldest_active_token()` - Internal function for limit management
  - Also closes the associated `TokenUsage` record
- `clear_all_active_tokens()` - Release all active tokens
  - Sets all active tokens to `:available`
  - Closes all open `TokenUsage` records

**Query Functions:**
- `list_all_tokens()` - Get all tokens with their current state
  - Returns tokens with current user info if active
- `list_available_tokens()` - Get all available tokens
- `list_active_tokens()` - Get all active tokens
- `get_token_by_id(token_id)` - Get specific token with current state
- `get_token_by_user(user_id)` - Get active token for a user
- `count_active_tokens()` - Count active tokens
- `count_available_tokens()` - Count available tokens

**Usage History:**
- `get_token_usage_history(token_id)` - Get all usage records for a token
  - Returns ordered list of `TokenUsage` records
  - Includes user_id, started_at, ended_at for each usage

**Expired Token Management:**
- `find_expired_tokens()` - Find tokens active > 2 minutes
- `release_expired_tokens()` - Release all expired tokens
  - Also closes associated `TokenUsage` records

### 3. Supervised Process Layer

#### GenServer: `JustTravelTest.Tokens.Manager`

**Purpose**: Monitor and auto-release tokens based on time limits

**State:**
- Timer reference for periodic checks
- Configuration (check interval, token lifetime)

**Functions:**
- `start_link/1` - Start the GenServer
- `check_and_release_expired/0` - Check for expired tokens and release them
- `schedule_next_check/1` - Schedule next periodic check

**Behavior:**
- Runs periodic check every 30 seconds (configurable)
- Finds tokens active > 2 minutes
- Releases them automatically
- Handles GenServer lifecycle

#### Integration with Application Supervisor
- Add `JustTravelTest.Tokens.Manager` to `application.ex` children

### 4. Business Logic Flow

#### Token Registration Flow:
```
1. User requests token with user_id
2. Check count of active tokens
3. If count >= 100:
   a. Find oldest active token (by activated_at)
   b. Release it:
      - Set state: :available
      - Clear utilizer_uuid
      - Set released_at to now
      - Update TokenUsage record: set ended_at to now
4. Find first available token
5. Activate it:
   - Set state: :active
   - Set utilizer_uuid to user_id
   - Set activated_at to now
6. Create TokenUsage record:
   - token_id: the activated token
   - user_id: the requesting user
   - started_at: now
   - ended_at: null (will be set on release)
7. Return token_id and user_id
```

#### Auto-Release Flow (2-minute timeout):
```
1. Periodic job runs every 30 seconds
2. Query tokens where:
   - state = :active
   - activated_at < (now - 2 minutes)
3. For each expired token:
   - Set state: :available
   - Clear utilizer_uuid
   - Set released_at to now
   - Update TokenUsage record: set ended_at to now
4. Log releases if needed
```

### 5. API/Web Layer

#### JSON API Endpoints (RESTful)

**1. Register Token Usage**
- **Endpoint**: `POST /api/tokens/use`
- **Request Body**: 
  ```json
  {
    "user_id": "uuid-string"
  }
  ```
- **Response** (200 OK):
  ```json
  {
    "token_id": "uuid-string",
    "user_id": "uuid-string"
  }
  ```
- **Error Responses**:
  - `400 Bad Request`: Invalid user_id format
  - `500 Internal Server Error`: System error

**2. List All Available and Used Tokens**
- **Endpoint**: `GET /api/tokens`
- **Query Parameters** (optional):
  - `state`: `available` | `active` | `all` (default: `all`)
- **Response** (200 OK):
  ```json
  {
    "tokens": [
      {
        "token_id": "uuid-string",
        "state": "available|active",
        "current_user_id": "uuid-string|null",
        "activated_at": "2024-01-01T12:00:00Z|null",
        "released_at": "2024-01-01T12:05:00Z|null"
      }
    ]
  }
  ```

**3. Query a Specific Token and Its User**
- **Endpoint**: `GET /api/tokens/:token_id`
- **Response** (200 OK):
  ```json
  {
    "token_id": "uuid-string",
    "state": "available|active",
    "current_user_id": "uuid-string|null",
    "activated_at": "2024-01-01T12:00:00Z|null",
    "released_at": "2024-01-01T12:05:00Z|null",
    "usage_count": 5
  }
  ```
- **Error Responses**:
  - `404 Not Found`: Token not found

**4. Query the Usage History of a Specific Token**
- **Endpoint**: `GET /api/tokens/:token_id/history`
- **Response** (200 OK):
  ```json
  {
    "token_id": "uuid-string",
    "history": [
      {
        "user_id": "uuid-string",
        "started_at": "2024-01-01T12:00:00Z",
        "ended_at": "2024-01-01T12:02:00Z|null"
      }
    ]
  }
  ```
- **Note**: History ordered by `started_at` descending (most recent first)
- **Error Responses**:
  - `404 Not Found`: Token not found

**5. Clear Active Tokens**
- **Endpoint**: `POST /api/tokens/clear_active`
- **Response** (200 OK):
  ```json
  {
    "cleared_count": 42,
    "status": "ok"
  }
  ```
- **Behavior**: Releases all currently active tokens and closes their usage records

#### Optional: LiveView Dashboard
- Real-time view of token status
- List active/available tokens
- Manual release controls
- View usage history

### 6. Testing Strategy

#### Unit Tests
- Context functions (activate, release, queries)
- Edge cases (exactly 100 active, no available tokens, etc.)

#### Integration Tests
- GenServer periodic job behavior
- Database transactions
- Concurrent activation requests

#### Test Helpers
- Factory functions for creating tokens
- Helper to advance time for expiration testing

## File Structure

```
lib/
  just_travel_test/
    tokens/
      manager.ex          # GenServer for auto-release
      context.ex          # Main context module
    schemas/
      token.ex            # Ecto schema for Token
      token_usage.ex      # Ecto schema for TokenUsage
  just_travel_test_web/
    controllers/
      token_controller.ex # API endpoints
    live/
      token_dashboard_live.ex  # Optional LiveView dashboard

priv/repo/migrations/
  YYYYMMDDHHMMSS_create_tokens.exs
  YYYYMMDDHHMMSS_create_token_usages.exs

test/
  just_travel_test/
    tokens/
      context_test.exs
      manager_test.exs
  just_travel_test_web/
    controllers/
      token_controller_test.exs
  support/
    token_factory.ex      # Test helpers
```

## Implementation Order

1. **Database Layer**
   - Create `tokens` migration
   - Create `token_usages` migration
   - Create Token schema
   - Create TokenUsage schema
   - Update seeds.exs to generate 100 tokens

2. **Context Layer**
   - Implement basic CRUD operations for tokens
   - Implement usage history tracking
   - Implement `register_token_usage/1` with limit management
   - Implement release logic (single and bulk)
   - Implement expired token queries
   - Implement history query functions

3. **Supervised Process**
   - Create GenServer for periodic checks
   - Integrate with application supervisor
   - Test auto-release functionality

4. **API Layer**
   - Create JSON API endpoints:
     - POST /api/tokens/use
     - GET /api/tokens
     - GET /api/tokens/:token_id
     - GET /api/tokens/:token_id/history
     - POST /api/tokens/clear_active
   - Add error handling
   - Add UUID validation
   - Add JSON response formatting

5. **Testing**
   - Write comprehensive tests for context functions
   - Test usage history tracking
   - Test edge cases (exactly 100 active, concurrent requests)
   - Test API endpoints
   - Test concurrent scenarios

6. **Optional Enhancements**
   - LiveView dashboard
   - Telemetry/metrics
   - Rate limiting

## Configuration

Add to `config/config.exs`:
```elixir
config :just_travel_test, JustTravelTest.Tokens,
  max_active_tokens: 100,
  token_lifetime_minutes: 2,
  check_interval_seconds: 30
```

## Error Handling

- **No available tokens**: Should not happen (we release oldest), but handle gracefully
- **Invalid user_id**: Validate UUID format (return 400 Bad Request)
- **Token not found**: Return 404 Not Found with appropriate message
- **Concurrent activation**: Use database transactions/locks
- **Invalid request body**: Return 400 Bad Request with validation errors

## Performance Considerations

- Use database indexes for efficient queries
- Batch operations when possible
- Consider using `:ets` for in-memory tracking if needed (future optimization)
- Use database-level locking for atomic operations

## Future Enhancements

- Metrics and monitoring
- Rate limiting per user
- Token reservation system
- WebSocket updates for real-time status
- Pagination for token lists and history
- Filtering and sorting options for API endpoints

