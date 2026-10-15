# 4. PostgreSQL with pgvector as the retrieval store

- **Status:** Accepted
- **Date:** 2026-10-13, revised 2026-10-15

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
  retrieval is too weak, the first option is
  [pg_textsearch](https://github.com/timescale/pg_textsearch), a BM25
  extension under the PostgreSQL licence that reuses the built-in `english`
  and `french` configurations. ParadeDB and VectorChord-bm25 are AGPL.
- Filtered vector search relies on pgvector's iterative index scans
  (`hnsw.iterative_scan`, since 0.8.0); without them, a selective filter
  returns too few results.
- Row-level security is enforced with `FORCE ROW LEVEL SECURITY`, and the
  application role is neither the table owner nor allowed to bypass it.
- At much larger scale, a dedicated vector database could become necessary.

## Alternatives considered

- **Qdrant**: native BM25 with French and English stemming, built-in fusion,
  and filtering inside the vector index. But authorisation stops at the
  collection level, so per-document rights depend on the application adding a
  filter to every query; the open-source defaults have no authentication and
  no TLS; snapshots are a separate backup with no transaction shared with the
  metadata; and its snapshot and upload paths have had several advisories
  ([Qdrant advisories](https://github.com/qdrant/qdrant/security/advisories)).
- **OpenSearch or Elasticsearch**: strong keyword search, but heavy to run in
  a homelab.
- **Embedded stores (Chroma, LanceDB)**: simple to start with, weaker on
  concurrent access, access control and operations.
