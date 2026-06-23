# frozen_string_literal: true

require 'mcp'

require_relative 'agroportal_mcp/client_setup'
require_relative 'agroportal_mcp/tools/search_classes'
require_relative 'agroportal_mcp/tools/list_ontologies'
require_relative 'agroportal_mcp/tools/get_class'
require_relative 'agroportal_mcp/tools/get_submission'
require_relative 'agroportal_mcp/tools/get_metrics'

# AgroPortal MCP server: exposes the ontologies_api_client capabilities as MCP
# tools. Serves over stdio for local clients (bin/agroportal_mcp) or over
# Streamable HTTP/SSE for remote deployment (config.ru). Register additional
# tools by adding them to TOOLS.
module AgroportalMcp
  SERVER_NAME = 'agroportal'

  TOOLS = [
    AgroportalMcp::Tools::SearchClasses,
    AgroportalMcp::Tools::ListOntologies,
    AgroportalMcp::Tools::GetClass,
    AgroportalMcp::Tools::GetSubmission,
    AgroportalMcp::Tools::GetMetrics
  ].freeze

  # Configure the API client from the environment and build a server instance
  # with every tool registered. Shared by all transports.
  def self.build_server
    AgroportalMcp::ClientSetup.configure!
    MCP::Server.new(name: SERVER_NAME, tools: TOOLS)
  end

  # Default entrypoint: serve over stdio. MCP clients spawn bin/agroportal_mcp,
  # which calls this.
  def self.run
    transport = MCP::Server::Transports::StdioTransport.new(build_server)
    transport.open
  end

  # Build the Streamable HTTP transport (SSE) as a Rack app for remote
  # deployment; mounted from config.ru. See the README "Remote deployment".
  #
  # stateless: when false (default) the server keeps per-client sessions and
  # can push server->client messages over a long-lived GET SSE stream. When
  # true, each POST is self-contained with no session state, which is simpler
  # to scale horizontally behind a load balancer.
  def self.http_transport(stateless: false)
    MCP::Server::Transports::StreamableHTTPTransport.new(build_server, stateless: stateless)
  end
end
