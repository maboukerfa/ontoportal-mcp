# frozen_string_literal: true

require 'json'
require 'mcp'
require 'ontologies_api_client'

module AgroportalMcp
  module Tools
    # MCP tool exposing ontology submission (versioned upload) metadata. Fetches
    # /ontologies/{ACRONYM}/latest_submission, or /submissions/{id} for a
    # specific version, directly via HTTP.get.
    class GetSubmission < MCP::Tool
      tool_name 'get_submission'
      description <<~DESC
        Get details of an ontology's submission (a versioned upload) from
        AgroPortal: version, status, format, dates, license, homepage,
        documentation, namespace & version IRI, natural languages, keywords,
        abstract, and description. Omit submission_id for the latest submission,
        or pass one to fetch a specific version. Use list_ontologies to find an
        acronym.
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
          url  = submission_id ? "#{base}/submissions/#{submission_id}" : "#{base}/latest_submission"
          sub  = LinkedData::Client::HTTP.get(url, display: 'all')

          if sub.nil? || sub.errors
            detail = sub&.errors ? Array(sub.errors).join('; ') : 'not found'
            target = submission_id ? "submission #{submission_id}" : 'latest submission'
            return MCP::Tool::Response.new(
              [{ type: 'text', text: %(No #{target} for #{ontology}: #{detail}) }],
              error: true
            )
          end

          MCP::Tool::Response.new([{ type: 'text', text: JSON.pretty_generate(sub.to_hash) }])
        rescue StandardError => e
          MCP::Tool::Response.new(
            [{ type: 'text', text: "Failed to fetch submission: #{e.class}: #{e.message}" }],
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
