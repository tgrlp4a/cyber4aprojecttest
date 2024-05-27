FROM debian:buster-slim

# Installer les dépendances nécessaires, Nginx, Wazuh, Elastic Agent, et autres utilitaires
RUN apt-get update && apt-get install -y \
    nginx wget lsb-release procps curl libcap2-bin net-tools psmisc && \
    wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.7.3-1_amd64.deb && \
    WAZUH_MANAGER='192.168.9.11' dpkg -i ./wazuh-agent_4.7.3-1_amd64.deb && \
    curl -L -O https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-8.12.2-linux-x86_64.tar.gz && \
    tar xzvf elastic-agent-8.12.2-linux-x86_64.tar.gz && \
    mv elastic-agent-8.12.2-linux-x86_64 /usr/share/elastic-agent && \
    rm elastic-agent-8.12.2-linux-x86_64.tar.gz && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

# Créer les répertoires nécessaires et ajuster les permissions
RUN mkdir -p /var/lib/nginx/body && \
    mkdir -p /var/lib/nginx/proxy && \
    mkdir -p /var/lib/nginx/fastcgi && \
    mkdir -p /var/lib/nginx/uwsgi && \
    mkdir -p /var/lib/nginx/scgi && \
    mkdir -p /var/log/nginx && \
    mkdir -p /var/run/nginx && \
    chown -R www-data:www-data /var/lib/nginx && \
    chown -R www-data:www-data /var/log/nginx && \
    chown -R www-data:www-data /var/run/nginx && \
    chown -R www-data:www-data /var/www/html && \
    touch /var/run/nginx.pid && \
    chown www-data:www-data /var/run/nginx.pid && \
    groupadd -r wazuh || true && useradd -r -g wazuh wazuh || true && \
    chmod -R 755 /var/ossec && \
    chmod +x /etc/init.d/wazuh-agent && \
    chown -R wazuh:wazuh /var/ossec && \
    mkdir -p /usr/share/elastic-agent/data/tmp && \
    chown -R root:root /usr/share/elastic-agent && \
    chmod -R 755 /usr/share/elastic-agent

# Copier les fichiers statiques de votre site dans le conteneur
COPY ./static /var/www/html

# Copier la configuration Nginx personnalisée
COPY ./conf/nginx.conf /etc/nginx/nginx.conf

# Copier le script de démarrage
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Utiliser root pour exécution initiale
USER root

# Exposer le port sur lequel Nginx écoute
EXPOSE 80

# Définir le point d'entrée
ENTRYPOINT ["/usr/local/bin/start.sh"]

# Commande par défaut
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]
