# Preloads and Joins Optimization in Token Queries

## Overview

This document explains how we use **preloads** and **joins** in our token query functions to optimize database performance and avoid the N+1 query problem.

## What are Preloads and Joins?

### Preloads
- **Preloading** in Ecto loads associated data in a separate query but efficiently batches them
- Example: Loading tokens and their associated usage records
- Uses `Repo.preload/2` or `preload/2` in queries

### Joins
- **Joins** combine data from multiple tables in a single SQL query
- More efficient than separate queries when you need aggregated data (counts, sums, etc.)
- Uses `join/4` or `left_join/4` in Ecto queries

## The N+1 Query Problem

### What is it?

The N+1 query problem occurs when you:
1. Fetch a list of records (1 query)
2. Then fetch related data for each record (N queries)

**Example of N+1 Problem:**
```elixir
# BAD: N+1 queries
tokens = list_all_tokens()  # 1 query - gets 100 tokens

# Then for each token, fetch usage count
Enum.map(tokens, fn token ->
  count_usages(token.id)  # 100 more queries! (N+1 problem)
end)
# Total: 101 queries!
```

### Why is it bad?

- **Performance**: 101 database round-trips instead of 1
- **Latency**: Each query adds network and database overhead
- **Scalability**: Gets worse as data grows
- **Resource usage**: Wastes database connections and CPU

## Our Solution: Joins with Aggregation

### How We Fixed It

Instead of multiple queries, we use a **single query with a LEFT JOIN**:

```elixir
# GOOD: Single query with join
tokens = list_all_tokens(with_usage_count: true)  # 1 query with join
# Usage counts included in the result
# Total: 1 query!
```

### The SQL Generated

When you use `with_usage_count: true`, Ecto generates:

```sql
SELECT 
  t0."id", 
  t0."state", 
  t0."utilizer_uuid", 
  t0."activated_at", 
  t0."released_at", 
  t0."inserted_at", 
  t0."updated_at",
  count(t1."id") as usage_count
FROM "tokens" AS t0 
LEFT OUTER JOIN "token_usages" AS t1 ON t1."token_id" = t0."id" 
WHERE t0."state" = 'active'
GROUP BY t0."id"
ORDER BY t0."activated_at"
```

**Key Points:**
- `LEFT OUTER JOIN` ensures we get tokens even if they have no usage records
- `count(t1."id")` aggregates usage records in the database
- `GROUP BY` groups results by token ID
- All done in **one database round-trip**

## Schema Associations

### TokenSchema Association

We added a `has_many` association to enable joins:

```elixir
defmodule JustTravelTest.Token.TokenSchema do
  schema "tokens" do
    # ... fields ...
    has_many :token_usages, JustTravelTest.Token.TokenUsageSchema, foreign_key: :token_id
  end
end
```

This association allows us to:
- Use `assoc(t, :token_usages)` in queries
- Preload usage records when needed
- Join efficiently for aggregations

## Optimized Query Functions

### 1. `get_token_by_id/2`

**Basic usage (no join):**
```elixir
token = Tokens.get_token_by_id(token_id)
# Returns: %TokenSchema{...}
```

**With usage count (join):**
```elixir
token = Tokens.get_token_by_id(token_id, preload_usage_count: true)
# Returns: %{id: "...", state: :active, usage_count: 5, ...}
# Single query with LEFT JOIN
```

**When to use:**
- Use `preload_usage_count: true` when you need the usage count for API responses
- Use basic version when you only need token data

### 2. `list_all_tokens/1`

**Basic usage:**
```elixir
tokens = Tokens.list_all_tokens()
# Returns: [%TokenSchema{}, ...]
# 1 simple query
```

**With usage counts:**
```elixir
tokens = Tokens.list_all_tokens(with_usage_count: true)
# Returns: [%{id: "...", usage_count: 3, ...}, ...]
# 1 query with LEFT JOIN and GROUP BY
```

**Performance comparison:**
- **Without join**: 1 query for tokens
- **With join**: 1 query for tokens + counts (more efficient than N+1)

### 3. `list_active_tokens/1`

Same pattern as `list_all_tokens/1`:

```elixir
# Basic
active = Tokens.list_active_tokens()

# With counts
active = Tokens.list_active_tokens(with_usage_count: true)
```

### 4. `get_token_usage_history/2`

**Basic usage:**
```elixir
history = Tokens.get_token_usage_history(token_id)
# Returns: [%TokenUsageSchema{}, ...]
# 1 query for usage records
```

**With token preload:**
```elixir
history = Tokens.get_token_usage_history(token_id, preload_token: true)
# Returns: [%TokenUsageSchema{token: %TokenSchema{}}, ...]
# 2 queries: one for usage, one for tokens (batched)
```

**When to use:**
- Use `preload_token: true` when you need token details with history
- Use basic version when you only need usage records

