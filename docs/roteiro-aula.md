# Roteiro da parte prática

Repositório: https://github.com/ralphsblue/aula-docker-ci-cd

A VPS precisa estar preparada antes (veja [vps-setup.md](vps-setup.md)).
Nos comandos abaixo, troque `IP_DA_VPS` e `SEU_SUBDOMINIO` pelos valores reais.

## Antes da aula

- [ ] Fazer um ensaio completo, do começo ao fim, no mesmo notebook e na mesma rede da aula.
- [ ] Baixar antes as imagens usadas, para não depender da internet da faculdade:
  ```sh
  docker pull nginx:1.30.7-alpine
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

## Etapa 4: deploy manual

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

# 4. copiar o compose de produção para a VPS
scp -i ~/.ssh/aula-deploy docker-compose.prod.yml deploy@IP_DA_VPS:aula-docker/docker-compose.yml

# 5. entrar na VPS e atualizar
ssh -i ~/.ssh/aula-deploy deploy@IP_DA_VPS
cd aula-docker
docker compose pull
docker compose up -d
exit
```

Abrir `https://SEU_SUBDOMINIO.duckdns.org`: o SHA no rodapé mudou.
Perguntar à turma: "e se eu esquecer um passo? e se eu buildar sem rodar os testes? e se forem 10 deploys por dia?"

## Etapa 5: CD ao vivo

**Objetivo:** o mesmo deploy da etapa 4, mas sozinho, a cada merge na `main`.

