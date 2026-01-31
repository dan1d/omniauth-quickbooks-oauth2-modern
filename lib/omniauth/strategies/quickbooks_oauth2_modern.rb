# frozen_string_literal: true

require "omniauth-oauth2"
require "faraday"
require "json"

module OmniAuth
  module Strategies
    # OmniAuth strategy for QuickBooks Online OAuth 2.0
    #
    # This strategy handles QuickBooks' OAuth 2.0 flow with:
    # - Sandbox and production environment support
    # - OpenID Connect userinfo fetching for user details
    # - Proper token refresh handling
    #
    # @example Basic usage with Devise
    #   config.omniauth :quickbooks_oauth2_modern,
    #                   ENV['QBO_CLIENT_ID'],
    #                   ENV['QBO_CLIENT_SECRET'],
    #                   sandbox: !Rails.env.production?,
    #                   scope: 'com.intuit.quickbooks.accounting openid profile email'
    #
    class QuickbooksOauth2Modern < OmniAuth::Strategies::OAuth2
      option :name, :quickbooks_oauth2_modern

      # Default scopes for QuickBooks accounting access with OpenID
      option :scope, "com.intuit.quickbooks.accounting openid profile email"

      # Sandbox mode (default: true for safety)
      option :sandbox, true

      option :client_options, {
        site: "https://appcenter.intuit.com",
        authorize_url: "/connect/oauth2",
        token_url: "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer"
      }

      # Use realmId (company ID) as the unique identifier
      uid { realm_id }

      info do
        {
          email: raw_info["email"],
          first_name: raw_info["givenName"],
          last_name: raw_info["familyName"],
          name: full_name,
          phone: raw_info["phoneNumber"],
          realm_id: realm_id
        }
      end

      credentials do
        hash = { "token" => access_token.token }
        hash["refresh_token"] = access_token.refresh_token if access_token.refresh_token
        hash["expires_at"] = access_token.expires_at if access_token.expires_at
        hash["expires"] = access_token.expires?
        hash
      end

      extra do
        {
          realm_id: realm_id,
          raw_info: raw_info
        }
      end

      # Fetch user info from OpenID Connect endpoint if available
      def raw_info
        @raw_info ||= fetch_user_info
      end

      # Override callback_url to support custom redirect URIs
      def callback_url
        options[:redirect_uri] || (full_host + script_name + callback_path)
      end

      private

      # The QuickBooks company ID (realmId)
      def realm_id
        request.params["realmId"]
      end

      # Construct full name from OpenID info
      def full_name
        name = [raw_info["givenName"], raw_info["familyName"]].compact.join(" ")
        name.empty? ? nil : name
      end

      # Fetch user info from OpenID Connect userinfo endpoint
      # Only available if 'openid' scope was requested
      def fetch_user_info
        return {} unless openid_scope_requested?

        response = access_token.get(userinfo_url)
        JSON.parse(response.body)
      rescue StandardError => e
        log(:error, "Failed to fetch userinfo: #{e.message}")
        {}
      end

      # Check if OpenID scopes were requested
      def openid_scope_requested?
        scope = options[:scope] || ""
        scope.split(/\s+/).include?("openid")
      end

      # Get the appropriate userinfo URL based on environment
      def userinfo_url
        domain = options[:sandbox] ? "sandbox-accounts.platform.intuit.com" : "accounts.platform.intuit.com"
        "https://#{domain}/v1/openid_connect/userinfo"
      end
    end
  end
end
