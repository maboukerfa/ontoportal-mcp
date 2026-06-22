# agroportal-mcp

An [MCP](https://modelcontextprotocol.io) server that exposes the
[AgroPortal / OntoPortal](https://agroportal.eu) API as tools for LLM
clients (Claude Desktop, Claude Code, …). It is a thin wrapper around the
[`ontologies_api_client`](../ontologies_api_ruby_client) Ruby gem, served over
stdio with the official [`mcp`](https://rubygems.org/gems/mcp) gem.

## Tools

| Tool | Description |
| --- | --- |
| `search_classes` | Full-text search over ontology classes/concepts. Returns label, URI, source ontology, and definition. Supports restricting to specific ontologies and (optionally) federated search across other OntoPortal instances. |
| `list_ontologies` | List the ontologies available on the portal, optionally filtered by a case-insensitive match on acronym or name. Returns acronym, name, and URI. Supports federation. |
| `get_class` | Fetch a single class/concept by its URI within an ontology. Returns preferred label, definition(s), synonyms, obsolete status, and whether it has children. Accepts a `language` code (default `en`). |

More tools (e.g. `search_ontologies`, ontology metrics, submission details) can
be added under `lib/agroportal_mcp/tools/` and registered in `TOOLS`
(`lib/agroportal_mcp.rb`).

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

## Layout

```
bin/agroportal_mcp                     # executable stdio entrypoint
lib/agroportal_mcp.rb                  # server: configures client, registers TOOLS
lib/agroportal_mcp/client_setup.rb     # env -> LinkedData::Client config (+ Rails.cache shim)
lib/agroportal_mcp/tools/              # one file per MCP tool
  search_classes.rb
```
