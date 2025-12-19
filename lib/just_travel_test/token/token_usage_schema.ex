defmodule JustTravelTest.Token.TokenUsageSchema do
  @moduledoc """
  TokenUsage schema tracking the history of token usage.

  Each record represents a period when a token was used by a user.
  When a token is active, `ended_at` is null.
  When a token is released, `ended_at` is set to the release timestamp.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "token_usages" do
    field :user_id, :binary_id
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime

    belongs_to :token, JustTravelTest.Token.TokenSchema, foreign_key: :token_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(token_usage, attrs) do
    token_usage
    |> cast(attrs, [:token_id, :user_id, :started_at, :ended_at])
    |> validate_required([:token_id, :user_id, :started_at])
    |> validate_uuid(:token_id)
    |> validate_uuid(:user_id)
    |> foreign_key_constraint(:token_id)
  end

  defp validate_uuid(changeset, field) do
    case get_field(changeset, field) do
      nil -> add_error(changeset, field, "can't be blank")
      value when is_binary(value) ->
        case Ecto.UUID.cast(value) do
          {:ok, _uuid} -> changeset
          :error -> add_error(changeset, field, "must be a valid UUID")
        end
      _ -> changeset
    end
  end
end
