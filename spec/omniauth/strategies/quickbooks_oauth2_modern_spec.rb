# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OmniAuth::Strategies::QuickbooksOauth2Modern do
  include Rack::Test::Methods

  let(:app) do
    Rack::Builder.new do
      use OmniAuth::Test::PhonySession
      use OmniAuth::Strategies::QuickbooksOauth2Modern, 'client_id', 'client_secret', sandbox: true
      run ->(env) { [200, { 'Content-Type' => 'text/plain' }, [env.key?('omniauth.auth').to_s]] }
    end.to_app
  end

  let(:strategy) { described_class.new(app, 'client_id', 'client_secret') }

  describe 'client options' do
    subject(:client_options) { strategy.options.client_options }

    it 'has correct site' do
      expect(client_options[:site]).to eq('https://appcenter.intuit.com')
    end

    it 'has correct authorize_url' do
      expect(client_options[:authorize_url]).to eq('/connect/oauth2')
    end

    it 'has correct token_url' do
      expect(client_options[:token_url]).to eq('https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer')
    end
  end

  describe 'default options' do
    it 'has correct name' do
      expect(strategy.options.name).to eq(:quickbooks_oauth2_modern)
    end

    it 'has sandbox enabled by default' do
      expect(strategy.options.sandbox).to be true
    end

    it 'has default scope' do
      expect(strategy.options.scope).to eq('com.intuit.quickbooks.accounting openid profile email')
    end
  end

  describe 'sandbox mode' do
    context 'when sandbox is true' do
      let(:strategy) { described_class.new(app, 'client_id', 'client_secret', sandbox: true) }

      it 'uses sandbox userinfo URL' do
        expect(strategy.send(:userinfo_url)).to include('sandbox-accounts.platform.intuit.com')
      end

      it 'returns full sandbox userinfo path' do
        expect(strategy.send(:userinfo_url)).to eq('https://sandbox-accounts.platform.intuit.com/v1/openid_connect/userinfo')
      end
    end

    context 'when sandbox is false' do
      let(:strategy) { described_class.new(app, 'client_id', 'client_secret', sandbox: false) }

      it 'uses production userinfo URL' do
        expect(strategy.send(:userinfo_url)).to include('accounts.platform.intuit.com')
        expect(strategy.send(:userinfo_url)).not_to include('sandbox')
      end

      it 'returns full production userinfo path' do
        expect(strategy.send(:userinfo_url)).to eq('https://accounts.platform.intuit.com/v1/openid_connect/userinfo')
      end
    end
  end

  describe '#callback_url' do
    context 'with custom redirect_uri' do
      let(:strategy) do
        described_class.new(app, 'client_id', 'client_secret',
                            redirect_uri: 'https://custom.example.com/callback')
      end

      it 'uses the custom redirect_uri' do
        expect(strategy.callback_url).to eq('https://custom.example.com/callback')
      end
    end

    context 'without custom redirect_uri' do
      before do
        allow(strategy).to receive_messages(full_host: 'https://example.com', script_name: '',
                                            callback_path: '/auth/quickbooks_oauth2_modern/callback')
      end

      it 'builds callback URL from host and path' do
        expect(strategy.callback_url).to eq('https://example.com/auth/quickbooks_oauth2_modern/callback')
      end
    end
  end

  describe 'credentials' do
    let(:access_token) do
      double(
        token: 'access_token_value',
        refresh_token: 'refresh_token_value',
        expires_at: 1_704_067_200,
        expires?: true
      )
    end

    before do
      allow(strategy).to receive(:access_token).and_return(access_token)
    end

    it 'includes token' do
      expect(strategy.credentials['token']).to eq('access_token_value')
    end

    it 'includes refresh_token' do
      expect(strategy.credentials['refresh_token']).to eq('refresh_token_value')
    end

    it 'includes expires_at' do
      expect(strategy.credentials['expires_at']).to eq(1_704_067_200)
    end

    it 'includes expires flag' do
      expect(strategy.credentials['expires']).to be true
    end

    context 'when refresh_token is nil' do
      let(:access_token) do
        double(
          token: 'access_token_value',
          refresh_token: nil,
          expires_at: 1_704_067_200,
          expires?: true
        )
      end

      it 'does not include refresh_token key' do
        expect(strategy.credentials).not_to have_key('refresh_token')
      end
    end

    context 'when expires_at is nil' do
      let(:access_token) do
        double(
          token: 'access_token_value',
          refresh_token: 'refresh_token_value',
          expires_at: nil,
          expires?: false
        )
      end

      it 'does not include expires_at key' do
        expect(strategy.credentials).not_to have_key('expires_at')
      end

      it 'sets expires to false' do
        expect(strategy.credentials['expires']).to be false
      end
    end
  end

  describe 'info' do
    let(:raw_info) do
      {
        'email' => 'user@example.com',
        'givenName' => 'John',
        'familyName' => 'Doe',
        'phoneNumber' => '555-123-4567'
      }
    end

    before do
      allow(strategy).to receive_messages(raw_info: raw_info, request: double(params: { 'realmId' => '123456789' }))
    end

    it 'includes email' do
      expect(strategy.info[:email]).to eq('user@example.com')
    end

    it 'includes first_name' do
      expect(strategy.info[:first_name]).to eq('John')
    end

    it 'includes last_name' do
      expect(strategy.info[:last_name]).to eq('Doe')
    end

    it 'includes full name' do
      expect(strategy.info[:name]).to eq('John Doe')
    end

    it 'includes phone' do
      expect(strategy.info[:phone]).to eq('555-123-4567')
    end

    it 'includes realm_id' do
      expect(strategy.info[:realm_id]).to eq('123456789')
    end

    context 'when only givenName is present' do
      let(:raw_info) { { 'givenName' => 'John' } }

      it 'returns just the first name' do
        expect(strategy.info[:name]).to eq('John')
      end
    end

    context 'when only familyName is present' do
      let(:raw_info) { { 'familyName' => 'Doe' } }

      it 'returns just the last name' do
        expect(strategy.info[:name]).to eq('Doe')
      end
    end

    context 'when neither name is present' do
      let(:raw_info) { { 'email' => 'user@example.com' } }

      it 'returns nil for name' do
        expect(strategy.info[:name]).to be_nil
      end
    end
  end

  describe 'uid' do
    before do
      allow(strategy).to receive(:request).and_return(double(params: { 'realmId' => '123456789' }))
    end

    it 'uses realmId as uid' do
      expect(strategy.uid).to eq('123456789')
    end

    context 'when realmId is missing' do
      before do
        allow(strategy).to receive(:request).and_return(double(params: {}))
      end

      it 'returns nil' do
        expect(strategy.uid).to be_nil
      end
    end
  end

  describe 'extra' do
    let(:raw_info) { { 'email' => 'user@example.com' } }

    before do
      allow(strategy).to receive_messages(raw_info: raw_info, request: double(params: { 'realmId' => '123456789' }))
    end

    it 'includes realm_id' do
      expect(strategy.extra[:realm_id]).to eq('123456789')
    end

    it 'includes raw_info' do
      expect(strategy.extra[:raw_info]).to eq(raw_info)
    end
  end

  describe '#raw_info' do
    let(:userinfo_response) do
      {
        'sub' => 'user-uuid',
        'email' => 'user@example.com',
        'givenName' => 'John',
        'familyName' => 'Doe'
      }
    end

    context 'when openid scope is requested' do
      let(:access_token) { double }
      let(:response) { double(body: userinfo_response.to_json) }

      before do
        allow(strategy).to receive(:access_token).and_return(access_token)
        allow(access_token).to receive(:get).and_return(response)
      end

      it 'fetches user info from userinfo endpoint' do
        expect(access_token).to receive(:get).with('https://sandbox-accounts.platform.intuit.com/v1/openid_connect/userinfo')
        strategy.raw_info
      end

      it 'returns parsed user info' do
        expect(strategy.raw_info).to eq(userinfo_response)
      end

      it 'caches the result' do
        expect(access_token).to receive(:get).once.and_return(response)
        strategy.raw_info
        strategy.raw_info
      end
    end

    context 'when openid scope is not requested' do
      let(:strategy) do
        described_class.new(app, 'client_id', 'client_secret',
                            scope: 'com.intuit.quickbooks.accounting')
      end

      it 'returns empty hash' do
        expect(strategy.raw_info).to eq({})
      end
    end

    context 'when userinfo fetch fails' do
      let(:access_token) { double }

      before do
        allow(strategy).to receive(:access_token).and_return(access_token)
        allow(access_token).to receive(:get).and_raise(StandardError.new('Network error'))
        allow(strategy).to receive(:log)
      end

      it 'returns empty hash' do
        expect(strategy.raw_info).to eq({})
      end

      it 'logs the error' do
        expect(strategy).to receive(:log).with(:error, 'Failed to fetch userinfo: Network error')
        strategy.raw_info
      end
    end
  end

  describe '#openid_scope_requested?' do
    context 'when scope includes openid' do
      let(:strategy) do
        described_class.new(app, 'client_id', 'client_secret',
                            scope: 'com.intuit.quickbooks.accounting openid')
      end

      it 'returns true' do
        expect(strategy.send(:openid_scope_requested?)).to be true
      end
    end

    context 'when scope does not include openid' do
      let(:strategy) do
        described_class.new(app, 'client_id', 'client_secret',
                            scope: 'com.intuit.quickbooks.accounting')
      end

      it 'returns false' do
        expect(strategy.send(:openid_scope_requested?)).to be false
      end
    end

    context 'when scope is nil' do
      let(:strategy) do
        s = described_class.new(app, 'client_id', 'client_secret')
        allow(s.options).to receive(:[]).with(:scope).and_return(nil)
        s
      end

      it 'returns false' do
        expect(strategy.send(:openid_scope_requested?)).to be false
      end
    end

    context 'when openid is part of another scope name' do
      let(:strategy) do
        described_class.new(app, 'client_id', 'client_secret',
                            scope: 'com.intuit.quickbooks.accounting openidconnect')
      end

      it 'returns false (exact match required)' do
        expect(strategy.send(:openid_scope_requested?)).to be false
      end
    end
  end
end
