defmodule JustTravelTestWeb.Token.TokenControllerTest do
  use JustTravelTestWeb.ConnCase

  alias JustTravelTest.Tokens
  alias JustTravelTest.TokenFactory

  describe "POST /api/tokens/activate" do
    test "activates a token successfully", %{conn: conn} do
      TokenFactory.create_token(state: :available)
      user_id = TokenFactory.user_uuid()

      conn =
        post(conn, ~p"/api/tokens/activate", %{
          "user_id" => user_id
        })

      assert %{"token_id" => token_id, "user_id" => ^user_id} = json_response(conn, 200)
      assert token_id != nil

      # Verify token is active
      token = Tokens.get_token_by_id(token_id)
      assert token.state == :active
      assert token.utilizer_uuid == user_id
    end

    test "returns error for invalid user_id format", %{conn: conn} do
      conn = post(conn, ~p"/api/tokens/activate", %{"user_id" => "invalid-uuid"})

      assert json_response(conn, 400)["status"] == "bad_request"
      assert json_response(conn, 400)["message"] =~ "Invalid user_id format"
    end

    test "returns error for missing user_id", %{conn: conn} do
      conn = post(conn, ~p"/api/tokens/activate", %{})

      assert json_response(conn, 400)["status"] == "bad_request"
      assert json_response(conn, 400)["message"] =~ "Missing required parameter"
    end

    test "releases oldest token when limit reached", %{conn: conn} do
      # Create 100 active tokens
      user_ids = Enum.map(1..100, fn _ -> TokenFactory.user_uuid() end)

      tokens =
        Enum.map(user_ids, fn user_id ->
          TokenFactory.create_token(
            state: :active,
            utilizer_uuid: user_id,
            activated_at: DateTime.utc_now() |> DateTime.truncate(:second)
          )
        end)

      oldest_token = Enum.min_by(tokens, & &1.activated_at)

      # Create one available token
      available_token = TokenFactory.create_token(state: :available)

      new_user_id = TokenFactory.user_uuid()

      conn = post(conn, ~p"/api/tokens/activate", %{"user_id" => new_user_id})

      assert %{"token_id" => token_id} = json_response(conn, 200)
      assert token_id == available_token.id

      # Oldest token should be released
      released = Tokens.get_token_by_id(oldest_token.id)
      assert released.state == :available
    end
  end

  describe "GET /api/tokens" do
    test "lists all tokens", %{conn: conn} do
      TokenFactory.create_tokens(3, state: :available)
      TokenFactory.create_tokens(2, state: :active, utilizer_uuid: TokenFactory.user_uuid())

      conn = get(conn, ~p"/api/tokens")

      assert %{"tokens" => tokens} = json_response(conn, 200)
      assert length(tokens) == 5
    end

    test "filters by state=available", %{conn: conn} do
      TokenFactory.create_tokens(3, state: :available)
      TokenFactory.create_tokens(2, state: :active, utilizer_uuid: TokenFactory.user_uuid())

      conn = get(conn, ~p"/api/tokens?state=available")

      assert %{"tokens" => tokens} = json_response(conn, 200)
      assert length(tokens) == 3
      assert Enum.all?(tokens, &(&1["state"] == "available"))
    end

    test "filters by state=active", %{conn: conn} do
      TokenFactory.create_tokens(3, state: :available)
      TokenFactory.create_tokens(2, state: :active, utilizer_uuid: TokenFactory.user_uuid())

      conn = get(conn, ~p"/api/tokens?state=active")

      assert %{"tokens" => tokens} = json_response(conn, 200)
      assert length(tokens) == 2
      assert Enum.all?(tokens, &(&1["state"] == "active"))
    end

    test "returns error for invalid state filter", %{conn: conn} do
      conn = get(conn, ~p"/api/tokens?state=invalid")

      assert json_response(conn, 400)["status"] == "bad_request"
      assert json_response(conn, 400)["message"] =~ "Invalid state filter"
    end
  end

  describe "GET /api/tokens/:token_id" do
    test "returns token details", %{conn: conn} do
      token = TokenFactory.create_token(
        state: :active,
        utilizer_uuid: TokenFactory.user_uuid(),
        activated_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )

      conn = get(conn, ~p"/api/tokens/#{token.id}")

      assert %{
               "token_id" => token_id,
               "state" => "active",
               "usage_count" => usage_count
             } = json_response(conn, 200)

      assert token_id == token.id
      assert usage_count >= 0
    end

    test "returns 404 for non-existent token", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = get(conn, ~p"/api/tokens/#{fake_id}")

      assert json_response(conn, 404)["status"] == "not_found"
      assert json_response(conn, 404)["message"] =~ "Token not found"
    end
  end

  describe "GET /api/tokens/:token_id/usages" do
    test "returns usage history", %{conn: conn} do
      token = TokenFactory.create_token(state: :available)
      user1 = TokenFactory.user_uuid()
      user2 = TokenFactory.user_uuid()

      # Create usage history
      {:ok, _} = Tokens.register_token_usage(user1)
      {:ok, _} = Tokens.release_token(token.id)
      {:ok, _} = Tokens.register_token_usage(user2)

      conn = get(conn, ~p"/api/tokens/#{token.id}/usages")

      assert %{"token_id" => token_id, "usages" => usages} = json_response(conn, 200)
      assert token_id == token.id
      assert length(usages) == 2
    end

    test "returns 404 for non-existent token", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = get(conn, ~p"/api/tokens/#{fake_id}/usages")

      assert json_response(conn, 404)["status"] == "not_found"
    end
  end

  describe "DELETE /api/tokens/active" do
    test "clears all active tokens", %{conn: conn} do
      TokenFactory.create_tokens(5, state: :active, utilizer_uuid: TokenFactory.user_uuid())
      TokenFactory.create_tokens(3, state: :available)

      conn = delete(conn, ~p"/api/tokens/active")

      assert %{"cleared_count" => 5, "status" => "ok"} = json_response(conn, 200)

      assert Tokens.count_active_tokens() == 0
    end

    test "returns 0 when no active tokens", %{conn: conn} do
      TokenFactory.create_tokens(3, state: :available)

      conn = delete(conn, ~p"/api/tokens/active")

      assert %{"cleared_count" => 0, "status" => "ok"} = json_response(conn, 200)
    end
  end
end
