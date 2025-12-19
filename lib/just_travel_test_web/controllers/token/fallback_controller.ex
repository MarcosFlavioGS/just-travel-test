defmodule JustTravelTestWeb.Token.FallbackController do
  @moduledoc """
  Call functions for the fallback controller and
  puts specific error views considering parameters received from captured
  errors from the token_controller.
  """
  use JustTravelTestWeb, :controller

  def call(conn, {:error, :token_not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: JustTravelTestWeb.Token.ErrorJSON)
    |> render(:error, status: :not_found, resource: :token)
  end

  def call(conn, {:error, :invalid_user_id}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: JustTravelTestWeb.Token.ErrorJSON)
    |> render(:error, status: :bad_request, reason: :invalid_user_id)
  end

  def call(conn, {:error, :missing_user_id}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: JustTravelTestWeb.Token.ErrorJSON)
    |> render(:error, status: :bad_request, reason: :missing_user_id)
  end

  def call(conn, {:error, :invalid_state_filter}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: JustTravelTestWeb.Token.ErrorJSON)
    |> render(:error, status: :bad_request, reason: :invalid_state_filter)
  end

  def call(conn, {:error, :no_available_tokens}) do
    conn
    |> put_status(:internal_server_error)
    |> put_view(json: JustTravelTestWeb.Token.ErrorJSON)
    |> render(:error, status: :internal_server_error, reason: :no_available_tokens)
  end

  def call(conn, {:error, reason}) do
    conn
    |> put_status(:internal_server_error)
    |> put_view(json: JustTravelTestWeb.Token.ErrorJSON)
    |> render(:error, status: :internal_server_error, reason: reason)
  end
end
