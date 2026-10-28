# Feuille de route à long terme

Ce document conserve la vision d'origine de SummerAI (rédigée d'abord en
français en juillet 2026) et le travail qui vient **après** la publication
publique de la v1. Le périmètre de la v1 lui-même est dans
[`roadmap.md`](roadmap.md).

## Vision cible

L'objectif final est une plateforme où l'utilisateur parle à **un seul agent
orchestrateur**, qui achemine les requêtes vers des services spécialisés de
recherche documentaire, de raisonnement, de relecture et de service de
modèles, et qui déploie des profils de modèles selon la charge et les
ressources GPU disponibles.

## Ce que sont devenues les phases d'origine

| Phase d'origine | Sujet | Aujourd'hui |
|---|---|---|
| 0 | Architecture, rôles, profils de modèles, critères de réussite | v1, jalon M0 |
| 1 | MVP Docker Compose | v1, jalons M1 et M2 |
| 2 | RAG fiable | v1, jalons M2 et M3 |
| 3 | Couche d'agents hiérarchique | v1, jalon M4 |
| 4 | Service multi-profils | La v1 garde 2 à 3 profils (M1) ; le reste est ci-dessous |
| 5 | Observabilité et évaluation | v1, jalon M3 ; le reste est ci-dessous |
| 6 | Préparation à Kubernetes | Axe A |
| 7 | Déploiement k3s | Axe B ; un premier déploiement k3s avec un chart Helm simple suit la v1 |
| 8 | Renfort GPU distant | Axe C |
| 9 | Déploiement dynamique des modèles | Axe D |
| 10 | Durcissement et exploitation | Axe E ; contrôle d'accès (M2), isolation des outils (M4), sauvegardes et segmentation (M5) déplacés dans la v1 |

## Reporté depuis les phases d'origine 0 à 5

Ces éléments faisaient partie du premier plan mais sont hors du périmètre de
la v1 :

- **Quatre profils de service** : `vllm-chat-standard`,
  `vllm-reasoning-medium`, `vllm-review-fast` et `vllm-large-burst`, plus un
  service d'embeddings dédié optionnel. La v1 fait tourner 2 à 3 profils
  derrière la passerelle ([ADR 0002](adr/0002-inference-runtimes.md)).
- **Registre de modèles** : modèles disponibles avec des métadonnées par
  modèle (longueur de contexte, VRAM, latence attendue, coût), utilisé par un
  routeur interne.
- **Rejeu de prompts** : relancer des prompts de production enregistrés sur un
  nouveau modèle ou une nouvelle version de prompt.
- **Métriques de file d'attente** et **scores de qualité des sorties
  d'agents** dans les tableaux de bord.

## Axe A : préparation à Kubernetes

Objectif : préparer la migration vers Kubernetes sans rien casser. Le vrai
intérêt de Kubernetes pour le service de modèles apparaît avec
l'ordonnancement des GPU, la mise à l'échelle automatique, les réplicas
multiples, les pools préchauffés et le routage avancé.

Préparation technique :

- conteneuriser proprement chaque composant ;
- externaliser toute la configuration ;
- rendre les services sans état quand c'est possible ;
- séparer clairement les volumes persistants ;
- séparer les dépendances réseau et les secrets.

Livrables :

- manifestes de base ou charts Helm ;
- conventions de labels et d'annotations ;
- une stratégie de sondes (liveness, readiness, startup) ;
- une stratégie de stockage pour les poids des modèles et les caches.

## Axe B : déploiement k3s

Objectif : faire tourner la plateforme sur k3s dans le homelab, avec
l'orchestration des GPU, une découverte de services plus propre et des
classes de service de modèles.

Fondations :

- k3s (ou kubeadm) ;
- NVIDIA GPU Operator, selon le matériel ;
- ingress ;
- stockage objet persistant ;
- base de données vectorielle persistante ;
- un déploiement de service de modèles par profil ;
- métriques GPU, et mise à l'échelle automatique sur des métriques
  pertinentes.

Résultat attendu :

- plusieurs services de modèles coexistent ;
- le routeur choisit le bon profil ;
- la plateforme redémarre proprement ;
- les caches et les index persistent.

## Axe C : renfort GPU distant

Objectif : ajouter de la capacité GPU à la demande. Le plan de contrôle reste
le même, mais des nœuds ou des pools distants (par exemple des GPU loués) sont
activés au besoin, sans dépendre d'une API LLM propriétaire.

À construire :

- une logique qui suit la capacité disponible ;
- des seuils de déclenchement ;
- un pool préchauffé optionnel ;
- le téléchargement et la mise en cache des poids des modèles ;
- le routage vers un backend distant quand un profil local manque de VRAM.

Points d'attention :

- démarrages à froid des grands modèles ;
- proximité entre stockage et calcul ;
- sécurité réseau des points d'accès distants.

## Axe D : déploiement dynamique des modèles

Objectif : l'orchestrateur ne se contente plus de choisir un modèle déjà en
cours d'exécution ; il peut demander le déploiement d'un profil lourd selon la
charge, le type de requête et les GPU disponibles.

Mécanisme cible :

1. l'orchestrateur classe la requête ;
2. il cherche un profil déjà chaud ;
3. sinon, il déclenche un déploiement ;
4. il attend que le profil soit prêt ;
5. il achemine la requête ;
6. il réduit ensuite les ressources, selon une politique.

## Axe E : durcissement et exploitation à long terme

La sécurité et les sauvegardes commencent dans la v1 et sont renforcées à
chaque étape. Cet axe fait du projet une plateforme d'IA privée durable :
gouvernance, rotation des secrets à grande échelle et maintenance des
modèles.

À couvrir :

- RBAC et segmentation réseau à l'échelle de la plateforme ;
- sauvegardes du stockage vectoriel et du stockage objet, avec des politiques
  de rétention ;
- rotation des secrets ;
- quotas ;
- isolation des outils des agents ;
- une politique de mise à jour des modèles ;
- documentation d'exploitation (runbooks).
