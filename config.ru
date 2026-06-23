# frozen_string_literal: true

# Rack entrypoint for the AgroPortal MCP server over Streamable HTTP (SSE).
#
#   bundle exec puma config.ru -p 9292        # or: falcon serve -b http://0.0.0.0:9292
#
# This is the remote-deployment counterpart to bin/agroportal_mcp (stdio).
# Pin the bundle to this project so it can be launched from any directory.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('Gemfile', __dir__)
require 'bundler/setup'

require_relative 'lib/agroportal_mcp'
require_relative 'lib/agroportal_mcp/middleware'

truthy = ->(value) { %w[1 true yes on].include?(value.to_s.strip.downcase) }

# Optional deployment-wide gate. When AGROPORTAL_MCP_BEARER_TOKEN is set, every
# request must carry `Authorization: Bearer <token>`. Independent of the
# per-user key below; only do without it behind a trusted network/proxy.
bearer = ENV['AGROPORTAL_MCP_BEARER_TOKEN'].to_s
use AgroportalMcp::Middleware::BearerAuth, bearer unless bearer.empty?

# Per-user AgroPortal keys via the X-Agroportal-User-Apikey header. The server's
# AGROPORTAL_API_KEY is the base credential; each caller's key is forwarded as
# `userapikey`. With AGROPORTAL_MCP_REQUIRE_USER_APIKEY set, requests lacking the
# header are rejected; otherwise they fall back to the server key.
require_user_key = truthy.call(ENV['AGROPORTAL_MCP_REQUIRE_USER_APIKEY'])
use AgroportalMcp::Middleware::UserApikey, require_user_key: require_user_key

# Boot diagnostics (stderr).
warn '[agroportal-mcp] AGROPORTAL_MCP_BEARER_TOKEN unset; no deployment-wide gate.' if bearer.empty?
if require_user_key
  warn '[agroportal-mcp] Per-user mode: requests must send X-Agroportal-User-Apikey.'
else
  warn '[agroportal-mcp] WARNING: requests without X-Agroportal-User-Apikey use the server ' \
       'key (set AGROPORTAL_MCP_REQUIRE_USER_APIKEY=true to require per-user keys).'
end

stateless = truthy.call(ENV['AGROPORTAL_MCP_STATELESS'])

run AgroportalMcp.http_transport(stateless: stateless)
