# API Endpoint Naming: Current vs. RESTful Alternatives

## Current Endpoints

| Endpoint | Method | Current Name | Purpose |
|----------|--------|--------------|---------|
| 1 | POST | `/api/tokens/use` | Register token usage |
| 2 | GET | `/api/tokens` | List all tokens |
| 3 | GET | `/api/tokens/:token_id` | Get specific token |
| 4 | GET | `/api/tokens/:token_id/history` | Get usage history |
| 5 | POST | `/api/tokens/clear_active` | Clear all active tokens |

## RESTful Naming Principles

### 1. Use Nouns, Not Verbs
- ❌ `/tokens/use` (verb)
- ✅ `/token-usages` or `/tokens/activate` (noun/resource)

### 2. Use HTTP Methods Correctly
- **GET**: Retrieve data (idempotent, safe)
- **POST**: Create new resource or perform action
- **PUT**: Update/replace resource (idempotent)
- **PATCH**: Partial update
- **DELETE**: Remove resource (idempotent)

### 3. Resource Hierarchy
- Top-level: `/tokens`, `/token-usages`
- Nested: `/tokens/:token_id/usages`
- Actions: Use HTTP methods, not verbs in URLs

## Proposed Alternatives

### Option 1: Token-Usages as Main Resource (Recommended)

This treats "token usage" as a first-class resource:

| Current | Proposed | Method | Rationale |
|---------|----------|--------|-----------|
| `POST /api/tokens/use` | `POST /api/token-usages` | POST | Creating a usage record |
| `GET /api/tokens` | `GET /api/tokens` | GET | ✅ Keep (already good) |
| `GET /api/tokens/:token_id` | `GET /api/tokens/:token_id` | GET | ✅ Keep (already good) |
| `GET /api/tokens/:token_id/history` | `GET /api/tokens/:token_id/usages` | GET | "usages" is clearer than "history" |
| `POST /api/tokens/clear_active` | `DELETE /api/tokens/active` | DELETE | DELETE for removal, more RESTful |

**Pros:**
- ✅ Treats usage as a resource (RESTful)
- ✅ Clear separation: tokens vs. usages
- ✅ DELETE method is semantically correct
- ✅ "usages" is more descriptive than "history"

**Cons:**
- ⚠️ Requires a new controller or additional actions

### Option 2: Keep Tokens as Main Resource

This keeps tokens as the primary resource with actions:

| Current | Proposed | Method | Rationale |
|---------|----------|--------|-----------|
| `POST /api/tokens/use` | `POST /api/tokens/activate` | POST | Activating a token |
| `GET /api/tokens` | `GET /api/tokens` | GET | ✅ Keep |
| `GET /api/tokens/:token_id` | `GET /api/tokens/:token_id` | GET | ✅ Keep |
| `GET /api/tokens/:token_id/history` | `GET /api/tokens/:token_id/usages` | GET | "usages" is clearer |
| `POST /api/tokens/clear_active` | `DELETE /api/tokens/active` | DELETE | DELETE for removal |

**Pros:**
- ✅ Keeps tokens as primary resource
- ✅ "activate" is clearer than "use"
- ✅ Simpler structure (one main resource)

**Cons:**
- ⚠️ "activate" might imply you choose the token (but we auto-assign)

### Option 3: Hybrid Approach (Most RESTful)

Combines both resources with proper nesting:

| Current | Proposed | Method | Rationale |
|---------|----------|--------|-----------|
| `POST /api/tokens/use` | `POST /api/token-usages` | POST | Creating usage record |
| `GET /api/tokens` | `GET /api/tokens` | GET | ✅ Keep |
| `GET /api/tokens/:token_id` | `GET /api/tokens/:token_id` | GET | ✅ Keep |
| `GET /api/tokens/:token_id/history` | `GET /api/token-usages?token_id=:id` | GET | Query usages by token |
| `POST /api/tokens/clear_active` | `DELETE /api/tokens/active` | DELETE | DELETE for removal |

**Pros:**
- ✅ Most RESTful
- ✅ Token-usages is a top-level resource
- ✅ Can query usages independently

**Cons:**
- ⚠️ More complex structure
- ⚠️ Query param for nested relationship

## Recommendation: Option 1 (Token-Usages as Resource)

### Final Proposed Endpoints

1. **POST `/api/token-usages`** - Register token usage
   - Body: `{"user_id": "uuid"}`
   - Creates a new token usage record
   - Returns: `{"token_id": "uuid", "user_id": "uuid"}`

