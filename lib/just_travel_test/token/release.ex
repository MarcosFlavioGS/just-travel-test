defmodule JustTravelTest.Tokens.Release do
  @moduledoc """
  Handles token release operations.
  """
  import Ecto.Query
  alias JustTravelTest.Repo
  alias JustTravelTest.Token.TokenSchema
  alias JustTravelTest.Token.TokenUsageSchema
  alias JustTravelTest.Tokens.Queries

  @doc """
  Releases a token by its ID.

  Sets the token state to `:available` and closes the active usage record.
  """
  def release_token(token_id) when is_binary(token_id) do
    case Ecto.UUID.cast(token_id) do
      {:ok, _uuid} ->
        Repo.transaction(fn ->
          case Repo.get(TokenSchema, token_id) do
            nil ->
              Repo.rollback({:error, :token_not_found})

            token when token.state == :available ->
              token

            token ->
              now = DateTime.utc_now() |> DateTime.truncate(:second)

              # Update token
              updated_token =
                token
                |> TokenSchema.changeset(%{
                  state: :available,
                  utilizer_uuid: nil,
                  released_at: now
                })
                |> Repo.update!()

              # Close active usage record
              close_active_usage(token_id, now)

              updated_token
          end
        end)
        |> case do
          {:ok, token} -> {:ok, token}
          {:error, {:error, reason}} -> {:error, reason}
          {:error, reason} -> {:error, reason}
        end

      :error ->
        {:error, :invalid_token_id}
    end
  end

  def release_token(_), do: {:error, :invalid_token_id}

  @doc """
  Releases a token by user ID.

  Finds the active token for a user and releases it.
  """
  def release_token_by_user(user_id) when is_binary(user_id) do
    case Ecto.UUID.cast(user_id) do
      {:ok, _uuid} ->
        case Queries.get_token_by_user(user_id) do
          nil ->
            {:error, :no_active_token_for_user}

          token ->
            release_token(token.id)
        end

      :error ->
        {:error, :invalid_user_id}
    end
  end

  def release_token_by_user(_), do: {:error, :invalid_user_id}

  @doc """
  Releases the oldest active token.

  This is an internal function used for limit management.
  Finds the token with the earliest `activated_at` timestamp and releases it.
  """
  def release_oldest_active_token do
    case get_oldest_active_token() do
      nil ->
        {:error, :no_active_tokens}

      token ->
        release_token(token.id)
        |> case do
          {:ok, _token} -> {:ok, token.id}
          error -> error
        end
    end
  end

  @doc """
  Clears all active tokens.

  Releases all currently active tokens and closes their usage records.
  Returns the count of cleared tokens.
  """
  def clear_all_active_tokens do
    Repo.transaction(fn ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Get all active token IDs
      active_token_ids =
        from(t in TokenSchema, where: t.state == :active, select: t.id)
        |> Repo.all()

      # Update all tokens to available
      {count, _} =
        from(t in TokenSchema, where: t.state == :active)
        |> Repo.update_all(
          set: [
            state: :available,
            utilizer_uuid: nil,
            released_at: now
          ]
        )

      # Close all active usage records
      from(usage in TokenUsageSchema,
        where: usage.token_id in ^active_token_ids and is_nil(usage.ended_at)
      )
      |> Repo.update_all(set: [ended_at: now])

      count
    end)
    |> case do
      {:ok, count} -> {:ok, count}
      {:error, reason} -> {:error, reason}
    end
  end

  ## Private Helper Functions

  defp get_oldest_active_token do
    from(t in TokenSchema,
      where: t.state == :active,
      order_by: [asc: t.activated_at],
      limit: 1
    )
    |> Repo.one()
  end

  defp close_active_usage(token_id, ended_at) do
    from(usage in TokenUsageSchema,
      where: usage.token_id == ^token_id and is_nil(usage.ended_at)
    )
    |> Repo.update_all(set: [ended_at: ended_at])
  end
end
