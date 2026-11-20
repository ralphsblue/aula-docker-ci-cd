# Aula - Docker && CI/CD

Site estático (HTML + CSS) que explica o que é o Docker.
Ele é o material de apoio da aula e também o "app" que a gente coloca no ar com CI/CD.

## Rodando na sua máquina

Pré-requisito: [Docker](https://docs.docker.com/get-docker/) instalado (no Windows, Docker Desktop com WSL 2).

```sh
docker compose up --build
```

Abra http://localhost:8080.
Para parar, aperte `Ctrl+C` e rode `docker compose down`.

Sem Compose, só com Docker:

```sh
docker build -t aula-docker .
docker run --rm -p 8080:80 aula-docker
```

## Versão do deploy no rodapé

O rodapé do site mostra qual versão está no ar: o SHA curto do commit e a data do build.
O `index.html` tem os marcadores `__GIT_SHA__` e `__BUILD_DATE__`, que o `Dockerfile` troca pelos valores passados com `--build-arg`.

```sh
docker build --build-arg GIT_SHA=abc1234 --build-arg BUILD_DATE="20/11/2026 14:00" -t aula-docker .
```

Sem build args (build local), o rodapé mostra `dev · local`.

## Testes

Os mesmos que o CI roda:

```sh
npx htmlhint@1.9.2 site/                       # valida o HTML (regras em .htmlhintrc)
docker build -t aula-docker:teste .
bash scripts/teste-fumaca.sh aula-docker:teste # sobe o container e confere a página
```

O teste de fumaça procura o texto `O que é Docker?` na página.
Mudar a saudação `Olá, turma!` não quebra o teste.

## Estrutura

```
site/                      o site (index.html + style.css)
Dockerfile                 receita da imagem (nginx + site)
.dockerignore              o que fica fora do build
docker-compose.yml         rodar local (porta 8080)
docker-compose.prod.yml    produção: imagem do GHCR + Caddy com HTTPS
Caddyfile                  configuração do Caddy (proxy reverso)
scripts/teste-fumaca.sh    teste de fumaça
.htmlhintrc                regras de validação do HTML
.github/workflows/ci.yml   CI: valida, builda e testa
.github/workflows/cd.yml   CD: publica a imagem no GHCR
docs/                      preparação da VPS e roteiro da aula
```

## Branches (etapas da aula)

| Branch | Conteúdo |
|---|---|
| `main` | Ponto de partida: site + Docker, sem workflows |
| `etapa-ci` | `main` + workflow de CI |
| `etapa-cd` | `etapa-ci` + workflow de CD (versão final) |

Para trazer um arquivo pronto de uma etapa sem trocar de branch:

```sh
git checkout origin/etapa-ci -- .github/workflows/ci.yml
```

## Documentação

- [docs/roteiro-aula.md](docs/roteiro-aula.md): roteiro da parte prática, comando por comando.
- [docs/vps-setup.md](docs/vps-setup.md): como preparar (e depois limpar) a VPS.
