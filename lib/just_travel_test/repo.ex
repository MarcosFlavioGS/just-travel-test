defmodule JustTravelTest.Repo do
  use Ecto.Repo,
    otp_app: :just_travel_test,
    adapter: Ecto.Adapters.Postgres
end
