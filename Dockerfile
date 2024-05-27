# Étape 1: Construire Nginx dans une image Debian intermédiaire
FROM debian:buster as build

# Installer Nginx, dépendances Wazuh et Wazuh
RUN apt-get update && \
    apt-get install -y nginx wget lsb-release procps

# Télécharger et installer l'agent Wazuh
RUN wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.7.3-1_amd64.deb -O /wazuh-agent_4.7.3-1_amd64.deb && \
    WAZUH_MANAGER='192.168.9.11' dpkg -i /wazuh-agent_4.7.3-1_amd64.deb && \
    rm /wazuh-agent_4.7.3-1_amd64.deb

# Nettoyer après installation pour garder l'image légère
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

# Créer les répertoires nécessaires et ajuster les permissions
RUN mkdir -p /var/lib/nginx/body /var/lib/nginx/proxy /var/lib/nginx/fastcgi /var/lib/nginx/uwsgi /var/lib/nginx/scgi /var/log/nginx /var/run/nginx && \
    chown -R www-data:www-data /var/lib/nginx /var/log/nginx /var/run/nginx /var/www/html

# Créer le fichier PID avec les bonnes permissions
RUN touch /var/run/nginx.pid && \
    chown www-data:www-data /var/run/nginx.pid

# Vérifier les dépendances de Nginx
RUN ldd /usr/sbin/nginx

# Ajouter un utilisateur et un groupe wazuh si ils n'existent pas déjà
RUN groupadd -r wazuh || true && \
    useradd -r -g wazuh wazuh || true

# Ajuster les permissions des fichiers Wazuh
RUN chmod -R 755 /var/ossec && \
    chmod +x /etc/init.d/wazuh-agent && \
    chown -R wazuh:wazuh /var/ossec

# Étape 2: Préparer l'image finale basée sur Debian
FROM debian:buster-slim

# Installer les dépendances nécessaires
RUN apt-get update && apt-get install -y procps && \
    rm -rf /var/lib/apt/lists/*

# Copier l'exécutable Nginx et les fichiers nécessaires depuis l'image de build
COPY --from=build /usr/sbin/nginx /usr/sbin/nginx
COPY --from=build /etc/nginx /etc/nginx
COPY --from=build /var/log/nginx /var/log/nginx
COPY --from=build /var/lib/nginx /var/lib/nginx
COPY --from=build /var/run/nginx /var/run/nginx
COPY --from=build /var/run/nginx.pid /var/run/nginx.pid
COPY --from=build /var/www/html /var/www/html

# Copier les fichiers statiques de votre site dans le conteneur
COPY ./static /var/www/html

# Copier la configuration Nginx personnalisée
COPY ./conf/nginx.conf /etc/nginx/nginx.conf

# Copier l'agent Wazuh et ses bibliothèques
COPY --from=build /var/ossec /var/ossec
COPY --from=build /etc/init.d/wazuh-agent /etc/init.d/wazuh-agent
COPY --from=build /lib/x86_64-linux-gnu/libcrypt.so.1 /lib/x86_64-linux-gnu/libcrypt.so.1
COPY --from=build /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6
COPY --from=build /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/libpthread.so.0
COPY --from=build /lib/x86_64-linux-gnu/libdl.so.2 /lib/x86_64-linux-gnu/libdl.so.2
COPY --from=build /lib/x86_64-linux-gnu/libpcre.so.3 /lib/x86_64-linux-gnu/libpcre.so.3
COPY --from=build /lib/x86_64-linux-gnu/libz.so.1 /lib/x86_64-linux-gnu/libz.so.1
COPY --from=build /usr/lib/x86_64-linux-gnu/libssl.so.1.1 /usr/lib/x86_64-linux-gnu/libssl.so.1.1
COPY --from=build /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1 /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1
COPY --from=build /lib/x86_64-linux-gnu/libm.so.6 /lib/x86_64-linux-gnu/libm.so.6
COPY --from=build /lib/x86_64-linux-gnu/libgcc_s.so.1 /lib/x86_64-linux-gnu/libgcc_s.so.1
COPY --from=build /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2

# Ajouter un utilisateur et un groupe wazuh si ils n'existent pas déjà
RUN groupadd -r wazuh || true && \
    useradd -r -g wazuh wazuh || true

# Ajuster les permissions des fichiers Wazuh et démarrer le service Wazuh
RUN chown -R wazuh:wazuh /var/ossec && \
    chmod +x /etc/init.d/wazuh-agent

# Copier le script de démarrage
COPY /start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Utiliser root pour exécution initiale
USER root

# Exposer le port sur lequel Nginx écoute
EXPOSE 80

# Définir le point d'entrée
ENTRYPOINT ["/usr/local/bin/start.sh"]

# Commande par défaut
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]
