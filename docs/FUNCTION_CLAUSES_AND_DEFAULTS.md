# Function Clauses and Default Arguments in Elixir

## Overview

This document explains how Elixir's function clause matching works, specifically when using default arguments with multiple function definitions.

## The Pattern We Use

```elixir
def list_active_tokens(opts \\ [])

def list_active_tokens(opts) do
  # Implementation
end
```

## How It Works

### Step 1: Function Header (Default Declaration)

```elixir
def list_active_tokens(opts \\ [])
```

This line does **two things**:
1. **Declares the function signature** with a default value
2. **Tells Elixir**: "If someone calls `list_active_tokens()` without arguments, use `[]` as the default"

**Important**: This is NOT the implementation - it's just a declaration!

### Step 2: Function Implementation

```elixir
def list_active_tokens(opts) do
  # Actual implementation code
end
```

This is the **actual function body** that gets executed.

## How Elixir Selects Which Function to Call

Elixir uses **pattern matching** to determine which function clause to execute. Here's the process:

### When You Call `list_active_tokens()` (no arguments):

1. Elixir looks for a function clause that matches
2. Finds: `def list_active_tokens(opts \\ [])`
3. Applies the default: `opts = []`
4. Then matches: `def list_active_tokens(opts)` where `opts = []`
5. Executes the function body with `opts = []`

### When You Call `list_active_tokens(with_usage_count: true)`:

1. Elixir looks for a function clause that matches
2. Doesn't find `def list_active_tokens(opts \\ [])` because we provided an argument
3. Matches: `def list_active_tokens(opts)` where `opts = [with_usage_count: true]`
4. Executes the function body with `opts = [with_usage_count: true]`

## Visual Flow Diagram

```
Call: list_active_tokens()
         │
         ▼
    ┌─────────────────────────┐
    │ Elixir looks for match  │
    └─────────────────────────┘
         │
         ▼
    ┌─────────────────────────┐
    │ Finds: opts \\ []        │
    │ Applies default: []     │
    └─────────────────────────┘
         │
         ▼
    ┌─────────────────────────┐
    │ Matches: opts            │
    │ opts = []                │
    └─────────────────────────┘
         │
         ▼
    ┌─────────────────────────┐
    │ Executes function body   │
    └─────────────────────────┘
```

```
Call: list_active_tokens(with_usage_count: true)
         │
         ▼
    ┌─────────────────────────┐
    │ Elixir looks for match  │
    └─────────────────────────┘
         │
         ▼
    ┌─────────────────────────┐
    │ Skips: opts \\ []       │
    │ (argument provided)     │
    └─────────────────────────┘
         │
         ▼
    ┌─────────────────────────┐
    │ Matches: opts            │
    │ opts = [with_usage_count: true]
    └─────────────────────────┘
         │
         ▼
    ┌─────────────────────────┐
    │ Executes function body   │
    └─────────────────────────┘
```

## Why We Need the Header

### Without the Header (WRONG):

```elixir
# This would cause a compilation error!
def list_active_tokens(opts \\ []) do
  # Implementation
end

# Error: default values can only be used in function headers
```

### With the Header (CORRECT):

```elixir
# Header declares the default
def list_active_tokens(opts \\ [])

# Implementation matches any opts value
def list_active_tokens(opts) do
  # Implementation
end
```

## Multiple Clauses Example

You can have multiple clauses with different patterns:

```elixir
def process_token(token_id, opts \\ [])

# Clause 1: When opts is empty
def process_token(token_id, []) when is_binary(token_id) do
  # Handle without options
end

# Clause 2: When opts has :preload
def process_token(token_id, [preload: true]) when is_binary(token_id) do
  # Handle with preload
end

# Clause 3: Catch-all for other opts
def process_token(token_id, opts) when is_binary(token_id) do
  # Handle with other options
end
```

Elixir will try to match in order:
1. First tries `opts = []`
2. Then tries `opts = [preload: true]`
3. Finally matches any other `opts`

## Real Example from Our Code

### Our Implementation:

```elixir
def list_active_tokens(opts \\ [])

def list_active_tokens(opts) do
  query = from(t in TokenSchema, where: t.state == :active, order_by: [asc: t.activated_at])

  if Keyword.get(opts, :with_usage_count, false) do
    # Join version
    from(t in query,
      left_join: usage in assoc(t, :token_usages),
      group_by: [t.id],
      select: %{token: t, usage_count: count(usage.id)}
    )
    |> Repo.all()
    |> Enum.map(fn %{token: token, usage_count: count} ->
      token |> Map.from_struct() |> Map.put(:usage_count, count)
    end)
  else
    # Simple version
    Repo.all(query)
  end
end
```

