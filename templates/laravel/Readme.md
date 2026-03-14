Laravel Project Template
Este repositório fornece um template completo para projetos Laravel com suporte a:
Desenvolvimento local via Docker/Docker Compose
Deploy em Kubernetes (prod)
CI/CD via GitHub Actions
Gerenciamento de variáveis sensíveis (`envcrypt.sh`)
O objetivo é permitir que qualquer projeto novo seja iniciado de forma rápida, previsível e confiável, cobrindo desde instalação até troubleshooting.
---
⚡ Pré-requisitos
Antes de começar, certifique-se de ter instalado:
Docker ≥ 24.x
Docker Compose ≥ 2.x
kubectl
Helm (opcional)
Git
PHP 8.2+ e Composer (para instalação local opcional)
Dicas para evitar problemas comuns:
No Linux, adicione seu usuário ao grupo `docker` para evitar erros de permissão.
Atualize Docker Desktop para suporte a volumes e redes personalizadas.
Para SELinux/AppArmor, ajuste permissões em `docker/` e `storage/`.
---
1️⃣ Criar o projeto Laravel
Se ainda não tiver um projeto Laravel:
```bash
composer create-project laravel/laravel:^10 nome-do-projeto
cd nome-do-projeto
```
> ⚠️ Se houver erro de memória do Composer:
> ```bash
> COMPOSER_MEMORY_LIMIT=-1 composer create-project laravel/laravel:^10 nome-do-projeto
> ```
---
2️⃣ Instalar os arquivos do template
Clone ou copie os arquivos do template para o projeto:
```bash
cp -r path/do/template/docker ./docker
cp -r path/do/template/app/k8s ./app/k8s
cp Makefile envcrypt.sh ./
```
> Verifique para não sobrescrever arquivos importantes do Laravel sem revisão.
---
3️⃣ Rodando localmente com Docker
3.1 Build e startup
```bash
docker-compose build
docker-compose up -d
```
`app`: container Laravel
`nginx`: serve o Laravel em `http://localhost:8080` (confirme a porta em `docker/nginx/nginx.conf`)
3.2 Acessar container app
```bash
docker-compose exec app bash
```
Dentro do container:
```bash
composer install
php artisan key:generate
php artisan migrate
```
3.3 Debug e problemas comuns
Permissão storage/cache:
```bash
chmod -R 777 storage bootstrap/cache
```
Container não sobe:
```bash
docker-compose logs <service>
```
---
4️⃣ Deploy para Kubernetes (Produção)
4.1 Preparar arquivos
Atualize `app/k8s/deployment.yaml` com a imagem Docker correta.
Use `envcrypt.sh` para gerar secrets criptografados.
4.2 Aplicar no cluster
```bash
kubectl apply -f app/k8s/deployment.yaml
kubectl get pods -A
kubectl get svc -A
```
4.3 Diagnóstico de pods problemáticos
```bash
kubectl logs <pod-name> -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
```
4.4 Próximos passos
Configurar Ingress ou LoadBalancer.
Configurar CI/CD no `.github/workflows/build.yml` para buildar e pushar a imagem Docker.
---
5️⃣ Previsão de erros e manutenção
Situação	Como diagnosticar	Correção
Pods não sobem	`kubectl describe pod` + `kubectl logs`	Verificar imagem, volumes, secrets
Permissão storage/cache	Container logs	Ajustar chmod/chown
Falha CI/CD	GitHub Actions logs	Corrigir secrets, tokens, permissões
Dependências PHP	Composer install error	Usar `COMPOSER_MEMORY_LIMIT=-1`
---
6️⃣ Makefile útil
Exemplos de comandos:
```makefile
up:
	docker-compose up -d

down:
	docker-compose down

logs:
	docker-compose logs -f

k8s-deploy:
	kubectl apply -f app/k8s/deployment.yaml
```
---
7️⃣ Conclusão
Este template permite:
Desenvolvimento local idêntico ao ambiente de produção
Deploy simples e previsível em Kubernetes
Fácil debug e manutenção
Aplicação de boas práticas de CI/CD
Seguindo este README, qualquer projeto Laravel pode ser iniciado rapidamente, mantendo consistência entre local e prod.