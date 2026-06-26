# frozen_string_literal: true

require 'mcp'
require 'ontologies_api_client'

require_relative 'json_dump'

module AgroportalMcp
  module Tools
    # MCP tool wrapping LinkedData::Client::Models::Ontology.all — lists the
    # ontologies available on the portal.
    class ListOntologies < MCP::Tool
      DEFAULT_LIMIT = 50

      tool_name 'list_ontologies'
      description <<~DESC
        List ontologies available in AgroPortal. Returns each ontology's
        acronym, name, and URI. Use this to discover which ontologies exis.
        If u need more information about the ontologies metadata call list_submissions tool.
      DESC

      input_schema(
        properties: {
          limit: {
            type: 'integer',
            description: "Maximum number of ontologies to return (default #{DEFAULT_LIMIT})."
          },
          federate: {
            type: 'boolean',
            description: 'If true, also list ontologies from the configured federated OntoPortal instances.'
          }
        }
      )

      class << self
        def call(limit: nil, federate: nil, server_context: nil)
          params = { include: 'all' }
          params[:federate] = true if federate

          results = Array(LinkedData::Client::Models::Ontology.all(params))
          errors  = results.select { |o| o.errors }.map(&:errors)
          onts    = results.reject { |o| o.errors }

          total = onts.size
          lim   = limit && limit.positive? ? limit : DEFAULT_LIMIT
          shown = onts.sort_by { |o| o.acronym.to_s.downcase }.first(lim)

          payload = { total: total, shown: shown.size, ontologies: shown.map(&:to_hash) }
          payload[:errors] = errors unless errors.empty?
          MCP::Tool::Response.new([{ type: 'text', text: JsonDump.dump(payload) }])
        rescue StandardError => e
          MCP::Tool::Response.new(
            [{ type: 'text', text: "Failed to list ontologies: #{e.class}: #{e.message}" }],
            error: true
          )
        end
      end
    end
  end
end
