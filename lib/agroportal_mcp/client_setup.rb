# frozen_string_literal: true

# Load full ActiveSupport: the client relies on cache instrumentation
# (ActiveSupport::Notifications) and core extensions (e.g. `blank?`) along the
# federation/search path, beyond just active_support/cache.
require 'active_support/all'
require 'logger'

# Order matters here. ontologies_api_client requires `spawnling`, which at load
# time branches on `defined?(::Rails)`: when Rails is ABSENT it loads cleanly,
# but when present it reads `::Rails::VERSION::MAJOR` and `::Rails.logger`. So we
# must require the client while no `Rails` constant exists.
require 'ontologies_api_client'

# The client's federation layer (request_federation.rb) then calls `Rails.cache`
# at RUNTIME, even for non-federated requests. Now that the gem has finished
# loading, define a minimal standalone shim it can use.
unless defined?(Rails)
  module Rails
    def self.cache
      @cache ||= ActiveSupport::Cache::MemoryStore.new
    end

    def self.logger
      @logger ||= Logger.new($stderr)
    end
  end
end

module AgroportalMcp
  # Reads connection settings from the environment and configures the API client.
  module ClientSetup
    DEFAULT_REST_URL = 'https://data.agroportal.eu'

    module_function

    def configure!
      apikey = ENV['AGROPORTAL_API_KEY'] || ENV['AGROPORTAL_APIKEY']
      if apikey.nil? || apikey.strip.empty?
        abort('AGROPORTAL_API_KEY is not set. Create one from your AgroPortal ' \
              'account page and pass it through the MCP server env config.')
      end

      rest_url = ENV.fetch('AGROPORTAL_REST_URL', DEFAULT_REST_URL)

      LinkedData::Client.config do |config|
        config.rest_url          = rest_url
        config.apikey            = apikey
        # Keep stdout clean: the client prints cache status to stdout when
        # caching is enabled, which would corrupt the stdio JSON-RPC stream.
        config.cache             = false
        config.federated_portals = federated_portals
      end
    end

    # Optional federation. Format (space-separated triples, comma-separated):
    #   AGROPORTAL_FEDERATED_PORTALS="ecoportal https://data.ecoportal.lifewatch.eu KEY, ..."
    def federated_portals
      raw = ENV['AGROPORTAL_FEDERATED_PORTALS'].to_s.strip
      return {} if raw.empty?

      raw.split(',').each_with_object({}) do |entry, portals|
        name, api, key = entry.strip.split(/\s+/, 3)
        next if name.nil? || api.nil? || key.nil?

        portals[name.to_sym] = { api: api, apikey: key }
      end
    end
  end
end
