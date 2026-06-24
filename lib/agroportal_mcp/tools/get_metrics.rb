# frozen_string_literal: true

require 'json'
require 'mcp'
require 'ontologies_api_client'

module AgroportalMcp
  module Tools
    # MCP tool exposing ontology submission metrics (size + hierarchy stats),
    # from /ontologies/{ACRONYM}/metrics or
    # /ontologies/{ACRONYM}/submissions/{id}/metrics.
    class GetMetrics < MCP::Tool
      tool_name 'get_metrics'
      description <<~DESC
        Get size and structure metrics for an ontology submission in AgroPortal:
        number of classes, individuals, and properties, plus hierarchy stats
        (max depth, max/average child count). Omit submission_id for the latest
        submission. Note: for SKOS vocabularies the concepts are counted as
        individuals, not classes.
      DESC

      input_schema(
        properties: {
          ontology: {
            type: 'string',
            description: 'Ontology acronym (e.g. "AGROVOC") or full ontology URI.'
          },
          submission_id: {
            type: 'integer',
            description: 'Specific submission id (version). Omit for the latest submission.'
          }
        },
        required: %w[ontology]
      )

      class << self
        def call(ontology:, submission_id: nil, server_context: nil)
          base = ontology_url_for(ontology)
          url  = submission_id ? "#{base}/submissions/#{submission_id}/metrics" : "#{base}/metrics"
          metrics = LinkedData::Client::HTTP.get(url)
          metrics = metrics.first if metrics.is_a?(Array)

          if metrics.nil? || metrics.errors
            detail = metrics&.errors ? Array(metrics.errors).join('; ') : 'not found'
            target = submission_id ? " submission #{submission_id}" : ''
            return MCP::Tool::Response.new(
              [{ type: 'text', text: %(No metrics for #{ontology}#{target}: #{detail}) }],
              error: true
            )
          end

          MCP::Tool::Response.new([{ type: 'text', text: JSON.pretty_generate(metrics.to_hash) }])
        rescue StandardError => e
          MCP::Tool::Response.new(
            [{ type: 'text', text: "Failed to fetch metrics: #{e.class}: #{e.message}" }],
            error: true
          )
        end

        private

        def ontology_url_for(ontology)
          return ontology if ontology.to_s.start_with?('http')

          "#{LinkedData::Client.settings.rest_url}/ontologies/#{ontology}"
        end
      end
    end
  end
end
