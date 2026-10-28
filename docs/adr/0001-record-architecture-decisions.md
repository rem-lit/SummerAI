# 1. Consigner les décisions d'architecture

- **Statut :** Acceptée
- **Date :** 2026-10-13

## Contexte

SummerAI réunit le service des modèles, la recherche documentaire, les agents,
l'observabilité et l'infrastructure. Les choix faits dans un domaine
contraignent les autres, et leurs raisons s'oublient vite.

## Décision

Les décisions importantes sont consignées sous forme de courtes décisions
d'architecture (ADR) dans `docs/adr/`, selon le format de Michael Nygard :
contexte, décision, conséquences. Les ADR sont numérotées et jamais
supprimées ; une décision qui change fait l'objet d'une nouvelle ADR qui
remplace l'ancienne.

## Conséquences

- Chaque ADR explique le *pourquoi*, ce que le code seul ne peut pas faire.
- Relire les décisions avant un jalon prend peu de temps.
- Une ADR doit être écrite ou mise à jour dans la même pull request (PR) que
  le changement qu'elle décrit.
