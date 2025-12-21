defmodule JustTravelTestWeb.Health.FallbackController do
  @moduledoc """
  Call functions for the fallback controller and
  puts specific error views considering parameters received from captured
  errors from the health_controller.
  """
  use JustTravelTestWeb, :controller

  def call(conn, {:error, checks}) do
    conn
    |> put_status(:service_unavailable)
    |> put_view(json: JustTravelTestWeb.Health.ErrorJSON)
    |> render(:error, status: :service_unavailable, checks: checks)
  end
end
