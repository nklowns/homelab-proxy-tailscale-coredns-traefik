# Persistência do estado do HAProxy (server-state)

Este diretório é montado em `/var/lib/haproxy` dentro do container `docker-socket-proxy` para permitir que o HAProxy salve e recarregue o arquivo de estado de servidores entre reinícios (server-state).

## Arquivos
- `server-state`: arquivo gerenciado pelo HAProxy. Pode iniciar vazio.
