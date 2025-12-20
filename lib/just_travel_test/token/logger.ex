defmodule JustTravelTest.Tokens.Logger do
  @moduledoc """
  Structured logging helper for token operations.

  Provides consistent logging format with context for production monitoring.
  """
  require Logger

  @doc """
  Logs token activation with structured context.
  """
  def log_activation_success(token_id, user_id, metadata \\ %{}) do
    Logger.info("Token activated",
      token_id: token_id,
      user_id: user_id,
      event: :token_activation,
      status: :success,
      metadata: metadata
    )
  end

  def log_activation_failure(user_id, reason, metadata \\ %{}) do
    Logger.warning("Token activation failed",
      user_id: user_id,
      event: :token_activation,
      status: :failure,
      reason: reason,
      metadata: metadata
    )
  end

  @doc """
  Logs token release with structured context.
  """
  def log_release_success(token_id, user_id, metadata \\ %{}) do
    Logger.info("Token released",
      token_id: token_id,
      user_id: user_id,
      event: :token_release,
      status: :success,
      metadata: metadata
    )
  end

  def log_release_failure(token_id, reason, metadata \\ %{}) do
    Logger.warning("Token release failed",
      token_id: token_id,
      event: :token_release,
      status: :failure,
      reason: reason,
      metadata: metadata
    )
  end

  @doc """
  Logs token expiration with structured context.
  """
  def log_expiration(count, metadata \\ %{}) do
    Logger.info("Tokens expired and released",
      event: :token_expiration,
      count: count,
      metadata: metadata
    )
  end

  @doc """
  Logs manager check with structured context.
  """
  def log_manager_check(released_count, metadata \\ %{}) do
    Logger.debug("Token manager periodic check",
      event: :manager_check,
      released_count: released_count,
      metadata: metadata
    )
  end

  @doc """
  Logs errors with full context for debugging.
  """
  def log_error(operation, error, metadata \\ %{}) do
    Logger.error("Token operation error",
      event: :error,
      operation: operation,
      error: inspect(error),
      metadata: metadata
    )
  end
end
