# Why Use `Repo.transaction()`?

## The Problem: Multiple Related Database Operations

In our `register_token_usage/1` function, we perform **multiple related database operations** that must succeed or fail together:

```elixir
def register_token_usage(user_id) when is_binary(user_id) do
  Repo.transaction(fn ->
    # 1. Validate user_id
    # 2. Check if limit reached → potentially release oldest token
    # 3. Find and lock an available token
    # 4. Update token to :active
    # 5. Create usage history record
  end)
end
```

### What Happens Inside `do_register_token_usage/1`:

1. **Count active tokens** (read operation)
2. **Release oldest token** (if limit reached) - multiple operations:
   - Update token state to `:available`
   - Set `utilizer_uuid` to `nil`
   - Set `released_at` timestamp
   - Update usage record's `ended_at`
3. **Find and lock available token** (with `FOR UPDATE SKIP LOCKED`)
4. **Update token to active**:
   - Set state to `:active`
   - Set `utilizer_uuid` to `user_id`
   - Set `activated_at` timestamp
5. **Create usage history record** (insert new `TokenUsage`)

**All of these operations must happen atomically!**

## What Could Go Wrong Without Transactions?

### Scenario 1: Partial Updates (Data Inconsistency)

```elixir
# ❌ WITHOUT TRANSACTION - DANGEROUS!

def register_token_usage(user_id) do
  # Step 1: Release oldest token (if needed)
  if active_count >= 100 do
    Release.release_oldest_active_token()  # ← Commits immediately!
  end
  
  # Step 2: Find available token
  token = get_available_token()
  
  # Step 3: Update token to active
  Repo.update!(token_changeset)  # ← Commits immediately!
  
  # Step 4: Create usage record
  # 💥 CRASH HERE! (e.g., database constraint violation)
  Repo.insert!(usage_changeset)  # ← Fails!
end
```

**Result:**
- ✅ Oldest token was released (committed)
- ✅ Token was activated (committed)
- ❌ Usage record was NOT created (failed)
- **Problem**: Token is active but has no usage record! Data is inconsistent!

### Scenario 2: Race Conditions (Concurrent Requests)

```elixir
# ❌ WITHOUT TRANSACTION - RACE CONDITION!

# Time 0ms: User A requests token
active_count = Queries.count_active_tokens()  # Returns: 99

# Time 1ms: User B requests token (concurrent!)
active_count = Queries.count_active_tokens()  # Returns: 99 (same!)

# Time 2ms: User A activates token
# Token count becomes 100

# Time 3ms: User B activates token
# Token count becomes 101 ❌ VIOLATES 100 TOKEN LIMIT!
```

**Result:**
- Both users get tokens
- System has 101 active tokens (violates business rule!)
- **Problem**: No atomicity - operations interleave incorrectly

### Scenario 3: Token Locking Issues

```elixir
# ❌ WITHOUT TRANSACTION - LOCKING PROBLEM!

# Step 1: Find available token (no lock)
token = Repo.one(query)  # Returns token_123

# Step 2: Another request gets the same token!
other_token = Repo.one(query)  # Also returns token_123!

# Step 3: Both try to activate the same token
Repo.update!(token_changeset)      # User A activates token_123
Repo.update!(other_token_changeset) # User B also activates token_123 ❌
```

**Result:**
- Same token activated twice
- Two users share one token
- **Problem**: `FOR UPDATE SKIP LOCKED` only works within a transaction!

## How Transactions Solve These Problems

### ✅ WITH TRANSACTION - SAFE!

```elixir
def register_token_usage(user_id) do
  Repo.transaction(fn ->
    # All operations happen atomically:
    
    # 1. Release oldest (if needed)
    if active_count >= 100 do
      Release.release_oldest_active_token()
    end
    
    # 2. Find and LOCK available token
    token = get_available_token()  # FOR UPDATE SKIP LOCKED works!
    
    # 3. Update token
    Repo.update!(token_changeset)
    
    # 4. Create usage record
    Repo.insert!(usage_changeset)
    
    # If ANY step fails, ALL changes are rolled back!
  end)
end
```

**Benefits:**
1. **Atomicity**: All operations succeed or all fail
2. **Isolation**: Other transactions see consistent state
3. **Consistency**: Business rules are enforced
4. **Locking**: `FOR UPDATE SKIP LOCKED` works correctly

