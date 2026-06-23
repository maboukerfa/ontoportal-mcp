# agroportal-mcp

An [MCP](https://modelcontextprotocol.io) server that exposes the
[AgroPortal / OntoPortal](https://agroportal.eu) API as tools for LLM
clients (Claude Desktop, Claude Code, …). It is a thin wrapper around the
[`ontologies_api_client`](../ontologies_api_ruby_client) Ruby gem, served with
the official [`mcp`](https://rubygems.org/gems/mcp) gem over **stdio** (for local
clients) or **Streamable HTTP / SSE** (for remote deployment).

## Tools

| Tool | Description |
| --- | --- |
| `search_classes` | Full-text search over ontology classes/concepts. Returns label, URI, source ontology, and definition. Supports restricting to specific ontologies and (optionally) federated search across other OntoPortal instances. |
| `list_ontologies` | List the ontologies available on the portal, optionally filtered by a case-insensitive match on acronym or name. Returns acronym, name, and URI. Supports federation. |
| `get_class` | Fetch a single class/concept by its URI within an ontology. Returns preferred label, definition(s), synonyms, obsolete status, and whether it has children. Accepts a `language` code (default `en`). |
| `get_submission` | Get an ontology submission's metadata: version, status, format, dates, license, homepage/documentation, namespace & version IRI, natural languages, keywords, abstract, and description. Defaults to the latest submission; pass `submission_id` for a specific version. |
| `get_metrics` | Get size/structure metrics for a submission: class, individual, and property counts plus hierarchy stats (max depth, max/average child count). Defaults to the latest submission. (For SKOS vocabularies, concepts count as individuals.) |

More tools (e.g. `search_ontologies`, mappings, notes) can be added under
`lib/agroportal_mcp/tools/` and registered in `TOOLS` (`lib/agroportal_mcp.rb`).

## Requirements

- Ruby ≥ 2.7 (this project was set up with Homebrew Ruby at
  `/usr/local/opt/ruby/bin/ruby`).
- A checkout of `ontologies_api_ruby_client` as a sibling directory (the
  `Gemfile` references it via `path: '../ontologies_api_ruby_client'`).
- An AgroPortal API key (create one from your AgroPortal account page).

## Install

```bash
export PATH="/usr/local/opt/ruby/bin:$PATH"
cd ontologies_api_mcp
bundle install
```

## Configuration

The server reads its connection settings from the environment:

| Variable | Required | Default | Notes |
| --- | --- | --- | --- |
| `AGROPORTAL_API_KEY` | yes | — | Your API key. |
| `AGROPORTAL_REST_URL` | no | `https://data.agroportal.eu` | Point at another OntoPortal API to target a different portal. |
| `AGROPORTAL_FEDERATED_PORTALS` | no | — | Enables the `federate` option. Space-separated `name url apikey` triples, comma-separated: `"ecoportal https://data.ecoportal.lifewatch.eu KEY1, biodivportal https://data.biodivportal.gfbio.dev KEY2"`. |
| `AGROPORTAL_MCP_BEARER_TOKEN` | no | — | HTTP transport only. When set, every request must send `Authorization: Bearer <token>`; unset means no auth (a warning is logged at boot). |
| `AGROPORTAL_MCP_STATELESS` | no | `false` | HTTP transport only. `true` makes each request self-contained (no sessions / no server→client SSE stream), which is simpler to scale horizontally. |
| `AGROPORTAL_MCP_REQUIRE_USER_APIKEY` | no | `false` | HTTP transport only. `true` rejects requests without an `X-Agroportal-User-Apikey` header (multi-tenant). When `false`, such requests fall back to `AGROPORTAL_API_KEY`. |

## Smoke test

You can drive the stdio protocol by hand:

```bash
export AGROPORTAL_API_KEY=your_key
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke","version":"0"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"search_classes","arguments":{"query":"wheat","pagesize":3}}}' \
  | /usr/local/opt/ruby/bin/ruby bin/agroportal_mcp
```

## Register with an MCP client

### Claude Code (CLI)

```bash
claude mcp add agroportal \
  --env AGROPORTAL_API_KEY=your_key \
  -- /usr/local/opt/ruby/bin/ruby \
     /Users/maboukerfa/code/agroportal/ontologies_api_mcp/bin/agroportal_mcp
```

### Claude Desktop (`claude_desktop_config.json`)

```json
{
  "mcpServers": {
    "agroportal": {
      "command": "/usr/local/opt/ruby/bin/ruby",
      "args": [
        "/Users/maboukerfa/code/agroportal/ontologies_api_mcp/bin/agroportal_mcp"
      ],
      "env": {
        "AGROPORTAL_API_KEY": "your_key",
        "AGROPORTAL_REST_URL": "https://data.agroportal.eu"
      }
    }
  }
}
```

The entrypoint pins `BUNDLE_GEMFILE` to this project, so it can be launched from
any working directory.

## Remote deployment (Streamable HTTP / SSE)

To serve the same tools to remote clients, run the MCP **Streamable HTTP**
transport instead of stdio. It uses SSE (`text/event-stream`) for streaming
server responses, and replaces the deprecated standalone HTTP+SSE transport.
`config.ru` mounts the server as a Rack app; install the `http` group
(`bundle install` does this by default) and run it under Puma:

```bash
export AGROPORTAL_API_KEY=your_key
export AGROPORTAL_MCP_BEARER_TOKEN=$(openssl rand -hex 32)   # recommended
bundle exec puma config.ru -p 9292
```

The endpoint serves JSON-RPC at the root path. Smoke-test the handshake (drop
the `Authorization` header if you left the token unset):

```bash
# 1) initialize — capture the Mcp-Session-Id from the response headers
curl -sN -i -X POST http://127.0.0.1:9292/ \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -H "Authorization: Bearer $AGROPORTAL_MCP_BEARER_TOKEN" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"smoke","version":"0"}}}'

# 2) tools/list — reuse the session id from step 1 (response streams back as SSE)
curl -sN -X POST http://127.0.0.1:9292/ \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -H "Authorization: Bearer $AGROPORTAL_MCP_BEARER_TOKEN" \
  -H 'Mcp-Session-Id: <id-from-step-1>' \
  -H 'MCP-Protocol-Version: 2025-11-25' \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
```

Operational notes:

- **Terminate TLS in front.** Run it behind a reverse proxy (nginx/Caddy) or load
  balancer that handles HTTPS — the bearer token is only as safe as the transport.
- **Don't expose it unauthenticated.** With `AGROPORTAL_MCP_BEARER_TOKEN` unset
  the endpoint is open (and warns at boot). Set it, or front it with an
  authenticating proxy.
- **Concurrency.** In the default stateful mode each connected client holds a
  long-lived SSE stream open, which ties up a Puma thread; size `--threads` (or
  set `AGROPORTAL_MCP_STATELESS=true`) to match expected concurrency. For many
  concurrent SSE streams, [Falcon](https://github.com/socketry/falcon)
  (fiber-based) scales better and serves the same `config.ru` — add `gem 'falcon'`
  to the `:http` group, then `bundle exec falcon serve -b http://0.0.0.0:9292`.

Register the remote server with Claude Code:

```bash
claude mcp add --transport http agroportal https://your-host.example/ \
  --header "Authorization: Bearer your_token"
```

### Multi-tenant: per-user API keys

Host one shared instance and let each user authenticate with their own AgroPortal
key. The server uses its own `AGROPORTAL_API_KEY` as the base credential and
forwards each caller's key as `userapikey`, so the API attributes requests —
permissions, rate limits, private ontologies — to that user.

```bash
export AGROPORTAL_API_KEY=server_app_key          # must be allowed to use userapikey (see below)
export AGROPORTAL_MCP_REQUIRE_USER_APIKEY=true     # reject requests with no user key
export AGROPORTAL_MCP_STATELESS=true               # recommended for multi-tenant
bundle exec puma config.ru -p 9292
```

Each user registers with their own key in the `X-Agroportal-User-Apikey` header:

```bash
claude mcp add --transport http agroportal https://mcp.agroportal.eu/ \
  --header "X-Agroportal-User-Apikey: <their_personal_key>"
```

The key is read per request and forwarded by the client's `user_apikey`
middleware, producing `Authorization: apikey token=<server>&userapikey=<user>`.
`Thread#[]` is fiber-local, so requests stay isolated under both Puma and Falcon.

Requirements and notes:

- **The server's `AGROPORTAL_API_KEY` must be permitted to use `userapikey`** — an
  admin/app account, not an ordinary user key. (You run AgroPortal, so you can
  mint one; confirm your API honours `userapikey` for it.)
- **HTTPS is mandatory** — users send their personal key on every request.
- **Keep the client cache off** (the default). A shared cache could serve one
  user's results, including private ontologies, to another.
- Without `AGROPORTAL_MCP_REQUIRE_USER_APIKEY`, a request that omits the header
  falls back to the server key; set it to reject those instead.
- The optional `AGROPORTAL_MCP_BEARER_TOKEN` gate is independent and can be
  layered on top for a deployment-wide secret.

## Layout

```
bin/agroportal_mcp                     # executable stdio entrypoint (local clients)
config.ru                              # Rack entrypoint: Streamable HTTP / SSE (remote)
lib/agroportal_mcp.rb                  # build_server + run (stdio) / http_transport (SSE)
lib/agroportal_mcp/middleware.rb       # Rack middlewares: bearer gate + per-user apikey
lib/agroportal_mcp/client_setup.rb     # env -> LinkedData::Client config (+ Rails.cache shim)
lib/agroportal_mcp/tools/              # one file per MCP tool
  search_classes.rb
```
