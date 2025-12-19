defmodule JustTravelTestWeb.TokenController do
  @moduledoc """
  Controller for token management API endpoints.
  """
  use JustTravelTestWeb, :controller
  alias JustTravelTest.Tokens

  @doc """
  Activates a token for use by a user.

  POST /api/tokens/activate
  Body: {"user_id": "uuid-string"}
  """
  def activate(conn, %{"user_id" => user_id}) do
    case Tokens.register_token_usage(user_id) do
      {:ok, %{token_id: token_id, user_id: user_id}} ->
        json(conn, %{
          token_id: token_id,
          user_id: user_id
        })

      {:error, :invalid_user_id} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid user_id format. Must be a valid UUID."})

      {:error, :no_available_tokens} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "No available tokens. This should not happen."})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to register token usage: #{inspect(reason)}"})
    end
  end

  def activate(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameter: user_id"})
  end

  @doc """
  Lists all tokens with optional state filter.

  GET /api/tokens?state=available|active|all
  """
  def index(conn, params) do
    state_filter = Map.get(params, "state", "all")

    tokens =
      case state_filter do
        "available" ->
          Tokens.list_available_tokens()

        "active" ->
          Tokens.list_active_tokens()

        "all" ->
          Tokens.list_all_tokens()

        _ ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "Invalid state filter. Must be 'available', 'active', or 'all'."})
          |> halt()
      end

    if conn.halted? do
      conn
    else
      json(conn, %{
        tokens:
          Enum.map(tokens, fn token ->
            %{
              token_id: token.id,
              state: to_string(token.state),
              current_user_id: token.utilizer_uuid,
              activated_at: token.activated_at,
              released_at: token.released_at
            }
          end)
      })
    end
  end

  @doc """
  Gets a specific token by ID with usage count.

  GET /api/tokens/:token_id
  """
  def show(conn, %{"token_id" => token_id}) do
    case Tokens.get_token_by_id(token_id, preload_usage_count: true) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Token not found"})

      token ->
        usage_count = Map.get(token, :usage_count, 0)

        json(conn, %{
          token_id: token.id,
          state: to_string(token.state),
          current_user_id: token.utilizer_uuid,
          activated_at: token.activated_at,
          released_at: token.released_at,
          usage_count: usage_count
        })
    end
  end

  @doc """
  Gets the usage records for a specific token.

  GET /api/tokens/:token_id/usages
  """
  def usages(conn, %{"token_id" => token_id}) do
    # First verify token exists
    case Tokens.get_token_by_id(token_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Token not found"})

      _token ->
        usages = Tokens.get_token_usage_history(token_id)

        json(conn, %{
          token_id: token_id,
          usages:
            Enum.map(usages, fn usage ->
              %{
                user_id: usage.user_id,
                started_at: usage.started_at,
                ended_at: usage.ended_at
              }
            end)
        })
    end
  end

  @doc """
  Clears all active tokens.

  DELETE /api/tokens/active
  """
  def clear_active(conn, _params) do
    case Tokens.clear_all_active_tokens() do
      {:ok, cleared_count} ->
        json(conn, %{
          cleared_count: cleared_count,
          status: "ok"
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to clear active tokens: #{inspect(reason)}"})
    end
  end
end
