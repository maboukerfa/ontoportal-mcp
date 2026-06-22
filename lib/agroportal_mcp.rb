# frozen_string_literal: true

require 'mcp'

require_relative 'agroportal_mcp/client_setup'
require_relative 'agroportal_mcp/tools/search_classes'
require_relative 'agroportal_mcp/tools/list_ontologies'
require_relative 'agroportal_mcp/tools/get_class'

# AgroPortal MCP server: exposes the ontologies_api_client capabilities as MCP
# tools over stdio. Register additional tools by adding them to TOOLS.
module AgroportalMcp
  SERVER_NAME = 'agroportal'

  TOOLS = [
    AgroportalMcp::Tools::SearchClasses,
    AgroportalMcp::Tools::ListOntologies,
    AgroportalMcp::Tools::GetClass
  ].freeze

  def self.run
    # Configure the API client from the environment before we start serving.
    AgroportalMcp::ClientSetup.configure!

    server = MCP::Server.new(name: SERVER_NAME, tools: TOOLS)
    transport = MCP::Server::Transports::StdioTransport.new(server)
    transport.open
  end
end
