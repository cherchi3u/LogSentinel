# Tests et scénarios d'attaque

## Vue d'ensemble

Ce document détaille les différents tests d'attaque mis en place pour valider le système de détection d'intrusions. Chaque test génère des alertes spécifiques qui sont capturées par Snort et remontées dans Kibana.

## Script de test principal

Le script `scripts/run-tests.sh` lance automatiquement tous les scénarios d'attaque. Il peut être exécuté avec :
```bash
sudo bash scripts/run-tests.sh
```

## Scénarios d'attaque implémentés

### 1. Scan de ports SYN

**Objectif** : Détecter les tentatives de reconnaissance réseau

**Règle Snort** : `sid:1000001` (Possible SYN scan)

**Méthode de détection** : Trafic TCP avec flag SYN répété rapidement depuis une même source

**Commande de test** :
```bash
nmap -sS -p22,80,3306 127.0.0.1
```

**Indicateurs dans Kibana** :
- Rechercher par `sid:1000001`
- Filtrer par `fields.log_source: "snort"`

### 2. Injection SQL (SQLi)

**Objectif** : Détecter les tentatives d'injection SQL

**Règle Snort** : `sid:1000002` (WEB SQLi attempt)

**Méthode de détection** : Présence de `UNION SELECT` dans l'URI HTTP vers le port 80

**Commande de test** :
```bash
curl "http://127.0.0.1/dvwa/vulnerabilities/sqli/?id=1' UNION SELECT 1,2,3--&Submit=Submit"
```

**Indicateurs dans Kibana** :
- Rechercher par `sid:1000002`
- Filtrer par `fields.log_source: "snort"`

### 3. Local File Inclusion (LFI)

**Objectif** : Détecter les tentatives d'accès à des fichiers système

**Règle Snort** : `sid:1000003` (accès à /etc/passwd)

**Méthode de détection** : URI contenant `/etc/passwd` vers le port 80

**Commande de test** :
```bash
curl "http://127.0.0.1/dvwa/vulnerabilities/fi/?page=../../../../etc/passwd"
```

**Indicateurs dans Kibana** :
- Rechercher par `sid:1000003`
- Filtrer par `fields.log_source: "snort"`

### 4. Brute-force SSH

**Objectif** : Détecter les tentatives de force brute sur SSH

**Règle Snort** : `sid:1000004` (tentatives multiples sur port 22)

**Méthode de détection** : Seuil de détection par source (10 tentatives/60s)

**Commande de test** :
```bash
hydra -l admin -P /usr/share/wordlists/rockyou.txt ssh://127.0.0.1
```

**Indicateurs dans Kibana** :
- Rechercher par `sid:1000004`
- Filtrer par `fields.log_source: "snort"`

### 5. Exploit paramètre PHP

**Objectif** : Détecter les tentatives d'exploitation de paramètres PHP

**Règle Snort** : `sid:1000005` (URI contenant .php?)

**Méthode de détection** : Motif large pour repérer des vecteurs d'attaque web génériques

**Commande de test** :
```bash
curl "http://127.0.0.1/dvwa/vulnerabilities/exec/?ip=127.0.0.1;ls"
```

**Indicateurs dans Kibana** :
- Rechercher par `sid:1000005`
- Filtrer par `fields.log_source: "snort"`

## Visualisation dans Kibana

### Configuration de l'index

1. Ouvrir Kibana : `http://127.0.0.1:5601`
2. Créer l'index pattern : `filebeat-*`
3. Sélectionner le champ temporel : `@timestamp`

### Filtres utiles

- `fields.log_source: "snort"` : Afficher uniquement les alertes Snort
- `message: "1000001"` : Filtrer par SID spécifique

