# frozen_string_literal: true

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

          MCP::Tool::Response.new([{ type: 'text', text: format_metrics(metrics, ontology) }])
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

        def format_metrics(metrics, ontology)
          sub = metrics.id.to_s[%r{/submissions/(\d+)}, 1]
          lines = ["Metrics for #{ontology}#{sub ? " (submission ##{sub})" : ''}:"]
          add(lines, 'Classes', delimit(metrics.classes))
          add(lines, 'Individuals', delimit(metrics.individuals))
          add(lines, 'Properties', delimit(metrics.properties))
          add(lines, 'Axioms', delimit(metrics.numberOfAxioms))
          add(lines, 'Max depth', metrics.maxDepth)
          add(lines, 'Max child count', metrics.maxChildCount)
          add(lines, 'Average child count', metrics.averageChildCount)
          add(lines, 'Classes with one child', metrics.classesWithOneChild)
          add(lines, 'Classes with >25 children', metrics.classesWithMoreThan25Children)
          add(lines, 'Classes with no definition', metrics.classesWithNoDefinition)
          lines.join("\n")
        end

        def add(lines, label, value)
          lines << "#{label}: #{value}" unless value.nil? || value.to_s.strip.empty?
        end

        # Add thousands separators to integer counts (no ActionView dependency).
        def delimit(value)
          return nil if value.nil? || value.to_s.strip.empty?

          value.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
        end
      end
    end
  end
end
