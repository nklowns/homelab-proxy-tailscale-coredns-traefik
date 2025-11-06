FROM alpine:latest

# Instala dependências básicas
RUN apk add --no-cache bash curl socat openssl

# Baixa e instala o acme.sh no diretório esperado
RUN curl https://get.acme.sh | sh

# Copia seu entrypoint para dentro do container
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
