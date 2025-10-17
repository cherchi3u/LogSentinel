# Projet SIEM - Détection d'intrusions

CHERCHI Matteo - Amolitho BALDE - Samuel MIDETE

## Objectif

Mettre en place un mini-SIEM local qui détecte et remonte des attaques courantes contre une application volontairement vulnérable (DVWA). Le système utilise une chaîne technique complète : Snort (détection) → syslog-ng (collecte) → Filebeat (expédition) → Elasticsearch (stockage) → Kibana (visualisation) + envoi d'alertes par email.

## Architecture

Le système se compose de plusieurs composants interconnectés :

- **Snort** : Détecte les intrusions via des règles personnalisées
- **syslog-ng** : Lit les alertes Snort et les formate vers un fichier
- **Filebeat** : Expédie les logs vers Elasticsearch
- **Elasticsearch** : Stocke et indexe les données
- **Kibana** : Interface de visualisation et d'analyse
- **DVWA** : Application vulnérable servant de cible d'attaque
- **Scripts d'alerte** : Envoi d'emails pour chaque alerte détectée

## Schéma du système

```
[Attaques] → [DVWA] → [Snort] → [syslog-ng] → [Filebeat] → [Elasticsearch] → [Kibana]
                                    ↓
                              [watch-alerts.sh] → [send-alert-email.sh] → [Email]
```

## Prérequis

- OS : Ubuntu/Debian avec accès Internet et droits root/sudo
- Ports libres : 9200 (Elasticsearch), 5601 (Kibana), 80 (DVWA), 22 (SSH)
- SMTP sortant : requis pour l'envoi d'emails d'alerte

## Lancement du projet

1. **Préparation**
   - Copier le dépôt sur la machine cible Linux : `/opt/siem`

2. **Installation et démarrage**
   - Depuis `/opt/siem`, exécuter : `sudo bash scripts/setup.sh`
   - Le script installe tous les composants et démarre les services

3. **Configuration des alertes email (optionnel)**
   - Éditer `scripts/send-alert-email.sh` avec vos paramètres SMTP

4. **Génération d'alertes de test**
   - Exécuter : `sudo bash scripts/run-tests.sh`
   - Ouvrir Kibana : `http://127.0.0.1:5601`
   - Créer l'index pattern `filebeat-*`



## Documentation détaillée

- [Tests et scénarios d'attaque](docs/tests.md)
- [Règles Snort personnalisées](docs/rules.md)

## Images et preuves

Les captures d'écran des tests et emails reçus sont disponibles dans le dossier `images/`.
