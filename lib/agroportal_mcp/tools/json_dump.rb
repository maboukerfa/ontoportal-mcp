# frozen_string_literal: true

require 'json'

module AgroportalMcp
  module Tools
    # Helper for emitting raw API records as JSON. The API client deserializes
    # linked resources (e.g. a submission's hasCreator/hasContributor, an agent's
    # affiliations) into nested model objects. Plain JSON renders those as
    # "#<...Agent:0x...>" inspect strings, which are useless. Replace any nested
    # model object with its id (URI) so the output stays usable — and the id can
    # be passed straight to get_agent (or another fetch tool).
    module JsonDump
      module_function

      # Serialize a value to pretty JSON, collapsing nested model objects to ids.
      def dump(value)
        JSON.pretty_generate(serialize(value))
      end

      def serialize(value)
        case value
        when LinkedData::Client::Base
          # Prefer the id (URI); fall back to the full hash if it has none.
          id = value.id if value.respond_to?(:id)
          id || serialize(value.to_hash)
        when Array
          value.map { |v| serialize(v) }
        when Hash
          value.each_with_object({}) { |(k, v), out| out[k] = serialize(v) }
        else
          value
        end
      end
    end
  end
end
