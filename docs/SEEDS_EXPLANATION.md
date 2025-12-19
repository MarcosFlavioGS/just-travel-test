# Understanding `seeds.exs` in Phoenix/Ecto Projects

## What is `seeds.exs`?

`seeds.exs` is a script that populates your database with **initial/reference data**. Think of it as the "data counterpart" to migrations:
- **Migrations** = Create/modify database structure (tables, columns, indexes)
- **Seeds** = Populate database with data (initial records, reference data, sample data)

### Purpose

The `seeds.exs` file serves several important purposes:

1. **Initial Data**: Populate required data that your application needs to function
2. **Reference Data**: Seed lookup tables, default configurations, etc.
3. **Development Data**: Create sample data for local development
4. **Reproducible Setup**: Ensure everyone starts with the same baseline data

## In Our Project

For our token management system, `seeds.exs`:
- Generates the **100 pre-generated UUID tokens** required by the system
- Sets them all to `:available` state initially
- Ensures the system always starts with the required tokens

This is **required system data**, not just sample data - the system cannot function without these 100 tokens.

## How It's Used

### 1. Manual Execution

You can run seeds directly:

```bash
mix run priv/repo/seeds.exs
```

This executes the script and populates the database.

### 2. Via Mix Alias: `mix setup`

Looking at our `mix.exs`:

```elixir
"ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"]
```

When you run:

```bash
mix setup
```

It executes in order:
1. `ecto.create` - Creates the database
2. `ecto.migrate` - Runs all migrations (creates tables, indexes, etc.)
3. `run priv/repo/seeds.exs` - Runs seeds (populates data)

This is the **standard way** to set up a new development environment.

### 3. Via `mix ecto.reset`

```elixir
"ecto.reset": ["ecto.drop", "ecto.setup"]
```

This command:
1. Drops the entire database (`ecto.drop`)
2. Recreates everything (`ecto.setup` = create + migrate + seeds)

Useful when you want to start completely fresh during development.

## Seeds vs Migrations

| Aspect | Migrations | Seeds |
|--------|------------|-------|
| **Purpose** | Create/modify database structure | Populate data |
| **What** | Tables, columns, indexes | Initial records |
| **Versioned** | Yes, tracked | No, can be re-run |
| **When** | Run once per migration | Can run multiple times |
| **Example** | Create `tokens` table | Insert 100 token records |

**Key Difference**: Migrations change structure, seeds populate data.

## Our `seeds.exs` Breakdown

```elixir
# 1. Generate 100 UUID tokens
tokens = 1..100 |> Enum.map(fn _ ->
  %{
    id: Ecto.UUID.generate(),  # Unique UUID for each token
    state: :available,          # All start as available
    inserted_at: DateTime.utc_now(),
    updated_at: DateTime.utc_now()
  }
end)

# 2. Insert all at once (efficient batch insert)
Repo.insert_all(Token, tokens)
```

### Why Batch Insert (`insert_all`)?

- **Performance**: Much faster than 100 individual `insert!` calls
- **Efficiency**: Single database transaction
- **Best Practice**: Use `insert_all` for bulk data insertion

## Common Use Cases

### 1. Required System Data
- Our tokens (required for the system to function)
- Default roles/permissions
- System configuration values

### 2. Development Data
- Sample users for testing
- Test data for development
- Demo content

### 3. Reference Data
- Countries, currencies
- Categories, tags
- Status types

## Important Notes

### 1. Idempotency

Seeds may run multiple times, so consider making them idempotent:

```elixir
# Check if tokens already exist
if Repo.aggregate(Token, :count) == 0 do
  # Only create if none exist
  Repo.insert_all(Token, tokens)
else
  IO.puts("Tokens already exist, skipping seed")
end
```

**Note**: Our current seeds will create duplicates if run twice. This is acceptable for development but could be improved for production scenarios.

### 2. Environment Awareness

You can make seeds environment-aware:

```elixir
if Mix.env() == :dev do
  # Only create dev data in development
  Repo.insert_all(Token, tokens)
end
```

### 3. Not for Production

- Seeds are typically run manually or in setup scripts
- Production data usually comes from real usage or separate import processes
- Don't rely on seeds for production data seeding

## Workflow Examples

### First Time Setup

```bash
mix setup
# → Creates DB → Runs migrations → Runs seeds → 100 tokens created
```

### Reset Everything (Development)

```bash
mix ecto.reset
# → Drops DB → Recreates everything → Fresh 100 tokens
```

### Just Run Seeds Again

```bash
mix run priv/repo/seeds.exs
# → Only runs seeds (if you modify seeds.exs)
```

### Typical Development Workflow

1. **New developer joins**: `mix setup` (creates DB, runs migrations, seeds data)
2. **Schema changes**: `mix ecto.migrate` (runs new migrations)
3. **Need fresh data**: `mix ecto.reset` (drops and recreates everything)
4. **Modified seeds**: `mix run priv/repo/seeds.exs` (re-runs seeds)

## Best Practices

1. **Use bang functions** (`insert!`, `update!`) - They fail fast if something goes wrong
2. **Batch operations** - Use `insert_all` for bulk inserts
3. **Make idempotent** - Check if data exists before creating (if needed)
4. **Keep it simple** - Seeds should be straightforward and easy to understand
5. **Document requirements** - Comment what data is required vs optional

## Summary

- **Purpose**: Populate initial/reference data
- **In our project**: Creates the 100 required tokens
- **Usage**: Via `mix setup` or `mix run priv/repo/seeds.exs`
- **When**: After migrations, to set up initial data
- **Why**: Ensures the system starts with required data

In our token management system, seeds ensure we always have exactly 100 tokens ready to use, which is a **requirement** of the system. Without these seeds, the system cannot function properly.

