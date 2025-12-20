# Environment Variables Guide

This document explains how to set environment variables for the JustTravelTest application.

## Required Environment Variables

These variables **must** be set in production:

### `DATABASE_URL`
PostgreSQL connection string.

**Format**: `ecto://USER:PASSWORD@HOST:PORT/DATABASE`

**Example**:
```bash
DATABASE_URL=ecto://postgres:password@localhost:5432/just_travel_test_prod
```

### `SECRET_KEY_BASE`
Secret key for signing and encrypting cookies and other secrets.

**Generate one**:
```bash
mix phx.gen.secret
```

**Example**:
```bash
SECRET_KEY_BASE=your_generated_secret_key_here
```

### `PHX_HOST`
Application hostname (domain name).

**Example**:
```bash
PHX_HOST=api.example.com
```

## Optional Environment Variables

### `PORT`
HTTP port for the application (default: 4000).

**Example**:
```bash
PORT=4000
```

### `POOL_SIZE`
Database connection pool size (default: 10).

**Example**:
```bash
POOL_SIZE=20
```

### Rate Limiting

**`ENABLE_RATE_LIMITING`**
Enable or disable rate limiting (default: "true" in production).

**Example**:
```bash
ENABLE_RATE_LIMITING=true
```

**`RATE_LIMIT_PER_MINUTE`**
Number of requests allowed per minute per IP (default: 100).

**Example**:
```bash
RATE_LIMIT_PER_MINUTE=200
```

### Token Management

**`MAX_ACTIVE_TOKENS`**
Maximum number of active tokens (default: 100).

**Example**:
```bash
MAX_ACTIVE_TOKENS=100
```

**`TOKEN_LIFETIME_MINUTES`**
Token lifetime in minutes (default: 2).

**Example**:
```bash
TOKEN_LIFETIME_MINUTES=2
```

**`CHECK_INTERVAL_SECONDS`**
Manager check interval in seconds (default: 30).

**Example**:
```bash
CHECK_INTERVAL_SECONDS=10
```

### Other Options

**`ECTO_IPV6`**
Enable IPv6 support (default: false).

**Example**:
```bash
ECTO_IPV6=true
```

**`DNS_CLUSTER_QUERY`**
DNS cluster query for distributed deployments.

**Example**:
```bash
DNS_CLUSTER_QUERY=app.example.com
```

## Methods to Set Environment Variables

### 1. Shell/Command Line (Temporary)

Set variables before running the command:

```bash
export DATABASE_URL=ecto://postgres:password@localhost:5432/just_travel_test_prod
export SECRET_KEY_BASE=$(mix phx.gen.secret)
export PHX_HOST=api.example.com
export PORT=4000

mix phx.server
```

Or inline with the command:

```bash
DATABASE_URL=ecto://postgres:password@localhost:5432/just_travel_test_prod \
SECRET_KEY_BASE=$(mix phx.gen.secret) \
PHX_HOST=api.example.com \
PORT=4000 \
mix phx.server
```

### 2. `.env` File (Development)

Create a `.env` file in the project root:

```bash
# .env
DATABASE_URL=ecto://postgres:password@localhost:5432/just_travel_test_dev
SECRET_KEY_BASE=dev_secret_key_here
PHX_HOST=localhost
PORT=4000
ENABLE_RATE_LIMITING=false
RATE_LIMIT_PER_MINUTE=1000
```

**Load with**:
```bash
source .env
mix phx.server
```

**Note**: Add `.env` to `.gitignore` to avoid committing secrets!

### 3. Systemd Service (Linux Production)

Create `/etc/systemd/system/just-travel-test.service`:

