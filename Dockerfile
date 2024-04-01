# Étape 1: Construire Nginx dans une image Debian intermédiaire
FROM debian:buster as build

# Installer Nginx et nettoyer après installation pour garder l'image légère
RUN apt-get update && \
    apt-get install -y nginx && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

# Étape 2: Préparer l'image distroless pour exécuter Nginx
FROM gcr.io/distroless/base-debian12

# Copier l'exécutable Nginx et les fichiers nécessaires
COPY --from=build /usr/sbin/nginx /usr/sbin/nginx
COPY --from=build /etc/nginx /etc/nginx
COPY --from=build /var/log/nginx /var/log/nginx
COPY --from=build /var/www/html /var/www/html

# Copier les fichiers statiques de votre site dans le conteneur
COPY ./static /var/www/html

# (Optionnel) Copier la configuration Nginx personnalisée si nécessaire
COPY ./nginx.conf /etc/nginx/nginx.conf

# Exposer le port sur lequel Nginx écoute
EXPOSE 80

# Utiliser un tableau pour CMD car distroless n'a pas de shell
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]