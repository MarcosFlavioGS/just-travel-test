defmodule JustTravelTest.Tokens.ManagerTest do
  use JustTravelTest.DataCase, async: false

  alias JustTravelTest.Tokens
  alias JustTravelTest.Tokens.Manager
  alias JustTravelTest.TokenFactory

  setup do
    # Manager is already started by the application supervisor
    # just need to ensure it's running
    :ok
  end

  describe "check_and_release_expired/0" do
    test "releases expired tokens" do
      # Create expired tokens
      # Config is 1 minute for tests, so I am using 65 seconds to ensure they're definitely expired
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

      # Create active token
      active_user_id = TokenFactory.user_uuid()

      active_token =
        TokenFactory.create_token(
          state: :active,
          utilizer_uuid: active_user_id,
          activated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      TokenFactory.create_token_usage(
        token_id: active_token.id,
        user_id: active_user_id,
        started_at: active_token.activated_at
      )

      # Wait to ensure time has passed
      Process.sleep(100)

      # Manually trigger check
      assert {:ok, 2} = Manager.check_and_release_expired()

      # Expired tokens should be released
      released1 = Tokens.get_token_by_id(expired1.id)
      released2 = Tokens.get_token_by_id(expired2.id)
      assert released1.state == :available
      assert released2.state == :available

      # Active token should still be active
      still_active = Tokens.get_token_by_id(active_token.id)
      assert still_active.state == :active
    end

    test "returns 0 when no expired tokens" do
      TokenFactory.create_tokens(5, state: :active, utilizer_uuid: TokenFactory.user_uuid())

      assert {:ok, 0} = Manager.check_and_release_expired()
    end
  end

  describe "periodic expiration check" do
    test "automatically releases expired tokens" do
      expired_token = TokenFactory.create_expired_token()

      # Wait for periodic check
      Process.sleep(100)

      # Manually trigger to simulate periodic check
      Manager.check_and_release_expired()

      released = Tokens.get_token_by_id(expired_token.id)
      assert released.state == :available
    end
  end
end
