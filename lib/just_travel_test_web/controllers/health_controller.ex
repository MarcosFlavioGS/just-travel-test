defmodule JustTravelTestWeb.HealthController do
  @moduledoc """
  Health check endpoint for monitoring and load balancers.

  Returns the status of critical system components:
  - Database connectivity
  - Token manager process status
  - System metrics
  """
  use JustTravelTestWeb, :controller
  alias JustTravelTest.Repo
  alias JustTravelTest.Tokens
  alias JustTravelTest.Tokens.Manager

  @doc """
  Health check endpoint.

  Returns 200 OK if all systems are healthy, 503 Service Unavailable otherwise.
  """
  def check(conn, _params) do
    case check_health() do
      {:ok, details} ->
        conn
        |> put_status(:ok)
        |> json(%{
          status: "healthy",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          checks: details
        })

      {:error, details} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{
          status: "unhealthy",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          checks: details
        })
    end
  end

  defp check_health do
    checks = %{
      database: check_database(),
      token_manager: check_token_manager(),
      metrics: get_metrics()
    }

    if Enum.all?(checks, fn {_key, {status, _details}} -> status == :ok end) do
      {:ok, format_checks(checks)}
    else
      {:error, format_checks(checks)}
    end
  end

  defp check_database do
    case Repo.query("SELECT 1", []) do
      {:ok, _result} ->
        {:ok, "connected"}

      {:error, reason} ->
        {:error, "disconnected: #{inspect(reason)}"}
    end
  end

  defp check_token_manager do
    case Process.whereis(Manager) do
      nil ->
        {:error, "not_running"}

      pid when is_pid(pid) ->
        if Process.alive?(pid) do
          {:ok, "running"}
        else
          {:error, "dead"}
        end
    end
  end

  defp get_metrics do
    try do
      active_count = Tokens.count_active_tokens()
      available_count = Tokens.count_available_tokens()

      {:ok,
       %{
         active_tokens: active_count,
         available_tokens: available_count,
         total_tokens: active_count + available_count
       }}
    rescue
      e -> {:error, "failed: #{inspect(e)}"}
    end
  end

  defp format_checks(checks) do
    Enum.into(checks, %{}, fn {key, {status, details}} ->
      {key, %{status: status, details: details}}
    end)
  end
end
