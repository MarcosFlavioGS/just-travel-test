defmodule JustTravelTest.Tokens.ReleaseTest do
  use JustTravelTest.DataCase, async: true

  alias JustTravelTest.Tokens
  alias JustTravelTest.TokenFactory

  alias JustTravelTest.Repo
  alias JustTravelTest.Token.TokenUsageSchema

  describe "release_token/1" do
    test "releases an active token" do
      user_id = TokenFactory.user_uuid()

      token =
        TokenFactory.create_token(
          state: :active,
          utilizer_uuid: user_id,
          activated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      # Create an active usage record
      usage =
        TokenFactory.create_token_usage(
          token_id: token.id,
          user_id: user_id,
          started_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      assert {:ok, released} = Tokens.release_token(token.id)

      # Verify token is released
      released_token = Tokens.get_token_by_id(token.id)
      assert released_token.state == :available
      assert released_token.utilizer_uuid == nil

      assert released.released_at != nil
      # Also verify it's set in the database
      assert released_token.released_at != nil

      # Verify usage record is closed - reload from database

      reloaded_usage = Repo.get(TokenUsageSchema, usage.id)
      assert reloaded_usage.ended_at != nil
    end

    test "returns error for non-existent token" do
      fake_token_id = Ecto.UUID.generate()

      result = Tokens.release_token(fake_token_id)
      assert {:error, :token_not_found} = result
    end
  end

  describe "release_token_by_user/1" do
    test "releases token by user_id" do
      user_id = TokenFactory.user_uuid()

      token =
        TokenFactory.create_token(
          state: :active,
          utilizer_uuid: user_id,
          activated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      # Create usage record to match the token
      TokenFactory.create_token_usage(
        token_id: token.id,
        user_id: user_id,
        started_at: token.activated_at
      )

      assert {:ok, _} = Tokens.release_token_by_user(user_id)

      released_token = Tokens.get_token_by_id(token.id)
      assert released_token.state == :available
    end

    test "returns error when user has no active token" do
      user_id = TokenFactory.user_uuid()
      assert {:error, :no_active_token_for_user} = Tokens.release_token_by_user(user_id)
    end
  end

  describe "release_oldest_active_token/0" do
    test "releases the oldest active token" do
      # Create tokens with different activation times
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      user1 = TokenFactory.user_uuid()
      user2 = TokenFactory.user_uuid()

      oldest_token =
        TokenFactory.create_token(
          state: :active,
          utilizer_uuid: user1,
          activated_at: DateTime.add(now, -300, :second)
        )

      # Create usage record for oldest token
      TokenFactory.create_token_usage(
        token_id: oldest_token.id,
        user_id: user1,
        started_at: oldest_token.activated_at
      )

      newer_token =
        TokenFactory.create_token(
          state: :active,
          utilizer_uuid: user2,
          activated_at: DateTime.add(now, -60, :second)
        )

      # Create usage record for newer token
      TokenFactory.create_token_usage(
        token_id: newer_token.id,
        user_id: user2,
        started_at: newer_token.activated_at
      )

      assert {:ok, released_token_id} = Tokens.release_oldest_active_token()
      assert released_token_id == oldest_token.id

      # Oldest should be released
      released = Tokens.get_token_by_id(oldest_token.id)
      assert released.state == :available

      # Newer should still be active
      still_active = Tokens.get_token_by_id(newer_token.id)
      assert still_active.state == :active
    end

    test "returns error when no active tokens exist" do
      TokenFactory.create_tokens(5, state: :available)

      assert {:error, :no_active_tokens} = Tokens.release_oldest_active_token()
    end
  end

  describe "clear_all_active_tokens/0" do
    test "releases all active tokens" do
      # Create mix of active and available tokens
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

      initial_available = Tokens.count_available_tokens()

      assert {:ok, cleared_count} = Tokens.clear_all_active_tokens()
      assert cleared_count >= 5

      # All should be available
      assert Tokens.count_active_tokens() == 0
      assert Tokens.count_available_tokens() >= initial_available + cleared_count

      # Verify all created tokens are released
      Enum.each(active_tokens, fn token ->
        released = Tokens.get_token_by_id(token.id)
        assert released.state == :available
        assert released.released_at != nil
      end)
    end

    test "returns 0 when no active tokens exist" do
      TokenFactory.create_tokens(5, state: :available)

      assert {:ok, 0} = Tokens.clear_all_active_tokens()
    end
  end
end
