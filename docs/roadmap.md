# Feuille de route vers la v1

La v1 est la première version publique : un assistant RAG auto-hébergé avec
citations, contrôle d'accès par utilisateur, une petite couche d'agents, une
qualité et des performances mesurées, et un déploiement documenté et
reproductible. Elle sert aussi de base aux installations réalisées pour des
entreprises.

La suite après la v1 est décrite dans la
[feuille de route à long terme](roadmap-long-term.md).

## Principes

- **D'abord une tranche verticale.** Un chemin complet minimal (modèle,
  recherche, évaluation) passe avant toute optimisation, pour que chaque
  changement suivant soit mesuré par rapport à une référence.
- **Mesuré, pas affirmé.** Chaque score ou mesure de ce dépôt vient d'un script
  de ce dépôt.
- **La sécurité dès le premier jalon.** Authentification, contrôle d'accès et
  isolation des outils sont intégrés au fur et à mesure que chaque couche est
  ajoutée, pas rajoutés à la fin.
- **Toujours présentable.** Chaque pull request garde l'état du README exact.
- **Reproductible ailleurs.** Ce qui tourne dans le homelab doit pouvoir être
  réinstallé sur une autre infrastructure à partir du dépôt.

## Jalons

| Jalon | Périmètre | État |
|---|---|---|
| M0 Fondations | Règles du dépôt, feuille de route, architecture, décisions d'architecture, cas d'usage | En revue |
| M1 Service des modèles | Moteurs d'inférence derrière une passerelle authentifiée compatible OpenAI | En cours |
| M2 Recherche | RAG hybride avec citations, contrôle d'accès par utilisateur, ingestion asynchrone | Pas commencé |
| M3 Mesure | Banc d'évaluation, observabilité, mesures matérielles | Pas commencé |
| M4 Agents | Planificateur, exécutant et relecteur avec contrats JSON et outils restreints | Pas commencé |
| M5 Sécurité et exploitation | Durcissement, tests de sécurité, infrastructure as code, sauvegarde et restauration | Pas commencé |
| M6 Publication | v1.0.0 | Pas commencé |

### M0 Fondations

- Règles du dépôt : licence, politique de sécurité, guide de contribution, CI
  avec recherche de secrets.
