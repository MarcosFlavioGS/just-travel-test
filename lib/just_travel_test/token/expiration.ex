defmodule JustTravelTest.Tokens.Expiration do
  @moduledoc """
  Handles expired token management.
  """
  import Ecto.Query
  alias JustTravelTest.Repo
  alias JustTravelTest.Token.TokenSchema
  alias JustTravelTest.Token.TokenUsageSchema

  @token_lifetime_minutes Application.compile_env(:just_travel_test, [JustTravelTest.Tokens, :token_lifetime_minutes], 2)

  @doc """
  Finds tokens that have been active for more than the configured lifetime.

  Returns a list of tokens that should be released.
  """
  def find_expired_tokens do
    cutoff_time =
      DateTime.utc_now()
      |> DateTime.add(-@token_lifetime_minutes, :minute)
      |> DateTime.truncate(:second)

    from(t in TokenSchema,
      where: t.state == :active and t.activated_at < ^cutoff_time,
      order_by: [asc: t.activated_at]
    )
    |> Repo.all()
  end

  @doc """
  Releases all expired tokens.

  Finds tokens active for more than the configured lifetime and releases them.
  Returns the count of released tokens.
  """
  def release_expired_tokens do
    expired_tokens = find_expired_tokens()

    if Enum.empty?(expired_tokens) do
      {:ok, 0}
    else
      Repo.transaction(fn ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        expired_token_ids = Enum.map(expired_tokens, & &1.id)

        # Update all expired tokens
        {count, _} =
          from(t in TokenSchema, where: t.id in ^expired_token_ids)
          |> Repo.update_all(
            set: [
              state: :available,
              utilizer_uuid: nil,
              released_at: now
            ]
          )

        # Close all active usage records for expired tokens
        from(usage in TokenUsageSchema,
          where: usage.token_id in ^expired_token_ids and is_nil(usage.ended_at)
        )
        |> Repo.update_all(set: [ended_at: now])

        count
      end)
      |> case do
        {:ok, count} -> {:ok, count}
        {:error, reason} -> {:error, reason}
      end
    end
  end
end
