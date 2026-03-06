# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Structure for Python unit tests (`pronto-libs/tests/`)
- Pytest configuration with fixtures (`conftest.py`)
- Unit tests for validation utilities (`test_validation.py`)

### Changed
- Improved error handling and logging across multiple modules
- Enhanced TypeScript type definitions in global.d.ts
- Refactored duplicate code in orders-board.ts

### Fixed
- Critical bug in auth.py where datetime result was not assigned
- Missing null checks in API response handling
- Silent exception handlers replaced with proper logging
- Inconsistent imports moved to module level
- Removed unnecessary `!important` CSS declarations
- Fixed watcher deep option in DataTable.vue

### Security
- CSP configuration hardened with version pinning
- Added proper error handling to prevent information leakage

## [1.0.0] - 2024-02-02

### Added
- Initial project structure
- Core authentication modules
- Order management system
- Employee and client interfaces
- Real-time notifications with Redis

### Features
- Multi-role authentication (admin, waiter, chef, cashier)
- Order workflow management
- Session/table management
- Payment processing integration
- Menu and product catalog

### Backend
- Flask-based API with SQLAlchemy
- JWT authentication
- Redis for real-time events
- PostgreSQL database

### Frontend
- Vue 3 components
- TypeScript support
- Responsive design

[Unreleased]: https://github.com/anomalyco/pronto/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/anomalyco/pronto/releases/tag/v1.0.0
