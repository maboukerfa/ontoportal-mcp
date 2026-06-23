# frozen_string_literal: true

require 'json'
require 'rack/utils'

module AgroportalMcp
  # Rack middlewares for the Streamable HTTP (SSE) deployment. Mounted from
  # config.ru; the stdio transport does not use these.
  module Middleware
    # Build a JSON-RPC error Rack response.
    def self.json_error(status, code, message, extra_headers = {})
      body = { jsonrpc: '2.0', id: nil, error: { code: code, message: message } }.to_json
      [status, { 'content-type' => 'application/json' }.merge(extra_headers), [body]]
    end

    # Optional deployment-wide gate. When a token is configured, every request
    # must send `Authorization: Bearer <token>`.
    class BearerAuth
      def initialize(app, token)
        @app = app
        @expected = "Bearer #{token}"
      end

      def call(env)
        provided = env['HTTP_AUTHORIZATION'].to_s
        # Length check first: secure_compare requires equal-length inputs.
        authorized = provided.bytesize == @expected.bytesize &&
                     ::Rack::Utils.secure_compare(provided, @expected)
        return @app.call(env) if authorized

        Middleware.json_error(401, -32_001, 'Unauthorized', 'www-authenticate' => 'Bearer')
      end
    end

    # Per-user AgroPortal API key. Reads the caller's key from the
    # `X-Agroportal-User-Apikey` header and exposes it to ontologies_api_client's
    # `user_apikey` Faraday middleware via `Thread.current[:session]`, which
    # appends `&userapikey=<key>` to the outbound Authorization header so the API
    # attributes the request to that user.
    #
    # `Thread#[]` is fiber-local, so this isolates per request under both Puma
    # (threads) and Falcon (fibers). Tool calls run inside the SSE streaming
    # response body, which the web server consumes *after* `call` returns, so the
    # key is re-established inside the wrapped body rather than only around
    # `@app.call`.
    class UserApikey
      HEADER = 'HTTP_X_AGROPORTAL_USER_APIKEY'
      User = Struct.new(:apikey)

      def initialize(app, require_user_key: false)
        @app = app
        @require_user_key = require_user_key
      end

      def call(env)
        key = env[HEADER].to_s.strip
        if key.empty? && @require_user_key
          return Middleware.json_error(401, -32_001, 'Missing X-Agroportal-User-Apikey header')
        end

        # Covers the synchronous path: requests whose handler runs inside
        # @app.call (initialize, or tool calls when enable_json_response is on).
        apply(key)
        status, headers, body = @app.call(env)

        if body.respond_to?(:call) # Rack 3 streaming (SSE) body, consumed later
          inner = body
          wrapped = proc do |stream|
            apply(key)
            begin
              inner.call(stream)
            ensure
              clear
            end
          end
          [status, headers, wrapped]
        else
          [status, headers, body]
        end
      ensure
        # Never leave the key set between returning the response and the server
        # consuming a streaming body; the wrapper above re-establishes it.
        clear
      end

      private

      def apply(key)
        Thread.current[:session] = key.empty? ? nil : { user: User.new(key) }
      end

      def clear
        Thread.current[:session] = nil
      end
    end
  end
end
