defmodule JustTravelTest.Tokens.ExpirationTest do
  use JustTravelTest.DataCase, async: true

  alias JustTravelTest.Tokens
  alias JustTravelTest.TokenFactory

  describe "find_expired_tokens/0" do
    test "finds tokens activated more than the configured lifetime ago" do
      # Create expired token (activated well past the configured lifetime threshold)
      # Config is 1 minute for tests, so use 65 seconds (1 minute 5 seconds) to ensure it's definitely expired
      user_id = TokenFactory.user_uuid()
      expired_time = DateTime.add(DateTime.utc_now(), -65, :second) |> DateTime.truncate(:second)

      expired_token =
        TokenFactory.create_token(
          state: :active,
          utilizer_uuid: user_id,
          activated_at: expired_time
        )

      # Reload token to ensure it's in the database with correct state
      alias JustTravelTest.Repo
      alias JustTravelTest.Token.TokenSchema
      expired_token = Repo.get!(TokenSchema, expired_token.id)

      # Verify token is active and has the correct activated_at
      assert expired_token.state == :active
      assert expired_token.activated_at == expired_time

      # Create usage record
      TokenFactory.create_token_usage(
        token_id: expired_token.id,
        user_id: user_id,
        started_at: expired_token.activated_at
      )

      # Create active token (not expired - activated now)
      active_user_id = TokenFactory.user_uuid()

      active_token =
        TokenFactory.create_token(
          state: :active,
          utilizer_uuid: active_user_id,
          activated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      # Create usage record for active token
      TokenFactory.create_token_usage(
        token_id: active_token.id,
        user_id: active_user_id,
        started_at: active_token.activated_at
      )

      # Wait a moment to ensure time has passed and query is fresh
      Process.sleep(100)

      expired = Tokens.find_expired_tokens()
      expired_ids = Enum.map(expired, & &1.id)

      assert expired_token.id in expired_ids
      refute active_token.id in expired_ids
    end

    test "returns empty list when no expired tokens exist" do
      TokenFactory.create_tokens(5, state: :active, utilizer_uuid: TokenFactory.user_uuid())

      assert Tokens.find_expired_tokens() == []
    end
  end

  describe "release_expired_tokens/0" do
    test "releases all expired tokens" do
      # Create expired tokens (activated well past the configured lifetime)
      # Config is 1 minute for tests, so use 65 seconds to ensure they're definitely expired
      user1 = TokenFactory.user_uuid()
      user2 = TokenFactory.user_uuid()
      expired_time = DateTime.add(DateTime.utc_now(), -65, :second) |> DateTime.truncate(:second)

      expired1 =
        TokenFactory.create_token(
          state: :active,
          utilizer_uuid: user1,
          activated_at: expired_time
        )

      expired2 =
        TokenFactory.create_token(
          state: :active,
          utilizer_uuid: user2,
          activated_at: expired_time
        )

      # Create usage records
      TokenFactory.create_token_usage(
        token_id: expired1.id,
        user_id: user1,
        started_at: expired1.activated_at
      )

      TokenFactory.create_token_usage(
        token_id: expired2.id,
        user_id: user2,
        started_at: expired2.activated_at
      )

      # Create active token (not expired)
      active_user_id = TokenFactory.user_uuid()

      active_token =
        TokenFactory.create_token(
          state: :active,
          utilizer_uuid: active_user_id,
          activated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      # Create usage record for active token
      TokenFactory.create_token_usage(
        token_id: active_token.id,
        user_id: active_user_id,
        started_at: active_token.activated_at
      )

      # Wait a moment to ensure time has passed
      Process.sleep(100)

      assert {:ok, 2} = Tokens.release_expired_tokens()

      # Expired tokens should be released
      released1 = Tokens.get_token_by_id(expired1.id)
      released2 = Tokens.get_token_by_id(expired2.id)
      assert released1.state == :available
      assert released2.state == :available

      # Active token should still be active
      still_active = Tokens.get_token_by_id(active_token.id)
      assert still_active.state == :active
    end

    test "closes usage records for expired tokens" do
      # Create expired token (activated well past the configured lifetime)
      # Config is 1 minute for tests, so use 65 seconds to ensure it's definitely expired
      user_id = TokenFactory.user_uuid()
      expired_time = DateTime.add(DateTime.utc_now(), -65, :second) |> DateTime.truncate(:second)

      expired_token =
        TokenFactory.create_token(
          state: :active,
          utilizer_uuid: user_id,
          activated_at: expired_time
        )

      # Create usage record
      TokenFactory.create_token_usage(
        token_id: expired_token.id,
        user_id: user_id,
        started_at: expired_token.activated_at
      )

      # Wait a moment to ensure time has passed
      Process.sleep(100)

      assert {:ok, 1} = Tokens.release_expired_tokens()

      # Usage record should be closed
      usages = Tokens.get_token_usage_history(expired_token.id)
      active_usage = Enum.find(usages, &is_nil(&1.ended_at))
      assert active_usage == nil
    end

    test "returns 0 when no expired tokens exist" do
      TokenFactory.create_tokens(5, state: :active, utilizer_uuid: TokenFactory.user_uuid())

      assert {:ok, 0} = Tokens.release_expired_tokens()
    end
  end
end
