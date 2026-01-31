# frozen_string_literal: true

require_relative 'lib/omniauth/quickbooks_oauth2_modern/version'

Gem::Specification.new do |spec|
  spec.name = 'omniauth-quickbooks-oauth2-modern'
  spec.version = OmniAuth::QuickbooksOauth2Modern::VERSION
  spec.authors = ['dan1d']
  spec.email = ['dan@theowner.me']

  spec.summary = 'OmniAuth strategy for QuickBooks Online OAuth 2.0 (OmniAuth 2.0+ compatible)'
  spec.description = 'An OmniAuth strategy for authenticating with QuickBooks Online using OAuth 2.0. ' \
                     'Compatible with OmniAuth 2.0+ and supports both sandbox and production environments ' \
                     'with OpenID Connect userinfo fetching.'
  spec.homepage = 'https://github.com/dan1d/omniauth-quickbooks-oauth2-modern'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'faraday', '>= 1.0', '< 3.0'
  spec.add_dependency 'omniauth', '~> 2.0'
  spec.add_dependency 'omniauth-oauth2', '~> 1.8'

  # Development dependencies
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rack-test', '~> 2.1'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.20'
  spec.add_development_dependency 'simplecov', '~> 0.22'
  spec.add_development_dependency 'webmock', '~> 3.18'
end
