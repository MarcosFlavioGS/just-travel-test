defmodule JustTravelTest.TokenFactory do
  @moduledoc """
  Factory functions for creating test tokens and token usages.
  """

  alias JustTravelTest.Repo
  alias JustTravelTest.Token.{TokenSchema, TokenUsageSchema}

  @doc """
  Creates a token with the given attributes.

  ## Examples

      # Create an available token
      token = create_token()

      # Create an active token
      token = create_token(state: :active, utilizer_uuid: Ecto.UUID.generate())

      # Create a token activated 3 minutes ago (expired)
      token = create_token(
        state: :active,
        utilizer_uuid: Ecto.UUID.generate(),
        activated_at: DateTime.add(DateTime.utc_now(), -180, :second)
      )
  """
  def create_token(attrs \\ []) do
    defaults = [
      id: Ecto.UUID.generate(),
      state: :available,
      utilizer_uuid: nil,
      activated_at: nil,
      released_at: nil,
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    ]

    # Merge attrs over defaults (attrs take precedence)
    final_attrs =
      defaults
      |> Keyword.merge(attrs)
      |> Enum.into(%{})

    %TokenSchema{}
    |> TokenSchema.changeset(final_attrs)
    |> Repo.insert!()
  end

  @doc """
  Creates multiple tokens at once.

  ## Examples

      # Create 10 available tokens
      tokens = create_tokens(10)

      # Create 5 active tokens
      tokens = create_tokens(5, state: :active, utilizer_uuid: Ecto.UUID.generate())
  """
  def create_tokens(count, attrs \\ []) do
    1..count
    |> Enum.map(fn _ -> create_token(attrs) end)
  end

  @doc """
  Creates a token usage record.

  ## Examples

      # Create an active usage (no ended_at)
      usage = create_token_usage(token_id: token.id, user_id: Ecto.UUID.generate())

      # Create a completed usage
      usage = create_token_usage(
        token_id: token.id,
        user_id: Ecto.UUID.generate(),
        started_at: DateTime.add(DateTime.utc_now(), -300, :second),
        ended_at: DateTime.add(DateTime.utc_now(), -60, :second)
      )
  """
  def create_token_usage(attrs) do
    defaults = [
      id: Ecto.UUID.generate(),
      started_at: DateTime.utc_now() |> DateTime.truncate(:second),
      ended_at: nil,
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    ]

    attrs
    |> Keyword.merge(defaults)
    |> Enum.into(%{})
    |> then(&Repo.insert!(%TokenUsageSchema{} |> Ecto.Changeset.change(&1)))
  end

  @doc """
  Creates a user UUID for testing.
  """
  def user_uuid, do: Ecto.UUID.generate()

  @doc """
  Helper to create an expired token (activated more than 2 minutes ago).
  """
  def create_expired_token(attrs \\ []) do
    expired_time = DateTime.add(DateTime.utc_now(), -180, :second)

    create_token(
      Keyword.merge(
        [
          state: :active,
          activated_at: expired_time,
          utilizer_uuid: Ecto.UUID.generate()
        ],
        attrs
      )
    )
  end

  @doc """
  Helper to create a token that will expire soon (activated 1 minute 50 seconds ago).
  """
  def create_soon_to_expire_token(attrs \\ []) do
    soon_to_expire_time = DateTime.add(DateTime.utc_now(), -110, :second)

    create_token(
      Keyword.merge(
        [
          state: :active,
          activated_at: soon_to_expire_time,
          utilizer_uuid: Ecto.UUID.generate()
        ],
        attrs
      )
    )
  end
end
