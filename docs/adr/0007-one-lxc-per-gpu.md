# 7. Un conteneur LXC par GPU, partageant le pilote de l'hôte

- **Statut :** Acceptée
- **Date :** 2026-10-15
- **Remplace :** [ADR 0005](0005-gpu-passthrough-vm.md)

## Contexte

- L'hôte GPU (`merlin`) a désormais deux cartes : une NVIDIA RTX 3090 (24 Go)
  et une RTX 3060 (8 Go), toutes deux Ampere. Il a un Intel Core i5-14400F,
  sans partie graphique intégrée, et 32 Go de RAM.
- Chaque carte a un rôle : la 3090 sert le modèle de langage principal, la
  3060 sert les modèles d'embeddings et de reranking
  ([ADR 0006](0006-llama-server-runtime.md)).
- Les serveurs de modèles sont des binaires `llama-server` natifs, pas des
  conteneurs.
- Le mainteneur a root sur l'hôte : les mises à jour du pilote et du noyau au
  niveau de l'hôte ne sont donc pas bloquantes.

L'ADR 0005 avait choisi le passthrough PCIe vers une VM. Avec deux cartes,
cela fait deux VM, chacune avec sa mémoire verrouillée tant qu'elle tourne :
32 Go ne suffisent pas pour les deux plus l'hôte.

## Décision

- Le pilote NVIDIA est installé **sur l'hôte** à partir du paquet `.run`
  officiel, avec DKMS et les en-têtes du noyau Proxmox. La même version est
  installée dans chaque conteneur avec `--no-kernel-module`.
- **Un conteneur LXC par GPU.** Chaque conteneur ne voit que les nœuds de
  périphérique de sa propre carte, déclarés avec des entrées `devN:` plutôt
  qu'avec des règles `cgroup2.devices.allow` brutes, dont les numéros majeurs
  peuvent changer d'un démarrage à l'autre.
- `llama-server` tourne comme binaire natif sous systemd dans chaque
  conteneur. Il n'y a pas de Docker dans les conteneurs.
- Le noyau de l'hôte est épinglé sur une version validée avec les deux
  cartes. Une mise à jour du noyau ou du pilote n'est appliquée qu'après que
  `dkms status` a confirmé que le module est compilé pour le nouveau noyau.
- La limite de puissance de la 3090 est fixée au démarrage par une unité
  systemd `oneshot`, à une valeur choisie avec les mesures.

## Conséquences

- La mémoire est partagée avec l'hôte au lieu d'être verrouillée par VM : les
  deux rôles tiennent dans 32 Go.
- L'isolation est plus faible qu'avec une VM : les conteneurs partagent le
  noyau de l'hôte, et le pilote noyau NVIDIA fait partie de leur surface
  d'attaque. Les conteneurs sont non privilégiés, n'exposent que leur propre
  carte et n'acceptent de trafic que via la passerelle.
- Les mises à jour du pilote touchent l'hôte et les deux conteneurs à la fois,
  et doivent garder leurs versions identiques. Ansible épingle la version à un
  seul endroit.
- L'organisation du déploiement sur `merlin` (unités systemd) diffère de celle
  de la VM de la plateforme (Docker Compose). Ansible couvre les deux.
- Cette organisation est propre à Proxmox. La variante cloud utilisera plutôt
  une VM GPU ; la configuration de `llama-server` se transpose sans
  changement.

## Options envisagées

- **Passthrough PCIe vers une VM par carte** (ADR 0005) : isolation plus
  forte, mais deux VM à mémoire verrouillée ne tiennent pas dans 32 Go.
- **Les deux cartes dans une seule VM** : une VM pour toutes les charges GPU,
  mais l'essentiel de la mémoire de l'hôte verrouillé et un point de
  défaillance unique pour le chat et la recherche documentaire.
- **Docker dans les conteneurs** : possible avec l'imbrication (nesting), mais
  ajoute une couche, avec des contournements connus pour le runtime GPU, sans
  bénéfice avec des binaires natifs.
