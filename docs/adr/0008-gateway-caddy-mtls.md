# 8. Caddy avec TLS mutuel comme passerelle des modèles

- **Statut :** Acceptée
- **Date :** 2026-10-15
- **Remplace :** [ADR 0003](0003-model-gateway.md)

## Contexte

La passerelle est le seul chemin vers les serveurs de modèles : la conception
**la plus sûre par défaut** l'emporte donc sur les fonctions de confort.

- **LiteLLM** (ADR 0003) est ouvert par défaut : sans clé maîtresse, toute
  requête est acceptée. Son interface d'administration et sa documentation
  d'API sont activées par défaut. En 2026, il a subi une compromission de sa
  chaîne d'approvisionnement sur PyPI (versions 1.82.7 et 1.82.8,
  [compte rendu de l'éditeur](https://docs.litellm.ai/blog/security-update-march-2026))
  et plusieurs avis de sécurité critiques, dont une injection SQL sans
  authentification dans la vérification des clés et un contournement de
  l'authentification vers les routes d'administration
  ([avis de sécurité de LiteLLM](https://github.com/BerriAI/litellm/security/advisories)).
- **`llama-server`** écoute sur `127.0.0.1` par défaut et prend en charge les
  clés d'API (`--api-key-file`). Les contrôles de santé et l'interface web
  intégrée restent sans authentification, et il ne prend pas en charge les
  certificats clients
  ([README du serveur](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md)).
- **Caddy** est un binaire statique unique avec TLS automatique, vérification
  des certificats clients, limites de taille de corps de requête, délais
  d'expiration et authentification déléguée (forward authentication)
  ([documentation de Caddy](https://caddyserver.com/docs/)).
- La v1 a peu de clients, tous connus : Open WebUI, l'orchestrateur, les
  scripts d'évaluation et de mesure.

## Décision

- **Caddy est le seul point d'entrée vers chaque serveur de modèles.**
- **Les clients machines s'authentifient par TLS mutuel**, avec des
  certificats émis par une autorité de certification privée propre au projet,
  un par client. Chaque client envoie aussi sa propre clé d'API, et n'est
  routé que vers les modèles dont il a besoin.
- **Les humains n'utilisent qu'Open WebUI**, derrière le même proxy, avec sa
  propre connexion.
- Sur `merlin`, chaque `llama-server` écoute sur `127.0.0.1` dans son
  conteneur, avec son propre fichier de clé d'API. Une instance Caddy dans
  chaque conteneur est la seule à écouter sur le réseau ; elle n'accepte que
  le certificat client de la passerelle et injecte la clé.
- `llama-server` tourne avec `--no-webui` et sans inspection des slots,
  écriture de propriétés, outils, fonctions d'agent ni backend RPC.
- La taille du corps des requêtes, les délais de réponse et les limites de
  débit sont fixés par client (OWASP LLM10, consommation non bornée).
- Les pare-feu des hôtes n'acceptent que le trafic de la passerelle sur les
  ports des modèles.

## Conséquences

- Aucun composant devant les modèles ne stocke de base de clés ni n'expose
  d'interface d'administration : la surface d'attaque reste réduite.
- Les certificats doivent être émis, renouvelés et révoqués. C'est automatisé
  avec Ansible et documenté dans le runbook d'exploitation.
- Pas de comptabilité d'usage ni de suivi des dépenses intégrés : l'usage
  provient des métriques de `llama-server` et des journaux d'accès de la
  passerelle, ce qui suffit pour une plateforme à un seul opérateur.
- Router vers un modèle cloud dans la variante cloud revient à ajouter une
  route Caddy avec ses propres identifiants vers l'amont.
- Si les clés virtuelles ou les budgets par équipe deviennent un vrai besoin,
  LiteLLM peut être reconsidéré dans une version corrigée, à partir d'une
  image signée, avec son interface d'administration et sa documentation
  désactivées.

## Options envisagées

- **LiteLLM** : riche en fonctions, mais ouvert par défaut et avec une large
  surface d'attaque, et un lourd historique d'avis de sécurité en 2026.
- **Clés d'API de `llama-server` seules** : simple, mais les clés circulent en
  clair sans TLS, et les points d'accès de santé et d'interface restent
  ouverts.
- **llama-swap** : utile pour changer de modèle plus tard, mais ses clés d'API
  sont désactivées par défaut ; s'il est utilisé, il se place derrière Caddy.
- **Envoy AI Gateway** : conçu pour Kubernetes, plus que ce dont la v1 a
  besoin.
