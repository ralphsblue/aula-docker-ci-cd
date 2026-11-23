# Preparando a VPS

A VPS é de um amigo e já roda vários sites dele, então a regra é: **não mexer no que já existe**.
Tudo da aula é **adicionado** ao lado do que está lá, e no final tem o passo a passo para remover.

## Como fica

```
internet → nginx da VPS (80/443, HTTPS via certbot) → 127.0.0.1:8180 → container aula-docker
```

| O que | Onde |
|---|---|
| Container do site | projeto Compose `aula-docker`, porta `127.0.0.1:8180` |
| Arquivos do deploy | `/home/deploy/aula-docker/docker-compose.yml` |
| Site do nginx | `/etc/nginx/sites-available/aula-docker` (+ link em `sites-enabled`) |
| Certificado | `certbot`, nome `SEU_SUBDOMINIO.duckdns.org` |
| Usuário do GitHub Actions | `deploy` (grupo `docker`) |

O que **não** muda: as configs do nginx que já existem, firewall, portas abertas, containers e projetos Compose do dono da VPS.

## 0. Conferências antes de começar

Só leitura, nada é alterado:

```sh
ss -tlnH | grep ':8180 ' || echo "8180 livre"
sudo docker compose ls | grep aula-docker || echo "nome aula-docker livre"
ls /etc/nginx/sites-available/aula-docker 2>/dev/null || echo "nome do site livre"
getent passwd deploy || echo "usuário deploy livre"
```

## 1. DuckDNS

1. Entre em https://www.duckdns.org com uma conta do GitHub ou Google.
2. Crie um subdomínio e preencha o campo `current ip` com o IP da VPS.
3. Confira na sua máquina: `nslookup SEU_SUBDOMINIO.duckdns.org` tem que responder o IP da VPS.

## 2. Chave SSH só para o deploy

Na **sua** máquina:

```sh
ssh-keygen -t ed25519 -f ~/.ssh/aula-deploy -C "aula-deploy" -N ""
cat ~/.ssh/aula-deploy.pub
```

## 3. Usuário `deploy`

Na VPS, colando a chave pública do passo 2 no lugar de `CHAVE_PUBLICA`:

```sh
sudo adduser --disabled-password --gecos "" deploy
sudo usermod -aG docker deploy
sudo install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
echo "CHAVE_PUBLICA" | sudo tee /home/deploy/.ssh/authorized_keys
sudo chown deploy:deploy /home/deploy/.ssh/authorized_keys
sudo chmod 600 /home/deploy/.ssh/authorized_keys
```

> [!WARNING]
> Quem está no grupo `docker` consegue virar root na máquina (pode montar `/` dentro de um container).
> A chave do `deploy` vai ficar como secret no GitHub: trate essa chave como uma senha de root e apague tudo depois da aula.

Teste da sua máquina:

```sh
ssh -i ~/.ssh/aula-deploy deploy@IP_DA_VPS docker ps
```

## 4. Site no nginx

Copie o arquivo `deploy/nginx-aula-docker.conf` do repositório para a VPS, trocando o subdomínio:

```sh
sed 's/SEU_SUBDOMINIO/meusubdominio/' deploy/nginx-aula-docker.conf | ssh vps "sudo tee /etc/nginx/sites-available/aula-docker > /dev/null"
```

Na VPS:

```sh
sudo ln -s /etc/nginx/sites-available/aula-docker /etc/nginx/sites-enabled/aula-docker
sudo nginx -t && sudo systemctl reload nginx
```

O `nginx -t` testa **todas** as configs antes.
Se ele acusar qualquer erro, o `&&` impede o reload e os sites que já estão no ar continuam como estavam.
O `reload` não derruba conexões: o nginx troca de configuração sem parar.

## 5. HTTPS

```sh
sudo certbot --nginx --redirect -d SEU_SUBDOMINIO.duckdns.org
```

O certbot edita só o arquivo `aula-docker` (as linhas `# managed by Certbot`) e renova o certificado sozinho.

## 6. Secrets no GitHub

Na sua máquina, dentro do repositório:

```sh
gh secret set VPS_HOST --body "IP_DA_VPS"
gh secret set VPS_USER --body "deploy"
gh secret set VPS_SSH_KEY < ~/.ssh/aula-deploy
gh secret set DOMAIN --body "SEU_SUBDOMINIO.duckdns.org"
```

## 7. Primeiro deploy manual

```sh
ssh -i ~/.ssh/aula-deploy deploy@IP_DA_VPS mkdir -p aula-docker
scp -i ~/.ssh/aula-deploy docker-compose.prod.yml deploy@IP_DA_VPS:aula-docker/docker-compose.yml
ssh -i ~/.ssh/aula-deploy deploy@IP_DA_VPS "cd aula-docker && docker compose pull && docker compose up -d"
```

Abra `https://SEU_SUBDOMINIO.duckdns.org` e confira o SHA no rodapé.

## Removendo tudo depois da aula

Na VPS:

```sh
sudo -u deploy sh -c "cd ~/aula-docker && docker compose down --rmi all"
sudo rm /etc/nginx/sites-enabled/aula-docker /etc/nginx/sites-available/aula-docker
sudo nginx -t && sudo systemctl reload nginx
sudo certbot delete --cert-name SEU_SUBDOMINIO.duckdns.org
sudo deluser --remove-home deploy
```

Fora da VPS:

- Apague o subdomínio no DuckDNS.
- Apague os secrets: `gh secret delete VPS_HOST`, e o mesmo para `VPS_USER`, `VPS_SSH_KEY` e `DOMAIN`.
- Apague a chave local: `rm ~/.ssh/aula-deploy ~/.ssh/aula-deploy.pub`.
- Avise o dono da VPS para retirar o sudo do seu usuário.
