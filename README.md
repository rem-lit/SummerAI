# Vision cible

Le but final est une plateforme où l’utilisateur parle à un **agent orchestrateur** unique, qui route vers des services spécialisés de retrieval, raisonnement, review et serving vLLM, avec déploiement de profils de modèles selon la charge et les ressources GPU disponibles. Pour y arriver sans te noyer, il faut séparer le projet en étapes qui valident chacune une couche technique précise.

## Phase 0

Objectif : cadrer l’architecture et les règles du jeu avant d’écrire la stack. Cette phase doit fixer les profils de modèles, les rôles d’agents, les types de documents à ingérer, les contraintes de sécurité, et les métriques minimales à suivre comme latence, TTFT, throughput, coût électrique/VRAM et qualité RAG.

À produire :

- schéma logique des composants ;
    
- taxonomie des rôles `Orchestrateur / Planning / Execution spécialisé / Review Critique` ;
    
- matrice des profils de modèles `small / medium / large / burst` ;
    
- définition des critères de réussite du MVP.
    

## Phase 1

Objectif : construire le **MVP local en Docker Compose**, sans Kubernetes. La littérature LLMOps recommande de commencer par un système simple mais réel, instrumenté et observable, plutôt que de sauter directement dans une plateforme complexe.

Stack de départ :

- Open WebUI ;
    
- orchestrateur applicatif simple ;
    
- vLLM unique ;
    
- vector DB ;
    
- object storage ;
    
- workers d’ingestion ;
    
- reverse proxy ;
    
- logs et métriques de base.
    

Livrables :

- un chat fonctionnel ;
    
- un endpoint d’inférence vLLM ;
    
- un RAG mono-collection ;
    
- une ingestion manuelle de documents ;
    
- une base de sécurité minimale : secrets hors du repo, sauvegarde du vector store et de l'object storage ;
    
- des logs structurés sur chaque requête.
    

## Phase 2

Objectif : rendre le RAG **fiable**. Les feuilles de route RAG modernes insistent sur le fait qu’un “vector DB + prompt” ne suffit pas ; il faut penser retrieval hybride, chunking, reranking, fraîcheur des données et évaluation.

À ajouter :

- pipeline d’ingestion asynchrone ;
    
- versionnement des documents ;
    
- chunking configurable ;
    
- embeddings séparés ;
    
- reranker ;
    
- stratégie de reindexation ;
    
