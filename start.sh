#!/bin/sh

# Fonction pour vérifier et libérer un port spécifique
free_port() {
  local port=$1
  echo "Vérification de l'utilisation du port $port..."
  if netstat -tuln | grep -q ":$port"; then
    echo "Port $port est utilisé. Tentative de libération..."
    fuser -k $port/tcp
    sleep 5  # Attendre que le port soit libéré
    if netstat -tuln | grep -q ":$port"; then
      echo "Impossible de libérer le port $port. Sortie."
      exit 1
    else
      echo "Port $port libéré avec succès."
    fi
  else
    echo "Port $port est libre."
  fi
}

# Installer psmisc si nécessaire
if ! command -v fuser >/dev/null 2>&1; then
  echo "Installation de psmisc pour utiliser fuser..."
  apt-get update && apt-get install -y psmisc
fi

# Libérer le port 6789 si nécessaire
free_port 6789

# Démarrer l'agent Wazuh
echo "Démarrage de l'agent Wazuh..."
/etc/init.d/wazuh-agent start

# Vérifier si l'agent Wazuh a démarré avec succès
if [ $? -ne 0 ]; then
  echo "Échec du démarrage de l'agent Wazuh"
  echo "Vérification des journaux de Wazuh pour les erreurs..."
  tail -n 50 /var/ossec/logs/ossec.log
  exit 1
fi

# Initialiser l'agent Elastic
echo "Initialisation de l'agent Elastic..."
/usr/share/elastic-agent/elastic-agent install -f

# Démarrer l'agent Elastic
echo "Démarrage de l'agent Elastic..."
/usr/share/elastic-agent/elastic-agent run &

# Attendre la création de la socket de contrôle de l'agent Elastic
echo "Attente de la création de la socket de contrôle de l'agent Elastic..."
sleep 100

# Vérifier si la socket de contrôle de l'agent Elastic a été créée
if [ ! -e /usr/share/elastic-agent/data/tmp/elastic-agent-control.sock ]; then
  echo "Socket de contrôle de l'agent Elastic non trouvée, sortie."
  exit 1
fi

# Enrôler l'agent Elastic avec le jeton correct
ENROLLMENT_TOKEN="RlJUd1VZNEJfZFVqdGliRHNSdDc6NXNOWTJ5b0lTZDZJS253bnNzaHVjdw=="  # Remplacer par votre jeton réel
echo "Enrôlement de l'agent Elastic..."
/usr/share/elastic-agent/elastic-agent enroll --url=https://192.168.9.13:8220 --enrollment-token=$ENROLLMENT_TOKEN --insecure

# Vérifier si l'agent Elastic s'est enrôlé avec succès
if [ $? -ne 0 ]; then
  echo "Échec de l'enrôlement de l'agent Elastic"
  exit 1
fi

# Suivre les journaux de Wazuh en arrière-plan
tail -f /var/ossec/logs/ossec.log &

# Démarrer Nginx
echo "Démarrage de Nginx..."
exec "$@"
