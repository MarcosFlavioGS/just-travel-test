defmodule JustTravelTest.Tokens.History do
  @moduledoc """
  Handles token usage history operations.
  """
  import Ecto.Query
  alias JustTravelTest.Repo
  alias JustTravelTest.Token.TokenUsageSchema

  @doc """
  Gets the usage history for a specific token.

  Returns all usage records ordered by `started_at` descending (most recent first).
  """
  def get_token_usage_history(token_id) when is_binary(token_id) do
    case Ecto.UUID.cast(token_id) do
      {:ok, _uuid} ->
        from(usage in TokenUsageSchema,
          where: usage.token_id == ^token_id,
          order_by: [desc: usage.started_at]
        )
        |> Repo.all()

      :error ->
        []
    end
  end

  def get_token_usage_history(_), do: []
end
