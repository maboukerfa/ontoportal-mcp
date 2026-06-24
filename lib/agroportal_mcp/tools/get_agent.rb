# frozen_string_literal: true

require 'cgi'
require 'json'
require 'mcp'
require 'ontologies_api_client'

module AgroportalMcp
  module Tools
    # MCP tool exposing an AgroPortal agent (a FOAF Agent) by its id. An agent is
    # any person or organization with a role in an ontology — contributor,
    # creator, curator, publisher, funder, etc. Fetches /agents/{id} directly via
    # HTTP.get and returns the raw record.
    class GetAgent < MCP::Tool
      tool_name 'get_agent'
      description <<~DESC
        Get an AgroPortal agent by its id. An agent is any person or organization
        that has a role in an ontology — contributor, creator, curator,
        publisher, funder, etc. Returns the agent's name, type (person or
        organization), identifiers (e.g. ORCID), email, homepage, affiliations,
        and any other recorded values. Agent ids are surfaced on ontology
        submissions (see get_submission); pass the numeric id or the full agent
        URI.
      DESC

      input_schema(
        properties: {
          agent_id: {
            type: 'string',
            description: 'Agent id — the numeric local id (e.g. "123") or the ' \
                         'full agent URI (e.g. "https://data.agroportal.eu/agents/123").'
          }
        },
        required: %w[agent_id]
      )

      class << self
        def call(agent_id:, server_context: nil)
          agent = LinkedData::Client::HTTP.get(agent_url_for(agent_id), display: 'all')

          if agent.nil? || agent.errors
            detail = agent&.errors ? Array(agent.errors).join('; ') : 'not found'
            return MCP::Tool::Response.new(
              [{ type: 'text', text: %(Agent "#{agent_id}" not found: #{detail}) }],
              error: true
            )
          end

          MCP::Tool::Response.new([{ type: 'text', text: JSON.pretty_generate(agent.to_hash) }])
        rescue StandardError => e
          MCP::Tool::Response.new(
            [{ type: 'text', text: "Failed to fetch agent: #{e.class}: #{e.message}" }],
            error: true
          )
        end

        private

        def agent_url_for(agent_id)
          return agent_id if agent_id.to_s.start_with?('http')

          "#{LinkedData::Client.settings.rest_url}/agents/#{CGI.escape(agent_id.to_s)}"
        end
      end
    end
  end
end