2. **GET `/api/tokens`** - List tokens (keep as-is)
   - Query: `?state=available|active|all`
   - Returns: `{"tokens": [...]}`

3. **GET `/api/tokens/:token_id`** - Get token (keep as-is)
   - Returns: Token details with usage_count

4. **GET `/api/tokens/:token_id/usages`** - Get token usages
   - Returns: `{"token_id": "uuid", "usages": [...]}`
   - Note: Changed "history" → "usages" (clearer, more RESTful)

5. **DELETE `/api/tokens/active`** - Clear active tokens
   - Returns: `{"cleared_count": 42, "status": "ok"}`
   - Note: Changed POST → DELETE (semantically correct)

### Why This is Better

#### 1. POST /api/token-usages vs POST /api/tokens/use

**Current:** `POST /api/tokens/use`
- ❌ "use" is a verb (not RESTful)
- ❌ Unclear what resource is being created

**Proposed:** `POST /api/token-usages`
- ✅ Creates a token-usage resource (RESTful)
- ✅ Clear: you're creating a usage record
- ✅ Follows REST convention: POST creates resource

#### 2. GET /api/tokens/:token_id/usages vs /history

**Current:** `GET /api/tokens/:token_id/history`
- ❌ "history" is vague (history of what?)
- ❌ Not a standard REST term

**Proposed:** `GET /api/tokens/:token_id/usages`
- ✅ "usages" clearly indicates the resource
- ✅ Standard REST pattern: nested resource
- ✅ Matches our schema name (`token_usages`)

#### 3. DELETE /api/tokens/active vs POST /clear_active

**Current:** `POST /api/tokens/clear_active`
- ❌ "clear_active" is a verb phrase
- ❌ POST for deletion is semantically wrong

**Proposed:** `DELETE /api/tokens/active`
- ✅ DELETE method for removal (semantically correct)
- ✅ `/active` represents the collection to delete
- ✅ More RESTful and intuitive

## Alternative: Keep Current Names

If you prefer to keep the current naming, here are minimal improvements:

| Current | Minimal Improvement | Reason |
|---------|-------------------|--------|
| `POST /api/tokens/use` | `POST /api/tokens/activate` | "activate" is clearer |
| `GET /api/tokens/:token_id/history` | `GET /api/tokens/:token_id/usages` | "usages" is more specific |
| `POST /api/tokens/clear_active` | `DELETE /api/tokens/active` | DELETE is more appropriate |

## Comparison Table

| Aspect | Current | Option 1 (Recommended) | Option 2 | Option 3 |
|--------|---------|----------------------|----------|----------|
| **RESTful** | ⚠️ Mixed | ✅ Very RESTful | ✅ RESTful | ✅ Most RESTful |
| **Clarity** | ⚠️ Some verbs | ✅ Clear nouns | ✅ Clear | ✅ Very clear |
| **HTTP Methods** | ⚠️ POST for delete | ✅ Correct methods | ✅ Correct | ✅ Correct |
| **Complexity** | ✅ Simple | ✅ Simple | ✅ Simple | ⚠️ More complex |
| **Resource Model** | ⚠️ Unclear | ✅ Clear separation | ✅ Tokens-focused | ✅ Both resources |

## Implementation Impact

### If We Choose Option 1:

**Changes needed:**
1. Rename route: `POST /api/tokens/use` → `POST /api/token-usages`
2. Rename route: `GET /api/tokens/:token_id/history` → `GET /api/tokens/:token_id/usages`
3. Change method: `POST /api/tokens/clear_active` → `DELETE /api/tokens/active`
4. Update controller action names (optional, can keep same)
5. Update response key: `"history"` → `"usages"` (optional)

**Backward compatibility:**
- Could keep old routes and add new ones
- Or do a breaking change (recommended for new API)

## My Recommendation

**Go with Option 1** because:
1. ✅ Most RESTful and follows conventions
2. ✅ Clear resource model (tokens vs. token-usages)
3. ✅ Correct HTTP methods (DELETE for removal)
4. ✅ Better naming ("usages" vs "history")
5. ✅ Professional API design

**Minimal changes if you want to keep it simple:**
- Just change "history" → "usages"
- Change POST clear_active → DELETE active
- Keep "use" if you prefer (though "token-usages" is better)

What do you think? Should we implement Option 1, or would you prefer a different approach?

