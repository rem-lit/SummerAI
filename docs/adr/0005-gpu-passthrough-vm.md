# 5. Confier le GPU à une machine virtuelle par passthrough PCIe

- **Statut :** Remplacée par l'[ADR 0007](0007-one-lxc-per-gpu.md)
- **Date :** 2026-10-13

## Contexte

- L'hôte GPU (`merlin`) a un Intel Core i5-14400F, 32 Go de RAM et une NVIDIA
  RTX 3090 (24 Go), et fait tourner Proxmox VE. Le CPU n'a pas de partie
  graphique intégrée : la RTX 3090 est donc aussi la carte sur laquelle l'hôte
  démarre.
- Chaque charge GPU est un conteneur Docker (vLLM et, éventuellement, les
  modèles d'embeddings et de reranking), déployé avec Ansible et Docker
  Compose.
- Proxmox offre deux façons de donner le GPU à un invité : le passthrough PCIe
  vers une machine virtuelle (VFIO), ou le partage du pilote NVIDIA de l'hôte
  avec un conteneur LXC.
- L'administration courante ne doit pas exiger root sur l'hyperviseur.

## Comparaison

| Critère | VM avec passthrough PCIe | Conteneur LXC partageant le pilote de l'hôte |
|---|---|---|
| Isolation | Noyau invité séparé ; l'IOMMU isole la carte. Une pile d'inférence compromise reste confinée dans la VM | Partage le noyau de l'hôte et expose au conteneur le pilote noyau NVIDIA de l'hôte |
| Pilote NVIDIA | Installé dans la VM uniquement ; l'hôte se contente d'associer la carte à `vfio-pci` | Installé sur l'hôte, avec des bibliothèques en espace utilisateur de version strictement identique dans le conteneur |
| Mises à jour | Les mises à jour du pilote et du noyau se font dans la VM, sans toucher à l'hôte | Chaque mise à jour du noyau ou du pilote de l'hôte exige root sur l'hôte, et les bibliothèques du conteneur doivent suivre |
| Docker et NVIDIA Container Toolkit | Installation standard, identique à une instance GPU dans le cloud | Docker dans LXC exige l'imbrication (nesting) et des contournements pour le runtime GPU |
| Mémoire | Toute la mémoire de la VM est verrouillée tant que la carte est attachée : pas de ballooning, pas de surallocation | Partagée avec l'hôte ; rien n'est réservé |
| Partage du GPU | La carte appartient à une seule VM ; ni l'hôte ni les autres invités ne peuvent l'utiliser | Plusieurs conteneurs peuvent utiliser la carte en même temps |
| Performances | Proches du natif | Natives |
| Sauvegardes | Les sauvegardes de disque fonctionnent ; pas la migration à chaud ni les instantanés mémoire | Sauvegardes de conteneur simples |
| Portabilité | Même organisation qu'une VM GPU dans le cloud : les rôles Ansible se transposent à la variante cloud | Propre à Proxmox |

## Décision

Faire passer la RTX 3090 en passthrough vers une seule **VM d'inférence**, qui
fait tourner tous les conteneurs GPU.

L'hôte demande une configuration initiale unique avec root : IOMMU activé,
carte associée à `vfio-pci` et mappage de ressource PCI Proxmox pour cette
carte. Ensuite, la VM est gérée avec un compte limité aux VM SummerAI et
autorisé à utiliser ce mappage.

## Conséquences

- La mémoire de la VM est verrouillée tant qu'elle tourne. Avec 32 Go sur
  l'hôte, la VM peut obtenir environ 24 Go, assez pour charger un modèle qui
  remplit la carte, mais il reste peu pour les autres invités de `merlin`.
- Aucun autre invité de `merlin` ne peut utiliser le GPU. Tout ce qui en a
  besoin tourne dans la VM d'inférence.
- La RTX 3090 est le seul adaptateur graphique de l'hôte. L'hôte doit la
  libérer au démarrage (pas de framebuffer sur la carte) et n'est ensuite géré
  que par le réseau ; l'accès à la console locale passe par une carte
  graphique temporaire.
- Le CPU mélange cœurs performance et cœurs efficacité ; épingler les vCPU de
  la VM sur les cœurs performance mérite une mesure.
- Les services qui n'utilisent que le CPU (base de données, passerelle,
  inférence sur CPU, observabilité) tournent sur l'hyperviseur principal, qui
  a bien plus de mémoire.
