defmodule JustTravelTest.Tokens.Manager do
  @moduledoc """
  GenServer that periodically checks for and releases expired tokens.

  This process runs a periodic job every N seconds (configurable) to find
  tokens that have been active for more than the configured lifetime (2 minutes)
  and automatically releases them.

  The process is supervised and will automatically restart on failure.
  """
  use GenServer
  alias JustTravelTest.Tokens.Expiration

  @check_interval_seconds Application.compile_env(
                            :just_travel_test,
                            [JustTravelTest.Tokens, :check_interval_seconds],
                            30
                          )

  ## Client API

  @doc """
  Starts the token manager GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Manually triggers a check for expired tokens.
  Useful for testing or manual intervention.
  """
  def check_and_release_expired do
    GenServer.call(__MODULE__, :check_and_release_expired)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    # Schedule the first check
    timer_ref = schedule_next_check()

    {:ok, %{timer_ref: timer_ref}}
  end

  @impl true
  def handle_info(:check_expired_tokens, state) do
    # Perform the check and release expired tokens
    case Expiration.release_expired_tokens() do
      {:ok, count} when count > 0 ->
        require Logger
        Logger.info("TokenManager: Released #{count} expired token(s)")

      {:ok, 0} ->
        :ok

      {:error, reason} ->
        require Logger
        Logger.error("TokenManager: Error releasing expired tokens: #{inspect(reason)}")
    end

    # Schedule the next check and update state
    timer_ref = schedule_next_check()

    {:noreply, %{state | timer_ref: timer_ref}}
  end

  @impl true
  def handle_call(:check_and_release_expired, _from, state) do
    result = Expiration.release_expired_tokens()
    {:reply, result, state}
  end

  defp schedule_next_check do
    # Returns a timer reference that can be used to cancel if needed
    Process.send_after(self(), :check_expired_tokens, @check_interval_seconds * 1000)
  end
end
