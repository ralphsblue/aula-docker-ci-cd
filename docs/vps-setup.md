# Preparando a VPS

> [!IMPORTANT]
> **Rascunho (fase 2).**
> Ainda não temos acesso à VPS.
> O passo 0 decide se usamos o Caddy deste repositório ou o proxy que já existe lá, e o resto deste guia pode mudar com isso.

A VPS é de um amigo, então a regra é: **não mexer no que já existe**.
Tudo da aula fica isolado em um usuário `deploy` e na pasta `/home/deploy/aula-docker`.
No final tem o passo a passo para remover tudo.

## 0. Diagnóstico: o que já existe na VPS?

```sh
docker --version
sudo ss -tlnp | grep -E ':(80|443)\s'
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}'
```

| Resultado | O que fazer |
|---|---|
| Nada nas portas 80/443 | Seguir este guia com o Caddy. |
| Traefik nas portas 80/443 | Trocar o Caddy por labels do Traefik no serviço `site`. Precisa do nome da rede, do entrypoint HTTPS e do certresolver do Traefik. |
| nginx nas portas 80/443 | Trocar o Caddy por um arquivo de site no nginx com `proxy_pass` e HTTPS via certbot. |

## 1. Docker

Só se o `docker --version` acima não encontrou nada:

```sh
curl -fsSL https://get.docker.com | sudo sh
```

Anote se o Docker foi instalado por nós, para saber se ele deve ser removido no final.

## 2. Usuário `deploy`

```sh
sudo adduser --disabled-password --gecos "" deploy
sudo usermod -aG docker deploy
```

> [!WARNING]
> Quem está no grupo `docker` consegue virar root na máquina (pode montar `/` dentro de um container).
> A chave SSH do `deploy` vai ficar guardada como secret no GitHub: trate essa chave como uma senha de root e apague tudo depois da aula.

## 3. Chave SSH só para o deploy

Na **sua** máquina:

```sh
ssh-keygen -t ed25519 -f ~/.ssh/aula-deploy -C "aula-deploy" -N ""
```

Na VPS, autorize a chave pública (`~/.ssh/aula-deploy.pub`):

```sh
sudo mkdir -p /home/deploy/.ssh
echo "COLE_AQUI_O_CONTEUDO_DE_aula-deploy.pub" | sudo tee /home/deploy/.ssh/authorized_keys
sudo chown -R deploy:deploy /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh
sudo chmod 600 /home/deploy/.ssh/authorized_keys
```

Teste da sua máquina:

```sh
ssh -i ~/.ssh/aula-deploy deploy@IP_DA_VPS docker ps
```

## 4. Portas 80 e 443

Se o firewall `ufw` estiver ativo (`sudo ufw status`):

```sh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

Se a VPS for de um provedor com firewall no painel (AWS, Oracle, Hetzner...), libere 80 e 443 lá também.

## 5. DuckDNS

1. Entre em https://www.duckdns.org com uma conta do GitHub ou Google.
2. Crie um subdomínio, por exemplo `minhaaula`, e preencha o campo `current ip` com o IP da VPS.
3. Confira: `nslookup minhaaula.duckdns.org` tem que responder o IP da VPS.

## 6. Secrets no GitHub

Na sua máquina, dentro do repositório:

```sh
gh secret set VPS_HOST --body "IP_DA_VPS"
gh secret set VPS_USER --body "deploy"
gh secret set VPS_SSH_KEY < ~/.ssh/aula-deploy
gh secret set DOMAIN --body "minhaaula.duckdns.org"
```

## 7. Primeiro deploy manual

```sh
ssh -i ~/.ssh/aula-deploy deploy@IP_DA_VPS mkdir -p aula-docker
scp -i ~/.ssh/aula-deploy docker-compose.prod.yml Caddyfile deploy@IP_DA_VPS:aula-docker/
ssh -i ~/.ssh/aula-deploy deploy@IP_DA_VPS
```

Já dentro da VPS:

```sh
cd aula-docker
cat > .env << 'EOF'
IMAGE=ghcr.io/ralphsblue/aula-docker-ci-cd:latest
DOMAIN=minhaaula.duckdns.org
EOF
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
docker compose -f docker-compose.prod.yml logs -f caddy
```

Abra `https://minhaaula.duckdns.org` e confira o SHA no rodapé.

## Removendo tudo depois da aula

Na VPS, como `deploy`:

```sh
cd ~/aula-docker
docker compose -f docker-compose.prod.yml down --volumes --rmi all
```

Na VPS, com o seu usuário de sempre:

```sh
sudo deluser --remove-home deploy
sudo ufw delete allow 80/tcp     # só se você liberou no passo 4
sudo ufw delete allow 443/tcp    # só se você liberou no passo 4
```

Se o Docker foi instalado por nós no passo 1, remova também:

```sh
sudo apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo rm -rf /var/lib/docker /var/lib/containerd
```

Fora da VPS:

- Apague o subdomínio no DuckDNS.
- Apague os secrets: `gh secret delete VPS_HOST`, e o mesmo para `VPS_USER`, `VPS_SSH_KEY` e `DOMAIN`.
- Apague a chave local: `rm ~/.ssh/aula-deploy ~/.ssh/aula-deploy.pub`.
