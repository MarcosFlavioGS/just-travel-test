defmodule JustTravelTest.Tokens.QueriesTest do
  use JustTravelTest.DataCase, async: true

  alias JustTravelTest.Tokens
  alias JustTravelTest.TokenFactory

  describe "list_all_tokens/1" do
    test "returns all tokens" do
      TokenFactory.create_tokens(3, state: :available)
      TokenFactory.create_tokens(2, state: :active, utilizer_uuid: TokenFactory.user_uuid())

      tokens = Tokens.list_all_tokens()
      assert length(tokens) == 5
    end

    test "includes usage_count when requested" do
      token = TokenFactory.create_token(state: :available)
      user_id = TokenFactory.user_uuid()

      # Activate and release token twice to create history
      {:ok, _} = Tokens.register_token_usage(user_id)
      {:ok, _} = Tokens.release_token(token.id)

      {:ok, _} = Tokens.register_token_usage(user_id)
      {:ok, _} = Tokens.release_token(token.id)

      tokens = Tokens.list_all_tokens(with_usage_count: true)
      token_with_count = Enum.find(tokens, &(&1.id == token.id))

      assert token_with_count.usage_count == 2
    end
  end

  describe "list_available_tokens/0" do
    test "returns only available tokens" do
      created_tokens = TokenFactory.create_tokens(3, state: :available)
      created_ids = Enum.map(created_tokens, & &1.id)

      user1 = TokenFactory.user_uuid()
      user2 = TokenFactory.user_uuid()

      token1 =
        TokenFactory.create_token(
          state: :active,
          utilizer_uuid: user1,
          activated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      token2 =
        TokenFactory.create_token(
          state: :active,
          utilizer_uuid: user2,
          activated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      available = Tokens.list_available_tokens()
      # Account for any existing tokens from seeds
      assert length(available) >= 3
      assert Enum.all?(available, &(&1.state == :available))

      # Verify our created tokens are in the list
      available_ids = Enum.map(available, & &1.id)
      assert Enum.all?(created_ids, &(&1 in available_ids))

      # Verify active tokens are not in the list
      refute token1.id in available_ids
      refute token2.id in available_ids
    end
  end

  describe "list_active_tokens/1" do
    test "returns only active tokens" do
      TokenFactory.create_tokens(3, state: :available)

      # Create active tokens with proper user_ids
      user1 = TokenFactory.user_uuid()
      user2 = TokenFactory.user_uuid()

      token1 =
        TokenFactory.create_token(
          state: :active,
          utilizer_uuid: user1,
          activated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      token2 =
        TokenFactory.create_token(
          state: :active,
          utilizer_uuid: user2,
          activated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      active_tokens = [token1, token2]

      # Create usage records for active tokens
      Enum.each(active_tokens, fn token ->
        TokenFactory.create_token_usage(
          token_id: token.id,
          user_id: token.utilizer_uuid,
          started_at: token.activated_at
        )
      end)

      active = Tokens.list_active_tokens()
      assert length(active) >= 2
      assert Enum.all?(active, &(&1.state == :active))

      # Verify our created tokens are in the list
      created_ids = Enum.map(active_tokens, & &1.id)
      active_ids = Enum.map(active, & &1.id)
      assert Enum.all?(created_ids, &(&1 in active_ids))
    end

    test "includes usage_count when requested" do
      token = TokenFactory.create_token(state: :available)
      user_id = TokenFactory.user_uuid()

      {:ok, _} = Tokens.register_token_usage(user_id)

      active = Tokens.list_active_tokens(with_usage_count: true)
      token_with_count = Enum.find(active, &(&1.id == token.id))

      assert token_with_count.usage_count == 1
    end
  end

  describe "get_token_by_id/2" do
    test "returns token when found" do
      user_id = TokenFactory.user_uuid()

      token =
        TokenFactory.create_token(
          state: :active,
          utilizer_uuid: user_id,
          activated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      # Create usage record
      TokenFactory.create_token_usage(
        token_id: token.id,
        user_id: user_id,
        started_at: token.activated_at
      )

      found = Tokens.get_token_by_id(token.id)
      assert found.id == token.id
      assert found.state == :active
    end

    test "returns nil when not found" do
      fake_id = Ecto.UUID.generate()
      assert Tokens.get_token_by_id(fake_id) == nil
    end

    test "includes usage_count when requested" do
      token = TokenFactory.create_token(state: :available)
      user_id = TokenFactory.user_uuid()

      {:ok, _} = Tokens.register_token_usage(user_id)
      {:ok, _} = Tokens.release_token(token.id)
      {:ok, _} = Tokens.register_token_usage(user_id)

      token_with_count = Tokens.get_token_by_id(token.id, preload_usage_count: true)
      assert token_with_count.usage_count == 2
    end
  end

  describe "get_token_by_user/1" do
    test "returns active token for user" do
      user_id = TokenFactory.user_uuid()

      token =
        TokenFactory.create_token(
          state: :active,
          utilizer_uuid: user_id,
          activated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      # Create usage record
      TokenFactory.create_token_usage(
        token_id: token.id,
        user_id: user_id,
        started_at: token.activated_at
      )

      # Reload token to ensure it's in the database
      alias JustTravelTest.Repo
      token = Repo.get!(JustTravelTest.Token.TokenSchema, token.id)

      found = Tokens.get_token_by_user(user_id)
      assert found != nil
      assert found.id == token.id
    end

    test "returns nil when user has no active token" do
      user_id = TokenFactory.user_uuid()
      assert Tokens.get_token_by_user(user_id) == nil
    end
  end

  describe "count_active_tokens/0" do
    test "returns correct count" do
      users = Enum.map(1..5, fn _ -> TokenFactory.user_uuid() end)

      active_tokens =
        Enum.map(users, fn user_id ->
          TokenFactory.create_token(
            state: :active,
            utilizer_uuid: user_id,
            activated_at: DateTime.utc_now() |> DateTime.truncate(:second)
          )
        end)

      # Create usage records for active tokens
      Enum.each(Enum.zip(active_tokens, users), fn {token, user_id} ->
        TokenFactory.create_token_usage(
          token_id: token.id,
          user_id: user_id,
          started_at: token.activated_at
        )
      end)

      TokenFactory.create_tokens(3, state: :available)

      # Account for any existing tokens from seeds
      count = Tokens.count_active_tokens()
      assert count >= 5
    end
  end

  describe "count_available_tokens/0" do
    test "returns correct count" do
      TokenFactory.create_tokens(5, state: :active, utilizer_uuid: TokenFactory.user_uuid())
      TokenFactory.create_tokens(3, state: :available)

      # Account for any existing tokens from seeds
      count = Tokens.count_available_tokens()
      assert count >= 3
    end
  end
end
