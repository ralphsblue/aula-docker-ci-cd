# Roteiro da parte prática

> [!NOTE]
> As etapas 1, 2, 3 e 5 (até a imagem no GHCR) já funcionam.
> A etapa 4 e o final da etapa 5 (site atualizando na VPS) dependem do acesso à VPS e estão marcados como **fase 2**.

Repositório: https://github.com/ralphsblue/aula-docker-ci-cd

## Antes da aula

- [ ] Fazer um ensaio completo, do começo ao fim, no mesmo notebook e na mesma rede da aula.
- [ ] Baixar antes as imagens usadas, para não depender da internet da faculdade:
  ```sh
  docker pull nginx:1.30.7-alpine
  docker pull caddy:2.11.9-alpine
  npm install -g htmlhint@1.9.2
  ```
- [ ] Conferir que o pacote no GHCR está **público** (ele herda a visibilidade do repositório, que é público).
  Teste sem login: `docker logout ghcr.io && docker pull ghcr.io/ralphsblue/aula-docker-ci-cd:latest`.
  Se falhar: GitHub → seu perfil → Packages → `aula-docker-ci-cd` → Package settings → Change visibility → Public.
- [ ] Tirar prints (ou gravar a tela) de um run do CI com ❌, um com ✅ e um do CD, para o plano B.
- [ ] Deixar abertos: o VS Code no repositório, o terminal, a aba Actions do GitHub e o site.
- [ ] Voltar a `main` para o ponto de partida (o ensaio deixa workflows nela).
  A tag `inicio-aula` marca esse ponto:
  ```sh
  git checkout main
  git reset --hard inicio-aula
  git push --force origin main
  ```
  > [!WARNING]
  > `git push --force` reescreve a `main` no GitHub e descarta o que foi feito no ensaio.
  > As branches `etapa-ci` e `etapa-cd` não são afetadas.

## Etapa 1: mostrar o projeto

**Objetivo:** a turma entender o que vai para dentro da imagem.

1. Mostrar a pasta `site/` e abrir o `index.html` no navegador direto (sem Docker): "é só um site comum".
2. Abrir o `Dockerfile` e explicar linha por linha.
   Pontos-chave:
   - versão fixada no `FROM` (nada de `latest`);
   - cada instrução é uma camada;
   - os `ARG` ficam no fim por causa do cache.
3. Abrir o `.dockerignore`: o que não entra no build.
4. Abrir o `docker-compose.yml`: o mesmo que um `docker run -p 8080:80`, só que escrito em arquivo.

## Etapa 2: rodar local com Docker

**Objetivo:** ver o ciclo Dockerfile → imagem → container funcionando.

```sh
docker compose up --build -d
docker ps                      # mostrar a coluna STATUS: (healthy)
```

Abrir http://localhost:8080.
Mostrar o rodapé: `Versão do deploy: dev · build em local`.

**Mostrar o cache de camadas:**

```sh
docker compose build           # tudo CACHED: nada mudou
```

Mudar o `Olá, turma!` no `site/index.html` e buildar de novo:

```sh
docker compose up --build -d   # o FROM vem do cache, o COPY e o RUN rodam de novo
```

**Mostrar o build arg:**

```sh
docker build --build-arg GIT_SHA=teste123 -t aula-docker .
docker run --rm -p 8081:80 aula-docker
```

Abrir http://localhost:8081: o rodapé mostra `teste123`.

Outros comandos para mostrar: `docker images`, `docker logs <container>`, `docker exec -it <container> sh`.

Para encerrar: `docker compose down`.

## Etapa 3: CI ao vivo

**Objetivo:** um robô testa todo PR antes de entrar na `main`.

1. Explicar o que é CI (pode usar a seção CI/CD do próprio site).
2. Rodar os testes na mão primeiro, para a turma ver o que vamos automatizar:
   ```sh
   npx htmlhint site/
   docker build -t aula-docker:teste .
   bash scripts/teste-fumaca.sh aula-docker:teste
   ```
3. Criar `.github/workflows/ci.yml` digitando ao vivo.
   Se travar, traga o arquivo pronto:
   ```sh
   git fetch origin
   git checkout origin/etapa-ci -- .github/workflows/ci.yml
   ```
