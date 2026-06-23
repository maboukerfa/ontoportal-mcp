# frozen_string_literal: true

require 'mcp'
require 'ontologies_api_client'

module AgroportalMcp
  module Tools
    # MCP tool exposing ontology submission (versioned upload) metadata. Fetches
    # /ontologies/{ACRONYM}/latest_submission, or /submissions/{id} for a
    # specific version, directly via HTTP.get.
    class GetSubmission < MCP::Tool
      # Only request the fields we render (@id/@type are always returned).
      FIELDS = %w[
        submissionId version status released creationDate modificationDate
        hasOntologyLanguage hasLicense homepage documentation naturalLanguage
        publication description preferredNamespaceUri preferredNamespacePrefix
        versionIRI URI abstract keywords
      ].join(',')

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
          sub  = LinkedData::Client::HTTP.get(url, display: FIELDS)

          if sub.nil? || sub.errors
            detail = sub&.errors ? Array(sub.errors).join('; ') : 'not found'
            target = submission_id ? "submission #{submission_id}" : 'latest submission'
            return MCP::Tool::Response.new(
              [{ type: 'text', text: %(No #{target} for #{ontology}: #{detail}) }],
              error: true
            )
          end

          MCP::Tool::Response.new([{ type: 'text', text: format_submission(sub, ontology) }])
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

        def format_submission(sub, ontology)
          # naturalLanguage values are lexvo URIs; show the trailing language code.
          languages    = Array(sub.naturalLanguage).compact.map { |u| u.to_s.split('/').last }.reject(&:empty?)
          keywords     = Array(sub.keywords).compact
          publications = Array(sub.publication).compact

          lines = []
          lines << "#{acronym_for(ontology, sub)} — submission ##{sub.submissionId}" \
                   "#{sub.version ? " (version #{sub.version})" : ''}"
          add(lines, 'Status', sub.status)
          add(lines, 'Format', sub.hasOntologyLanguage)
          add(lines, 'Version IRI', sub.versionIRI)
          add(lines, 'Ontology URI', sub['URI'])
          add(lines, 'Namespace prefix', sub.preferredNamespacePrefix)
          add(lines, 'Namespace URI', sub.preferredNamespaceUri)
          add(lines, 'Released', date_only(sub.released))
          add(lines, 'Created', date_only(sub.creationDate))
          add(lines, 'Modified', date_only(sub.modificationDate))
          add(lines, 'License', sub.hasLicense)
          add(lines, 'Homepage', sub.homepage)
          add(lines, 'Documentation', sub.documentation)
          add(lines, 'Natural languages', languages.empty? ? nil : languages.sort.join(', '))
          add(lines, 'Keywords', keywords.empty? ? nil : keywords.join(', '))
          add(lines, 'Submission URI', sub.id)

          unless publications.empty?
            lines << 'Publications:'
            publications.each { |p| lines << "  - #{p}" }
          end
          add_block(lines, 'Abstract', sub.abstract)
          add_block(lines, 'Description', sub.description)

          lines.join("\n")
        end

        def add(lines, label, value)
          lines << "#{label}: #{value}" unless value.nil? || value.to_s.strip.empty?
        end

        def add_block(lines, label, value)
          return if value.nil? || value.to_s.strip.empty?

          lines << "#{label}:"
          lines << "  #{truncate(value)}"
        end

        def acronym_for(ontology, sub)
          return ontology unless ontology.to_s.start_with?('http')

          sub.id.to_s[%r{/ontologies/([^/]+)}, 1] || ontology
        end

        def date_only(value)
          value.to_s[0, 10] if value
        end

        def truncate(text, max = 500)
          text = text.to_s
          text.length > max ? "#{text[0, max]}…" : text
        end
      end
    end
  end
end
