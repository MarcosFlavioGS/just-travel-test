defmodule JustTravelTestWeb.Token.TokenJSON do
  @moduledoc """
  This module contains all view functions for token API responses.
  """

  @doc """
  Renders the activated token response.
  """
  def activate(%{token_id: token_id, user_id: user_id}) do
    %{
      token_id: token_id,
      user_id: user_id
    }
  end

  @doc """
  Renders a list of tokens.
  """
  def index(%{tokens: tokens}) do
    %{
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
    }
  end

  @doc """
  Renders a single token with usage count.
  """
  def show(%{token: token, usage_count: usage_count}) do
    %{
      token_id: token.id,
      state: to_string(token.state),
      current_user_id: token.utilizer_uuid,
      activated_at: token.activated_at,
      released_at: token.released_at,
      usage_count: usage_count
    }
  end

  @doc """
  Renders token usage records.
  """
  def usages(%{token_id: token_id, usages: usages}) do
    %{
      token_id: token_id,
      usages:
        Enum.map(usages, fn usage ->
          %{
            user_id: usage.user_id,
            started_at: usage.started_at,
            ended_at: usage.ended_at
          }
        end)
    }
  end

  @doc """
  Renders the clear active tokens response.
  """
  def clear_active(%{cleared_count: cleared_count}) do
    %{
      cleared_count: cleared_count,
      status: "ok"
    }
  end
end
