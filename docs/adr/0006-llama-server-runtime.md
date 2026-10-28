# 6. Le serveur llama.cpp comme seul moteur d'inférence de la v1

- **Statut :** Acceptée
- **Date :** 2026-10-15
- **Remplace :** [ADR 0002](0002-inference-runtimes.md)

## Contexte

- `merlin` a deux cartes Ampere : une RTX 3090 (24 Go) et une RTX 3060
  (8 Go).
- La v1 sert un utilisateur et quelques agents, pas de nombreux utilisateurs
  simultanés. La fiabilité des réponses compte plus que la taille du modèle ;
  l'objectif est d'au moins 20 jetons par seconde en génération.
- Les modèles principaux candidats sont des versions récentes de Qwen
  distribuées en quantifications GGUF, par exemple
  [Qwen3.8-27B](https://huggingface.co/Qwen/Qwen3.8-27B) (dense, Apache 2.0)
  et [Qwen3.6-35B-A3B](https://huggingface.co/Qwen/Qwen3.6-35B-A3B) (mixture
  of experts, 3B paramètres actifs, Apache 2.0).
- La prise en charge de GGUF par vLLM est décrite dans sa propre documentation
  comme « highly experimental and under-optimized » (très expérimentale et
  peu optimisée) et exige désormais un plugin hors de l'arbre principal
  ([documentation GGUF de vLLM](https://docs.vllm.ai/en/latest/features/quantization/gguf.html)).
- Le `llama-server` de llama.cpp sert GGUF nativement, expose l'API OpenAI et
  une API Messages compatible Anthropic
  ([annonce](https://huggingface.co/blog/ggml-org/anthropic-messages-api-in-llamacpp)),
  les embeddings et le reranking, ainsi que des métriques Prometheus.

## Décision

- **`llama-server` fait tourner tous les modèles de la v1**, une carte par
  rôle, sans modèle réparti sur les deux cartes :
  - RTX 3090 : le modèle de langage principal, un seul slot, cache clé-valeur
    quantifié (`q8_0`, jamais `q4_0`) ;
  - RTX 3060 : le modèle d'embeddings et le reranker, chacun dans son propre
    processus `llama-server`, sans quantification du cache clé-valeur.
- Le modèle principal, sa quantification, sa longueur de contexte et ses
  paramètres d'échantillonnage sont choisis avec le banc d'évaluation, pas à
  l'avance. Les valeurs de départ viennent de la fiche du modèle.
- llama.cpp est compilé à partir d'une version épinglée, avec une version de
  CUDA connue pour fonctionner (CUDA 13.2 casse certains types de
  quantification,
  [ticket llama.cpp 21255](https://github.com/ggml-org/llama.cpp/issues/21255)).
- Les fonctions optionnelles (prédiction multi-jetons, budget de
  raisonnement, second profil de modèle via llama-swap) ne sont activées que si
  le banc d'évaluation ne montre aucune régression.
- **vLLM reste une référence de mesure**, pas un moteur de production : la
  même famille de modèles dans une quantification native vLLM, mesurée sur la
  RTX 3090 sous charge concurrente.

## Conséquences

- Un seul slot sur le modèle principal signifie que les requêtes de
  l'interface, des agents et de l'évaluation passent l'une après l'autre.
  C'est acceptable pour la v1 et c'est documenté ; la concurrence deviendrait
  une raison de reconsidérer vLLM.
- La longueur de contexte sur 24 Go est limitée par les poids du modèle et le
  cache clé-valeur. La vitesse de génération est mesurée avec des tailles de
  contexte réalistes, pas seulement avec un contexte vide.
- Le démarrage rapide sur CPU utilise le même moteur avec un petit modèle : la
  configuration est la même partout.
- Jamais activés : le backend RPC, qui a une vulnérabilité critique non
  corrigée, et les fonctions d'outils ou d'agent intégrées à `llama-server`.
  Les modèles ne sont téléchargés que depuis des éditeurs de confiance, car
  l'analyse des fichiers GGUF a connu des bugs de sécurité mémoire
  ([avis de sécurité de llama.cpp](https://github.com/ggml-org/llama.cpp/security/advisories)).

## Options envisagées

- **vLLM comme moteur principal** (ADR 0002) : meilleur sous charge
  concurrente, mais GGUF y est expérimental, et la concurrence n'est pas le
  besoin de la v1.
- **Ollama** : pratique, mais ajoute une couche au-dessus de llama.cpp, avec
  moins de contrôle sur ses paramètres et ses métriques.
- **Répartir un grand modèle sur les deux cartes** : ajoute de la capacité
  mémoire, pas de la vitesse, et supprime la carte dédiée à la recherche
  documentaire.
