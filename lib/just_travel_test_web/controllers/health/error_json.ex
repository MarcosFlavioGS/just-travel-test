defmodule JustTravelTestWeb.Health.ErrorJSON do
  @moduledoc """
  Contains all error view functions for the health_controller.
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

  # Error for unhealthy system
  def error(%{status: :service_unavailable, checks: checks}) do
    %{
      status: "unhealthy",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      checks: checks
    }
  end

  # Generic error fallback
  def error(%{checks: checks}) do
    %{
      status: "unhealthy",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      checks: checks
    }
  end
end
