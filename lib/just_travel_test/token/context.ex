defmodule JustTravelTest.Tokens do
  @moduledoc """
  Context for managing tokens and their usage.

  This module provides a unified API that delegates to specialized modules:
  - `JustTravelTest.Tokens.Registration` - Token registration and activation
  - `JustTravelTest.Tokens.Release` - Token release operations
  - `JustTravelTest.Tokens.Queries` - Token query operations
  - `JustTravelTest.Tokens.History` - Usage history operations
  - `JustTravelTest.Tokens.Expiration` - Expired token management
  """

  # Delegate to specialized modules
  defdelegate register_token_usage(user_id), to: JustTravelTest.Tokens.Registration

  defdelegate release_token(token_id), to: JustTravelTest.Tokens.Release
  defdelegate release_token_by_user(user_id), to: JustTravelTest.Tokens.Release
  defdelegate release_oldest_active_token(), to: JustTravelTest.Tokens.Release
  defdelegate clear_all_active_tokens(), to: JustTravelTest.Tokens.Release

  defdelegate list_all_tokens(opts \\ []), to: JustTravelTest.Tokens.Queries
  defdelegate list_available_tokens(), to: JustTravelTest.Tokens.Queries
  defdelegate list_active_tokens(opts \\ []), to: JustTravelTest.Tokens.Queries
  defdelegate get_token_by_id(token_id, opts \\ []), to: JustTravelTest.Tokens.Queries
  defdelegate get_token_by_user(user_id), to: JustTravelTest.Tokens.Queries
  defdelegate count_active_tokens(), to: JustTravelTest.Tokens.Queries
  defdelegate count_available_tokens(), to: JustTravelTest.Tokens.Queries

  defdelegate get_token_usage_history(token_id, opts \\ []), to: JustTravelTest.Tokens.History

  defdelegate find_expired_tokens(), to: JustTravelTest.Tokens.Expiration
  defdelegate release_expired_tokens(), to: JustTravelTest.Tokens.Expiration
end
