# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-01-31

### Added

- TokenClient class for easy token refresh in Rails apps
- `refresh_token` method with result object pattern
- `token_expired?` helper with configurable buffer
- Comprehensive RSpec tests for TokenClient (26 new tests)

## [1.0.0] - 2026-01-31

### Added

- Initial release with OmniAuth 2.0+ compatibility
- Support for QuickBooks Online OAuth 2.0 authentication
- Sandbox and production environment support
- OpenID Connect userinfo fetching for user details
- Automatic realm_id (company ID) extraction
- Comprehensive documentation and examples
