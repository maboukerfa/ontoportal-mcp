# frozen_string_literal: true

require 'cgi'
require 'mcp'
require 'ontologies_api_client'

module AgroportalMcp
  module Tools
    # MCP tool wrapping LinkedData::Client::Models::Class.find — fetches a single
    # ontology class/concept by its URI within a given ontology.
    class GetClass < MCP::Tool
      tool_name 'get_class'
      description <<~DESC
        Fetch a single ontology class/concept by its URI within a given
        ontology. Returns the preferred label, definition(s), synonyms,
        obsolete status, and whether it has children. Use search_classes first
        to discover a class URI and its ontology acronym.
      DESC

      input_schema(
        properties: {
          ontology: {
            type: 'string',
            description: 'Ontology acronym (e.g. "AGROVOC") or full ontology URI.'
          },
          class_id: {
            type: 'string',
            description: 'The class/concept URI, e.g. "http://aims.fao.org/aos/agrovoc/c_8373".'
          },
          language: {
            type: 'string',
            description: 'Language code for labels/definitions, e.g. "en" or "fr". ' \
                         'Defaults to "en"; without it the portal returns an arbitrary language.'
          }
        },
        required: %w[ontology class_id]
      )

      class << self
        def call(ontology:, class_id:, language: nil, server_context: nil)
          # Bypass Models::Class.find: it explores via `ontology.explore.class(id)`,
          # but `class` is Object#class (0-arity) so it never reaches the link
          # resolver. Hit the verified class endpoint directly instead.
          url = "#{ontology_url_for(ontology)}/classes/#{CGI.escape(class_id)}"
          cls = LinkedData::Client::HTTP.get(url, language: language || 'en')

          if cls.nil? || cls.errors
            detail = cls&.errors ? Array(cls.errors).join('; ') : 'not found'
            return MCP::Tool::Response.new(
              [{ type: 'text', text: %(Class "#{class_id}" not found in #{ontology}: #{detail}) }],
              error: true
            )
          end

          MCP::Tool::Response.new([{ type: 'text', text: format_class(cls, ontology) }])
        rescue StandardError => e
          MCP::Tool::Response.new(
            [{ type: 'text', text: "Failed to fetch class: #{e.class}: #{e.message}" }],
            error: true
          )
        end

        private

        def ontology_url_for(ontology)
          return ontology if ontology.to_s.start_with?('http')

          "#{LinkedData::Client.settings.rest_url}/ontologies/#{ontology}"
        end

        def format_class(cls, ontology)
          definitions = Array(cls.definition).compact
          synonyms    = Array(cls.synonym).compact

          lines = []
          lines << "#{cls.prefLabel || '(no preferred label)'}#{cls.obsolete? ? ' [OBSOLETE]' : ''}"
          lines << "URI: #{cls.id}"
          lines << "Ontology: #{ontology}"
          unless definitions.empty?
            lines << 'Definition:'
            definitions.each { |d| lines << "  - #{d}" }
          end
          lines << "Synonyms: #{synonyms.join(', ')}" unless synonyms.empty?
          lines << "Has children: #{cls.hasChildren ? 'yes' : 'no'}"
          lines.join("\n")
        end
      end
    end
  end
end
