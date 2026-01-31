# frozen_string_literal: true

require "spec_helper"

RSpec.describe OmniAuth::Strategies::QuickbooksOauth2Modern do
  include Rack::Test::Methods

  let(:app) do
    Rack::Builder.new do
      use OmniAuth::Test::PhonySession
      use OmniAuth::Strategies::QuickbooksOauth2Modern, "client_id", "client_secret", sandbox: true
      run ->(env) { [200, { "Content-Type" => "text/plain" }, [env.key?("omniauth.auth").to_s]] }
    end.to_app
  end

  let(:strategy) { described_class.new(app, "client_id", "client_secret") }

  describe "client options" do
    subject(:client_options) { strategy.options.client_options }

    it "has correct site" do
      expect(client_options[:site]).to eq("https://appcenter.intuit.com")
    end

    it "has correct authorize_url" do
      expect(client_options[:authorize_url]).to eq("/connect/oauth2")
    end

    it "has correct token_url" do
      expect(client_options[:token_url]).to eq("https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer")
    end
  end

  describe "default options" do
    it "has correct name" do
      expect(strategy.options.name).to eq(:quickbooks_oauth2_modern)
    end

    it "has sandbox enabled by default" do
      expect(strategy.options.sandbox).to be true
    end

    it "has default scope" do
      expect(strategy.options.scope).to eq("com.intuit.quickbooks.accounting openid profile email")
    end
  end

  describe "sandbox mode" do
    context "when sandbox is true" do
      let(:strategy) { described_class.new(app, "client_id", "client_secret", sandbox: true) }

      it "uses sandbox userinfo URL" do
        expect(strategy.send(:userinfo_url)).to include("sandbox-accounts.platform.intuit.com")
      end
    end

    context "when sandbox is false" do
      let(:strategy) { described_class.new(app, "client_id", "client_secret", sandbox: false) }

      it "uses production userinfo URL" do
        expect(strategy.send(:userinfo_url)).to include("accounts.platform.intuit.com")
        expect(strategy.send(:userinfo_url)).not_to include("sandbox")
      end
    end
  end

  describe "#callback_url" do
    context "with custom redirect_uri" do
      let(:strategy) do
        described_class.new(app, "client_id", "client_secret",
                            redirect_uri: "https://custom.example.com/callback")
      end

      it "uses the custom redirect_uri" do
        expect(strategy.callback_url).to eq("https://custom.example.com/callback")
      end
    end
  end

  describe "info" do
    let(:raw_info) do
      {
        "email" => "user@example.com",
        "givenName" => "John",
        "familyName" => "Doe",
        "phoneNumber" => "555-123-4567"
      }
    end

    before do
      allow(strategy).to receive(:raw_info).and_return(raw_info)
      allow(strategy).to receive(:request).and_return(double(params: { "realmId" => "123456789" }))
    end

    it "includes email" do
      expect(strategy.info[:email]).to eq("user@example.com")
    end

    it "includes first_name" do
      expect(strategy.info[:first_name]).to eq("John")
    end

    it "includes last_name" do
      expect(strategy.info[:last_name]).to eq("Doe")
    end

    it "includes full name" do
      expect(strategy.info[:name]).to eq("John Doe")
    end

    it "includes phone" do
      expect(strategy.info[:phone]).to eq("555-123-4567")
    end

    it "includes realm_id" do
      expect(strategy.info[:realm_id]).to eq("123456789")
    end
  end

  describe "uid" do
    before do
      allow(strategy).to receive(:request).and_return(double(params: { "realmId" => "123456789" }))
    end

    it "uses realmId as uid" do
      expect(strategy.uid).to eq("123456789")
    end
  end

  describe "extra" do
    let(:raw_info) { { "email" => "user@example.com" } }

    before do
      allow(strategy).to receive(:raw_info).and_return(raw_info)
      allow(strategy).to receive(:request).and_return(double(params: { "realmId" => "123456789" }))
    end

    it "includes realm_id" do
      expect(strategy.extra[:realm_id]).to eq("123456789")
    end

    it "includes raw_info" do
      expect(strategy.extra[:raw_info]).to eq(raw_info)
    end
  end

  describe "#openid_scope_requested?" do
    context "when scope includes openid" do
      let(:strategy) do
        described_class.new(app, "client_id", "client_secret",
                            scope: "com.intuit.quickbooks.accounting openid")
      end

      it "returns true" do
        expect(strategy.send(:openid_scope_requested?)).to be true
      end
    end

    context "when scope does not include openid" do
      let(:strategy) do
        described_class.new(app, "client_id", "client_secret",
                            scope: "com.intuit.quickbooks.accounting")
      end

      it "returns false" do
        expect(strategy.send(:openid_scope_requested?)).to be false
      end
    end
  end
end
