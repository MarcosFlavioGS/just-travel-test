defmodule JustTravelTest.Tokens.RegistrationTest do
  use JustTravelTest.DataCase, async: true

  alias JustTravelTest.Tokens
  alias JustTravelTest.TokenFactory

  describe "register_token_usage/1" do
    test "successfully activates an available token" do
      # Create an available token
      token = TokenFactory.create_token(state: :available)

      user_id = TokenFactory.user_uuid()

      assert {:ok, %{token_id: token_id, user_id: ^user_id}} =
               Tokens.register_token_usage(user_id)

      assert token_id == token.id

      # Verify token is now active
      updated_token = Tokens.get_token_by_id(token_id)
      assert updated_token.state == :active
      assert updated_token.utilizer_uuid == user_id
      assert updated_token.activated_at != nil

      # Verify usage record was created
      usages = Tokens.get_token_usage_history(token_id)
      assert length(usages) == 1
      assert hd(usages).user_id == user_id
      assert hd(usages).started_at != nil
      assert hd(usages).ended_at == nil
    end

    test "returns error for invalid UUID format" do
      assert {:error, :invalid_user_id} = Tokens.register_token_usage("invalid-uuid")
    end

    test "releases oldest active token when limit is reached" do
      # Clear all tokens first to avoid seed data interference
      Tokens.clear_all_active_tokens()

      # Create exactly 100 active tokens with different activation times
      base_time = DateTime.utc_now() |> DateTime.truncate(:second)

      user_ids = Enum.map(1..100, fn _ -> TokenFactory.user_uuid() end)

      tokens =
        user_ids
        |> Enum.with_index()
        |> Enum.map(fn {user_id, index} ->
          # Create tokens with slightly different activation times
          activated_at = DateTime.add(base_time, -index, :second)

          TokenFactory.create_token(
            state: :active,
            utilizer_uuid: user_id,
            activated_at: activated_at
          )
        end)

      # Sort by activated_at to find the oldest
      oldest_token = Enum.min_by(tokens, & &1.activated_at)

      # Create one available token
      _available_token = TokenFactory.create_token(state: :available)

      # Verify we have exactly 100 active tokens
      assert Tokens.count_active_tokens() == 100

      # Try to activate a new token (should release oldest)
      new_user_id = TokenFactory.user_uuid()

      assert {:ok, %{token_id: token_id, user_id: ^new_user_id}} =
               Tokens.register_token_usage(new_user_id)

      # The new token should be activated (could be the available one or another)
      assert token_id != nil

      # The oldest token should be released
      released_token = Tokens.get_token_by_id(oldest_token.id)
      assert released_token.state == :available
      assert released_token.utilizer_uuid == nil
      assert released_token.released_at != nil

      # Verify the usage record for the oldest token is closed
      old_usages = Tokens.get_token_usage_history(oldest_token.id)
      active_usage = Enum.find(old_usages, &is_nil(&1.ended_at))
      assert active_usage == nil
    end

    test "handles concurrent activation requests" do
      # Clear all tokens first to avoid seed data interference
      Tokens.clear_all_active_tokens()

      # Create 10 available tokens (enough for all concurrent requests)
      TokenFactory.create_tokens(10, state: :available)

      # Simulate concurrent requests
      user_ids = Enum.map(1..10, fn _ -> TokenFactory.user_uuid() end)

      results =
        Task.async_stream(
          user_ids,
          fn user_id -> Tokens.register_token_usage(user_id) end,
          timeout: 5000
        )
        |> Enum.to_list()

      # All should succeed (some may have triggered oldest token release)
      # Task.async_stream returns {:ok, result} or {:error, reason}
      # The result from register_token_usage is already {:ok, ...}, so it gets double-wrapped
      assert Enum.all?(results, fn
               {:ok, {:ok, _}} -> true
               {:ok, {:error, _}} -> false
               {:error, _} -> false
               _ -> false
             end)

      # Verify all succeeded
      successful =
        Enum.count(results, fn
          {:ok, {:ok, _}} -> true
          _ -> false
        end)

      assert successful == length(user_ids)

      # Should have exactly 10 active tokens (we created 10 available and activated 10)
      assert Tokens.count_active_tokens() == 10
    end

    test "creates usage history record on activation" do
      token = TokenFactory.create_token(state: :available)
      user_id = TokenFactory.user_uuid()

      assert {:ok, _} = Tokens.register_token_usage(user_id)

      usages = Tokens.get_token_usage_history(token.id)
      assert length(usages) == 1

      usage = hd(usages)
      assert usage.user_id == user_id
      assert usage.token_id == token.id
      assert usage.started_at != nil
      assert usage.ended_at == nil
    end
  end
end
