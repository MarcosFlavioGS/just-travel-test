defmodule JustTravelTestWeb.Plugs.RateLimiter do
  @moduledoc """
  Simple rate limiting plug using ETS for in-memory storage.

  Limits requests per IP address within a time window.
  """
  import Plug.Conn
  use JustTravelTestWeb, :controller
  require Logger

  @default_limit 100
  @default_window_ms 60_000

  def init(opts) do
    limit = Keyword.get(opts, :limit, @default_limit)
    window_ms = Keyword.get(opts, :window_ms, @default_window_ms)
    table_name = Keyword.get(opts, :table_name, :rate_limiter)

    # Create ETS table if it doesn't exist
    case :ets.whereis(table_name) do
      :undefined ->
        :ets.new(table_name, [:set, :public, :named_table, read_concurrency: true])

      _ ->
        :ok
    end

    %{limit: limit, window_ms: window_ms, table_name: table_name}
  end

  def call(conn, %{limit: limit, window_ms: window_ms, table_name: table_name}) do
    client_ip = get_client_ip(conn)
    now = System.system_time(:millisecond)

    case check_rate_limit(client_ip, limit, window_ms, table_name, now) do
      :ok ->
        conn

      {:error, :rate_limit_exceeded} ->
        Logger.warning("Rate limit exceeded",
          client_ip: client_ip,
          limit: limit,
          window_ms: window_ms
        )

        conn
        |> put_status(:too_many_requests)
        |> json(%{
          error: "Rate limit exceeded",
          message: "Too many requests. Please try again later.",
          retry_after: div(window_ms, 1000)
        })
        |> halt()
    end
  end

  defp check_rate_limit(client_ip, limit, window_ms, table_name, now) do
    key = {client_ip, div(now, window_ms)}

    case :ets.lookup(table_name, key) do
      [] ->
        :ets.insert(table_name, {key, 1, now})
        :ok

      [{^key, count, _timestamp}] when count < limit ->
        :ets.update_element(table_name, key, {2, count + 1})
        :ok

      [{^key, count, _timestamp}] when count >= limit ->
        {:error, :rate_limit_exceeded}
    end
  end

  defp get_client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      [] -> to_string(:inet_parse.ntoa(conn.remote_ip))
    end
  end
end
