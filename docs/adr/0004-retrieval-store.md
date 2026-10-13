# 4. PostgreSQL with pgvector as the retrieval store

- **Status:** Accepted
- **Date:** 2026-10-13

## Context

Retrieval in v1 needs:

- vector search and keyword search, combined (hybrid search);
- documents, versions and chunks, kept consistent with each other;
- per-user access control applied **before** results are ranked, so that a
  forbidden document can never reach the model;
- a backup and restore procedure that is simple enough to test regularly.

The corpus of a homelab deployment is small: well under a million chunks.

## Decision

Use **PostgreSQL with the pgvector extension** as the single retrieval store:

- embeddings in a `vector` column with an HNSW index;
- keyword search with PostgreSQL full-text search;
- results of both fused with reciprocal rank fusion, then reranked;
- documents, versions, chunks and access rights in the same database, written
  in one transaction at ingestion;
- access rights applied in the `WHERE` clause of the retrieval query, with
  PostgreSQL row-level security as a second layer.

## Consequences

- One stateful service to operate, secure, back up and restore.
- Access control and retrieval cannot drift apart: they are the same query.
- PostgreSQL's full-text ranking is not BM25. If evaluation shows keyword
  retrieval is too weak, the options are a BM25 extension or sparse vectors;
  the decision will then be revisited with numbers.
- At much larger scale, a dedicated vector database could become necessary.

## Alternatives considered

- **Qdrant**: native hybrid search and payload filtering, but a second
  stateful store next to the relational data, with its own backups and its own
  consistency problem.
- **OpenSearch or Elasticsearch**: strong keyword search, but heavy to run in
  a homelab.
- **Embedded stores (Chroma, LanceDB)**: simple to start with, weaker on
  concurrent access, access control and operations.
