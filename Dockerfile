# ------------------------------------------------------------------
# Dockerfile: a "receita" da imagem do nosso site.
# Cada instrução abaixo gera uma CAMADA da imagem.
# Se uma camada não mudou desde o último build, o Docker reaproveita (cache).
# ------------------------------------------------------------------

# 1) Imagem base: o servidor web nginx rodando em Alpine Linux (bem pequena).
#    A versão é fixada: o build de hoje e o de daqui a um mês usam a mesma base.
#    Nada de "latest", que muda sem avisar.
FROM nginx:1.30.7-alpine

# 2) Copia os arquivos do site para a pasta que o nginx serve.
#    Se nenhum arquivo em site/ mudou, esta camada vem do cache.
COPY site/ /usr/share/nginx/html/

# 3) Informações do build, passadas com --build-arg no "docker build".
#    Os valores depois do "=" são o padrão quando ninguém passa nada (build local).
#    Ficam no FIM do arquivo de propósito: mudam a cada commit,
#    então tudo o que vem antes continua aproveitando o cache.
ARG GIT_SHA=dev
ARG BUILD_DATE=local

# 4) Troca os marcadores __GIT_SHA__ e __BUILD_DATE__ do rodapé pelos valores reais.
#    É assim que o site mostra qual versão está no ar.
RUN sed -i \
      -e "s|__GIT_SHA__|${GIT_SHA}|g" \
      -e "s|__BUILD_DATE__|${BUILD_DATE}|g" \
      /usr/share/nginx/html/index.html

# 5) Documenta a porta em que o nginx escuta dentro do container.
#    (Quem publica a porta para fora é o "-p" ou o "ports:" do Compose.)
EXPOSE 80

# 6) Healthcheck: a cada 30s o Docker pergunta "o site está respondendo?".
#    O resultado aparece na coluna STATUS do "docker ps": (healthy) ou (unhealthy).
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://127.0.0.1/ || exit 1

# Não precisamos de CMD: a imagem do nginx já sabe como iniciar o servidor.
