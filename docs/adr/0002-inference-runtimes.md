# 2. Moteurs d'inférence : vLLM sur GPU, llama.cpp sur CPU

- **Statut :** Remplacée par l'[ADR 0006](0006-llama-server-runtime.md)
- **Date :** 2026-10-13

## Contexte

- Le homelab dispose d'un seul GPU : une NVIDIA RTX 3090 (24 Go, Ampere,
  compute capability 8.6), dans un hôte équipé d'un Intel Core i5-14400F et de
  32 Go de RAM. L'hyperviseur principal, un Dell R730 avec un Xeon
  E5-2680 v4 et 96 Go de RAM, n'a pas de GPU.
- Les binaires précompilés de vLLM exigent un GPU de compute capability 7.5
  ou plus ([prérequis d'installation de vLLM](https://github.com/vllm-project/vllm/blob/main/docs/getting_started/installation/gpu.cuda.inc.md)).
  Les cartes plus anciennes, comme les GPU de centre de données de génération
  Pascal, ne sont pas prises en charge.
- vLLM offre un débit élevé sur un GPU pris en charge (continuous batching,
  paged attention), mais charge un seul modèle par processus et réserve
  d'emblée l'essentiel de la mémoire du GPU.
- Le démarrage rapide de la v1 doit fonctionner pour quelqu'un qui n'a aucun
  GPU.

## Décision

- **vLLM** sert le modèle principal sur la RTX 3090.
- **llama.cpp** (`llama-server`, modèles GGUF) sert un petit modèle sur CPU.
  C'est le moteur du démarrage rapide et un second profil, peu coûteux, dans
  le homelab. C'est aussi la solution de repli pour tout GPU antérieur à la
  compute capability 7.5.
- La v1 fait tourner **deux ou trois profils**, pas plus : le modèle principal
  sur GPU, le petit modèle sur CPU et, si l'évaluation montre que cela en vaut
  la peine, un service dédié aux embeddings et au reranking.
- Les deux moteurs exposent l'API OpenAI et se trouvent derrière la passerelle
  ([ADR 0003](0003-model-gateway.md)) ; les clients ne les appellent jamais
  directement.

## Conséquences

- Avec une seule carte de 24 Go, un seul modèle vLLM est chargé à la fois.
  Changer de modèle principal implique de redémarrer le service vLLM.
- Le modèle doit tenir dans 24 Go avec son cache KV. Le modèle et la
  quantification sont choisis avec les mesures du jalon M3, pas à l'avance.
- Faire tourner les embeddings et le reranker sur le même GPU implique de
  réduire la part de mémoire réservée par vLLM. Le choix entre ce GPU et le
  CPU se fait sur mesure.
- La passerelle masque aux clients le mélange des moteurs, qui doit lui-même
  être documenté et mesuré.

## Options envisagées

- **vLLM seul** : exclut le démarrage rapide sur les machines sans GPU pris en
  charge.
- **llama.cpp seul** : plus simple, mais débit plus faible sous charge
  concurrente sur la RTX 3090.
- **Ollama** : pratique pour un seul utilisateur, mais son ordonnancement et
  ses métriques se prêtent moins bien à la mesure du débit et de la latence
  sous charge.
- **Versions communautaires de vLLM pour les GPU plus anciens** : non
  officielles, elles compromettraient l'objectif de reproductibilité.
