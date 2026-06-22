# frozen_string_literal: true

require 'mcp'
require 'ontologies_api_client'

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
          params = {}
          params[:ontologies]          = ontologies if present?(ontologies)
          params[:require_exact_match] = true if exact_match
          params[:require_definitions] = true if require_definitions
          params[:pagesize]            = pagesize if pagesize
          params[:federate]            = true if federate

          result = LinkedData::Client::Models::Class.search(query, params)
          MCP::Tool::Response.new([{ type: 'text', text: format_result(query, result) }])
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

        def format_result(query, result)
          classes = Array(result.collection)
          errors  = Array(result.errors).compact

          lines = []
          if classes.empty?
            lines << %(No classes found for "#{query}".)
          else
            lines << %(Found #{classes.size} result(s) for "#{query}":)
            lines << ''
            classes.each_with_index { |cls, i| lines.concat(format_class(cls, i + 1)) << '' }
          end

          unless errors.empty?
            lines << 'Warnings (some portals failed):'
            errors.each { |err| lines << "- #{err}" }
          end

          lines.join("\n").strip
        end

        def format_class(cls, index)
          definition = Array(cls.definition).first
          obsolete   = cls.obsolete? ? ' [OBSOLETE]' : ''
          [
            "#{index}. #{cls.prefLabel || '(no preferred label)'}#{obsolete}",
            "   URI: #{cls.id}",
            "   Ontology: #{ontology_acronym(cls) || 'n/a'}",
            (definition ? "   Definition: #{truncate(definition)}" : nil)
          ].compact
        end

        def ontology_acronym(cls)
          link = cls.links && cls.links['ontology']
          link&.split('/')&.last
        end

        def truncate(text, max = 300)
          text = text.to_s
          text.length > max ? "#{text[0, max]}…" : text
        end
      end
    end
  end
end