- Cette feuille de route, l'[architecture](architecture.md) et les
  [décisions d'architecture](adr/).
- [Cas d'usage et corpus](use-case.md) : problème, utilisateurs, données,
  critères de réussite.

**Terminé quand** le cas d'usage est confirmé et que l'architecture en tient
compte.

### M1 Service des modèles

- Noyau de l'hôte épinglé, pilote NVIDIA sur l'hôte, un conteneur LXC par GPU
  ([ADR 0007](adr/0007-one-lxc-per-gpu.md)).
- llama.cpp compilé depuis une version épinglée ; `llama-server` sert le
  modèle principal sur la RTX 3090, les modèles d'embeddings et de reranking
  sur la RTX 3060, et un petit modèle sur CPU
  ([ADR 0006](adr/0006-llama-server-runtime.md)).
- Limite de puissance de la RTX 3090 appliquée au démarrage ; `llama-bench`
  mesuré à plusieurs limites.
- Passerelle Caddy avec TLS mutuel, un certificat et une clé par client, et
  aucun point d'accès sans authentification
  ([ADR 0008](adr/0008-gateway-caddy-mtls.md)).
- Un profil Docker Compose pour qui n'a pas de GPU, avec le même moteur.

**Terminé quand** un client muni d'un certificat valide peut discuter avec le
modèle à travers la passerelle, qu'un client sans certificat est refusé, et
qu'un smoke test tourne en CI sur le profil CPU.

### M2 Recherche

- Ingestion du corpus avec découpage et embeddings configurables.
- Recherche hybride (vectorielle et plein texte, fusionnées par *reciprocal
  rank fusion*), puis un reranker ([ADR 0004](adr/0004-retrieval-store.md)).
- Les réponses citent leurs sources.
- Un point d'accès compatible OpenAI, utilisé par Open WebUI comme modèle.
- **Contrôle d'accès par utilisateur** appliqué dans la requête de recherche
  elle-même, avec l'identité de l'utilisateur transmise depuis l'interface.
- Ingestion asynchrone, versionnement des documents par empreinte du contenu,
  et stratégie de réindexation.

**Terminé quand** des tests automatisés montrent qu'un utilisateur n'obtient
jamais un extrait d'un document qu'il n'a pas le droit de lire, et que chaque
réponse porte des citations.

### M3 Mesure

- Un jeu de référence d'au moins 50 questions, écrites et vérifiées à la main.
- `make eval` : les métriques de recherche (recall@k, MRR, nDCG) tournent en
  CI ; les métriques de génération (fidélité, pertinence de la réponse,
  exactitude des citations) tournent dans le homelab, et les résultats sont
  versionnés avec le commit, le modèle et les réglages utilisés.
- Traces par requête ; métriques de latence, délai jusqu'au premier jeton,
  jetons par seconde, taux d'erreur, utilisation et mémoire des GPU ; tableaux
  de bord Grafana et alertes de base exportés dans `observability/`.
- Mesures dans `benchmarks/` : vitesse de génération et de traitement du
  prompt pour plusieurs tailles de contexte et limites de puissance, délai
  jusqu'au premier jeton, VRAM, consommation, coût par million de jetons
  comparé à une API dans le cloud, et vLLM comme référence sous charge
  concurrente.

**Terminé quand** le README affiche de vrais scores et de vraies mesures,
chacun reproductible par une commande documentée.

### M4 Agents

- Un orchestrateur qui délègue à un planificateur, un exécutant et un
  relecteur.
- Des contrats JSON entre agents, validés par des schémas typés.
- Une liste d'autorisation d'outils par agent, avec le moindre privilège.
- Un journal d'exécution par lancement.
- Une comparaison avec un RAG simple sur le jeu de référence, en qualité et en
  latence.

**Terminé quand** la couche d'agents n'est gardée que là où elle améliore les
réponses de façon mesurable, et que le compromis est documenté.

### M5 Sécurité et exploitation

- Reverse proxy avec TLS et authentification devant chaque point d'accès ;
  gestion des secrets ; journaux d'audit des accès et des appels d'outils.
- `docs/security.md` : modèle de menace, mesures en place, correspondance avec
  l'OWASP Top 10 for LLM Applications et, quand c'est pertinent, avec le guide
  d'hygiène informatique et le ReCyF de l'ANSSI.
- Suites de tests pour l'injection de prompt (directe, et indirecte par des
  documents piégés) et pour les fuites de données entre utilisateurs.
- Terraform pour les machines virtuelles et Ansible pour la configuration et
  le déploiement, dans `infra/`.
- Documentation réseau : zones, matrice des flux et règles de pare-feu
  (anonymisées).
- Sauvegarde, et restauration automatisée dans un environnement neuf.

**Terminé quand** les tests de sécurité tournent en CI avec des résultats
documentés, et qu'une restauration reproduit les mêmes scores de recherche que
l'original.

### M6 Publication

- README avec schéma d'architecture, captures d'écran ou démonstration
  enregistrée, et les chiffres mesurés.
- Démarrage rapide testé depuis un clone neuf sur une machine sans GPU.
- Étiquette `v1.0.0`.

## Piste parallèle : boucle de travail déléguée

Une méthode de développement, pas un jalon du produit. Des modèles locaux
planifient et vérifient, un exécutant distant produit des correctifs, et des
vérifications déterministes tranchent. Elle est décrite dans
[la boucle de travail déléguée](delegated-loop.md) et consignée dans
l'[ADR 0009](adr/0009-delegated-worker-loop.md).

| Date | Étape |
|---|---|
| 2026-10-24 | Boucle v0 fonctionnelle de bout en bout |
| 2026-10-24 au 2026-10-28 | Lancement mesuré sur de vraies tâches |
| 2026-10-28 | Revue des mesures et décision sur la suite |

Travaux liés : supervision (journal, canal entre modèles, Telegram), plan de
contrôle, recherche dans les dépôts git, et socle du dépôt avec revue par
d'autres agents. Ils sont suivis dans les tickets #3 à #7.

## Séquence des pull requests

| # | Branche | Jalon | Périmètre |
|---|---|---|---|
| 1 | `chore/repo-foundation` | M0 | Licence, fichiers communautaires, CI, documentation, cas d'usage |
| 2 | `feat/inference-gateway` | M1 | Conteneurs GPU, llama.cpp, limite de puissance, smoke tests (fusionnée, PR #9) |
| 2 bis | `docs/fr-anssi-nis2` | M0 | Documentation en français, cas d'usage ANSSI et NIS 2 |
| 2 ter | `feat/gateway-caddy` | M1 | Caddy avec TLS mutuel, profil Compose CPU, smoke test en CI |
| 3 | `feat/rag-baseline` | M2 | Ingestion, recherche hybride, reranker, citations, Open WebUI |
| 4 | `feat/eval-harness` | M3 | Jeu de référence, `make eval`, premiers scores |
| 5 | `feat/access-control` | M2 | Droits d'accès des documents, transmission de l'identité, tests de fuite |
| 6 | `feat/async-ingestion` | M2 | Ingestion asynchrone, versionnement, réindexation |
| 7 | `feat/observability` | M3 | Traces, métriques, tableaux de bord, alertes |
| 8 | `bench/inference` | M3 | Mesures matérielles et comparaison des coûts |
| 9 | `feat/agent-orchestrator` | M4 | Agents, contrats, liste d'autorisation des outils, comparaison |
| 10 | `security/hardening-tests` | M5 | Proxy, authentification, secrets, journaux d'audit, tests de sécurité |
| 11 | `infra/iac-network` | M5 | Terraform, Ansible, documentation réseau |
| 12 | `ops/backup-restore` | M5 | Sauvegarde et test de restauration automatisé |
| 13 | `docs/v1-release` | M6 | README final et publication |

Le banc d'évaluation (4) arrive juste après la référence (3) pour que chaque
changement suivant soit mesuré. Les mesures matérielles (8) ne dépendent que
du service des modèles (2) et peuvent avancer en parallèle.

## Après la v1

- **Variante cloud** : la même application avec un service de modèles géré,
  et `docs/local-vs-cloud.md` qui compare coût, latence, confidentialité des
  données, souveraineté et effort de maintenance.
- **Kubernetes** : un déploiement k3s avec un chart Helm simple.

## Définition de « terminé » pour la v1

- Quelqu'un qui n'a jamais vu le projet peut le cloner, suivre le démarrage
  rapide et obtenir un chat RAG qui fonctionne.
- Le README contient un schéma d'architecture, des captures d'écran et de vrais
  chiffres : scores RAG, latence et jetons par seconde.
- Le jeu de référence et le script d'évaluation se lancent en une commande, et
  en CI.
- Les tests de sécurité (injection de prompt, isolation entre utilisateurs)
  sont documentés avec leurs résultats.
- Les droits d'accès par utilisateur sont appliqués dans la recherche.
- Une sauvegarde et une restauration ont été testées.
- Aucun secret dans l'historique git, vérifié en CI.
