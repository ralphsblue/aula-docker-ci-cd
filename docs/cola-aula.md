# Cola da Aula — Docker + CI/CD (Passo a Passo)

> **Domínio em produção:** https://dockerclass.duckdns.org  
> **Repositório:** https://github.com/ralphsblue/aula-docker-ci-cd  
> **Aba Actions:** https://github.com/ralphsblue/aula-docker-ci-cd/actions

---

## Antes de começar (deixar aberto)

1. **VS Code** aberto nesta pasta (`C:\faculdade\aula-rafael`), com o terminal integrado em **Git Bash**.
2. **Navegador** com 3 abas prontas:
   - `http://localhost:8080`
   - `https://github.com/ralphsblue/aula-docker-ci-cd/actions` *(na visão **All workflows**)*
   - `https://dockerclass.duckdns.org` *(já no ar com o texto original `Olá, turma!`)*

---

## Passo 1 — Subir o projeto no Docker local

Mostrar rapidamente `Dockerfile`, `.dockerignore` e `docker-compose.yml`, depois subir o container:

```sh
docker compose up --build -d
docker ps
```

- Abrir **`http://localhost:8080`**.
- Mostrar o site rodando e o rodapé: `Versão do deploy: dev · build em local`.

---

## Passo 2 — Alterar o código-fonte e mostrar que o Docker NÃO mudou

1. Abrir `site/index.html` e editar a linha 17 (`<h1>Olá, turma!</h1>`), por exemplo:
   ```html
   <h1>Olá, turma de Sistemas!</h1>
   ```
2. Salvar o arquivo e recarregar **`http://localhost:8080`**.
3. **O que mostrar:** a página **não mudou**, porque o `COPY site/ /usr/share/nginx/html/` congelou os arquivos dentro da imagem na hora do build.

---

## Passo 3 — Buildar e subir o container novamente

```sh
docker compose up --build -d
```

- Mostrar no terminal que o `FROM` veio do **`CACHED`** e só o `COPY` e o `RUN` rodaram de novo.
- Recarregar **`http://localhost:8080`** → **agora mudou!**
- **Gancho para CI/CD:** *"Em produção, toda vez que alterarmos o código, não queremos testar na mão, buildar imagem, enviar pro registry, acessar o servidor via SSH e reiniciar o container manualmente."*

*(Não desfaça a alteração do `site/index.html` — ela vai servir para provar a diferença entre CI e CD nos próximos passos!)*

---

## Passo 4 — Explicar CI e trazer o arquivo pronto

Explicar o conceito de **CI (Integração Contínua)** e puxar o workflow pronto:

```sh
git checkout origin/etapa-ci -- .github/workflows/ci.yml
```

Abrir `.github/workflows/ci.yml` no VS Code e explicar linha por linha:
- **`on:`** roda em `pull_request` e em `push` na `main`.
- **`runs-on: ubuntu-24.04`:** máquina virtual limpa do GitHub Actions.
- **Passos:**
  1. `actions/checkout@v7` — baixa o código.
  2. `npx --yes htmlhint@1.9.2 site/` — valida o HTML (`.htmlhintrc`).
  3. `docker build -t aula-docker:teste .` — testa se a imagem builda.
  4. `bash scripts/teste-fumaca.sh aula-docker:teste` — sobe o container e confere HTTP 200 + texto `"O que é Docker?"`.

---

## Passo 5 — Commit + Push (CI verde, SEM deploy em produção)

```sh
git add site/index.html .github/workflows/ci.yml
git commit -m "feat: atualiza saudacao e adiciona CI"
git push
```

1. Abrir **GitHub → Actions → All workflows** e acompanhar o workflow **`CI`** ficar ✅ verde (~25s).
2. Abrir **`https://dockerclass.duckdns.org`** (recarregar com `Ctrl+F5`):
   - **Continua mostrando `Olá, turma!`** e o SHA antigo no rodapé.
   - **Ponto-chave:** o CI validou o código e a imagem automaticamente, mas **não fez deploy**.

---

## Passo 6 — Explicar CD e trazer o arquivo pronto

Explicar o conceito de **CD (Entrega Contínua)** e puxar o workflow pronto:

```sh
git checkout origin/etapa-cd -- .github/workflows/cd.yml
```

Abrir `.github/workflows/cd.yml` no VS Code e explicar linha por linha:
- **`on: workflow_run`:** só dispara quando o workflow **`CI`** termina com sucesso na `main`.
- **Job `publicar`:**
  1. Baixa exatamente o commit testado pelo CI.
  2. Gera `SHA_CURTO` e `DATA_BUILD` (horário de São Paulo).
  3. Faz login no GHCR usando `GITHUB_TOKEN` (token temporário automático).
  4. `docker build` passando `--build-arg GIT_SHA` e `BUILD_DATE`.
  5. `docker push` das tags `:latest` e `:<SHA_CURTO>` no GHCR.
- **Job `deploy` (`needs: publicar`):**
  1. Usa os **Secrets** do repositório (`VPS_HOST`, `VPS_USER`, `VPS_SSH_KEY`, `DOMAIN`).
  2. Configura a chave SSH no runner.
  3. Copia `docker-compose.prod.yml` para a VPS via `scp`.
  4. Roda `docker compose pull && docker compose up -d` na VPS via `ssh`.
  5. Faz `curl` em `https://dockerclass.duckdns.org/` até confirmar que o SHA novo apareceu no rodapé.

---

## Passo 7 — Commit + Push (CI ✅ → CD ✅ → produção no ar!)

```sh
git add .github/workflows/cd.yml
git commit -m "cd: adiciona deploy automatico na VPS"
git push
```

1. Abrir **GitHub → Actions → All workflows** *(dica: não clique em `← CI`, fique em **All workflows** para ver os dois)*:
   - Primeiro roda **`CI`** (~25s) → ✅
   - Assim que o CI termina, dispara **`CD`** (~50s) → clique nele para mostrar o grafo **`publicar` → `deploy`** ficando ✅.
2. Recarregar **`https://dockerclass.duckdns.org`** (e pedir para a turma abrir no celular):
   - **Texto novo no ar** (`Olá, turma de Sistemas!`) + **novo SHA no rodapé**!

---

## Depois da aula (ou depois de um treino)

### Resetar o repositório para `inicio-aula`
```sh
docker compose down
git checkout main
git reset --hard inicio-aula
git push --force origin main
```

### Limpar a VPS depois que a aula acabar
Siga a seção **Removendo tudo depois da aula** em [vps-setup.md](vps-setup.md#removendo-tudo-depois-da-aula).
