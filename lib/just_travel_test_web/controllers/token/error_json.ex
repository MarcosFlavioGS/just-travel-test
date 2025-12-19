defmodule JustTravelTestWeb.Token.ErrorJSON do
  @moduledoc """
  Contains all error view functions for the token_controller.
  """
  # If you want to customize a particular status code,
  # you may add your own clauses, such as:
  #
  # def render("500.json", _assigns) do
  #   %{errors: %{detail: "Internal Server Error"}}
  # end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".
  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end

  # Error for not found
  def error(%{status: :not_found, resource: :token}) do
    %{
      status: :not_found,
      message: "Token not found"
    }
  end

  # Error for invalid user_id
  def error(%{status: :bad_request, reason: :invalid_user_id}) do
    %{
      status: :bad_request,
      message: "Invalid user_id format. Must be a valid UUID."
    }
  end

  # Error for missing parameter
  def error(%{status: :bad_request, reason: :missing_user_id}) do
    %{
      status: :bad_request,
      message: "Missing required parameter: user_id"
    }
  end

  # Error for invalid state filter
  def error(%{status: :bad_request, reason: :invalid_state_filter}) do
    %{
      status: :bad_request,
      message: "Invalid state filter. Must be 'available', 'active', or 'all'."
    }
  end

  # Error for no available tokens
  def error(%{status: :internal_server_error, reason: :no_available_tokens}) do
    %{
      status: :internal_server_error,
      message: "No available tokens. This should not happen."
    }
  end

  # Generic internal server error
  def error(%{status: :internal_server_error, reason: reason}) do
    %{
      status: :internal_server_error,
      message: "Failed to process request: #{inspect(reason)}"
    }
  end
end
