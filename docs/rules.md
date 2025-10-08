# Règles Snort personnalisées

## Vue d'ensemble

Ce document détaille les règles personnalisées Snort implémentées dans le fichier `snort/local.rules`. Ces règles sont conçues pour détecter des attaques spécifiques contre l'application DVWA et les services du système.

## Structure des règles

Toutes les règles personnalisées utilisent des SID (Signature ID) >= 1000000 pour éviter les conflits avec les règles officielles Snort.

## Règles implémentées

### Règle 1000001 - Détection de scan de ports SYN

**Objectif** : Détecter les tentatives de reconnaissance réseau par scan SYN

**Syntaxe** :
```
alert tcp any any -> any any (msg:"Possible SYN scan"; flags:S; detection_filter: track by_src, count 20, seconds 3; sid:1000001; rev:1;)
```

**Explication** :
- `alert tcp` : Alerte sur le protocole TCP
- `any any -> any any` : Source et destination quelconques
- `flags:S` : Détecte les paquets avec le flag SYN
- `detection_filter: track by_src, count 20, seconds 3` : Seuil de 20 paquets SYN en 3 secondes par source
- `sid:1000001` : Identifiant unique de la règle

**Déclenchement** : Lors d'un scan nmap -sS ou équivalent

### Règle 1000002 - Détection d'injection SQL

**Objectif** : Détecter les tentatives d'injection SQL via URL

**Syntaxe** :
```
alert tcp any any -> any 80 (msg:"WEB SQLi attempt (uri)"; content:"UNION SELECT"; nocase; http_uri; sid:1000002; rev:2;)
```

**Explication** :
- `any 80` : Cible le port 80 (HTTP)
- `content:"UNION SELECT"` : Recherche la chaîne "UNION SELECT"
- `nocase` : Recherche insensible à la casse
- `http_uri` : Recherche uniquement dans l'URI HTTP

**Déclenchement** : Lors d'une requête contenant "UNION SELECT" dans l'URL

### Règle 1000003 - Détection de Local File Inclusion

**Objectif** : Détecter les tentatives d'accès au fichier /etc/passwd

**Syntaxe** :
```
alert tcp any any -> any 80 (msg:"WEB LFI request attempt - /etc/passwd"; flow:to_server,established; content:"/etc/passwd"; http_uri; nocase; classtype:web-application-attack; sid:1000003; rev:1;)
```

**Explication** :
- `flow:to_server,established` : Connexion établie vers le serveur
- `content:"/etc/passwd"` : Recherche l'accès au fichier passwd
- `classtype:web-application-attack` : Classification de l'attaque

**Déclenchement** : Lors d'une requête contenant "/etc/passwd" dans l'URL

### Règle 1000004 - Détection de brute-force SSH

**Objectif** : Détecter les tentatives de force brute sur SSH

**Syntaxe** :
```
alert tcp any any -> any 22 (msg:"SSH brute force suspect"; detection_filter: track by_src, count 10, seconds 60; sid:1000004; rev:1;)
```

**Explication** :
- `any 22` : Cible le port 22 (SSH)
- `detection_filter: track by_src, count 10, seconds 60` : Seuil de 10 tentatives en 60 secondes par source

**Déclenchement** : Lors de multiples tentatives de connexion SSH depuis la même source

### Règle 1000005 - Détection d'exploitation PHP

**Objectif** : Détecter les tentatives d'exploitation de paramètres PHP

**Syntaxe** :
```
alert tcp any any -> any 80 (msg:"PHP exploit param"; content:".php?"; nocase; http_uri; sid:1000005; rev:2;)
```

**Explication** :
- `content:".php?"` : Recherche les URLs contenant ".php?"
- `http_uri` : Recherche uniquement dans l'URI HTTP

**Déclenchement** : Lors d'une requête vers un script PHP avec des paramètres
