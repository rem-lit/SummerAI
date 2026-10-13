# Contributing

SummerAI is primarily a personal portfolio project, but issues and suggestions
are welcome. This file describes how changes are made, so the history stays
easy to review.

## Workflow

1. One branch and one pull request per piece of work. Branch names use the
   pattern `<type>/<short-description>`, for example `feat/rag-baseline` or
   `docs/architecture`.
2. Commits follow [Conventional Commits](https://www.conventionalcommits.org/):
   `feat:`, `fix:`, `docs:`, `chore:`, `ci:`, `refactor:`, `test:`, `perf:`.
3. Every pull request fills in the template, passes CI and updates
   [`CHANGELOG.md`](CHANGELOG.md) under *Unreleased*.

## Local checks

Install [pre-commit](https://pre-commit.com/) once, then enable the hooks:

```bash
pipx install pre-commit   # or: uv tool install pre-commit
pre-commit install
pre-commit run --all-files
```

The hooks run the same checks as CI: formatting, Markdown lint and a secret
scan.

## Rules

- **No secrets in the repository**, ever. Configuration goes through
  environment variables, with a committed `.env.example` that holds names and
  safe defaults only.
- **No unmeasured numbers.** Every benchmark result or evaluation score in the
  documentation must come from a script in this repository, together with the
  commit, model, hardware and settings used to produce it.
- **Public text is in English**: code, comments, documentation and commit
  messages.
- **Infrastructure details are sanitised** before being published: no public
  IP addresses, serial numbers, credentials, configuration dumps or exact
  firmware builds.
