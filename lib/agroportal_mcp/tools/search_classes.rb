# frozen_string_literal: true

require 'mcp'
require 'ontologies_api_client'

require_relative 'json_dump'

module AgroportalMcp
  module Tools
    # MCP tool wrapping LinkedData::Client::Models::Class.search — full-text
    # search over ontology classes/concepts in AgroPortal (and, optionally,
    # federated OntoPortal instances).
    class SearchClasses < MCP::Tool
      tool_name 'search_classes'
      description <<~DESC
        Search ontology classes/concepts by text across AgroPortal. Returns
        matching terms with their preferred label, URI, source ontology, and
        definition. Use this to look up agronomic/biomedical terms, find a
        concept's URI, or discover which ontologies define a term.
      DESC

      input_schema(
        properties: {
          query: {
            type: 'string',
            description: 'Text to search for, e.g. "wheat" or "photosynthesis".'
          },
          ontologies: {
            type: 'string',
            description: 'Optional comma-separated ontology acronyms to restrict ' \
                         'the search, e.g. "AGROVOC,ENVO".'
          },
          exact_match: {
            type: 'boolean',
            description: 'If true, only return classes whose label exactly matches the query.'
          },
          require_definitions: {
            type: 'boolean',
            description: 'If true, only return classes that have a definition.'
          },
          pagesize: {
            type: 'integer',
            description: 'Maximum number of results to return (default: server default, ~50).'
          },
          federate: {
            type: 'boolean',
            description: 'If true, also search the configured federated OntoPortal instances.'
          }
        },
        required: ['query']
      )

      class << self
        def call(query:, ontologies: nil, exact_match: nil, require_definitions: nil,
                 pagesize: nil, federate: nil, server_context: nil)
          params = { include: 'all' }
          params[:ontologies]          = ontologies if present?(ontologies)
          params[:require_exact_match] = true if exact_match
          params[:require_definitions] = true if require_definitions
          params[:pagesize]            = pagesize if pagesize
          params[:federate]            = true if federate

          result = LinkedData::Client::Models::Class.search(query, params)
          payload = { query: query, results: Array(result.collection).map(&:to_hash) }
          errors = Array(result.errors).compact
          payload[:errors] = errors unless errors.empty?
          MCP::Tool::Response.new([{ type: 'text', text: JsonDump.dump(payload) }])
        rescue StandardError => e
          MCP::Tool::Response.new(
            [{ type: 'text', text: "Search failed: #{e.class}: #{e.message}" }],
            error: true
          )
        end

        private

        def present?(value)
          value.is_a?(String) && !value.strip.empty?
        end
      end
    end
  end
end
