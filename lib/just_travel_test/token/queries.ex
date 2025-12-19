defmodule JustTravelTest.Tokens.Queries do
  @moduledoc """
  Handles token query operations.
  """
  import Ecto.Query
  alias JustTravelTest.Repo
  alias JustTravelTest.Token.TokenSchema

  @doc """
  Lists all tokens with their current state.
  """
  def list_all_tokens do
    from(t in TokenSchema, order_by: [asc: t.id])
    |> Repo.all()
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
  """
  def list_active_tokens do
    from(t in TokenSchema, where: t.state == :active, order_by: [asc: t.activated_at])
    |> Repo.all()
  end

  @doc """
  Gets a token by its ID.
  """
  def get_token_by_id(token_id) when is_binary(token_id) do
    case Ecto.UUID.cast(token_id) do
      {:ok, _uuid} -> Repo.get(TokenSchema, token_id)
      :error -> nil
    end
  end

  def get_token_by_id(_), do: nil

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
