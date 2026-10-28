# Runbook : hôte GPU et conteneur LLM

Comment `merlin` et le conteneur LLM sont configurés pour
[M1](../roadmap.md#m1-service-des-modèles), selon
[l'ADR 0006](../adr/0006-llama-server-runtime.md) et
[l'ADR 0007](../adr/0007-one-lxc-per-gpu.md). Chaque étape a été exécutée à la
main et vérifiée avant la suivante ; Ansible remplacera ce runbook en M5.

Les fichiers de configuration cités plus bas sont dans
[`deploy/merlin/`](../../deploy/merlin/).

> **État :** hôte, conteneur LLM, limite de puissance et conteneur de recherche
> documentaire terminés. Reste à faire dans M1 : la passerelle Caddy.

## Versions épinglées

| Composant | Version | Raison |
|---|---|---|
| Proxmox VE | 9.2 | Version actuelle |
| Noyau de l'hôte | 6.17.13-21-pve, épinglé | Le noyau 7.0, par défaut en 9.2, a des problèmes NVIDIA signalés sur les cartes RTX série 30 |
| Pilote NVIDIA | 595.104.02, branche de production, modules noyau ouverts, DKMS | Branche de production actuelle ; les modules ouverts sont recommandés pour Ampere |
| Toolkit CUDA (conteneur) | 13.1 | CUDA 13.2 casse certains types de quantification ([llama.cpp #21255](https://github.com/ggml-org/llama.cpp/issues/21255)), corrigé en 13.3, que le pilote 595 ne prend pas en charge |
| llama.cpp | v0.7.0, commit `620d2225cc436ab0b001e3200e590e3b286ef9ab` | Première version stable ; a passé le smoke test de chat et d'appel d'outil |
| Modèle principal | `unsloth/Qwen3.8-27B-GGUF`, fichier `Qwen3.8-27B-UD-Q4_K_XL.gguf`, révision `4ca720788d1e01f1bff70c033e0d0028fd02e502` | Apache 2.0 |
| Modèle d'embeddings | `Qwen/Qwen3-Embedding-0.6B-GGUF`, fichier `Qwen3-Embedding-0.6B-Q8_0.gguf`, révision `370f27d7550e0def9b39c1f16d3fbaa13aa67728` | Apache 2.0, 1024 dimensions, multilingue |
| Modèle de reranking | `ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF`, fichier `qwen3-reranker-0.6b-q8_0.gguf`, révision `a02f48bb4f057028298c21fa033da2b30d7742d5` | Apache 2.0 ; cette conversion inclut le gabarit de reranking |
| Runtime CUDA (conteneur de recherche documentaire) | `cuda-cudart-13-1` 13.1.80-1, `libcublas-13-1` 13.2.2.2-1 | Mêmes versions que le toolkit du conteneur LLM |

## 1. Hôte : noyau

```bash
apt install proxmox-kernel-6.17 proxmox-headers-6.17
proxmox-boot-tool kernel pin 6.17.13-21-pve
```

Seuls les en-têtes 6.17 sont installés, donc DKMS ne compile le pilote que
pour ce noyau. Avant toute mise à jour du noyau ou du pilote, `dkms status`
doit montrer le module compilé pour le nouveau noyau.

## 2. Hôte : écarter les pilotes libres

Copier [`blacklist-nvidia-open-drivers.conf`](../../deploy/merlin/host/blacklist-nvidia-open-drivers.conf)
dans `/etc/modprobe.d/`, lancer `update-initramfs -u -k all` et redémarrer.

Vérification : `uname -r` affiche le noyau épinglé, `lsmod` n'affiche aucun
module `nouveau` ou `nova`, et Secure Boot est désactivé
(`mokutil --sb-state`) ; sinon, le module DKMS non signé ne se chargerait pas.

## 3. Hôte : pilote NVIDIA

```bash
apt install build-essential dkms pkg-config
V=595.104.02
B=https://download.nvidia.com/XFree86/Linux-x86_64/$V
wget "$B/NVIDIA-Linux-x86_64-$V.run" "$B/NVIDIA-Linux-x86_64-$V.run.sha256sum"
sha256sum -c "NVIDIA-Linux-x86_64-$V.run.sha256sum"
sh "NVIDIA-Linux-x86_64-$V.run" --dkms
```

Réponses : modules noyau MIT/GPL, DKMS oui, bibliothèques 32 bits non,
`nvidia-xconfig` non. La somme de contrôle vient du même serveur : elle
détecte un téléchargement corrompu, pas un fichier altéré.

Vérification avant le redémarrage : `dkms status` montre le module comme
`installed` pour le noyau épinglé, `modinfo -F license nvidia` affiche
`Dual MIT/GPL`, et `nvidia-smi` liste les deux cartes.

## 4. Hôte : persistance et fichiers de périphérique

Copier [`nvidia.conf`](../../deploy/merlin/host/nvidia.conf) dans
`/etc/modules-load.d/`, et les deux unités
[`nvidia-persistenced.service`](../../deploy/merlin/host/nvidia-persistenced.service)
et [`nvidia-uvm-devices.service`](../../deploy/merlin/host/nvidia-uvm-devices.service)
dans `/etc/systemd/system/`, puis :

```bash
systemctl daemon-reload
systemctl enable --now nvidia-persistenced nvidia-uvm-devices
```

Le démon de persistance garde le pilote chargé, donc les fichiers de
périphérique et les limites de puissance survivent aux périodes d'inactivité.
`/dev/nvidia-uvm*` n'est pas créé au démarrage, et CUDA en a besoin dans les
conteneurs.

Vérification après un redémarrage : les deux services sont `active`, le mode
persistance est `Enabled` sur les deux cartes, et `/dev/nvidia0`,
`/dev/nvidia1`, `/dev/nvidiactl`, `/dev/nvidia-uvm` et `/dev/nvidia-uvm-tools`
existent. Les droits des périphériques ne sont pas élargis sur l'hôte ; chaque
conteneur fixe son propre groupe et ses propres droits.

## 5. Conteneur LLM

Un conteneur Debian 13 non privilégié qui ne voit que la RTX 3090
(`/dev/nvidia0` sur cet hôte, la carte à l'adresse PCI la plus basse).

```bash
pct create <id> <storage>:vztmpl/debian-13-standard_<version>_amd64.tar.zst \
  --hostname elias --unprivileged 1 --features nesting=1 \
  --cores 6 --memory 16384 --swap 0 \
  --rootfs <fast-storage>:80 \
  --net0 name=eth0,bridge=vmbr0,tag=20,ip=dhcp,firewall=1 \
  --onboot 1
pct set <id> \
  --dev0 /dev/nvidia0,gid=2000,mode=0660 \
  --dev1 /dev/nvidiactl,gid=2000,mode=0660 \
  --dev2 /dev/nvidia-uvm,gid=2000,mode=0660 \
  --dev3 /dev/nvidia-uvm-tools,gid=2000,mode=0660
```

Les entrées `devN:` sont utilisées plutôt que des règles
`cgroup2.devices.allow`, car le numéro majeur de `nvidia-uvm` est attribué au
démarrage. L'autre carte, `nvidia-modeset` et `nvidia-caps` ne sont pas
transmis.

Dans le conteneur, le même pilote sans son module noyau :

```bash
groupadd -g 2000 gpu
sh NVIDIA-Linux-x86_64-595.104.02.run --no-kernel-module
```

Vérification : `nvidia-smi` dans le conteneur ne liste que la RTX 3090. Sa
colonne `Persistence-M` indique `Off` dans le conteneur ; c'est la valeur de
l'hôte qui compte.

Le conteneur doit pouvoir résoudre `deb.debian.org`,
`developer.download.nvidia.com`, `github.com`, `huggingface.co` et l'hôte de
téléchargement de Hugging Face `cas-bridge.xethub.hf.co`.

## 6. llama.cpp

Le toolkit CUDA seul, depuis le dépôt Debian 13 de NVIDIA. Ne jamais installer
les paquets `cuda` ou `cuda-drivers` : ils installeraient un second pilote.

```bash
apt install build-essential cmake git wget ca-certificates libssl-dev pkg-config
wget https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i cuda-keyring_1.1-1_all.deb && apt update
apt install cuda-toolkit-13-1

git clone --depth 1 --branch v0.7.0 https://github.com/ggml-org/llama.cpp /opt/src/llama.cpp
cd /opt/src/llama.cpp
cmake -B build-static -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
  -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=86 \
  -DCMAKE_CUDA_COMPILER=/usr/local/cuda-13.1/bin/nvcc \
  -DGGML_RPC=OFF -DLLAMA_BUILD_TESTS=OFF
cmake --build build-static -j 6 --target llama-server llama-bench

install -d /opt/llama.cpp/v0.7.0/bin
install -m 0755 build-static/bin/llama-server build-static/bin/llama-bench /opt/llama.cpp/v0.7.0/bin/
ln -sfn /opt/llama.cpp/v0.7.0 /opt/llama.cpp/current
```

La compilation statique garde `libggml` et `libllama` dans le binaire, donc
chaque version est autonome et un retour arrière se fait en changeant un lien
symbolique. Seules les bibliothèques CUDA restent dynamiques. Compilé pour
`sm_86` uniquement, l'architecture Ampere des deux cartes. Le backend RPC
n'est pas compilé.

Vérification : `git rev-parse HEAD` correspond au commit épinglé,
`llama-server --list-devices` affiche la RTX 3090, et
`ldd /opt/llama.cpp/current/bin/llama-server` résout toutes les bibliothèques.

## 7. Modèle et clé d'API

```bash
useradd --system --user-group --groups gpu --home-dir /var/lib/llama --shell /usr/sbin/nologin llama
install -d -o root -g llama -m 0750 /var/lib/llama /var/lib/llama/models /etc/llama
openssl rand -hex 32 > /etc/llama/api-key
chown root:llama /etc/llama/api-key && chmod 0640 /etc/llama/api-key

REV=4ca720788d1e01f1bff70c033e0d0028fd02e502
F=Qwen3.8-27B-UD-Q4_K_XL.gguf
wget -c -O /var/lib/llama/models/$F "https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/resolve/$REV/$F"
chown root:llama /var/lib/llama/models/$F && chmod 0640 /var/lib/llama/models/$F
```

Vérifier le téléchargement avec
[`models.sha256`](../../deploy/merlin/llama/models.sha256), copié dans
`/var/lib/llama/models/` :

```bash
cd /var/lib/llama/models && sha256sum -c --ignore-missing models.sha256
```

Le compte de service peut lire le modèle et la clé, mais pas les modifier. La
clé ne quitte jamais le conteneur et n'est pas stockée dans ce dépôt.

## 8. Service

L'unité est un gabarit,
[`llama-server@.service`](../../deploy/merlin/llama/llama-server@.service) :
une instance par modèle, dont les arguments sont dans
`/etc/llama/<instance>.conf`. Copier l'unité dans `/etc/systemd/system/` et
[`chat.conf`](../../deploy/merlin/llama/chat.conf) dans `/etc/llama/`
(`root:llama`, mode `0640`), puis :

```bash
systemctl daemon-reload
systemctl enable --now llama-server@chat
```

systemd lit le fichier `.conf` comme un fichier d'environnement : une barre
oblique inverse en fin de ligne la prolonge, et `$LLAMA_ARGS` est découpé sur
les espaces dans `ExecStart`. Un argument entre guillemets contenant une
espace serait découpé aussi ; aucun des arguments actuels n'en contient.

Réglages, d'après [l'ADR 0006](../adr/0006-llama-server-runtime.md),
[l'ADR 0008](../adr/0008-gateway-caddy-mtls.md) et la fiche du modèle :

- Boucle locale uniquement, clé d'API obligatoire, pas d'interface web, pas de
  point d'accès `/slots`, pas d'outils intégrés, métriques activées.
- Toutes les couches sur le GPU, un slot, contexte de 32K, flash attention,
  cache clé-valeur `q8_0`. La taille du contexte sera augmentée d'après la
  mémoire mesurée.
- Échantillonnage du mode réflexion d'après la fiche du modèle :
  température 1,0 ; top-p 0,95 ; top-k 20 ; min-p 0.
- `-lm dio` charge le modèle en E/S directes. Avec le mappage mémoire par
  défaut, le fichier du modèle reste dans le cache de pages, qui est compté
  dans la mémoire du conteneur : `systemctl status` indiquait 14,2 Go sur sa
  limite de 16 Go, contre 1,1 Go en E/S directes.
- Pas encore de projecteur d'images (`--mmproj`) : texte seulement.
- La tête de prédiction multi-jetons du modèle est chargée mais inutilisée ;
  le serveur journalise ses tenseurs comme inutilisés. Le décodage spéculatif
  sera évalué plus tard.
- Isolation systemd : aucun privilège ni aucune capacité, système de fichiers
  en lecture seule. `MemoryDenyWriteExecute` n'est pas activé, car le pilote
  CUDA doit mapper de la mémoire exécutable. Le filtrage des périphériques est
  fait par le conteneur, pas par systemd.

## 9. Smoke test

```bash
scripts/smoke/llm.sh
```

Le [script](../../scripts/smoke/llm.sh) vérifie que les requêtes sans clé sont
rejetées, que le modèle est listé sous son alias, qu'une réponse de chat
s'arrête normalement avec le raisonnement dans `reasoning_content`, et qu'un
appel d'outil renvoie des arguments JSON valides. Il lit la clé dans un
fichier et la passe à `curl` comme fichier d'en-têtes, pour qu'elle
n'apparaisse jamais sur une ligne de commande. Il a besoin de
[`lib.sh`](../../scripts/smoke/lib.sh) dans le même répertoire.

Depuis l'hôte, sans cloner le dépôt dans le conteneur (épingler le commit
testé) :

```bash
C=https://raw.githubusercontent.com/rem-lit/SummerAI/<commit>/scripts/smoke
pct exec <id> -- install -d /root/smoke
pct exec <id> -- wget -q -O /root/smoke/lib.sh "$C/lib.sh"
pct exec <id> -- wget -q -O /root/smoke/llm.sh "$C/llm.sh"
pct exec <id> -- bash /root/smoke/llm.sh
```

## 10. Hôte : limite de puissance

La limite vient d'un balayage mesuré, décrit avec ses résultats dans
[`benchmarks/power-limit/`](../../benchmarks/power-limit/). Copier
[`nvidia-power-limits.service`](../../deploy/merlin/host/nvidia-power-limits.service)
dans `/etc/systemd/system/`, puis :

```bash
systemctl daemon-reload
systemctl enable --now nvidia-power-limits
```

Vérification, aussi après un redémarrage :
`nvidia-smi -i 00000000:01:00.0 --query-gpu=power.limit --format=csv` affiche
la limite choisie.

## 11. Conteneur de recherche documentaire

Un second conteneur non privilégié, `mevanwi`, pour les modèles d'embeddings
et de reranking sur la RTX 3060 (`/dev/nvidia1`). Les deux modèles utilisent
ensemble environ 4,3 Go des 8 Go de la carte.

```bash
pct create <id> <storage>:vztmpl/debian-13-standard_<version>_amd64.tar.zst \
  --hostname mevanwi --unprivileged 1 --features nesting=1 \
  --cores 4 --memory 4096 --swap 0 \
  --rootfs <fast-storage>:20 \
  --net0 name=eth0,bridge=vmbr0,tag=20,ip=dhcp,firewall=1 \
  --onboot 1
pct set <id> \
  --dev0 /dev/nvidia1,gid=2000,mode=0660 \
  --dev1 /dev/nvidiactl,gid=2000,mode=0660 \
  --dev2 /dev/nvidia-uvm,gid=2000,mode=0660 \
  --dev3 /dev/nvidia-uvm-tools,gid=2000,mode=0660
```

`<storage>` est le stockage qui contient le modèle de conteneur, un stockage
de type répertoire ; un stockage LVM ne peut pas contenir de modèles de
conteneur.

Dans le conteneur : le groupe `gpu` et le pilote sans son module noyau, comme
dans la [section 5](#5-conteneur-llm), puis seulement les bibliothèques
runtime de CUDA, pas le toolkit :

```bash
groupadd -g 2000 gpu
sh NVIDIA-Linux-x86_64-595.104.02.run --no-kernel-module --silent --no-install-compat32-libs
apt install wget curl ca-certificates jq libgomp1
wget https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i cuda-keyring_1.1-1_all.deb && apt update
apt install cuda-cudart-13-1=13.1.80-1 libcublas-13-1=13.2.2.2-1
```

Le binaire `llama-server` n'est pas recompilé : la compilation statique de la
[section 6](#6-llamacpp) est copiée en passant par l'hôte, et sa somme de
contrôle comparée des deux côtés.

```bash
pct pull <llm-id> /opt/llama.cpp/v0.7.0/bin/llama-server /root/llama-server
pct exec <id> -- install -d /opt/llama.cpp/v0.7.0/bin
pct push <id> /root/llama-server /opt/llama.cpp/v0.7.0/bin/llama-server --perms 0755
pct exec <id> -- ln -sfn /opt/llama.cpp/v0.7.0 /opt/llama.cpp/current
```

Vérification : `ldd /opt/llama.cpp/current/bin/llama-server` n'affiche aucun
`not found`, et `llama-server --list-devices` ne montre que la RTX 3060.

Compte de service, clé et modèles comme dans la
[section 7](#7-modèle-et-clé-dapi), avec sa propre clé et ces deux modèles :

```bash
H=https://huggingface.co
wget -c -O /var/lib/llama/models/Qwen3-Embedding-0.6B-Q8_0.gguf \
  "$H/Qwen/Qwen3-Embedding-0.6B-GGUF/resolve/370f27d7550e0def9b39c1f16d3fbaa13aa67728/Qwen3-Embedding-0.6B-Q8_0.gguf"
wget -c -O /var/lib/llama/models/qwen3-reranker-0.6b-q8_0.gguf \
  "$H/ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF/resolve/a02f48bb4f057028298c21fa033da2b30d7742d5/qwen3-reranker-0.6b-q8_0.gguf"
```

Puis la même unité que dans la [section 8](#8-service), avec
[`embed.conf`](../../deploy/merlin/llama/embed.conf) et
[`rerank.conf`](../../deploy/merlin/llama/rerank.conf) :

```bash
systemctl enable --now llama-server@embed llama-server@rerank
```

Réglages :

- Embeddings sur le port 9932, reranking sur le port 9933, boucle locale
  uniquement.
- `--embedding` pour le modèle d'embeddings ; `--rerank` pour le reranker, qui
  sert `/v1/rerank`. Le type de pooling vient des métadonnées de chaque
  modèle : dernier jeton pour les embeddings, rank pour le reranking.
- Batch physique (`-ub`) égal au contexte de 8192 jetons, car une entrée d'un
  modèle d'embeddings ou de reranking doit tenir dans un seul batch physique.
- Les requêtes de recherche ont besoin d'un préfixe d'instruction
  (`Instruct: …` puis `Query: …`) ; les documents sont encodés sans préfixe.

Smoke test, depuis l'hôte, comme dans la [section 9](#9-smoke-test) mais avec
[`retrieval.sh`](../../scripts/smoke/retrieval.sh) : authentification et
alias des deux instances, trois vecteurs normalisés de 1024 dimensions, une
question plus proche du passage qui y répond que d'un passage sans rapport, et
ce passage classé premier par le reranker.

## Dépannage

| Symptôme | Cause |
|---|---|
| `nvidia-smi: command not found` dans le conteneur | Les commandes collées après `pct enter` sont perdues : les lancer une par une dans le conteneur |
| `Field "minor_number" is not a valid field to query` | Non disponible avec ce pilote ; le périphérique qu'un conteneur reçoit identifie sa carte |
| Service affiché brièvement comme `(a-server)` | systemd prépare l'isolation avant `exec` ; normal pendant quelques millisecondes |
| Mémoire du conteneur proche de sa limite avec le modèle sur le GPU | Modèle mappé en mémoire dans le cache de pages ; utiliser `-lm dio` |
| `jq: Cannot iterate over null` sur `/v1/models` | Requête sans clé valide : le serveur a renvoyé une erreur |
| `pct create` échoue avec `illegal characters` dans le volume du modèle de conteneur | Le modèle de conteneur a été cherché sur un stockage LVM ; utiliser le stockage de type répertoire qui le contient |
| `libgomp.so.1: cannot open shared object file` | `libgomp1` manquant : la compilation statique lie quand même le runtime OpenMP de façon dynamique |
| Avertissements de locale avec `pct exec` | L'hôte transmet son `LANG`, que le conteneur n'a pas ; sans conséquence |
