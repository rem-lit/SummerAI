# Journal des modifications

Toutes les modifications notables du projet sont consignées dans ce fichier.

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/), et le
projet suit le [versionnement sémantique](https://semver.org/lang/fr/spec/v2.0.0.html).

## [Non publié]

### Ajouté

- README avec les objectifs du projet, son état actuel et l'architecture
  cible.
- Feuille de route de la v1 ([`docs/roadmap.md`](docs/roadmap.md)) et document
  d'architecture ([`docs/architecture.md`](docs/architecture.md)).
- Cas d'usage avec rôles, données, critères de réussite et plan du jeu de
  référence ([`docs/use-case.md`](docs/use-case.md)).
- Décisions d'architecture ([`docs/adr/`](docs/adr/)) : `llama-server` seul
  moteur d'inférence en v1 (ADR 0006), un conteneur LXC par GPU (ADR 0007),
  Caddy avec TLS mutuel comme passerelle (ADR 0008), PostgreSQL avec pgvector
  (ADR 0004). Les ADR 0002, 0003 et 0005 sont conservées comme remplacées.
- Licence Apache 2.0, politique de sécurité, guide de contribution et modèle
  de pull request.
- Workflow de CI (lint Markdown, vérification des liens, recherche de secrets
  sur tout l'historique), hooks pre-commit et mises à jour Dependabot pour les
  GitHub Actions.
- Description de la boucle de travail déléguée utilisée pour construire le
  projet ([`docs/delegated-loop.md`](docs/delegated-loop.md)), proposition
  d'ADR 0009, et piste parallèle dans la feuille de route.
- Runbook de l'hôte GPU ([`docs/runbooks/gpu-host.md`](docs/runbooks/gpu-host.md)) :
  noyau épinglé, pilote NVIDIA avec DKMS, un conteneur non privilégié par
  carte, llama.cpp compilé depuis une version épinglée, modèles servis par
  `llama-server` en local avec une clé d'API.
- Fichiers de configuration de l'hôte et des conteneurs dans
  [`deploy/merlin/`](deploy/merlin/) : liste noire des pilotes libres, unités
  de persistance et des nœuds de périphériques, unité `llama-server` en bac à
  sable.
- Smoke test d'une instance `llama-server`
  ([`scripts/smoke/llm.sh`](scripts/smoke/llm.sh)) : authentification, alias
  du modèle, réponse avec raisonnement séparé, appel d'outil.
- Mesure de la limite de puissance d'un GPU
  ([`scripts/bench/power-limit.sh`](scripts/bench/power-limit.sh)) avec un
  générateur de graphiques, et les premiers résultats pour la RTX 3090
  ([`benchmarks/power-limit/`](benchmarks/power-limit/)). Une unité de
  démarrage applique la limite choisie.
- Conteneur de recherche sur la RTX 3060 : modèles d'embeddings
  (`Qwen3-Embedding-0.6B`) et de reranking (`Qwen3-Reranker-0.6B`), chacun
  servi par sa propre instance `llama-server`, avec leurs empreintes dans
  [`deploy/merlin/llama/models.sha256`](deploy/merlin/llama/models.sha256).
- Smoke test des modèles de recherche
  ([`scripts/smoke/retrieval.sh`](scripts/smoke/retrieval.sh)) :
  authentification, taille et norme des vecteurs, similarité, ordre du
  reranking.

### Modifié

- Toute la documentation est en français. Le code, ses commentaires et les
  messages des scripts restent en anglais.
- Le cas d'usage de référence devient un assistant de conformité cyber
  appuyé sur le guide d'hygiène informatique et le référentiel ReCyF de
  l'ANSSI (directive NIS 2), à la place de l'Essential Eight australien.
- `llama-server` tourne comme unité modèle, une instance par modèle, avec les
  arguments de chaque instance dans `/etc/llama/<instance>.conf`. L'unité est
  passée de `deploy/merlin/llm/llama-server.service` à
  [`deploy/merlin/llama/llama-server@.service`](deploy/merlin/llama/llama-server@.service).
- Les smoke tests partagent leurs fonctions dans
  [`scripts/smoke/lib.sh`](scripts/smoke/lib.sh), et celui du modèle de
  langage pose ses questions en français, sur le guide d'hygiène de l'ANSSI et
  une CVE.
- La mesure de limite de puissance arrête et relance toutes les instances
  `llama-server` du conteneur.
- La feuille de route d'origine devient la
  [feuille de route à long terme](docs/roadmap-long-term.md) ; les phases 0 à
  5 sont replanifiées dans la feuille de route de la v1.
- `IDEAS.md` est déplacé dans [`docs/ideas.md`](docs/ideas.md).

### Corrigé

- En-tête de tableau en double dans la séquence des pull requests de la
  feuille de route.

### Retiré

- `docker-compose.yml` vide et `.env.example` provisoire. Les deux reviendront
  avec les premiers services déployables.
