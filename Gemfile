source 'https://rubygems.org'

# Official Model Context Protocol SDK (server + stdio transport).
gem 'mcp'

# The AgroPortal / OntoPortal API client, consumed from the AgroPortal repo.
gem 'ontologies_api_client',
    git: 'https://github.com/agroportal/ontologies_api_ruby_client.git',
    branch: 'master'

# Remote deployment over Streamable HTTP (SSE). Not needed for the default
# stdio transport. `rack` is required by MCP's StreamableHTTPTransport; `puma`
# serves it (Falcon works too — see the README).
group :http do
  gem 'puma'
  gem 'rack'
end
