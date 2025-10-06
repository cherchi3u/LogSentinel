#!/bin/bash

# Script de surveillance des alertes Snort
# On surveille le fichier /tmp/snort-alerts en continu et on déclenche l'envoi d'email pour chaque nouvelle alerte

# On crée le fichier s'il n'existe pas
touch /tmp/snort-alerts

# On surveille le fichier et on envoie les alertes
tail -f /tmp/snort-alerts | while read line; do
    if [ ! -z "$line" ] && [ "$line" != "" ]; then
        echo "$line" | /opt/siem/scripts/send-alert-email.sh
    fi
done
