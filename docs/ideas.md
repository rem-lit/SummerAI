# Réserve d'idées

Idées recueillies pendant la conception de SummerAI. Ce ne sont **pas** des
engagements ; la dernière colonne indique où en est chacune par rapport à la
[feuille de route v1](roadmap.md) et à la
[feuille de route à long terme](roadmap-long-term.md).

| Idée | Détails | Statut |
|---|---|---|
| Génération en deux étapes | Une première passe lente construit une base de connaissances très spécialisée, avec vérification des faits et de la cohérence ; un modèle plus léger répond ensuite aux utilisateurs à partir de cette base, pour réduire la mémoire nécessaire au moment de la requête. | Recherche, long terme |
| Modèles spécialisés | Fine-tuning pour des domaines restreints ; enchaînement de plusieurs LLM. | Long terme |
| Mémoire de contexte dynamique | Promouvoir des concepts dans un contexte stable selon leur fréquence dans les prompts, les générations et les réponses des utilisateurs sur un sujet donné. | Recherche, long terme |
| Mesures par spécialité | Comparer les modèles existants par domaine, par exemple avec RAGAS. | En partie dans la v1 (banc d'évaluation, jalon M3) |
| Éditions serveur et locale | Une édition serveur (VPS ou sur site) et une édition locale conteneurisée qui utilise le GPU du client, toutes deux déployées par des pipelines CI à chaque push, sur le modèle de la distribution de n8n. | La v1 fournit des profils Compose GPU et CPU seul |
| Choix du modèle selon le contexte | Choisir le modèle selon le contexte et les ressources disponibles : API cloud, GPU locaux, ou un mélange des deux. | Variante cloud après la v1 ; une version pour le développement est la [boucle de travail déléguée](delegated-loop.md) |
| Plusieurs modes | Assistant IA, RAG, automatisation (n8n), agent agissant sur la machine, mode projet (orchestration de plusieurs IA). | La v1 couvre l'assistant, le RAG et des agents aux outils restreints ; le reste relève du long terme |
| Maillage GPU pair à pair | Mettre en commun les ressources GPU de plusieurs machines. | Long terme (axe C) |
| Questionnaire de charge | Interroger les utilisateurs sur leur charge prévue pour anticiper les déploiements. | Long terme (axe D) |
| GPU loués | Utiliser une place de marché de GPU comme vast.ai pour absorber les pics de charge. | Long terme (axe C) |
