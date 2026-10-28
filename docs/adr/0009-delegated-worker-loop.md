# 9. Boucle de travail déléguée pour le développement

- **Statut :** Proposée
- **Date :** 2026-10-16

## Contexte

Les modèles distants écrivent le code lourd et les longs documents mieux que
les modèles locaux disponibles sur le homelab, mais leur usage est facturé.
Les modèles locaux suffisent pour planifier, vérifier la cohérence et relire.
L'essentiel de l'usage facturé va à du travail qui n'est pas de la
production : explorer un dépôt, résumer des résultats, planifier et discuter.

SummerAI est public et sa promesse produit est que les documents privés ne
quittent jamais la plateforme. Aucun usage d'un modèle distant pendant le
développement ne doit affaiblir cette promesse.

## Décision

- Le développement utilise une **boucle de travail déléguée** : le côté local
  rédige la fiche de tâche et le paquet de contexte, un exécutant distant ne
  renvoie qu'un patch, et des contrôles déterministes tranchent. Git est
  l'état partagé et les exécutants sont sans état. Voir
  [la description](../delegated-loop.md).
- **Les backends se trouvent derrière un adaptateur unique** (CLI sans
  interface, API hébergée compatible OpenAI, `llama-server` local). Un fichier
  `.workers.yaml` par dépôt associe des classes de tâches à des chaînes de
  backends, du moins cher au plus capable, avec des plafonds de tentatives et
  de coût.
- **La boucle est un flux de travail de développement, jamais une partie du
  chemin d'exécution.** Le contenu d'un dépôt ne part vers un exécutant
  distant que si ce dépôt l'autorise ; par défaut, c'est non, et rien du
  corpus de recherche documentaire ni des runbooks confidentiels de
  l'entreprise fictive n'est jamais envoyé.
- **La sortie des exécutants n'est pas fiable.** Les patchs s'exécutent dans
  un conteneur jetable, sans secrets ni accès réseau. Les paquets de contexte
  sont analysés à la recherche de secrets et limités en taille. Aucun patch
  n'est fusionné automatiquement.
- **Chaque tentative est mesurée** et chaque action journalisée. Les chiffres
  publiés viennent du script de rapport de consommation, avec le commit, le
  modèle et les paramètres utilisés.
- Les niveaux de modèles sont choisis selon le **coût mesuré par tâche
  résolue**.

## Conséquences

- L'usage distant se concentre sur la production de code, là où il est le
  plus efficace.
- Le code de l'orchestrateur, les adaptateurs et le contrôle de passage sont
  de nouveaux composants à construire et à tester ; ils sont suivis dans les
  tickets #3 à #7.
- Les conditions d'utilisation, les limites de débit et la conservation des
  données de chaque backend distant doivent être vérifiées avant de s'y fier,
  en particulier pour un usage automatisé.
- La qualité dépend du paquet de contexte. C'est pourquoi un index de
  recherche sur les dépôts fait partie du plan.
- La décision est réexaminée le 2026-10-28 au regard des premières mesures,
  et remplacée si la boucle ne se rentabilise pas.
- La supervision (journal, canal entre modèles, Telegram) et le plan de
  contrôle devraient avoir leurs propres ADR, l'ADR 0010 et l'ADR 0011, quand
  ils seront construits.
