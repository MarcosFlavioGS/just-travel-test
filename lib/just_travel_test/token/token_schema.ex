defmodule JustTravelTest.Token.TokenSchema do
  @moduledoc """
  Token schema representing one of the 100 pre-generated tokens.

  Tokens can be in two states:
  - `:available` - Token is available for use
  - `:active` - Token is currently in use by a user
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "tokens" do
    field :state, Ecto.Enum, values: [:available, :active], default: :available
    field :utilizer_uuid, :binary_id
    field :activated_at, :utc_datetime
    field :released_at, :utc_datetime

    has_many :token_usages, JustTravelTest.Token.TokenUsageSchema, foreign_key: :token_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(token, attrs) do
    token
    |> cast(attrs, [:id, :state, :utilizer_uuid, :activated_at, :released_at])
    |> validate_required([:id, :state])
    |> validate_uuid(:id)
    |> validate_uuid(:utilizer_uuid, allow_nil: true)
  end

  defp validate_uuid(changeset, field, opts \\ []) do
    allow_nil = Keyword.get(opts, :allow_nil, false)

    case get_field(changeset, field) do
      nil when allow_nil -> changeset
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
