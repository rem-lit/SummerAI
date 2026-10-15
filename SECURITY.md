# Security Policy

SummerAI is a personal project in early development. Security is a core
design goal (see [`docs/architecture.md`](docs/architecture.md) and, once
published, `docs/security.md`), and reports are welcome.

## Supported versions

There is no stable release yet. Only the `main` branch receives fixes.

| Version | Supported |
|---|---|
| `main` | Yes |
| Anything else | No |

## Reporting a vulnerability

Please **do not open a public issue** for a security problem.

Use GitHub's private reporting instead: open the repository's **Security** tab,
then **Report a vulnerability**. Include:

- the affected component, file or configuration;
- steps to reproduce, or a proof of concept;
- the impact you expect (data exposure, privilege escalation, prompt injection
  leading to an unintended tool call, and so on).

You can expect an acknowledgement within 7 days. Confirmed issues are fixed on
`main` and credited in the changelog unless you prefer to stay anonymous.

## Scope

In scope: the code, container definitions, infrastructure-as-code and
documentation in this repository, including prompt-injection and cross-user
data-leakage issues in the retrieval and agent layers.

Out of scope: the author's own network and hosts. Do not scan or attack them;
the infrastructure described in the documentation is not exposed to the
internet.
