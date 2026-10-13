# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- English README with project goals, current status and target architecture.
- v1 roadmap ([`docs/roadmap.md`](docs/roadmap.md)) and architecture document
  ([`docs/architecture.md`](docs/architecture.md)).
- Use case: a private assistant for Essential Eight compliance and IT
  operations, with roles, data, success criteria and golden dataset plan
  ([`docs/use-case.md`](docs/use-case.md)).
- Architecture decision records for the inference runtimes, the model gateway,
  the retrieval store and GPU passthrough to a VM ([`docs/adr/`](docs/adr/)).
- Apache 2.0 licence, security policy, contribution guide and pull request
  template.
- CI workflow (Markdown lint, link check, secret scan over the full history),
  pre-commit hooks and Dependabot updates for GitHub Actions.

### Changed

- The original French roadmap is now an English long-term roadmap
  ([`docs/roadmap-long-term.md`](docs/roadmap-long-term.md)); phases 0 to 5 are
  re-planned in the v1 roadmap.
- `IDEAS.md` moved to [`docs/ideas.md`](docs/ideas.md) and translated.

### Removed

- Empty `docker-compose.yml` and placeholder `.env.example`. Both come back
  with the first deployable services.
