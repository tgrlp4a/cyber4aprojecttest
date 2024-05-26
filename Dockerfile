# Étape 1: Construire Nginx dans une image Debian intermédiaire
FROM debian:buster as build

# Installer Nginx et nettoyer après installation pour garder l'image légère
RUN apt-get update && \
    apt-get install -y nginx && \
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
    chown -R 65532:65532 /var/lib/nginx && \
    chown -R 65532:65532 /var/log/nginx && \
    chown -R 65532:65532 /var/run/nginx && \
    chown -R 65532:65532 /var/www/html

# Créer le fichier PID avec les bonnes permissions
RUN touch /var/run/nginx.pid && \
    chown 65532:65532 /var/run/nginx.pid

# Vérifier les dépendances de Nginx
RUN ldd /usr/sbin/nginx

# Étape 2: Préparer l'image distroless pour exécuter Nginx
FROM gcr.io/distroless/cc-debian12

# Copier l'exécutable Nginx et les fichiers nécessaires
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

# Copier les bibliothèques nécessaires
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

# Changer l'utilisateur de l'image Docker pour nonroot
USER nonroot

# Exposer le port sur lequel Nginx écoute
EXPOSE 80

# Utiliser un tableau pour CMD car distroless n'a pas de shell
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]
