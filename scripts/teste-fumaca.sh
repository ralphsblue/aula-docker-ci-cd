#!/usr/bin/env bash
# ------------------------------------------------------------------
# Teste de fumaça: "liga o aparelho e vê se sai fumaça".
# Sobe um container da imagem, acessa a página e confere duas coisas:
#   1) a página responde com status HTTP 200;
#   2) a página contém o texto esperado.
#
# Uso:  scripts/teste-fumaca.sh [imagem]
# Ex.:  docker build -t aula-docker:teste .
#       scripts/teste-fumaca.sh aula-docker:teste
# ------------------------------------------------------------------
set -euo pipefail

IMAGEM="${1:-aula-docker:teste}"
PORTA=8099
URL="http://localhost:${PORTA}/"
NOME_CONTAINER="teste-fumaca"

# Para quebrar o CI de propósito na aula: apague ou mude este título no site/index.html.
TEXTO_ESPERADO="O que é Docker?"

echo "▶ Subindo um container da imagem ${IMAGEM}..."
docker rm -f "$NOME_CONTAINER" > /dev/null 2>&1 || true
docker run -d --name "$NOME_CONTAINER" -p "${PORTA}:80" "$IMAGEM" > /dev/null

# Aconteça o que acontecer, remove o container no final.
trap 'docker rm -f "$NOME_CONTAINER" > /dev/null' EXIT

echo "▶ Esperando o site responder..."
for _ in $(seq 1 10); do
  curl -s -o /dev/null "$URL" && break
  sleep 1
done

echo "▶ Verificando o status HTTP..."
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$URL")
if [ "$STATUS" != "200" ]; then
  echo "❌ Esperava status 200, mas veio ${STATUS}"
  exit 1
fi
echo "✅ Status ${STATUS}"

echo "▶ Procurando o texto \"${TEXTO_ESPERADO}\" na página..."
if ! curl -s "$URL" | grep -qF "$TEXTO_ESPERADO"; then
  echo "❌ O texto \"${TEXTO_ESPERADO}\" não foi encontrado na página"
  exit 1
fi
echo "✅ Texto encontrado"

echo "🎉 Teste de fumaça passou!"
