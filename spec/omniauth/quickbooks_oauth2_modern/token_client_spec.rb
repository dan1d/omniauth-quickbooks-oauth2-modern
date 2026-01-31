# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OmniAuth::QuickbooksOauth2Modern::TokenClient do
  subject(:client) do
    described_class.new(
      client_id: 'test_client_id',
      client_secret: 'test_client_secret'
    )
  end

  let(:token_url) { 'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer' }

  describe '#initialize' do
    it 'sets the client_id' do
      expect(client.client_id).to eq('test_client_id')
    end

    it 'sets the client_secret' do
      expect(client.client_secret).to eq('test_client_secret')
    end
  end

  describe '#token_expired?' do
    context 'when expires_at is nil' do
      it 'returns true' do
        expect(client.token_expired?(nil)).to be true
      end
    end

    context 'when token is expired' do
      it 'returns true for past time' do
        expires_at = Time.now - 3600
        expect(client.token_expired?(expires_at)).to be true
      end

      it 'returns true for Unix timestamp in the past' do
        expires_at = Time.now.to_i - 3600
        expect(client.token_expired?(expires_at)).to be true
      end
    end

    context 'when token is within buffer period' do
      it 'returns true when within default 5 minute buffer' do
        expires_at = Time.now + 60 # 1 minute from now
        expect(client.token_expired?(expires_at)).to be true
      end
    end

    context 'when token is not expired' do
      it 'returns false for future time beyond buffer' do
        expires_at = Time.now + 3600 # 1 hour from now
        expect(client.token_expired?(expires_at)).to be false
      end

      it 'respects custom buffer_seconds' do
        expires_at = Time.now + 60 # 1 minute from now
        expect(client.token_expired?(expires_at, buffer_seconds: 30)).to be false
      end
    end
  end

  describe '#refresh_token' do
    let(:refresh_token) { 'test_refresh_token' }

    context 'when refresh_token is nil or empty' do
      it 'returns failure for nil token' do
        result = client.refresh_token(nil)
        expect(result).to be_failure
        expect(result.error).to eq('Refresh token is required')
      end

      it 'returns failure for empty token' do
        result = client.refresh_token('')
        expect(result).to be_failure
        expect(result.error).to eq('Refresh token is required')
      end
    end

    context 'when refresh is successful' do
      let(:success_response) do
        {
          'access_token' => 'new_access_token',
          'refresh_token' => 'new_refresh_token',
          'expires_in' => 3600,
          'token_type' => 'bearer'
        }
      end

      before do
        stub_request(:post, token_url)
          .with(
            headers: {
              'Content-Type' => 'application/x-www-form-urlencoded',
              'Accept' => 'application/json',
              'Authorization' => /^Basic /
            }
          )
          .to_return(
            status: 200,
            body: success_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns success' do
        result = client.refresh_token(refresh_token)
        expect(result).to be_success
      end

      it 'returns the new access token' do
        result = client.refresh_token(refresh_token)
        expect(result.access_token).to eq('new_access_token')
      end

      it 'returns the new refresh token' do
        result = client.refresh_token(refresh_token)
        expect(result.refresh_token).to eq('new_refresh_token')
      end

      it 'returns expires_in' do
        result = client.refresh_token(refresh_token)
        expect(result.expires_in).to eq(3600)
      end

      it 'calculates expires_at' do
        result = client.refresh_token(refresh_token)
        expect(result.expires_at).to be_within(5).of(Time.now.to_i + 3600)
      end

      it 'includes raw response' do
        result = client.refresh_token(refresh_token)
        expect(result.raw_response).to eq(success_response)
      end

      it 'sends Basic auth header' do
        client.refresh_token(refresh_token)

        expected_auth = Base64.strict_encode64('test_client_id:test_client_secret')
        expect(WebMock).to have_requested(:post, token_url)
          .with(headers: { 'Authorization' => "Basic #{expected_auth}" })
      end

      it 'sends grant_type in body' do
        client.refresh_token(refresh_token)

        expect(WebMock).to have_requested(:post, token_url)
          .with(body: /grant_type=refresh_token/)
      end
    end

    context 'when refresh fails with invalid_grant' do
      before do
        stub_request(:post, token_url)
          .to_return(
            status: 400,
            body: { 'error' => 'invalid_grant', 'error_description' => 'Token is invalid or expired' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns failure' do
        result = client.refresh_token(refresh_token)
        expect(result).to be_failure
      end

      it 'includes the error description' do
        result = client.refresh_token(refresh_token)
        expect(result.error).to eq('Token is invalid or expired')
      end
    end

    context 'when refresh fails with non-JSON response' do
      before do
        stub_request(:post, token_url)
          .to_return(
            status: 500,
            body: 'Internal Server Error',
            headers: { 'Content-Type' => 'text/plain' }
          )
      end

      it 'returns failure with body as error' do
        result = client.refresh_token(refresh_token)
        expect(result).to be_failure
        expect(result.error).to eq('Internal Server Error')
      end
    end

    context 'when network error occurs' do
      before do
        stub_request(:post, token_url)
          .to_raise(Faraday::ConnectionFailed.new('Connection refused'))
      end

      it 'returns failure with network error' do
        result = client.refresh_token(refresh_token)
        expect(result).to be_failure
        expect(result.error).to include('Network error')
      end
    end
  end

  describe OmniAuth::QuickbooksOauth2Modern::TokenClient::TokenResult do
    describe '#success?' do
      it 'returns true for successful result' do
        result = described_class.new(success: true, access_token: 'token')
        expect(result.success?).to be true
      end

      it 'returns false for failed result' do
        result = described_class.new(success: false, error: 'error')
        expect(result.success?).to be false
      end
    end

    describe '#failure?' do
      it 'returns false for successful result' do
        result = described_class.new(success: true, access_token: 'token')
        expect(result.failure?).to be false
      end

      it 'returns true for failed result' do
        result = described_class.new(success: false, error: 'error')
        expect(result.failure?).to be true
      end
    end
  end
end
