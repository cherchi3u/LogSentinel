#!/usr/bin/env bash

# On met à jour la liste des paquets et on installe les outils de base nécessaires
apt update
apt install -y curl ca-certificates gnupg lsb-release apt-transport-https software-properties-common openssh-server mailutils

echo "=== DEBUT setup.sh ==="

# On installe Docker si il n'est pas déjà présent
# On vérifie d'abord avec command -v pour éviter de réinstaller inutilement
if ! command -v docker >/dev/null 2>&1; then
  echo "###### Installation de Docker..."
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt update
  apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

# On installe les outils de surveillance : syslog-ng pour collecter les logs, snort pour détecter les intrusions, filebeat pour envoyer les logs vers Elasticsearch
echo "###### Installation syslog-ng, snort et filebeat..."

# On installe syslog-ng et Snort
echo "###### Installation de syslog-ng et Snort..."
# On préconfigure Snort pour éviter qu'il demande quel est notre réseau local
# On répond "any" pour qu'il surveille tout le trafic y compris localhost 127.0.0.1
echo "snort snort/home_net string any" | debconf-set-selections
# DEBIAN_FRONTEND=noninteractive empêche les prompts interactifs pendant l'installation
DEBIAN_FRONTEND=noninteractive apt install -y syslog-ng snort

# On installe Filebeat pour envoyer les logs vers Elasticsearch
echo "###### Installation de Filebeat..."
curl -fsSL "https://artifacts.elastic.co/GPG-KEY-elasticsearch" | gpg --dearmor | tee "/usr/share/keyrings/elasticsearch-keyring.gpg" >/dev/null
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-8.x.list > /dev/null
apt update
apt install -y filebeat

# On active le serveur SSH pour les tests d'intrusion
echo "###### Installation et activation de SSH..."
systemctl enable --now ssh

# On lance nos applications dans Docker : Elasticsearch pour stocker les logs, Kibana pour les visualiser, DVWA comme serveur de test
echo "###### Lancement docker-compose..."
cd "/opt/siem/deploy"
docker compose -f docker-compose-single.yml up -d

# On configure les règles Snort pour détecter les intrusions
echo "###### Déploiement des règles Snort..."
# On crée le dossier pour les règles personnalisées
mkdir -p "/etc/snort/rules"
# On copie nos règles personnalisées
cp "/opt/siem/snort/local.rules" "/etc/snort/rules/"

# On force Snort à surveiller tout le trafic (y compris localhost 127.0.0.1)
sed -i 's/^ipvar\s\+HOME_NET.*/ipvar HOME_NET any/' /etc/snort/snort.conf
# On nettoie les anciennes configurations pour éviter les doublons
sed -i '/^# Configuration de sortie pour syslog-ng$/,$d' /etc/snort/snort.conf

# On ajoute notre configuration finale à Snort
tee -a /etc/snort/snort.conf > /dev/null << 'EOF'
# Configuration de sortie pour syslog-ng
output alert_syslog: LOG_AUTH LOG_ALERT
output alert_fast: /var/log/snort/alert
# On supprime les alertes loopback
# Ces alertes sont normales sur localhost mais génèrent beaucoup de log inutiles
suppress gen_id 1, sig_id 527
suppress gen_id 1, sig_id 528
EOF

# On configure Filebeat pour qu'il envoie les logs vers Elasticsearch
echo "###### Configuration Filebeat..."
cp "/opt/siem/filebeat.yml.template" "/etc/filebeat/filebeat.yml"
systemctl enable --now filebeat

# On configure syslog-ng pour collecter les alertes Snort et les envoyer à Elasticsearch et par email
# syslog-ng ne peut pas déclencher directement le script send-alert-email.sh
# On écrit donc les alertes dans un fichier temporaire /tmp/snort-alerts
# Le script watch-alerts.sh surveille ce fichier et déclenche send-alert-email.sh automatiquement
echo "###### Configuration syslog-ng pour Snort et alertes email..."
tee /etc/syslog-ng/conf.d/snort.conf > /dev/null << EOF
# Configuration syslog-ng pour collecter les logs Snort
source s_snort { 
    file("/var/log/snort/alert*" follow-freq(1) flags(no-parse));
};

# Destination pour Elasticsearch
destination d_snort_elasticsearch { 
    file("/var/log/snort/syslog.out" template("\${ISODATE} \${HOST} snort: \${MESSAGE}\\n"));
};

# Destination pour alertes email - ÉCRIRE dans un fichier temporaire
destination d_snort_email {
    file("/tmp/snort-alerts" template("\${MESSAGE}\\n"));
};

# Logs vers Elasticsearch (tous)
log { 
    source(s_snort); 
    destination(d_snort_elasticsearch); 
};

# Alertes email (TOUTES les alertes Snort)
log {
    source(s_snort);
    destination(d_snort_email);
};
EOF

# On arrête le script de surveillance s'il tourne déjà pour éviter les doublons
pkill -f "watch-alerts.sh" 2>/dev/null || true
# On lance le script de surveillance des alertes en arrière-plan
nohup /opt/siem/scripts/watch-alerts.sh > /dev/null 2>&1 &

# On redémarre syslog-ng pour qu'il prenne en compte notre nouvelle configuration
systemctl restart syslog-ng

# On démarre Snort pour surveiller le trafic réseau
echo "###### Démarrage de Snort..."

# On s'assure qu'aucune instance de snort ne tourne déjà pour éviter les soucis
systemctl stop snort 2>/dev/null || true
pkill -f "snort" 2>/dev/null || true

# On prépare le dossier de logs et on démarre Snort
mkdir -p /var/log/snort
chmod 755 /var/log/snort

# On démarre Snort en mode daemon (arrière-plan) sur l'interface loopback (lo)
snort -i "lo" -c /etc/snort/snort.conf -l /var/log/snort -A fast -k none -D

# On donne les permissions aux fichiers de logs pour que Filebeat puisse les lire
chmod a+r /var/log/snort/* 2>/dev/null || true

echo "=== SETUP TERMINE ==="
echo "Accédez à Kibana : http://127.0.0.1:5601"
echo "Accédez à DVWA   : http://127.0.0.1/"
echo "Lancez les tests d'intrusion à présent : /opt/siem/scripts/run-tests.sh"