defmodule JustTravelTest.Tokens.HistoryTest do
  use JustTravelTest.DataCase, async: true

  alias JustTravelTest.Tokens
  alias JustTravelTest.TokenFactory

  describe "get_token_usage_history/2" do
    test "returns usage history for a token" do
      # Clear all tokens to ensure we can control which token is used
      Tokens.clear_all_active_tokens()

      # Make sure only our token is available
      token = TokenFactory.create_token(state: :available)
      user1 = TokenFactory.user_uuid()
      user2 = TokenFactory.user_uuid()

      # First usage - should get our token since it's the only available one
      {:ok, result1} = Tokens.register_token_usage(user1)
      assert result1.token_id == token.id

      {:ok, _} = Tokens.release_token(token.id)

      # Wait at least 1 second to ensure different timestamps (since we truncate to seconds)
      # Add a small buffer to be safe
      Process.sleep(1100)

      # Second usage - should get our token again
      {:ok, result2} = Tokens.register_token_usage(user2)
      assert result2.token_id == token.id

      history = Tokens.get_token_usage_history(token.id)
      assert length(history) == 2

      # Most recent first (ordered by started_at descending)
      # The second usage (user2) should be first since it was activated after user1
      first_usage = hd(history)
      second_usage = Enum.at(history, 1)

      # Verify we have both users
      user_ids = Enum.map(history, & &1.user_id)
      assert user1 in user_ids
      assert user2 in user_ids

      # Verify ordering: first_usage should be more recent than second_usage
      comparison = DateTime.compare(first_usage.started_at, second_usage.started_at)
      assert comparison == :gt, "Expected first_usage to be more recent, but timestamps are: first=#{inspect(first_usage.started_at)}, second=#{inspect(second_usage.started_at)}"

      # The first usage should be the most recent (user2, not ended)
      assert first_usage.user_id == user2
      assert first_usage.ended_at == nil

      # The second usage should be the older one (user1, ended)
      assert second_usage.user_id == user1
      assert second_usage.ended_at != nil
    end

    test "returns empty list for token with no history" do
      token = TokenFactory.create_token(state: :available)

      history = Tokens.get_token_usage_history(token.id)
      assert history == []
    end

    test "preloads token when requested" do
      token = TokenFactory.create_token(state: :available)
      user_id = TokenFactory.user_uuid()

      {:ok, _} = Tokens.register_token_usage(user_id)

      history = Tokens.get_token_usage_history(token.id, preload_token: true)
      assert length(history) == 1

      usage = hd(history)
      assert Ecto.assoc_loaded?(usage.token)
      assert usage.token.id == token.id
    end
  end
end
