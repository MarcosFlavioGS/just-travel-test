# GenServer Explanation: How It Works and Our Usage

## What is GenServer?

**GenServer** (Generic Server) is an Elixir/Erlang behavior that provides a standardized way to build stateful, concurrent processes. It's part of OTP (Open Telecom Platform) and is one of the most commonly used abstractions in Elixir applications.

### Key Concepts

- **Stateful Process**: Maintains state between function calls
- **Message Passing**: Communicates via asynchronous messages
- **Supervised**: Can be part of a supervision tree for reliability
- **Concurrent**: Runs independently, doesn't block other code

## Why Use GenServer?

### 1. State Management
- Maintains state that persists across function calls
- Unlike regular functions, state survives between invocations

### 2. Concurrency
- Runs in its own process
- Doesn't block the main application
- Can handle multiple requests concurrently

### 3. Reliability
- Can be supervised (auto-restart on failure)
- Isolated failures (crash doesn't affect other processes)
- Part of OTP's "let it crash" philosophy

### 4. Message Passing
- Asynchronous communication
- Can handle multiple types of messages
- Built-in queuing of messages

## How GenServer Works

### Basic Structure

```elixir
defmodule MyGenServer do
  use GenServer

  # Client API (what users call)
  def start_link(initial_state) do
    GenServer.start_link(__MODULE__, initial_state, name: __MODULE__)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  # Server Callbacks (what GenServer calls)
  @impl true
  def init(initial_state) do
    {:ok, initial_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end
```

### The Lifecycle

```
1. start_link/3 called
   ↓
2. init/1 callback executed
   ↓
3. GenServer process running (waiting for messages)
   ↓
4. Messages arrive → handle_call/handle_info/handle_cast
   ↓
5. Process continues running (or terminates)
```

## GenServer Callbacks

### 1. `init/1` - Initialization

Called when the GenServer starts:

```elixir
@impl true
def init(initial_state) do
  # Initialize your process
  {:ok, state}
  # or {:ok, state, {:continue, :setup}}
  # or {:stop, reason}
end
```

**Return values:**
- `{:ok, state}` - Success, continue with `state`
- `{:ok, state, {:continue, :action}}` - Success, then call `handle_continue/2`
- `{:stop, reason}` - Stop the process

### 2. `handle_call/3` - Synchronous Messages

Handles synchronous requests (caller waits for response):

```elixir
@impl true
def handle_call(request, from, state) do
  # Process the request
  {:reply, response, new_state}
  # or {:noreply, new_state}
  # or {:stop, reason, response, new_state}
end
```

**When to use:**
- When you need a response immediately
- When you need to ensure the operation completed
- Example: Getting current state, performing calculations

**Return values:**
- `{:reply, response, new_state}` - Send response, update state
- `{:noreply, new_state}` - Don't reply yet (will reply later)
- `{:stop, reason, response, new_state}` - Stop after replying

### 3. `handle_cast/2` - Asynchronous Messages

Handles asynchronous requests (caller doesn't wait):

```elixir
@impl true
def handle_cast(request, state) do
  # Process the request
  {:noreply, new_state}
  # or {:stop, reason, new_state}
end
```

**When to use:**
- When you don't need a response
- When you want fire-and-forget operations
- Example: Updating state, triggering side effects

**Return values:**
- `{:noreply, new_state}` - Continue with new state
- `{:stop, reason, new_state}` - Stop the process

### 4. `handle_info/2` - System Messages

Handles messages sent directly to the process (not via GenServer API):

```elixir
@impl true
def handle_info(message, state) do
  # Handle the message
  {:noreply, new_state}
  # or {:stop, reason, new_state}
end
```

**When to use:**
- Timer messages (`Process.send_after/3`)
- External messages (from other processes)
- System messages (DOWN, EXIT, etc.)

**Common pattern:**
```elixir
def handle_info(:do_something, state) do
  # Do something
  schedule_next_check()  # Schedule another message
  {:noreply, state}
end
```

### 5. `handle_continue/2` - Deferred Initialization

Called after `init/1` if it returns `{:continue, action}`:

```elixir
@impl true
def handle_continue(:setup, state) do
  # Perform setup that might take time
  {:noreply, new_state}
end
```

**When to use:**
- When initialization might block
- When you want to return from `init/1` quickly
- For async initialization

## Message Types Comparison

| Type | Function | Waits for Response? | Use Case |
|------|----------|-------------------|----------|
| **Call** | `GenServer.call/2` | ✅ Yes | Get data, perform operation |
| **Cast** | `GenServer.cast/2` | ❌ No | Update state, fire-and-forget |
| **Info** | `Process.send/2` | ❌ No | Timers, external messages |

## Our Implementation: Token Manager

### The Problem We're Solving

We need to automatically release tokens that have been active for more than 2 minutes. This requires:
- **Periodic checking** (every 30 seconds)
- **Background process** (doesn't block the main app)
- **Reliability** (restarts if it crashes)
- **State management** (tracking timer references)

### Our GenServer Code

```elixir
defmodule JustTravelTest.Tokens.Manager do
  use GenServer
  alias JustTravelTest.Tokens.Expiration

  @check_interval_seconds 30

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def check_and_release_expired do
    GenServer.call(__MODULE__, :check_and_release_expired)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    timer_ref = schedule_next_check()
    {:ok, %{timer_ref: timer_ref}}
  end

  @impl true
  def handle_info(:check_expired_tokens, state) do
    case Expiration.release_expired_tokens() do
      {:ok, count} when count > 0 ->
        Logger.info("TokenManager: Released #{count} expired token(s)")
      {:ok, 0} -> :ok
      {:error, reason} ->
        Logger.error("TokenManager: Error: #{inspect(reason)}")
    end

    timer_ref = schedule_next_check()
    {:noreply, %{state | timer_ref: timer_ref}}
  end

  @impl true
  def handle_call(:check_and_release_expired, _from, state) do
    result = Expiration.release_expired_tokens()
    {:reply, result, state}
  end

  defp schedule_next_check do
    Process.send_after(self(), :check_expired_tokens, @check_interval_seconds * 1000)
  end
end
```

### How Our Implementation Works

#### 1. Starting the GenServer

```elixir
# In application.ex
children = [
  # ... other children ...
  JustTravelTest.Tokens.Manager,  # Starts automatically
  # ...
]
```

**What happens:**
1. Application supervisor calls `start_link/1`
2. GenServer process starts
3. `init/1` callback executes
4. Schedules first check via `schedule_next_check()`
5. Returns `{:ok, state}` with timer reference
6. GenServer enters message loop

#### 2. Periodic Checks (handle_info)

```elixir
def handle_info(:check_expired_tokens, state) do
  # This runs every 30 seconds
  Expiration.release_expired_tokens()
  schedule_next_check()  # Schedule next check
  {:noreply, new_state}
end
```

**How it works:**
1. `schedule_next_check()` sends a message to self after 30 seconds
2. After 30 seconds, `:check_expired_tokens` message arrives
3. `handle_info/2` is called
4. Checks for expired tokens and releases them
5. Schedules the next check
6. Process continues waiting for next message

**The Timer Pattern:**
```elixir
Process.send_after(self(), :check_expired_tokens, 30000)
#                    ↑        ↑                    ↑
#                    |        |                    |
#              Send to    Message name      Milliseconds
#              this process
```

#### 3. Manual Check (handle_call)

```elixir
def handle_call(:check_and_release_expired, _from, state) do
  result = Expiration.release_expired_tokens()
  {:reply, result, state}  # Send result back to caller
end
```

**Usage:**
```elixir
# From anywhere in the code
result = JustTravelTest.Tokens.Manager.check_and_release_expired()
# Returns: {:ok, count} or {:error, reason}
```

**Why use `call` here?**
- We want to know the result immediately
- Useful for testing and manual intervention
- Synchronous operation ensures we get the result

### State Management

Our state is simple:
```elixir
%{timer_ref: timer_reference}
```

**Why store timer_ref?**
- Could cancel timer if needed (for graceful shutdown)
- Track active timers
- Debugging purposes

**State updates:**
```elixir
# Initial state
{:ok, %{timer_ref: ref1}}

# After first check
{:noreply, %{timer_ref: ref2}}  # New timer reference
```

### The Message Flow

```
Time 0s:   GenServer starts
            ↓
            init/1 schedules check
            ↓
Time 30s:  :check_expired_tokens message arrives
            ↓
            handle_info/2 executes
            ↓
            Releases expired tokens
            ↓
            Schedules next check
            ↓
Time 60s:  :check_expired_tokens message arrives
            ↓
            handle_info/2 executes
            ↓
            ... and so on
```

## Supervision Integration

### Why Supervision Matters

Our GenServer is **supervised**, meaning:

1. **Auto-restart**: If it crashes, supervisor restarts it
2. **Isolation**: Crash doesn't affect other processes
3. **Reliability**: System continues working even if manager fails

### How It's Supervised

```elixir
# In application.ex
children = [
  JustTravelTest.Tokens.Manager,  # ← Supervised!
  # ...
]

Supervisor.start_link(children, strategy: :one_for_one)
```

**Supervision Strategy: `:one_for_one`**
- If Manager crashes, only Manager restarts
- Other children (Repo, Endpoint, etc.) are unaffected

**What happens on crash:**
1. Manager process crashes
2. Supervisor detects crash
3. Supervisor restarts Manager
4. `init/1` is called again
5. New periodic checks start
6. System continues normally

## Real-World Example Flow

### Scenario: Token Expires After 2 Minutes

```
Time 0s:    User registers token usage
            Token activated_at = 14:00:00

Time 30s:   Manager checks (handle_info)
            No expired tokens (only 30s old)
            Schedules next check

Time 60s:   Manager checks
            No expired tokens (only 60s old)
            Schedules next check

Time 90s:   Manager checks
            No expired tokens (only 90s old)
            Schedules next check

Time 120s:  Manager checks
            Token is 120s old (> 2 minutes)
            Expiration.release_expired_tokens() called
            Token released!
            Logger.info("Released 1 expired token")
            Schedules next check

Time 150s:  Manager checks
            No expired tokens
            Continues...
```

## Key Benefits of Our Approach

### 1. Non-Blocking
- Runs in background
- Doesn't slow down API requests
- Doesn't block the main application

### 2. Reliable
- Supervised (auto-restarts)
- Continues even if individual checks fail
- Isolated failures

### 3. Efficient
- Single process for all checks
- Batch processing (releases all expired at once)
- Configurable interval

### 4. Testable
- Can manually trigger checks
- Can test expiration logic separately
- Easy to verify behavior

## Common GenServer Patterns

### Pattern 1: Periodic Tasks (Our Pattern)

```elixir
def handle_info(:tick, state) do
  # Do periodic work
  schedule_next_tick()
  {:noreply, state}
end

defp schedule_next_tick do
  Process.send_after(self(), :tick, interval)
end
```

### Pattern 2: State Cache

```elixir
def handle_call(:get_data, _from, state) do
  if state.cache_valid? do
    {:reply, state.cached_data, state}
  else
    data = fetch_data()
    {:reply, data, %{state | cache: data, cache_valid?: true}}
  end
end
```

### Pattern 3: Queue Processor

```elixir
def handle_cast({:add_task, task}, state) do
  queue = [task | state.queue]
  process_queue(%{state | queue: queue})
  {:noreply, %{state | queue: queue}}
end

def handle_info({:process_next, result}, state) do
  # Process next item in queue
  {:noreply, state}
end
```

## Debugging GenServer

### Check if Running

```elixir
Process.whereis(JustTravelTest.Tokens.Manager)
# Returns: #PID<0.123.0> if running
# Returns: nil if not running
```

### Inspect State

```elixir
:sys.get_state(JustTravelTest.Tokens.Manager)
# Returns current state
```

### Trace Messages

```elixir
:sys.trace(JustTravelTest.Tokens.Manager, true)
# See all messages being sent/received
```

## Summary

### What GenServer Provides

1. **Stateful Process**: Maintains state between calls
2. **Message Handling**: Handles synchronous and asynchronous messages
3. **Concurrency**: Runs independently
4. **Supervision**: Can be supervised for reliability

### How We Use It

1. **Periodic Checks**: Every 30 seconds
2. **Background Processing**: Doesn't block main app
3. **Token Expiration**: Automatically releases expired tokens
4. **Reliability**: Supervised, auto-restarts on failure

### Key Concepts

- **init/1**: Sets up initial state and schedules first check
- **handle_info/2**: Handles timer messages for periodic checks
- **handle_call/3**: Handles synchronous requests (manual checks)
- **Process.send_after/3**: Schedules future messages to self
- **Supervision**: Ensures process restarts if it crashes

### Why It's Perfect for Our Use Case

✅ **Background Processing**: Runs independently  
✅ **Periodic Execution**: Timer-based checks  
✅ **Reliability**: Supervised, auto-restarts  
✅ **Non-Blocking**: Doesn't affect API performance  
✅ **Simple**: Easy to understand and maintain  

GenServer is the perfect tool for our token expiration system! 🎯

