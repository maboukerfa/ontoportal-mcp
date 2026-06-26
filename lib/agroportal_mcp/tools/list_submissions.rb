# frozen_string_literal: true

require 'mcp'
require 'ontologies_api_client'

require_relative 'json_dump'

module AgroportalMcp
  module Tools
    # MCP tool listing ontology submissions (versioned uploads) with their
    # metadata. Fetches /ontologies/{ACRONYM}/submissions for a single ontology's
    # version history, or the portal-wide /submissions (latest submission of every
    # ontology) when no ontology is given. Use get_submission for a single version.
    class ListSubmissions < MCP::Tool
      DEFAULT_LIMIT = 50

      tool_name 'list_submissions'
      description <<~DESC
        List ontology submissions (versioned uploads) from AgroPortal with their
        metadata: version, status, format, dates, license, homepage,
        documentation, namespace & version IRI, natural languages, keywords,
        abstract, and description. Pass an ontology acronym to list that
        ontology's full submission history (all versions, newest first). Omit
        ontology to list the latest submission of every ontology on the portal,
        which is the quickest way to gather metadata across many ontologies at
        once. Use get_submission to fetch a single submission, or list_ontologies
        to find an acronym.
      DESC

      input_schema(
        properties: {
          ontology: {
            type: 'string',
            description: 'Ontology acronym (e.g. "AGROVOC") or full ontology URI. ' \
                         'Omit to list the latest submission of every ontology.'
          },
          limit: {
            type: 'integer',
            description: 'Maximum number of submissions to return when listing ' \
                         "portal-wide (default #{DEFAULT_LIMIT}). Ignored for a single ontology."
          }
        }
      )

      class << self
        def call(ontology: nil, limit: nil, server_context: nil)
          subs = fetch(ontology)
          subs = Array(subs).reject { |s| s.respond_to?(:errors) && s.errors }

          total = subs.size
          shown = ontology ? subs : subs.first(positive_limit(limit))

          payload = { total: total, shown: shown.size, submissions: shown.map(&:to_hash) }
          MCP::Tool::Response.new([{ type: 'text', text: JsonDump.dump(payload) }])
        rescue StandardError => e
          MCP::Tool::Response.new(
            [{ type: 'text', text: "Failed to list submissions: #{e.class}: #{e.message}" }],
            error: true
          )
        end

        private

        def fetch(ontology)
          url = if ontology
                  "#{ontology_url_for(ontology)}/submissions"
                else
                  "#{LinkedData::Client.settings.rest_url}/submissions"
                end
          LinkedData::Client::HTTP.get(url, display: 'all')
        end

        def ontology_url_for(ontology)
          return ontology if ontology.to_s.start_with?('http')

          "#{LinkedData::Client.settings.rest_url}/ontologies/#{ontology}"
        end

        def positive_limit(limit)
          limit && limit.positive? ? limit : DEFAULT_LIMIT
        end
      end
    end
  end
end