- observabilité minimale : traces par requête, métriques basiques (latence, taux d'erreur, précision retrieval) ;
    
- golden dataset de questions/réponses pour mesurer la qualité.
    

À valider :

- précision retrieval ;
    
- hallucinations sous contrôle ;
    
- réponse traçable à ses sources ;
    
- performances acceptables avec ton corpus réel.
    

## Phase 3

Objectif : ajouter la **couche agentique hiérarchique**. Les patterns planner-executor-reviewer et les approches hiérarchiques multi-agents montrent qu’il est plus robuste de faire passer toutes les interactions utilisateur par un orchestrateur unique, qui appelle ensuite des rôles spécialisés.

Architecture à viser :

- **Orchestrateur** : interface utilisateur, interprétation de la demande, retrieval RAG initial, gestion des retries ;
    
- **Planning** : planification des étapes, choix des agents et de l'ordre d'exécution ;
    
- **Execution spécialisé** : exécution des tâches spécialisées ;
    
- **Review Critique** : review/critique des livrables, validation avant réponse finale ;
    
- outils non-LLM : embeddings, rerank, indexation, connecteurs.
    

À produire :

- contrats d’entrées/sorties JSON entre agents ;
    
- gestion d’état de conversation ;
    
- règles de routage ;
    
- journal d’exécution par agent.
    

## Phase 4

Objectif : passer d’un backend unique à une **plateforme multi-profils vLLM**. vLLM ne sert pas plusieurs modèles dans une seule instance, donc ton design doit évoluer vers plusieurs services vLLM, chacun spécialisé par rôle ou par taille de modèle, avec routage par-dessus.

Profils recommandés :

- `vllm-chat-standard` ;
    
- `vllm-reasoning-medium` ;
    
- `vllm-review-fast` ;
    
- `vllm-large-burst` ;
    
- éventuellement un service embeddings séparé si besoin.
    

À ajouter :

- router interne ;
    
- registre des modèles disponibles ;
    
- métadonnées par modèle, contexte, VRAM, latence attendue, coût.
    

## Phase 5

Objectif : industrialiser l’**observabilité et l’évaluation** initiées dès la Phase 2. Les bonnes pratiques LLMOps insistent sur les traces, les évaluations automatiques, les régressions fonctionnelles, les coûts et la latence avant toute montée en complexité.

À instrumenter :

- temps de réponse ;
    
- TTFT ;
    
- tokens/sec ;
    
- file d’attente ;
    
- occupation GPU ;
    
- taux d’erreur ;
    
- score RAG sur dataset de test ;
    
- qualité des sorties des agents.
    

À ajouter :

- dashboards Grafana ;
    
- alerting basique ;
    
- replay de prompts ;
    
- benchmark de modèles ;
    
- suite d’évaluation avant changement de modèle/prompt.
    

## Phase 6

Objectif : préparer la **migration Kubernetes** sans tout casser. Les guides Kubernetes/vLLM récents montrent que l’intérêt réel apparaît avec GPU scheduling, autoscaling, multi-réplicas, warm pools et routage avancé.

Préparation technique :

- containeriser proprement chaque composant ;
    
- externaliser toute la config ;
    
- rendre les services stateless quand possible ;
    
- sortir les volumes persistants clairement ;
    
- séparer les dépendances réseaux et les secrets.
    

À produire :

- manifests ou Helm charts de base ;
    
- conventions de labels/annotations ;
    
- stratégie de probes ;
    
- stratégie de stockage des poids et caches.
    

## Phase 7

Objectif : déployer la **plateforme homelab sur k3s/Kubernetes**. À ce stade, tu introduis les briques d’orchestration GPU, la discovery plus propre et les classes de services vLLM.

Socle conseillé :

- k3s ou kubeadm ;
    
- GPU Operator selon le matériel ;
    
- ingress ;
    
- object storage persistant ;
    
- vector DB persistante ;
    
- déploiements vLLM par profil ;
    
- métriques GPU et autoscaling sur métriques pertinentes.
    

Résultat attendu :

- plusieurs services vLLM coexistent ;
    
- le router choisit le bon profil ;
    
- la plateforme redémarre proprement ;
    
- les caches et index persistent.
    

## Phase 8

Objectif : introduire le **burst GPU à la demande**. Ici, tu gardes le même plan de contrôle, mais tu ajoutes des nœuds ou pools distants à activer selon besoin, sans passer par une API LLM propriétaire.

À construire :

- logique de capacité disponible ;
    
- seuils de déclenchement ;
    
- warm pool éventuel ;
    
- téléchargement/caching des poids ;
    
- routage vers backend distant quand un profil local manque de VRAM.
    

Point de vigilance :

- les cold starts des gros modèles ;
    
- la proximité stockage/compute ;
    
- la sécurité réseau des endpoints distants.
    

## Phase 9

Objectif : automatiser le **déploiement dynamique des modèles**. C’est la phase où l’orchestrateur ne choisit plus seulement un modèle déjà prêt ; il peut aussi demander le déploiement d’un profil lourd en fonction de la charge, du type de requête et des GPU disponibles.

Mécanisme cible :

1. l’orchestrateur classe la requête ;
    
2. il cherche un profil déjà chaud ;
    
3. sinon il déclenche un déploiement ;
    
4. il attend la readiness ;
    
5. il route la requête ;
    
6. il scale down ensuite selon politique.
    

## Phase 10

Objectif : finaliser le hardening et l’exploitation durable. La sécurité et les sauvegardes de base sont posées dès la Phase 1 et renforcées à chaque phase ; ici, le projet devient une vraie plateforme homelab/plateforme privée d’IA, donc il faut industrialiser gouvernance, rotation des secrets à grande échelle et maintenance de modèles.

À couvrir :

- RBAC et segmentation ;
    
- sauvegardes de vecteurs et stockage objet ;
    
- rotation des secrets ;
    
- quotas ;
    
- isolation des outils agents ;
    
- politique de mise à jour de modèles ;
    
- documentation d’exploitation.
    

## Ordre pratique

Je te conseille cet ordre concret :

1. Architecture logique et profils.
    
2. MVP Compose avec vLLM unique (sécurité et sauvegardes minimales dès le départ).
    
3. RAG fiable et instrumenté (observabilité minimale incluse).
    
4. Orchestrateur multi-agent.
    
5. Multi-profils vLLM + routing.
    
6. Observabilité + évaluation (industrialisation).
    
7. Préparation à la migration Kubernetes.
    
8. Migration k3s/Kubernetes.
    
9. Burst GPU distant.
    
10. Déploiement automatique de gros modèles.
    
11. Hardening et exploitation (finalisation).
    
