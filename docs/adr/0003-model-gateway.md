# 3. LiteLLM comme passerelle des modèles

- **Statut :** Remplacée par l'[ADR 0008](0008-gateway-caddy-mtls.md)
- **Date :** 2026-10-13

## Contexte

- Plusieurs moteurs d'inférence vont coexister : vLLM, llama.cpp et, plus
  tard, un service de modèles managé dans le cloud
  ([feuille de route](../roadmap.md)).
- Les serveurs de modèles n'ont pas d'authentification digne de ce nom et ne
  doivent pas être joignables par les clients.
- L'usage, la latence et les erreurs doivent être mesurés par client et par
  modèle.

## Décision

Tout le trafic vers les modèles passe par un **proxy LiteLLM** qui expose
l'API OpenAI :

- une clé d'API par client (Open WebUI, orchestrateur, évaluation, mesures) ;
- un routage par nom de modèle vers le bon moteur, avec repli entre profils ;
- l'usage et la latence journalisés par clé et par modèle.

Les serveurs de modèles n'acceptent que le trafic venant de la passerelle,
ce qu'impose le pare-feu de l'hôte.

## Conséquences

- Les clients dépendent d'une seule API stable ; les moteurs peuvent changer
  librement.
- Ajouter la variante cloud après la v1 se résume à un changement de
  configuration de la passerelle.
- Un saut réseau de plus. Son surcoût fait partie des mesures.
- La passerelle stocke les clés et l'usage dans une base de données ; elle a
  sa propre base dans la même instance PostgreSQL que la recherche
  documentaire.
- La passerelle manipule des identifiants et voit tous les prompts : son image
  de conteneur est donc épinglée par empreinte (digest) et ses mises à jour
  sont relues.

## Options envisagées

- **Pas de passerelle** : chaque client parle à chaque moteur ; aucune
  authentification centrale ni suivi de l'usage.
- **Routeur maison** : contrôle total, mais refait ce que LiteLLM fournit déjà.
- **Passerelles natives Kubernetes** : pertinentes quand la plateforme passera
  sur Kubernetes (feuille de route à long terme), pas pour une v1 sous Docker
  Compose.
