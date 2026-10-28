# 4. PostgreSQL avec pgvector comme stockage de la recherche documentaire

- **Statut :** Acceptée
- **Date :** 2026-10-13, révisée le 2026-10-15

## Contexte

La recherche documentaire de la v1 a besoin :

- d'une recherche vectorielle et d'une recherche par mots-clés, combinées
  (recherche hybride) ;
- de documents, de versions et de fragments (chunks) cohérents entre eux ;
- d'un contrôle d'accès par utilisateur appliqué **avant** le classement des
  résultats, pour qu'un document interdit ne puisse jamais atteindre le
  modèle ;
- d'une procédure de sauvegarde et de restauration assez simple pour être
  testée régulièrement.

Le corpus d'un déploiement en homelab est petit : bien moins d'un million de
fragments.

## Décision

Utiliser **PostgreSQL avec l'extension pgvector** comme unique stockage de la
recherche documentaire :

- les embeddings dans une colonne `vector` avec un index HNSW ;
- la recherche par mots-clés avec la recherche plein texte de PostgreSQL ;
- les résultats des deux fusionnés par reciprocal rank fusion, puis passés au
  reranking ;
- les documents, versions, fragments et droits d'accès dans la même base,
  écrits dans une seule transaction à l'ingestion ;
- les droits d'accès appliqués dans la clause `WHERE` de la requête de
  recherche, avec la sécurité au niveau des lignes (row-level security) de
  PostgreSQL comme seconde couche.

## Conséquences

- Un seul service à état à exploiter, sécuriser, sauvegarder et restaurer.
- Le contrôle d'accès et la recherche ne peuvent pas diverger : c'est la même
  requête.
- Le classement plein texte de PostgreSQL n'est pas du BM25. Si l'évaluation
  montre que la recherche par mots-clés est trop faible, la première option
  est [pg_textsearch](https://github.com/timescale/pg_textsearch), une
  extension BM25 sous licence PostgreSQL qui réutilise les configurations
  intégrées `english` et `french`. ParadeDB et VectorChord-bm25 sont sous
  AGPL.
- La recherche vectorielle filtrée s'appuie sur les parcours d'index itératifs
  de pgvector (`hnsw.iterative_scan`, depuis la 0.8.0) ; sans eux, un filtre
  sélectif renvoie trop peu de résultats.
- La sécurité au niveau des lignes est imposée avec
  `FORCE ROW LEVEL SECURITY`, et le rôle applicatif n'est ni propriétaire des
  tables ni autorisé à la contourner.
- À bien plus grande échelle, une base vectorielle dédiée pourrait devenir
  nécessaire.

## Options envisagées

- **Qdrant** : BM25 natif avec racinisation en français et en anglais, fusion
  intégrée et filtrage à l'intérieur de l'index vectoriel. Mais l'autorisation
  s'arrête au niveau de la collection : les droits par document dépendent donc
  de l'application, qui doit ajouter un filtre à chaque requête ; la
  configuration open source par défaut n'a ni authentification ni TLS ; les
  snapshots sont une sauvegarde à part, sans transaction partagée avec les
  métadonnées ; et ses chemins de snapshot et d'upload ont fait l'objet de
  plusieurs avis de sécurité
  ([avis de sécurité de Qdrant](https://github.com/qdrant/qdrant/security/advisories)).
- **OpenSearch ou Elasticsearch** : recherche par mots-clés solide, mais
  lourds à faire tourner dans un homelab.
- **Stockages embarqués (Chroma, LanceDB)** : simples pour démarrer, plus
  faibles sur l'accès concurrent, le contrôle d'accès et l'exploitation.
