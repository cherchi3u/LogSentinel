#!/usr/bin/env bash

# Script de tests d'intrusion pour valider le système SIEM
# On lance 5 scénarios d'attaque pour générer des alertes et tester la détection

# On installe les outils nécessaires pour les tests d'intrusion
# nmap pour scanner les ports, hydra pour les attaques par force brute
echo "[+] Installation des outils de test..."
apt update
apt install -y nmap hydra

# On crée le dossier et les fichiers pour stocker les tests pour hydra
mkdir -p "/opt/siem/tests"
echo "root" > /opt/siem/tests/users.txt 2>/dev/null || true
echo "toor" > /opt/siem/tests/passwords.txt 2>/dev/null || true

echo "=== LANCEMENT DES TESTS ==="

# On scanne les ports ouverts sur localhost pour détecter les services
# -sS : scan SYN (plus discret), -p22,80,3306 : ports SSH, HTTP, MySQL
echo "[1] Scan de ports..."
nmap -sS -p22,80,3306 "127.0.0.1"

# On configure DVWA pour les tests web
# DVWA est une application volontairement vulnérable
echo "[DVWA] Configuration de DVWA..."
BASE="http://127.0.0.1"
JAR="/tmp/dvwa.cookies"

# Fonction pour récupérer les tokens de sécurité CSRF de DVWA
# Ces tokens sont obligatoires pour chaque requête pour éviter les attaques CSRF
get_token() {
  curl -s -L -b "$JAR" -c "$JAR" "$1" | grep -oP "user_token' value='\K[^']+" || true
}

# On configure DVWA complètement : login, création de la base de données, et niveau de sécurité faible
# Sans cette configuration DVWA serait en mode sécurisé et les tests ne fonctionneraient pas
echo "[DVWA] Login, setup et configuration security=low..."
curl -s -L -c "$JAR" "$BASE/login.php" >/dev/null
TOKEN=$(get_token "$BASE/login.php")
curl -s -L -b "$JAR" -c "$JAR" -d "username=admin&password=password&Login=Login&user_token=$TOKEN" "$BASE/login.php" >/dev/null
TOKEN=$(get_token "$BASE/setup.php")
curl -s -L -b "$JAR" -c "$JAR" -d "create_db=Create+%2F+Reset+Database&user_token=$TOKEN" "$BASE/setup.php" >/dev/null
TOKEN=$(get_token "$BASE/security.php")
curl -s -L -b "$JAR" -c "$JAR" -d "security=low&seclev_submit=Submit&user_token=$TOKEN" "$BASE/security.php" >/dev/null

# On teste l'injection SQL 
echo "[2] Test SQL injection (auth)..."
curl -s -b "$JAR" "$BASE/vulnerabilities/sqli/?Submit=Submit&id=1%20UNION%20SELECT%201,2" -o /dev/null || true

# On teste le Local File Inclusion (LFI) 
echo "[3] Test LFI..."
curl -s -b "$JAR" "$BASE/vulnerabilities/fi/?page=../../../../etc/passwd" -o /dev/null || true

# On teste le brute-force SSH avec hydra
echo "[4] Brute-force SSH (démo rapide)..."
hydra -L "/opt/siem/tests/users.txt" -P "/opt/siem/tests/passwords.txt" -t 2 -f ssh://127.0.0.1 || true

# On teste l'injection de commandes
echo "[5] Command injection..."
curl -s -b "$JAR" "$BASE/vulnerabilities/fi/include.php?test=1" -o /dev/null || true

echo "=== TESTS TERMINÉS ==="
echo "Ouvrez Kibana : http://127.0.0.1:5601"
echo "Dans Discover, créez l'index pattern filebeat-* et cherchez les alertes."
