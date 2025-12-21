defmodule JustTravelTestWeb.Health.HealthController do
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

  action_fallback JustTravelTestWeb.Health.FallbackController

  plug :accepts, ["json"]

  @doc """
  Health check endpoint.

  Returns 200 OK if all systems are healthy, 503 Service Unavailable otherwise.
  """
  def check(conn, _params) do
    with {:ok, checks} <- check_health() do
      conn
      |> put_status(:ok)
      |> render(:check, checks: checks)
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
    with {:ok, active_count} <- safe_count(fn -> Tokens.count_active_tokens() end),
         {:ok, available_count} <- safe_count(fn -> Tokens.count_available_tokens() end) do
      {:ok,
       %{
         active_tokens: active_count,
         available_tokens: available_count,
         total_tokens: active_count + available_count
       }}
    else
      {:error, reason} -> {:error, "failed: #{inspect(reason)}"}
    end
  end

  defp safe_count(operation) do
    try do
      {:ok, operation.()}
    rescue
      e -> {:error, e}
    end
  end

  defp format_checks(checks) do
    Enum.into(checks, %{}, fn {key, {status, details}} ->
      {key, %{status: status, details: details}}
    end)
  end
end
