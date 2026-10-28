# Politique de sécurité

SummerAI est un projet personnel en début de développement. La sécurité est
un objectif central de la conception (voir
[`docs/architecture.md`](docs/architecture.md) et, une fois publié,
`docs/security.md`), et les signalements sont les bienvenus.

## Versions prises en charge

Il n'y a pas encore de version stable. Seule la branche `main` reçoit des
correctifs.

| Version | Prise en charge |
|---|---|
| `main` | Oui |
| Toute autre version | Non |

## Signaler une vulnérabilité

Merci de **ne pas ouvrir d'issue publique** pour un problème de sécurité.

Utiliser plutôt le signalement privé de vulnérabilité de GitHub : ouvrir
l'onglet **Security** du dépôt, puis **Report a vulnerability**. Inclure :

- le composant, le fichier ou la configuration concernés ;
- les étapes pour reproduire, ou une preuve de concept ;
- l'impact attendu (exposition de données, élévation de privilèges, injection
  de prompt menant à un appel d'outil non voulu, etc.).

Vous pouvez attendre un accusé de réception sous 7 jours. Les problèmes
confirmés sont corrigés sur `main` et crédités dans le journal des
modifications, sauf si vous préférez rester anonyme.

## Périmètre

Dans le périmètre : le code, les définitions de conteneurs,
l'infrastructure as code et la documentation de ce dépôt, y compris les
problèmes d'injection de prompt et de fuite de données entre utilisateurs dans
les couches de recherche documentaire et d'agents.

Hors périmètre : le réseau et les hôtes de l'auteur. Ne pas les scanner ni les
attaquer ; l'infrastructure décrite dans la documentation n'est pas exposée à
Internet.
