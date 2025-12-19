# JustTravelTest

Esse é meu repositório para o teste técnico para a empresa Just Travel.

## 📋 Sobre o Projeto

Este projeto implementa um sistema robusto de gerenciamento de tokens que mantém exatamente 100 tokens UUID pré-gerados, com um limite máximo de 100 tokens ativos simultaneamente. O sistema inclui liberação automática de tokens após 2 minutos de uso e gerenciamento inteligente de disponibilidade.

## 🚀 Funcionalidades Principais

- **100 Tokens Únicos**: Tokens UUID pré-gerados e gerenciados
- **Limite de Ativação**: Máximo de 100 tokens ativos simultaneamente
- **Liberação Automática**: Tokens são automaticamente liberados após 2 minutos de uso
- **Gerenciamento de Limite**: Quando o limite é atingido, o token mais antigo é automaticamente liberado
- **Histórico de Uso**: Rastreamento completo do histórico de uso de cada token
- **API RESTful**: Endpoints JSON para todas as operações
- **Processo Supervisionado**: GenServer para verificação periódica de tokens expirados

## 📚 Documentação

A documentação completa do projeto está disponível em:

**[📖 Ver Documentação Completa](./doc/index.html)**

A documentação inclui:
- Referência completa da API
- Documentação de todos os módulos
- Guias de uso e exemplos
- Estrutura do projeto

## 🛠️ Tecnologias Utilizadas

- **Phoenix 1.8** - Framework web
- **Elixir** - Linguagem de programação
- **PostgreSQL** - Banco de dados
- **Ecto** - ORM e queries
- **GenServer** - Processos supervisionados para auto-liberação
- **ExDoc** - Geração de documentação

## 📦 Instalação

```bash
# Instalar dependências
mix deps.get

# Configurar o banco de dados
mix ecto.setup

# Iniciar o servidor
mix phx.server
```

O servidor estará disponível em `http://localhost:4000`

## 🧪 Testes

```bash
# Executar todos os testes
mix test

# Executar testes com cobertura
mix test --cover
```

## 📡 API Endpoints

### Ativar Token
```bash
POST /api/tokens/activate
Body: {"user_id": "uuid-string"}
```

### Listar Tokens
```bash
GET /api/tokens?state=available|active|all
```

### Obter Token por ID
```bash
GET /api/tokens/:token_id
```

### Histórico de Uso
```bash
GET /api/tokens/:token_id/usages
```

### Limpar Tokens Ativos
```bash
DELETE /api/tokens/active
```

Para mais detalhes sobre a API, consulte a [Documentação da API](./docs/API_DOCUMENTATION.md).

## 📖 Documentação Adicional

- [Documentação da API](./docs/API_DOCUMENTATION.md) - Guia completo dos endpoints
- [Plano do Sistema de Tokens](./TOKEN_SYSTEM_PLAN.md) - Arquitetura e design
- [Documentação do Código](./doc/index.html) - Referência completa gerada pelo ExDoc

## 🏗️ Estrutura do Projeto

```
lib/
  just_travel_test/
    token/              # Módulos de gerenciamento de tokens
      context.ex        # Facade principal
      registration.ex   # Ativação de tokens
      release.ex        # Liberação de tokens
      queries.ex        # Consultas
      history.ex        # Histórico de uso
      expiration.ex     # Gerenciamento de expiração
      manager.ex        # GenServer para auto-liberação
      token_schema.ex   # Schema do token
      token_usage_schema.ex  # Schema de histórico
  just_travel_test_web/
    controllers/
      token/            # Controllers da API
    live/               # LiveViews (futuro)

test/                   # Testes
docs/                   # Documentação adicional
doc/                    # Documentação gerada pelo ExDoc
```

## ⚙️ Configuração

O sistema é configurável através de `config/config.exs`:

```elixir
config :just_travel_test, JustTravelTest.Tokens,
  max_active_tokens: 100,
  token_lifetime_minutes: 2,
  check_interval_seconds: 30
```

## 📝 Licença

Este projeto foi desenvolvido como parte de um teste técnico.