## Real-World Example: What Happens in Our Code

### Without Transaction (Broken):

```elixir
# User requests token when system has 100 active tokens

# Step 1: Release oldest token
oldest_token.state = :available  # ← Committed to DB
oldest_token.utilizer_uuid = nil # ← Committed to DB
oldest_usage.ended_at = now       # ← Committed to DB

# Step 2: Try to find available token
available_token = get_available_token()  # Returns nil! (race condition)

# Step 3: Error - no token available
# ❌ But we already released the oldest token!
# ❌ System now has 99 active tokens (should have 100)
# ❌ Oldest token is available but no one got it
# ❌ Data is inconsistent!
```

### With Transaction (Correct):

```elixir
# User requests token when system has 100 active tokens

Repo.transaction(fn ->
  # Step 1: Release oldest token
  oldest_token.state = :available      # ← Not committed yet
  oldest_token.utilizer_uuid = nil     # ← Not committed yet
  oldest_usage.ended_at = now          # ← Not committed yet
  
  # Step 2: Try to find available token
  available_token = get_available_token()  # Returns nil!
  
  # Step 3: Error - no token available
  Repo.rollback(:no_available_tokens)
  
  # ✅ ALL changes are rolled back:
  # ✅ Oldest token remains active
  # ✅ System still has 100 active tokens
  # ✅ Data is consistent!
end)
```

## The ACID Properties

Transactions provide **ACID** guarantees:

### A - Atomicity
- **All or nothing**: Either all operations succeed or all fail
- In our code: If token activation fails, the oldest token release is also rolled back

### C - Consistency
- **Business rules enforced**: Database remains in a valid state
- In our code: We can never have more than 100 active tokens

### I - Isolation
- **Concurrent operations don't interfere**: Each transaction sees a consistent snapshot
- In our code: Two concurrent requests won't both get the same token

### D - Durability
- **Committed changes persist**: Once committed, changes survive crashes
- In our code: Once a token is activated, it stays activated even if the server restarts

## Performance Considerations

### Transaction Overhead

Transactions have a small performance cost:
- **Lock acquisition**: Database locks rows/tables
- **Logging**: Database logs all changes (for rollback)
- **Network round-trips**: Multiple operations in one transaction

### When NOT to Use Transactions

You might skip transactions for:
- **Read-only operations**: No need for atomicity
- **Single, independent operations**: One insert/update that doesn't depend on others
- **Operations that can be retried**: Idempotent operations

### When You MUST Use Transactions

Always use transactions for:
- **Multiple related writes**: Like our token activation
- **Operations that must be atomic**: Business-critical operations
- **Operations with locking**: `FOR UPDATE SKIP LOCKED` requires a transaction
- **Operations that can fail mid-way**: Need rollback capability

## Summary: Why We Use Transactions in `register_token_usage/1`

1. **Multiple Operations**: We perform 2-5 database operations that must succeed together
2. **Data Consistency**: Token state and usage history must always match
3. **Business Rules**: The 100-token limit must be enforced atomically
4. **Concurrency**: Multiple users requesting tokens simultaneously
5. **Error Recovery**: If any step fails, we need to roll back everything

**Without transactions, we risk:**
- Partial updates (token activated but no usage record)
- Race conditions (exceeding 100 active tokens)
- Data inconsistency (released token but no activation)
- Locking failures (same token activated twice)

**With transactions, we guarantee:**
- All operations succeed or all fail
- Business rules are always enforced
- Concurrent requests are handled safely
- Data remains consistent even on errors

## Code Comparison

### ❌ Without Transaction (Dangerous):
```elixir
def register_token_usage(user_id) do
  # Each operation commits immediately
  release_oldest_if_needed()  # ← Committed
  token = get_available_token()
  Repo.update!(token)         # ← Committed
  Repo.insert!(usage)         # ← If this fails, we're in trouble!
end
```

### ✅ With Transaction (Safe):
```elixir
def register_token_usage(user_id) do
  Repo.transaction(fn ->
    # All operations in one atomic block
    release_oldest_if_needed()  # ← Not committed yet
    token = get_available_token()
    Repo.update!(token)         # ← Not committed yet
    Repo.insert!(usage)         # ← If this fails, ALL rollback!
  end)
end
```

The transaction ensures that if **any** step fails, **all** changes are rolled back, keeping your data consistent and your business rules enforced.

