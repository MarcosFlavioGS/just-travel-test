# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     JustTravelTest.Repo.insert!(%JustTravelTest.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias JustTravelTest.Repo
alias JustTravelTest.Token.TokenSchema

# Generate 100 unique UUID tokens
IO.puts("Generating 100 tokens...")

tokens =
  1..100
  |> Enum.map(fn _ ->
    %{
      id: Ecto.UUID.generate(),
      state: :available,
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end)

# Insert all tokens in batches for efficiency
Repo.insert_all(TokenSchema, tokens)

IO.puts("✓ Successfully created 100 tokens")
