defmodule JustTravelTest.Tokens.Registration do
  @moduledoc """
  Handles token registration and activation logic.
  """
  import Ecto.Query
  alias JustTravelTest.Repo
  alias JustTravelTest.Token.TokenSchema
  alias JustTravelTest.Token.TokenUsageSchema
  alias JustTravelTest.Tokens.Release
  alias JustTravelTest.Tokens.Queries

  @max_active_tokens Application.compile_env(
                       :just_travel_test,
                       [JustTravelTest.Tokens, :max_active_tokens],
                       100
                     )

  @doc """
  Registers a token for use by a user.

  This is the main entry point for token activation. It:
  1. Checks if the limit of 100 active tokens is reached
  2. If reached, releases the oldest active token
  3. Activates an available token for the user
  4. Creates a usage history record

  Returns `{:ok, %{token_id: uuid, user_id: uuid}}` on success.
  Returns `{:error, reason}` on failure.
  """
  def register_token_usage(user_id) when is_binary(user_id) do
    Repo.transaction(fn ->
      # Validate user_id is a valid UUID
      case Ecto.UUID.cast(user_id) do
        {:ok, _uuid} ->
          do_register_token_usage(user_id)

        :error ->
          Repo.rollback(:invalid_user_id)
      end
    end)
    |> case do
      {:ok, result} -> result
      {:error, reason} -> {:error, reason}
    end
  end

  def register_token_usage(_), do: {:error, :invalid_user_id}

  defp do_register_token_usage(user_id) do
    # Check if we're at the limit
    active_count = Queries.count_active_tokens()

    if active_count >= @max_active_tokens do
      # Release the oldest active token
      Release.release_oldest_active_token()
    end

    # Find an available token
    case get_available_token() do
      nil ->
        Repo.rollback(:no_available_tokens)

      token ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        # Activate the token
        token
        |> TokenSchema.changeset(%{
          state: :active,
          utilizer_uuid: user_id,
          activated_at: now
        })
        |> Repo.update!()

        # Create usage history record
        %TokenUsageSchema{}
        |> TokenUsageSchema.changeset(%{
          token_id: token.id,
          user_id: user_id,
          started_at: now
        })
        |> Repo.insert!()

        {:ok, %{token_id: token.id, user_id: user_id}}
    end
  end

  defp get_available_token do
    from(t in TokenSchema,
      where: t.state == :available,
      limit: 1,
      lock: "FOR UPDATE SKIP LOCKED"
    )
    |> Repo.one()
  end
end
