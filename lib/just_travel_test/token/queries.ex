defmodule JustTravelTest.Tokens.Queries do
  @moduledoc """
  Handles token query operations.
  """
  import Ecto.Query
  alias JustTravelTest.Repo
  alias JustTravelTest.Token.TokenSchema

  @doc """
  Lists all tokens with their current state.

  Optionally includes usage counts via preload.
  """
  def list_all_tokens(opts \\ [])

  def list_all_tokens(opts) do
    query = from(t in TokenSchema, order_by: [asc: t.id])

    if Keyword.get(opts, :with_usage_count, false) do
      # Use a join to get usage counts efficiently
      from(t in query,
        left_join: usage in assoc(t, :token_usages),
        group_by: [t.id],
        select: %{
          token: t,
          usage_count: count(usage.id)
        }
      )
      |> Repo.all()
      |> Enum.map(fn %{token: token, usage_count: count} ->
        token
        |> Map.from_struct()
        |> Map.put(:usage_count, count)
      end)
    else
      Repo.all(query)
    end
  end

  @doc """
  Lists all available tokens.
  """
  def list_available_tokens do
    from(t in TokenSchema, where: t.state == :available, order_by: [asc: t.id])
    |> Repo.all()
  end

  @doc """
  Lists all active tokens.

  Optionally includes usage counts via preload.
  """
  def list_active_tokens(opts \\ [])

  def list_active_tokens(opts) do
    query = from(t in TokenSchema, where: t.state == :active, order_by: [asc: t.activated_at])

    if Keyword.get(opts, :with_usage_count, false) do
      # Use a join to get usage counts efficiently
      from(t in query,
        left_join: usage in assoc(t, :token_usages),
        group_by: [t.id],
        select: %{
          token: t,
          usage_count: count(usage.id)
        }
      )
      |> Repo.all()
      |> Enum.map(fn %{token: token, usage_count: count} ->
        token
        |> Map.from_struct()
        |> Map.put(:usage_count, count)
      end)
    else
      Repo.all(query)
    end
  end

  @doc """
  Gets a token by its ID.

  Optionally preloads token_usages if needed.
  """
  def get_token_by_id(token_id, opts \\ [])

  def get_token_by_id(token_id, opts) when is_binary(token_id) do
    case Ecto.UUID.cast(token_id) do
      {:ok, _uuid} ->
        query = TokenSchema |> where([t], t.id == ^token_id)

        query =
          if Keyword.get(opts, :preload_usage_count, false) do
            # Use a join to get usage count in a single query
            from(t in query,
              left_join: usage in assoc(t, :token_usages),
              group_by: [t.id],
              select: %{
                token: t,
                usage_count: count(usage.id)
              }
            )
          else
            query
          end

        result = Repo.one(query)

        case result do
          %{token: token, usage_count: count} ->
            # Add usage_count as a map field (not a struct field)
            token
            |> Map.from_struct()
            |> Map.put(:usage_count, count)

          token when is_struct(token) ->
            token

          _ ->
            nil
        end

      :error ->
        nil
    end
  end

  def get_token_by_id(_, _), do: nil

  @doc """
  Gets the active token for a user.
  """
  def get_token_by_user(user_id) when is_binary(user_id) do
    case Ecto.UUID.cast(user_id) do
      {:ok, _uuid} ->
        from(t in TokenSchema,
          where: t.state == :active and t.utilizer_uuid == ^user_id,
          limit: 1
        )
        |> Repo.one()

      :error ->
        nil
    end
  end

  def get_token_by_user(_), do: nil

  @doc """
  Counts active tokens.
  """
  def count_active_tokens do
    from(t in TokenSchema, where: t.state == :active, select: count())
    |> Repo.one()
  end

  @doc """
  Counts available tokens.
  """
  def count_available_tokens do
    from(t in TokenSchema, where: t.state == :available, select: count())
    |> Repo.one()
  end
end
