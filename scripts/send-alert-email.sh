#!/bin/bash
# Script d'envoi d'alertes email automatique

# Configuration email GMX
SMTP_SERVER="smtp.gmx.com"
SMTP_PORT="465"
FROM_EMAIL="cyber.test@gmx.fr"
TO_EMAIL="sbcfifam2@gmx.fr"
EMAIL_PASSWORD="Cyberprojet123+"

# Lire le message depuis stdin
MESSAGE=$(cat)

# Créer le contenu de l'email avec encodage UTF-8
SUBJECT="[SIEM] Detection d'intrusion - $(date '+%Y-%m-%d %H:%M:%S')"
BODY="
*** ALERTE DE SECURITE DETECTEE ***

Details de l'alerte:
$MESSAGE
"

# Envoyer l'email via curl et SMTP GMX avec encodage UTF-8
curl -s --ssl-reqd \
    --url "smtps://$SMTP_SERVER:$SMTP_PORT" \
    --user "$FROM_EMAIL:$EMAIL_PASSWORD" \
    --mail-from "$FROM_EMAIL" \
    --mail-rcpt "$TO_EMAIL" \
    --upload-file - <<< "From: $FROM_EMAIL
To: $TO_EMAIL
Subject: $SUBJECT
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 8bit

$BODY" > /dev/null 2>&1