```ini
[Unit]
Description=JustTravelTest Phoenix Application
After=network.target postgresql.service

[Service]
Type=simple
User=deploy
WorkingDirectory=/opt/just-travel-test
Environment="DATABASE_URL=ecto://postgres:password@localhost:5432/just_travel_test_prod"
Environment="SECRET_KEY_BASE=your_secret_key_here"
Environment="PHX_HOST=api.example.com"
Environment="PORT=4000"
Environment="POOL_SIZE=20"
Environment="ENABLE_RATE_LIMITING=true"
Environment="RATE_LIMIT_PER_MINUTE=100"
ExecStart=/opt/just-travel-test/bin/just_travel_test start
ExecStop=/opt/just-travel-test/bin/just_travel_test stop
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

**Enable and start**:
```bash
sudo systemctl daemon-reload
sudo systemctl enable just-travel-test
sudo systemctl start just-travel-test
```

### 4. Docker

**docker-compose.yml**:
```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "4000:4000"
    environment:
      - DATABASE_URL=ecto://postgres:password@db:5432/just_travel_test_prod
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - PHX_HOST=localhost
      - PORT=4000
      - POOL_SIZE=10
      - ENABLE_RATE_LIMITING=true
      - RATE_LIMIT_PER_MINUTE=100
    depends_on:
      - db

  db:
    image: postgres:15
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=just_travel_test_prod
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

**Dockerfile**:
```dockerfile
FROM elixir:1.19-alpine AS builder

WORKDIR /app
COPY . .
RUN mix deps.get && mix compile && mix release

FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/just_travel_test .
CMD ["./bin/just_travel_test", "start"]
```

**Run with**:
```bash
SECRET_KEY_BASE=$(mix phx.gen.secret) docker-compose up
```

### 5. Docker Environment File

Create `.env` file:
```bash
DATABASE_URL=ecto://postgres:password@db:5432/just_travel_test_prod
SECRET_KEY_BASE=your_secret_key_here
PHX_HOST=localhost
PORT=4000
```

**docker-compose.yml**:
```yaml
services:
  app:
    env_file:
      - .env
```

### 6. Kubernetes ConfigMap and Secret

**configmap.yaml**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: just-travel-test-config
data:
  PHX_HOST: "api.example.com"
  PORT: "4000"
  POOL_SIZE: "20"
  ENABLE_RATE_LIMITING: "true"
  RATE_LIMIT_PER_MINUTE: "100"
```

**secret.yaml**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: just-travel-test-secrets
type: Opaque
stringData:
  DATABASE_URL: "ecto://postgres:password@db:5432/just_travel_test_prod"
  SECRET_KEY_BASE: "your_secret_key_here"
```

**deployment.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: just-travel-test
spec:
  template:
    spec:
      containers:
      - name: app
        image: just-travel-test:latest
        envFrom:
        - configMapRef:
            name: just-travel-test-config
        - secretRef:
            name: just-travel-test-secrets
```

### 7. Heroku

Set variables via CLI:
```bash
heroku config:set DATABASE_URL=ecto://...
heroku config:set SECRET_KEY_BASE=...
heroku config:set PHX_HOST=api.example.com
heroku config:set PORT=4000
```

Or via Heroku Dashboard:
1. Go to your app → Settings → Config Vars
2. Add each variable

### 8. AWS Elastic Beanstalk

Create `.ebextensions/environment.config`:
```yaml
option_settings:
  aws:elasticbeanstalk:application:environment:
    DATABASE_URL: "ecto://postgres:password@host:5432/db"
    SECRET_KEY_BASE: "your_secret_key"
    PHX_HOST: "api.example.com"
    PORT: "4000"
```

Or set via AWS Console:
1. Go to Elastic Beanstalk → Configuration → Software
2. Add environment properties

### 9. GitHub Actions / CI/CD

**.github/workflows/deploy.yml**:
```yaml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
          SECRET_KEY_BASE: ${{ secrets.SECRET_KEY_BASE }}
          PHX_HOST: ${{ secrets.PHX_HOST }}
        run: |
          # deployment commands
