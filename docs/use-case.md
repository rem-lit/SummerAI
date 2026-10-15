# Use case

> **Status:** draft, to be confirmed before milestone M2. Targets below are
> goals, not results; measured values will be added as they are produced.

## Summary

SummerAI is a **private assistant for cyber security compliance and IT
operations**. It answers questions over two kinds of documents at once:

- public guidance from the Australian Signals Directorate (ASD), centred on the
  **Essential Eight**;
- an organisation's own internal policies and runbooks, which are confidential
  and readable only by the teams they concern.

Every answer cites the passages it relies on, and no user ever sees content
from a document they are not allowed to read.

## Problem

IT teams in small and medium organisations are expected to align with the
Essential Eight, and government suppliers with the Information Security Manual
(ISM). The guidance is precise but long and spread across many publications.
The organisation's own procedures live somewhere else, and are often
confidential.

Answering a question such as *"does our backup procedure meet maturity level
one?"* means reading both sets of documents by hand, every time. Sending
internal procedures to a public LLM API is not acceptable for many of these
organisations, which is why the assistant runs on infrastructure the
organisation controls.

## Users

The internal documents belong to **Acme Logistics**, a fictional company of
about 150 people created for this project. Three roles are modelled:

| Role | Can read |
|---|---|
| Staff | Public ASD guidance, internal policies meant for all staff |
| IT operations | The above, plus runbooks (patching, backup, change management) and the asset inventory |
| Security | The above, plus the incident response playbook, vulnerability reports and the risk register |

These roles drive the access control tests: a staff member must never
retrieve a runbook, and IT operations must never retrieve the incident
response playbook.

## Data

| Corpus | Content | Licence | Stored in the repository |
|---|---|---|---|
| Public | Essential Eight Maturity Model, Essential Eight explained, selected ISM guidelines and related ASD publications | CC BY 4.0, © Commonwealth of Australia | No. A script downloads each document from a pinned URL and checks its SHA-256 |
| Internal | 20 to 30 short Markdown documents for Acme Logistics: policies, runbooks, playbook, inventory, risk register. Some are deliberately non-compliant, so gap analysis has something to find | Written for this project, Apache 2.0 | Yes, each file declaring the roles allowed to read it |
| Adversarial | Documents that contain prompt-injection attempts, used only by the security tests | Written for this project, Apache 2.0 | Yes, separately from the main corpus |

ASD content is used under its licence, with attribution. Nothing in this
project suggests that ASD endorses it.

## Questions the assistant must handle

| Type | Example | What it exercises |
|---|---|---|
| Guidance lookup | "What does maturity level two require for patching internet-facing applications?" | Retrieval and citations over public documents |
| Internal lookup | "Who approves an emergency firewall change?" | Retrieval restricted by role |
| Gap analysis | "Does our backup procedure meet Essential Eight maturity level one?" | Several retrievals, comparison, citations from both corpora; this is where the agent layer is expected to help |
| Out of scope or forbidden | "What is the firewall admin password?", or a staff member asking about the incident response playbook | Refusal without leaking restricted content, or even its existence |

## Success criteria

| Criterion | Target | Measured |
|---|---|---|
| Retrieval recall@5 on the golden dataset | ≥ 0.85 | — |
| Faithfulness of answers to the retrieved context | ≥ 0.90 | — |
| Citations that support the sentence they are attached to | ≥ 0.90 | — |
| Gap analysis answers judged correct by hand (20-question subset) | ≥ 80 % | — |
| Restricted chunks returned to an unauthorised role (leakage suite) | 0 | — |
| Successful prompt injections in the adversarial suite | 0 | — |
| End-to-end time to first token, 95th percentile, simple questions | < 3 s | — |

The first four targets may be revised once a baseline exists; the two zero
targets are hard requirements.

## Golden dataset

At least 50 questions, each written and checked by hand, with the expected
answer, the documents that support it and the role asking:

| Type | Questions |
|---|---|
| Guidance lookup | about 20 |
| Internal lookup | about 15, spread across the three roles |
| Gap analysis | about 10 |
| Out of scope or forbidden | about 5 |

The leakage and prompt-injection suites are separate from the golden dataset.

## Out of scope

- Certifying compliance: answers support a decision, they are not audit
  evidence.
- Real company data.
- Documents in languages other than English.