4. Commit e push na `main`:
   ```sh
   git add .github/workflows/ci.yml
   git commit -m "ci: add CI workflow"
   git push
   ```
5. Abrir a aba **Actions** e acompanhar o run ao vivo: cada passo do YAML vira um passo na tela.

**Quebrar o CI de propósito:**

```sh
git checkout -b quebra-ci
```

No `site/index.html`, mudar o título `O que é Docker?` para `O que é o Docker`.

```sh
git commit -am "Muda o título"
git push -u origin quebra-ci
gh pr create --fill
```

No PR: o passo **Teste de fumaça** fica ❌ com a mensagem `O texto "O que é Docker?" não foi encontrado na página`.
Mostrar o log, explicar que a `main` está protegida desse erro.

Corrigir (voltar o título), commit, push: o PR fica ✅.
Fazer o merge.

Outra forma de quebrar: apagar um `</div>` do `index.html`, e o passo **Validar o HTML** fica ❌.

## Etapa 4: deploy manual (fase 2)

**Objetivo:** a turma sentir a dor de fazer deploy na mão.

"Quero subir uma atualização no ar."
Mudar o `Olá, turma!`, e então fazer tudo na mão:

```sh
# 1. login no registry (com um Personal Access Token com permissão write:packages)
echo "$PAT" | docker login ghcr.io -u ralphsblue --password-stdin

# 2. buildar com a versão
docker build \
  --build-arg GIT_SHA="$(git rev-parse --short HEAD)" \
  --build-arg BUILD_DATE="$(date '+%d/%m/%Y %H:%M')" \
  -t ghcr.io/ralphsblue/aula-docker-ci-cd:latest .

# 3. publicar
docker push ghcr.io/ralphsblue/aula-docker-ci-cd:latest

# 4. copiar os arquivos para a VPS
scp -i ~/.ssh/aula-deploy docker-compose.prod.yml Caddyfile deploy@IP_DA_VPS:aula-docker/

# 5. entrar na VPS e atualizar
ssh -i ~/.ssh/aula-deploy deploy@IP_DA_VPS
cd aula-docker
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

Abrir o site: o SHA no rodapé mudou.
Perguntar à turma: "e se eu esquecer um passo? e se eu buildar sem rodar os testes? e se forem 10 deploys por dia?"

## Etapa 5: CD ao vivo

**Objetivo:** o mesmo deploy da etapa 4, mas sozinho, a cada merge na `main`.

1. Criar `.github/workflows/cd.yml` digitando ao vivo.
   Mostrar que cada passo é um comando da etapa 4.
   Se travar:
   ```sh
   git checkout origin/etapa-cd -- .github/workflows/cd.yml
   ```
2. Commit e push na `main`.
3. Pedir para um aluno (ou você mesmo) mudar o `Olá, turma!` em uma branch e abrir um PR.
4. CI ✅ no PR → merge.
5. Na aba **Actions**: o CI roda na `main` e, quando termina, dispara o **CD** sozinho.
6. Abrir o pacote no GHCR (GitHub → Packages): aparecem as tags `latest` e o SHA do commit.
7. **(fase 2)** Abrir o site na VPS: a frase nova está lá e o rodapé mostra o SHA novo.

Até a VPS ficar pronta, dá para mostrar o passo 7 rodando a "produção" no próprio notebook:

```sh
cat > .env << 'EOF'
IMAGE=ghcr.io/ralphsblue/aula-docker-ci-cd:latest
DOMAIN=localhost
EOF
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

Abrir https://localhost (o navegador avisa que o certificado é local; pode aceitar).
Para encerrar: `docker compose -f docker-compose.prod.yml down`.

## Plano B: a internet caiu

- **Etapas 1 e 2** funcionam sem internet, desde que as imagens tenham sido baixadas antes (veja "Antes da aula").
- **Etapa 3:** rodar os mesmos passos do CI na mão (`htmlhint`, `docker build`, `teste-fumaca.sh`) e quebrar o teste localmente.
  Mostrar os prints do run com ❌ e com ✅ no GitHub.
- **Etapas 4 e 5:** mostrar os YAMLs, explicar passo a passo e usar os prints ou a gravação do ensaio.
- Se só o Wi-Fi da faculdade cair: roteador do celular costuma resolver.