```

## Verification

Check if environment variables are loaded:

```bash
# In Elixir console
iex -S mix
iex> System.get_env("DATABASE_URL")
iex> Application.get_env(:just_travel_test, JustTravelTest.Tokens)
```

Or add a temporary endpoint to check:

```elixir
# In router.ex (remove in production!)
get "/env-check", JustTravelTestWeb.EnvController, :check
```

## Security Best Practices

1. **Never commit secrets**: Add `.env` to `.gitignore`
2. **Use secret management**: Use services like AWS Secrets Manager, HashiCorp Vault, or similar
3. **Rotate secrets regularly**: Change `SECRET_KEY_BASE` periodically
4. **Use different secrets per environment**: Dev, staging, and production should have different secrets
5. **Limit access**: Only grant access to environment variables to authorized personnel
6. **Use strong secrets**: Generate `SECRET_KEY_BASE` with `mix phx.gen.secret`

## Example Setup Script

Create `scripts/setup-env.sh`:

```bash
#!/bin/bash

# Generate secret key
export SECRET_KEY_BASE=$(mix phx.gen.secret)

# Set database URL
export DATABASE_URL="ecto://postgres:password@localhost:5432/just_travel_test_${MIX_ENV:-dev}"

# Set host
export PHX_HOST="${PHX_HOST:-localhost}"

# Set port
export PORT="${PORT:-4000}"

# Set pool size
export POOL_SIZE="${POOL_SIZE:-10}"

# Rate limiting (disabled in dev/test)
if [ "$MIX_ENV" = "prod" ]; then
  export ENABLE_RATE_LIMITING="${ENABLE_RATE_LIMITING:-true}"
else
  export ENABLE_RATE_LIMITING="${ENABLE_RATE_LIMITING:-false}"
fi

export RATE_LIMIT_PER_MINUTE="${RATE_LIMIT_PER_MINUTE:-100}"

# Token management
export MAX_ACTIVE_TOKENS="${MAX_ACTIVE_TOKENS:-100}"
export TOKEN_LIFETIME_MINUTES="${TOKEN_LIFETIME_MINUTES:-2}"
export CHECK_INTERVAL_SECONDS="${CHECK_INTERVAL_SECONDS:-30}"

echo "Environment variables set!"
echo "DATABASE_URL: $DATABASE_URL"
echo "PHX_HOST: $PHX_HOST"
echo "PORT: $PORT"
```

**Usage**:
```bash
chmod +x scripts/setup-env.sh
source scripts/setup-env.sh
mix phx.server
```

## Troubleshooting

### Variables not loading?

1. **Check runtime.exs**: Variables are read at runtime, not compile time
2. **Check environment**: Make sure you're in the correct environment (`MIX_ENV=prod`)
3. **Check syntax**: Ensure no quotes around values unless needed
4. **Check permissions**: Ensure the user running the app can read environment variables

### Database connection fails?

1. **Check DATABASE_URL format**: Must be `ecto://USER:PASS@HOST:PORT/DB`
2. **Check database is running**: `pg_isready` or `psql -h HOST -U USER`
3. **Check network**: Ensure host/port are accessible
4. **Check credentials**: Verify username/password are correct

### Secret key issues?

1. **Generate new key**: `mix phx.gen.secret`
2. **Check length**: Should be 64+ characters
3. **Check encoding**: Ensure no special characters break the shell

## Quick Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DATABASE_URL` | ✅ Yes | - | PostgreSQL connection string |
| `SECRET_KEY_BASE` | ✅ Yes | - | Secret key for encryption |
| `PHX_HOST` | ✅ Yes | - | Application hostname |
| `PORT` | ❌ No | 4000 | HTTP port |
| `POOL_SIZE` | ❌ No | 10 | Database pool size |
| `ENABLE_RATE_LIMITING` | ❌ No | true (prod) | Enable rate limiting |
| `RATE_LIMIT_PER_MINUTE` | ❌ No | 100 | Requests per minute limit |
| `MAX_ACTIVE_TOKENS` | ❌ No | 100 | Max active tokens |
| `TOKEN_LIFETIME_MINUTES` | ❌ No | 2 | Token lifetime |
| `CHECK_INTERVAL_SECONDS` | ❌ No | 30 | Manager check interval |
| `ECTO_IPV6` | ❌ No | false | Enable IPv6 |
| `DNS_CLUSTER_QUERY` | ❌ No | - | DNS cluster query |

