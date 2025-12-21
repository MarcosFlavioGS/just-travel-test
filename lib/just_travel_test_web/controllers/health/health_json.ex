defmodule JustTravelTestWeb.Health.HealthJSON do
  @moduledoc """
  This module contains all view functions for health check API responses.
  """

  @doc """
  Renders the health check response.
  """
  def check(%{checks: checks}) do
    %{
      status: "healthy",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      checks: checks
    }
  end
end
