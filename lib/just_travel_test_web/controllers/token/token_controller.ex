defmodule JustTravelTestWeb.Token.TokenController do
  @moduledoc """
  Controller for token management API endpoints.
  """
  use JustTravelTestWeb, :controller

  alias JustTravelTest.Tokens

  action_fallback JustTravelTestWeb.Token.FallbackController

  # Set the default JSON view for all actions
  plug :put_view, json: JustTravelTestWeb.Token.TokenJSON

  @doc """
  Activates a token for use by a user.

  POST /api/tokens/activate
  Body: {"user_id": "uuid-string"}
  """
  def activate(conn, %{"user_id" => user_id}) do
    with {:ok, result} <- Tokens.register_token_usage(user_id) do
      conn
      |> put_status(:ok)
      |> render(:activate, result)
    end
  end

  def activate(_conn, _params) do
    {:error, :missing_user_id}
  end

  @doc """
  Lists all tokens with optional state filter.

  GET /api/tokens?state=available|active|all
  """
  def index(conn, params) do
    state_filter = Map.get(params, "state", "all")

    with {:ok, tokens} <- get_tokens_by_state(state_filter) do
      conn
      |> put_status(:ok)
      |> render(:index, tokens: tokens)
    end
  end

  @doc """
  Gets a specific token by ID with usage count.

  GET /api/tokens/:token_id
  """
  def show(conn, %{"token_id" => token_id}) do
    with token when not is_nil(token) <-
           Tokens.get_token_by_id(token_id, preload_usage_count: true) do
      usage_count = Map.get(token, :usage_count, 0)

      conn
      |> put_status(:ok)
      |> render(:show, token: token, usage_count: usage_count)
    else
      nil -> {:error, :token_not_found}
    end
  end

  @doc """
  Gets the usage records for a specific token.

  GET /api/tokens/:token_id/usages
  """
  def usages(conn, %{"token_id" => token_id}) do
    with token when not is_nil(token) <- Tokens.get_token_by_id(token_id),
         usages <- Tokens.get_token_usage_history(token_id) do
      conn
      |> put_status(:ok)
      |> render(:usages, token_id: token_id, usages: usages)
    else
      nil -> {:error, :token_not_found}
    end
  end

  @doc """
  Clears all active tokens.

  DELETE /api/tokens/active
  """
  def clear_active(conn, _params) do
    with {:ok, cleared_count} <- Tokens.clear_all_active_tokens() do
      conn
      |> put_status(:ok)
      |> render(:clear_active, cleared_count: cleared_count)
    end
  end

  ## Private Helper Functions

  defp get_tokens_by_state("available") do
    {:ok, Tokens.list_available_tokens()}
  end

  defp get_tokens_by_state("active") do
    {:ok, Tokens.list_active_tokens()}
  end

  defp get_tokens_by_state("all") do
    {:ok, Tokens.list_all_tokens()}
  end

  defp get_tokens_by_state(_) do
    {:error, :invalid_state_filter}
  end
end
