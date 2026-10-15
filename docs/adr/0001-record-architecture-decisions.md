# 1. Record architecture decisions

- **Status:** Accepted
- **Date:** 2026-10-13

## Context

SummerAI combines model serving, retrieval, agents, observability and
infrastructure. Choices in one area constrain the others, and the reasons
behind them are easy to forget.

## Decision

Significant decisions are recorded as short Architecture Decision Records in
`docs/adr/`, following Michael Nygard's format: context, decision,
consequences. Records are numbered and never deleted; a decision that changes
gets a new record that supersedes the old one.

## Consequences

- Each record explains *why*, which the code alone cannot.
- Reviewing the decisions before a milestone is quick.
- A record must be written or updated in the same pull request as the change
  it describes.