## Performance Comparison

### Scenario: List 100 tokens with usage counts

**Without optimization (N+1):**
```
Query 1: SELECT * FROM tokens                    (100 rows)
Query 2: SELECT count(*) FROM token_usages WHERE token_id = '...'  (1 row)
Query 3: SELECT count(*) FROM token_usages WHERE token_id = '...'  (1 row)
...
Query 101: SELECT count(*) FROM token_usages WHERE token_id = '...'  (1 row)

Total: 101 queries, ~1010ms (assuming 10ms per query)
```

**With optimization (join):**
```
Query 1: SELECT t.*, count(u.id) 
         FROM tokens t 
         LEFT JOIN token_usages u ON u.token_id = t.id 
         GROUP BY t.id

Total: 1 query, ~50ms
```

**Improvement: 20x faster!** 🚀

## When to Use Each Approach

### Use Joins When:
- ✅ You need **aggregated data** (counts, sums, averages)
- ✅ You're fetching **multiple records** with related data
- ✅ You want to **avoid N+1 queries**
- ✅ Performance is critical
- ✅ You're rendering **lists** with related information

### Don't Use Joins When:
- ❌ You only need **basic token data**
- ❌ You're doing **simple lookups** (single record)
- ❌ The dataset is **very small** (< 10 records)
- ❌ You don't need related data
- ❌ You want **simpler code** and performance isn't critical

## API Integration Example

### Example: GET /api/tokens/:token_id

According to our API plan, this endpoint needs:
```json
{
  "token_id": "uuid",
  "state": "active",
  "current_user_id": "uuid",
  "usage_count": 5  // <-- We need this!
}
```

**Without optimization:**
```elixir
def show(conn, %{"token_id" => token_id}) do
  token = Tokens.get_token_by_id(token_id)  # Query 1
  usage_count = count_usages(token_id)       # Query 2 (N+1 if in loop)
  # ...
end
```

**With optimization:**
```elixir
def show(conn, %{"token_id" => token_id}) do
  token = Tokens.get_token_by_id(token_id, preload_usage_count: true)  # 1 query!
  # token already has :usage_count field
  # ...
end
```

## Best Practices

### 1. Make it Optional
- Always provide a basic version without joins
- Add join options as optional parameters
- Maintains backward compatibility

### 2. Use Appropriate Joins
- `left_join` when you want all records (even without related data)
- `inner_join` when you only want records with related data
- We use `left_join` to include tokens with zero usage

### 3. Group By Correctly
- Always `GROUP BY` the primary table's ID when aggregating
- Ensures correct results and performance

### 4. Return Consistent Types
- When using joins, return maps with the struct + aggregated fields
- Makes it clear what data is available

## Code Examples

### Example 1: Efficient Token List with Counts

```elixir
# In your controller or LiveView
def index(conn, _params) do
  tokens = Tokens.list_all_tokens(with_usage_count: true)
  
  render(conn, :index, tokens: tokens)
  # Each token has :usage_count field
end
```

### Example 2: Token Detail with Count

```elixir
def show(conn, %{"token_id" => token_id}) do
  case Tokens.get_token_by_id(token_id, preload_usage_count: true) do
    nil ->
      conn
      |> put_status(:not_found)
      |> json(%{error: "Token not found"})
    
    token ->
      json(conn, %{
        token_id: token.id,
        state: token.state,
        usage_count: Map.get(token, :usage_count, 0)
      })
  end
end
```

### Example 3: History with Token Info

```elixir
def history(conn, %{"token_id" => token_id}) do
  history = Tokens.get_token_usage_history(token_id, preload_token: true)
  
  json(conn, %{
    token_id: token_id,
    history: Enum.map(history, fn usage ->
      %{
        user_id: usage.user_id,
        started_at: usage.started_at,
        ended_at: usage.ended_at,
        token_state: usage.token.state  # Preloaded!
      }
    end)
  })
end
```

## Summary

### Key Takeaways

1. **N+1 Problem**: Fetching related data in a loop causes many queries
2. **Solution**: Use joins to fetch everything in one query
3. **When to Use**: When you need aggregated data or multiple records with relations
4. **Implementation**: Optional parameters make joins available when needed
5. **Performance**: Can be 10-100x faster for large datasets

### Our Implementation

- ✅ Added `has_many` association to TokenSchema
- ✅ Made joins optional via function parameters
- ✅ Used `left_join` for inclusive results
- ✅ Aggregated counts in the database
- ✅ Maintained backward compatibility
- ✅ Returned consistent data structures

### Next Steps

When implementing the API layer:
- Use `preload_usage_count: true` for endpoints that need counts
- Use `with_usage_count: true` for list endpoints
- Use `preload_token: true` when token details are needed with history

This optimization ensures our API will be fast and scalable! 🚀