### How It's Called:

```elixir
# Call 1: No arguments
tokens = Tokens.list_active_tokens()
# → opts = [] (from default)
# → Keyword.get([], :with_usage_count, false) = false
# → Executes: Repo.all(query) (simple version)

# Call 2: With option
tokens = Tokens.list_active_tokens(with_usage_count: true)
# → opts = [with_usage_count: true]
# → Keyword.get([with_usage_count: true], :with_usage_count, false) = true
# → Executes: join version with Enum.map
```

## Key Concepts

### 1. Pattern Matching

Elixir matches function clauses based on:
- **Number of arguments**
- **Argument values** (patterns)
- **Guards** (`when` clauses)

### 2. Default Application

Defaults are applied **before** pattern matching:
```elixir
def foo(x \\ 10)  # Default declaration
def foo(x)        # Matches any x value (including 10)
```

### 3. Clause Order Matters

Elixir tries clauses **top to bottom**:
```elixir
def process(:special) do
  # This matches first
end

def process(x) do
  # This matches everything else
end
```

### 4. Guards Add Conditions

```elixir
def process(x) when is_binary(x) do
  # Only matches if x is a binary
end

def process(x) do
  # Matches everything else
end
```

## Common Patterns

### Pattern 1: Simple Default

```elixir
def greet(name \\ "World") do
  "Hello, #{name}!"
end

greet()        # → "Hello, World!"
greet("Alice") # → "Hello, Alice!"
```

### Pattern 2: Default with Multiple Clauses

```elixir
def process(data, opts \\ [])

def process(data, []) do
  # No options
end

def process(data, opts) do
  # With options
end
```

### Pattern 3: Keyword List Defaults

```elixir
def query(opts \\ []) do
  limit = Keyword.get(opts, :limit, 10)
  offset = Keyword.get(opts, :offset, 0)
  # ...
end

query()                           # limit=10, offset=0
query(limit: 20)                  # limit=20, offset=0
query(limit: 20, offset: 10)      # limit=20, offset=10
```

## Why This Pattern is Useful

### 1. Backward Compatibility

```elixir
# Old code still works
tokens = list_active_tokens()

# New code can use options
tokens = list_active_tokens(with_usage_count: true)
```

### 2. Clear API

```elixir
# It's obvious what the default is
def list_active_tokens(opts \\ [])
```

### 3. Flexible

```elixir
# Can add more options later without breaking existing code
def list_active_tokens(opts \\ [])

def list_active_tokens(opts) do
  with_count = Keyword.get(opts, :with_usage_count, false)
  with_user = Keyword.get(opts, :with_user, false)  # New option!
  # ...
end
```

## Comparison with Other Languages

### JavaScript (Default Parameters)

```javascript
function listActiveTokens(opts = {}) {
  // opts is always an object
  if (opts.withUsageCount) {
    // ...
  }
}
```

### Python (Default Arguments)

```python
def list_active_tokens(opts=None):
    if opts is None:
        opts = {}
    # ...
```

### Elixir (Our Pattern)

```elixir
def list_active_tokens(opts \\ [])

def list_active_tokens(opts) do
  # opts is always a list (keyword list)
  if Keyword.get(opts, :with_usage_count, false) do
    # ...
  end
end
```

## Summary

### How It Works:

1. **Header declares default**: `def function(arg \\ default)`
2. **Implementation matches**: `def function(arg)`
3. **Elixir applies default** if no argument provided
4. **Pattern matching** selects the right clause
5. **Function executes** with the matched values

### Key Points:

- ✅ Defaults are declared in a **separate header line**
- ✅ Implementation clause **matches any value** (including default)
- ✅ Elixir **applies defaults before matching**
- ✅ Pattern matching happens **top to bottom**
- ✅ This pattern provides **backward compatibility**

### Our Use Case:

```elixir
# Simple call (uses default)
Tokens.list_active_tokens()
# → opts = []

# With options
Tokens.list_active_tokens(with_usage_count: true)
# → opts = [with_usage_count: true]

# Both match the same implementation clause!
# The difference is in the opts value, handled by Keyword.get/3
```

This pattern allows us to have **optional parameters** while maintaining a **clean API** and **backward compatibility**! 🎯

