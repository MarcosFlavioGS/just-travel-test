# Understanding `Repo.rollback()`

## What is `Repo.rollback()`?

`Repo.rollback()` is an Ecto function that **aborts a database transaction** and reverts all changes made within that transaction. It's a way to explicitly signal that something went wrong and you want to cancel the entire operation.

## Key Characteristics

1. **Only works inside transactions**: `Repo.rollback()` can only be called within a `Repo.transaction()` block. Calling it outside a transaction will raise an error.

2. **Immediately exits**: When `Repo.rollback()` is called, it **immediately stops execution** of the transaction function and returns control to the code that called `Repo.transaction()`.

3. **Reverts all changes**: All database operations (inserts, updates, deletes) performed within the transaction are **completely undone** - it's as if they never happened.

4. **Returns an error tuple**: The transaction returns `{:error, value}` where `value` is whatever you passed to `Repo.rollback()`.

5. **Never returns normally**: `Repo.rollback()` has the type signature `@spec rollback(term()) :: no_return()`, meaning it never returns a value - it always raises an exception that Ecto catches and converts to an error tuple.

## How It Works in Our Codebase

### Example 1: Invalid User ID

```elixir
# lib/just_travel_test/token/registration.ex

def register_token_usage(user_id) when is_binary(user_id) do
  Repo.transaction(fn ->
    case Ecto.UUID.cast(user_id) do
      {:ok, _uuid} ->
        do_register_token_usage(user_id)

      :error ->
        Repo.rollback(:invalid_user_id)  # ← Aborts transaction here
    end
  end)
  |> case do
    {:ok, result} -> result
    {:error, reason} -> {:error, reason}  # ← Returns {:error, :invalid_user_id}
  end
end
```

**What happens:**
1. Transaction starts
2. User ID validation fails
3. `Repo.rollback(:invalid_user_id)` is called
4. Transaction is aborted immediately
5. No database changes are made
6. Function returns `{:error, :invalid_user_id}`

### Example 2: No Available Tokens

```elixir
# lib/just_travel_test/token/registration.ex

defp do_register_token_usage(user_id) do
  # ... limit checking code ...
  
  case get_available_token() do
    nil ->
      Repo.rollback(:no_available_tokens)  # ← Aborts transaction
    
    token ->
      # Activate token and create usage record
      # ... success path ...
  end
end
```

**What happens:**
1. Transaction is already running (from `register_token_usage/1`)
2. We try to find an available token
3. No token is found (`nil`)
4. `Repo.rollback(:no_available_tokens)` is called
5. **Even if** we had released the oldest token earlier in this transaction, that change is also rolled back
6. Function returns `{:error, :no_available_tokens}`

### Example 3: Token Not Found

```elixir
# lib/just_travel_test/token/release.ex

def release_token(token_id) when is_binary(token_id) do
  Repo.transaction(fn ->
    case Repo.get(TokenSchema, token_id) do
      nil ->
        Repo.rollback({:error, :token_not_found})  # ← Aborts transaction
      
      token when token.state == :available ->
        token  # Token already available, nothing to do
      
      token ->
        # Release the token
        # ... update logic ...
    end
  end)
end
```

**What happens:**
1. Transaction starts
2. Token lookup returns `nil`
3. `Repo.rollback({:error, :token_not_found})` is called
4. Transaction is aborted
5. Function returns `{:error, {:error, :token_not_found}}` (note the double-wrapping)

## Transaction Flow Diagram

```
┌─────────────────────────────────────┐
│  Repo.transaction(fn -> ... end)   │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ 1. Validate input             │ │
│  │ 2. Check business rules       │ │
│  │ 3. Perform database operations│ │
│  │                                │ │
│  │  If error occurs:              │ │
│  │  → Repo.rollback(reason)      │ │
│  │     ↓                          │ │
│  │  Transaction ABORTED           │ │
│  │  All changes REVERTED          │ │
│  └───────────────────────────────┘ │
│                                     │
│  Returns: {:error, reason}          │
└─────────────────────────────────────┘
```

## Why Use `Repo.rollback()` Instead of Returning an Error?

### Without `Repo.rollback()` (Problematic):

```elixir
# ❌ BAD: This doesn't rollback the transaction!
Repo.transaction(fn ->
  # Release oldest token
  Release.release_oldest_active_token()
  
  # Try to get available token
  case get_available_token() do
    nil -> {:error, :no_available_tokens}  # ← Transaction continues!
    token -> activate_token(token)
  end
end)
# Problem: If we return {:error, ...}, the transaction might still commit
# the changes made by release_oldest_active_token()!
```

### With `Repo.rollback()` (Correct):

```elixir
# ✅ GOOD: This properly aborts the transaction
Repo.transaction(fn ->
  # Release oldest token
  Release.release_oldest_active_token()
  
  # Try to get available token
  case get_available_token() do
    nil -> Repo.rollback(:no_available_tokens)  # ← Transaction aborted!
    token -> activate_token(token)
  end
end)
# Result: If no token is found, ALL changes (including the release) are rolled back
```

## Important Notes

1. **Atomicity**: Transactions ensure that either **all** operations succeed or **all** fail together. `Repo.rollback()` is the mechanism to trigger the "all fail" scenario.

2. **Error Value**: You can pass any value to `Repo.rollback()`. Common patterns:
   - `Repo.rollback(:error_reason)` - Simple atom
   - `Repo.rollback({:error, :reason})` - Error tuple (be careful of double-wrapping!)
   - `Repo.rollback("error message")` - String message

3. **Double-Wrapping**: Be careful when using error tuples:
   ```elixir
   Repo.rollback({:error, :token_not_found})
   # Returns: {:error, {:error, :token_not_found}}
   # You may need to unwrap it:
   |> case do
     {:error, {:error, reason}} -> {:error, reason}
     {:error, reason} -> {:error, reason}
   end
   ```

4. **Cannot be caught**: `Repo.rollback()` raises an exception that Ecto catches internally. You cannot use `try/rescue` to catch it - it's designed to always abort the transaction.

## Summary

- **Purpose**: Abort a database transaction and revert all changes
- **Usage**: Only inside `Repo.transaction()` blocks
- **Behavior**: Immediately stops execution and returns `{:error, value}`
- **Use case**: When you discover an error condition that makes the entire transaction invalid
- **Benefit**: Ensures data consistency by preventing partial updates

In our token management system, `Repo.rollback()` ensures that if we can't complete a token activation (e.g., no tokens available), we don't leave the system in an inconsistent state (e.g., with a token released but not activated).

