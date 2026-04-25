# Official nginx:alpine does not include the openssl(1) CLI. The
# docker-entrypoint.sh bootstrap (self-signed cert on cold start) needs
# it. Runtime apk install is slow and needs network; bake openssl in.
FROM nginx:1.27-alpine
RUN apk add --no-cache openssl
