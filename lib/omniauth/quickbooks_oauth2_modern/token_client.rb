# frozen_string_literal: true

require 'faraday'
require 'json'
require 'base64'

module OmniAuth
  module QuickbooksOauth2Modern
    # Client for managing QuickBooks OAuth2 tokens
    #
    # This class provides an easy way to refresh expired tokens in your Rails app.
    #
    # @example Basic usage
    #   client = OmniAuth::QuickbooksOauth2Modern::TokenClient.new(
    #     client_id: ENV['QBO_CLIENT_ID'],
    #     client_secret: ENV['QBO_CLIENT_SECRET']
    #   )
    #
    #   # Refresh an expired token
    #   result = client.refresh_token(user.qbo_refresh_token)
    #   if result.success?
    #     user.update!(
    #       qbo_access_token: result.access_token,
    #       qbo_refresh_token: result.refresh_token,
    #       qbo_token_expires_at: result.expires_at
    #     )
    #   end
    #
    # @example With automatic token refresh in a service
    #   class QuickBooksApiService
    #     def initialize(account)
    #       @account = account
    #       @client = OmniAuth::QuickbooksOauth2Modern::TokenClient.new(
    #         client_id: ENV['QBO_CLIENT_ID'],
    #         client_secret: ENV['QBO_CLIENT_SECRET']
    #       )
    #     end
    #
    #     def with_valid_token
    #       refresh_if_expired!
    #       yield @account.access_token
    #     end
    #
    #     private
    #
    #     def refresh_if_expired!
    #       return unless @client.token_expired?(@account.token_expires_at)
    #
    #       result = @client.refresh_token(@account.refresh_token)
    #       raise "Token refresh failed: #{result.error}" unless result.success?
    #
    #       @account.update!(
    #         access_token: result.access_token,
    #         refresh_token: result.refresh_token,
    #         token_expires_at: result.expires_at
    #       )
    #     end
    #   end
    #
    class TokenClient
      # Result object for token operations
      class TokenResult
        attr_reader :access_token, :refresh_token, :expires_at, :expires_in, :error, :raw_response

        def initialize(success:, access_token: nil, refresh_token: nil, expires_at: nil, expires_in: nil,
                       error: nil, raw_response: nil)
          @success = success
          @access_token = access_token
          @refresh_token = refresh_token
          @expires_at = expires_at
          @expires_in = expires_in
          @error = error
          @raw_response = raw_response
        end

        def success?
          @success
        end

        def failure?
          !@success
        end
      end

      # Intuit OAuth2 token endpoint
      TOKEN_URL = 'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer'

      attr_reader :client_id, :client_secret

      # Initialize a new TokenClient
      #
      # @param client_id [String] Your QuickBooks App Client ID
      # @param client_secret [String] Your QuickBooks App Client Secret
      def initialize(client_id:, client_secret:)
        @client_id = client_id
        @client_secret = client_secret
      end

      # Refresh an access token using a refresh token
      #
      # @param refresh_token [String] The refresh token to use
      # @return [TokenResult] Result object with new tokens or error
      def refresh_token(refresh_token)
        if refresh_token.nil? || refresh_token.empty?
          return TokenResult.new(success: false,
                                 error: 'Refresh token is required')
        end

        response = make_refresh_request(refresh_token)

        if response.success?
          parse_success_response(response)
        else
          parse_error_response(response)
        end
      rescue Faraday::Error => e
        TokenResult.new(success: false, error: "Network error: #{e.message}")
      rescue JSON::ParserError => e
        TokenResult.new(success: false, error: "Invalid JSON response: #{e.message}")
      rescue StandardError => e
        TokenResult.new(success: false, error: "Unexpected error: #{e.message}")
      end

      # Check if a token is expired or about to expire
      #
      # @param expires_at [Time, Integer] Token expiration time
      # @param buffer_seconds [Integer] Buffer before expiration (default: 300 = 5 minutes)
      # @return [Boolean] True if token is expired or will expire within buffer
      def token_expired?(expires_at, buffer_seconds: 300)
        return true if expires_at.nil?

        expires_at_time = expires_at.is_a?(Integer) ? Time.at(expires_at) : expires_at
        Time.now >= (expires_at_time - buffer_seconds)
      end

      private

      def make_refresh_request(refresh_token)
        # QuickBooks uses Basic Auth with base64 encoded client_id:client_secret
        credentials = Base64.strict_encode64("#{client_id}:#{client_secret}")

        Faraday.post(TOKEN_URL) do |req|
          req.headers['Authorization'] = "Basic #{credentials}"
          req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
          req.headers['Accept'] = 'application/json'
          req.body = URI.encode_www_form(
            grant_type: 'refresh_token',
            refresh_token: refresh_token
          )
        end
      end

      def parse_success_response(response)
        data = JSON.parse(response.body)

        expires_in = data['expires_in']&.to_i
        expires_at = expires_in ? Time.now.to_i + expires_in : nil

        TokenResult.new(
          success: true,
          access_token: data['access_token'],
          refresh_token: data['refresh_token'],
          expires_in: expires_in,
          expires_at: expires_at,
          raw_response: data
        )
      end

      def parse_error_response(response)
        error_data = begin
          JSON.parse(response.body)
        rescue JSON::ParserError
          { 'error' => response.body }
        end

        error_message = error_data['error_description'] || error_data['error'] || "HTTP #{response.status}"

        TokenResult.new(
          success: false,
          error: error_message,
          raw_response: error_data
        )
      end
    end
  end
end
