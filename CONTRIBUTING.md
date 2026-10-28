# Contribuer

SummerAI est un projet personnel, qui sert aussi de vitrine à l'activité de
l'auteur : l'installation d'infrastructures d'IA et de RAG pour les
entreprises. Les issues et les suggestions sont les bienvenues. Ce fichier
décrit comment les changements sont faits, pour que l'historique reste facile
à relire.

## Méthode de travail

1. Une branche et une pull request (PR) par tâche. Les noms de branche suivent
   le format `<type>/<short-description>`, par exemple `feat/rag-baseline` ou
   `docs/architecture`.
2. Les commits suivent [Conventional Commits](https://www.conventionalcommits.org/) :
   `feat:`, `fix:`, `docs:`, `chore:`, `ci:`, `refactor:`, `test:`, `perf:`.
3. Chaque PR remplit le modèle, passe la CI et met à jour
   [`CHANGELOG.md`](CHANGELOG.md) sous *Non publié*.

## Vérifications locales

Installer [pre-commit](https://pre-commit.com/) une fois, puis activer les
hooks :

```bash
pipx install pre-commit   # or: uv tool install pre-commit
pre-commit install
pre-commit run --all-files
```

Les hooks lancent les mêmes vérifications que la CI : formatage, lint Markdown
et recherche de secrets.

## Règles

- **Aucun secret dans le dépôt**, jamais. La configuration passe par des
  variables d'environnement, avec un `.env.example` versionné qui ne contient
  que des noms et des valeurs par défaut sans risque.
- **Aucun chiffre non mesuré.** Chaque résultat de mesure ou score
  d'évaluation de la documentation doit venir d'un script de ce dépôt, avec le
  commit, le modèle, le matériel et les réglages utilisés pour l'obtenir.
- **La documentation, les messages de commit et les pull requests sont en
  français.** Le code, ses commentaires et les messages des scripts restent en
  anglais.
- **Les détails d'infrastructure sont nettoyés** avant publication : pas
  d'adresses IP publiques, de numéros de série, d'identifiants, de copies de
  configuration ni de versions exactes de firmware.
