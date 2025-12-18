defmodule JustTravelTest.Repo.Migrations.CreateTokens do
  use Ecto.Migration

  def change do
    create table(:tokens, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :state, :string, null: false
      add :utilizer_uuid, :uuid
      add :activated_at, :utc_datetime
      add :released_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:tokens, [:state])
    create index(:tokens, [:activated_at])
  end
end