1. Criar `.github/workflows/cd.yml` colando os blocos de [CD em blocos para colar](#cd-em-blocos-para-colar), um de cada vez, explicando cada um.
   Se algo der errado:
   ```sh
   git checkout origin/etapa-cd -- .github/workflows/cd.yml
   ```
2. Commit e push na `main`.
3. Pedir para um aluno (ou você mesmo) mudar o `Olá, turma!` em uma branch e abrir um PR.
4. CI ✅ no PR → merge.
5. Na aba **Actions**: o CI roda na `main` e, quando termina, dispara o **CD** sozinho.
6. Abrir o pacote no GHCR (GitHub → Packages): aparecem as tags `latest` e o SHA do commit.
7. O job **deploy** entra na VPS, atualiza o container e confere o site: o passo **Conferir a versão no ar** fica ✅.
8. Abrir `https://SEU_SUBDOMINIO.duckdns.org` (pedir para a turma abrir no celular): a frase nova está lá e o rodapé mostra o SHA novo.

Se a VPS estiver fora do ar, dá para mostrar o passo 8 rodando a "produção" no próprio notebook:

```sh
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

Abrir http://localhost:8180.
Para encerrar: `docker compose -f docker-compose.prod.yml down`.

## CD em blocos para colar

Em vez de digitar o CD inteiro, cole um bloco por vez e explique.
Cada bloco corresponde a um comando do deploy manual da etapa 4.
Dica: deixe os comandos da etapa 4 projetados ao lado e vá riscando cada um conforme cola o bloco equivalente.

Colados em sequência, os blocos formam exatamente o `cd.yml` da branch `etapa-cd`.

> [!TIP]
> No VS Code, cole sempre com o cursor no **início de uma linha vazia** (coluna 0).
> Se a indentação sair torta, desfaça (`Ctrl+Z`) e cole com `Ctrl+Shift+V`, ou desligue `editor.formatOnPaste` e `editor.autoIndent` para esta aula.

### Bloco 1: cabeçalho e gatilho

**Deploy manual:** "só faço o deploy depois que os testes passaram".

**O que falar:**
- o CD não roda sozinho em todo push: ele espera o workflow **CI** terminar na `main`;
- `permissions`: o token automático do GitHub pode ler o código e publicar pacotes (imagens), nada mais.

```yaml
# ------------------------------------------------------------------
# CD - Entrega Contínua
# Quando o CI termina com sucesso na main, este workflow:
#   1) builda a imagem com a versão (SHA do commit) no rodapé;
#   2) publica a imagem no GitHub Container Registry (GHCR);
#   3) entra na VPS por SSH e atualiza o container;
#   4) confere se a versão nova está no ar.
# ------------------------------------------------------------------
name: CD

# QUANDO rodar: depois que o workflow "CI" terminar na main.
on:
  workflow_run:
    workflows: [CI]
    types: [completed]
    branches: [main]

# Permissões do GITHUB_TOKEN: ler o código e publicar pacotes (imagens) no GHCR.
permissions:
  contents: read
  packages: write
```

### Bloco 2: o job e o checkout

**Deploy manual:** `git pull` (pegar o código que vai para o ar).

**O que falar:**
- "terminou" não é "passou": o `if` só deixa seguir quando o CI deu ✅ e foi um push (não um PR);
- o checkout pega **exatamente o commit que o CI testou**, não "o que estiver na main agora".

```yaml
jobs:
  publicar:
    # Só continua se o CI passou (✅) e foi um push na main (não um PR).
    if: >-
      github.event.workflow_run.conclusion == 'success' &&
      github.event.workflow_run.event == 'push'
    runs-on: ubuntu-24.04

    steps:
      # 1) Baixa exatamente o commit que o CI testou.
      - name: Baixar o código
        uses: actions/checkout@v7
        with:
          ref: ${{ github.event.workflow_run.head_sha }}
```

### Bloco 3: nome e versão da imagem

**Deploy manual:** `git rev-parse --short HEAD` e `date`, que viram os `--build-arg`.

**O que falar:**
- o SHA curto é o mesmo que vai aparecer no rodapé do site;
- `$GITHUB_ENV` é como um passo passa variáveis para os próximos.

```yaml
      # 2) Monta o nome da imagem e as informações de versão.
      #    O GHCR exige nome em minúsculas, daí o ",," (bash: converte para minúsculas).
      #    Tudo que vai para $GITHUB_ENV vira variável nos próximos passos.
      - name: Definir nome e versão da imagem
        run: |
          {
            echo "IMAGEM=ghcr.io/${GITHUB_REPOSITORY,,}"
            echo "SHA_CURTO=$(git rev-parse --short=7 HEAD)"
            echo "DATA_BUILD=$(TZ=America/Sao_Paulo date '+%d/%m/%Y %H:%M')"
          } >> "$GITHUB_ENV"
```

### Bloco 4: login no registry

**Deploy manual:** `echo "$PAT" | docker login ghcr.io ...`

**O que falar:**
- no manual eu precisei criar um token (PAT) e guardar no meu notebook;
- aqui o GitHub gera um token temporário sozinho (`GITHUB_TOKEN`), que vale só durante este run.

```yaml
      # 3) Faz login no GHCR com o token automático do GitHub (sem senha nossa).
      - name: Login no GHCR
        run: echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u "${{ github.actor }}" --password-stdin
```

### Bloco 5: build

**Deploy manual:** `docker build --build-arg ... -t ... .`

**O que falar:**
- é o mesmo comando da etapa 4, letra por letra;
- duas tags: `latest` (a mais recente) e o SHA (permite saber e voltar a qualquer versão).

```yaml
      # 4) Builda a imagem passando a versão como build arg (veja os ARG no Dockerfile).
      #    Duas tags: "latest" (a mais recente) e o SHA (para saber qual commit é).
      #    A label "source" liga o pacote do GHCR a este repositório.
      - name: Buildar a imagem
        run: |
          docker build \
            --build-arg GIT_SHA="$SHA_CURTO" \
            --build-arg BUILD_DATE="$DATA_BUILD" \
            --label "org.opencontainers.image.source=https://github.com/${GITHUB_REPOSITORY}" \
            -t "$IMAGEM:latest" \
            -t "$IMAGEM:$SHA_CURTO" \
            .
```

### Bloco 6: publicar

**Deploy manual:** `docker push`

**O que falar:**
- depois deste passo, qualquer máquina do mundo consegue dar `docker pull` na imagem nova;
- a linha do `$GITHUB_STEP_SUMMARY` escreve um resumo na página do run.

```yaml
      # 5) Envia as duas tags para o GHCR.
      - name: Publicar no GHCR
        run: |
          docker push "$IMAGEM:latest"
          docker push "$IMAGEM:$SHA_CURTO"
          echo "✅ Publicado: $IMAGEM:$SHA_CURTO" >> "$GITHUB_STEP_SUMMARY"
```

### Bloco 7: o job de deploy e o SSH

**Deploy manual:** a chave `~/.ssh/aula-deploy` que eu uso no `ssh -i`.

**O que falar:**
- `needs: publicar`: só faz deploy se a imagem foi publicada;
- os dados da VPS vêm dos **secrets** do repositório (Settings → Secrets and variables → Actions): ninguém vê o valor, nem nos logs;
- a chave privada é gravada no lugar padrão (`~/.ssh/id_ed25519`), então `ssh` e `scp` funcionam sem `-i`;
- `ssh-keyscan` é o "yes" que a gente digita na primeira conexão SSH.

```yaml
  deploy:
    # Só roda depois que o job "publicar" terminar com sucesso.
    needs: publicar
    runs-on: ubuntu-24.04

    # Dados da VPS, cadastrados em Settings → Secrets and variables → Actions.
    env:
      VPS_HOST: ${{ secrets.VPS_HOST }}
      VPS_USER: ${{ secrets.VPS_USER }}
      VPS_SSH_KEY: ${{ secrets.VPS_SSH_KEY }}
      DOMAIN: ${{ secrets.DOMAIN }}

    steps:
      # 1) Baixa o código de novo: precisamos do docker-compose.prod.yml.
      - name: Baixar o código
        uses: actions/checkout@v7
        with:
          ref: ${{ github.event.workflow_run.head_sha }}

      # 2) Prepara o SSH: grava a chave privada e confia na VPS (known_hosts).
      - name: Preparar o SSH
        run: |
          mkdir -p ~/.ssh
          printf '%s\n' "$VPS_SSH_KEY" > ~/.ssh/id_ed25519
          chmod 600 ~/.ssh/id_ed25519
          ssh-keyscan -H "$VPS_HOST" >> ~/.ssh/known_hosts
```

### Bloco 8: copiar, atualizar e conferir

**Deploy manual:** `scp` + `ssh` + `docker compose pull` + `docker compose up -d` + abrir o site e olhar o rodapé.

**O que falar:**
- são os mesmos comandos da etapa 4, só que sem eu digitar;
- o último passo é o "abrir o site e olhar o rodapé" automatizado: se o SHA novo não aparecer, o CD fica ❌.

```yaml
      # 3) Copia o compose de produção para a VPS (com o nome docker-compose.yml).
      - name: Copiar o compose para a VPS
        run: |
          ssh "$VPS_USER@$VPS_HOST" "mkdir -p aula-docker"
          scp docker-compose.prod.yml "$VPS_USER@$VPS_HOST:aula-docker/docker-compose.yml"

      # 4) Na VPS: baixa a imagem nova e recria o container.
      - name: Atualizar o container na VPS
        run: ssh "$VPS_USER@$VPS_HOST" "cd aula-docker && docker compose pull && docker compose up -d"

      # 5) Confere no site público se o rodapé já mostra o SHA deste commit.
      - name: Conferir a versão no ar
        run: |
          SHA_CURTO=$(git rev-parse --short=7 HEAD)
          for tentativa in $(seq 1 10); do
            if curl -fsS "https://$DOMAIN/" | grep -qF "$SHA_CURTO"; then
              echo "✅ https://$DOMAIN está na versão $SHA_CURTO" | tee -a "$GITHUB_STEP_SUMMARY"
              exit 0
            fi
            echo "Tentativa $tentativa: a versão nova ainda não apareceu, esperando..."
            sleep 3
          done
          echo "❌ O site não mostrou a versão $SHA_CURTO"
          exit 1
```

## Plano B: a internet caiu

- **Etapas 1 e 2** funcionam sem internet, desde que as imagens tenham sido baixadas antes (veja "Antes da aula").
- **Etapa 3:** rodar os mesmos passos do CI na mão (`htmlhint`, `docker build`, `teste-fumaca.sh`) e quebrar o teste localmente.
  Mostrar os prints do run com ❌ e com ✅ no GitHub.
- **Etapas 4 e 5:** mostrar os YAMLs, explicar passo a passo e usar os prints ou a gravação do ensaio.
- Se só o Wi-Fi da faculdade cair: roteador do celular costuma resolver.
