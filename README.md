# justgu1/infra

Repositório GitOps central do cluster. Gerenciado pelo **ArgoCD** com o padrão **App-of-Apps**.

---

## Estrutura

```
infra/
├── bootstrap/          # Instalação manual única (root-app)
├── root/               # App-of-Apps raiz — aponta para apps/, services/, core/
├── projects/           # ArgoCD Projects (apps, services, core)
├── core/               # Infraestrutura base (cert-manager, ingress-nginx, metallb, sealed-secrets)
├── services/           # Serviços de plataforma (authentik, minio, n8n, passbolt)
├── apps/               # ← Aplicações internas (uma pasta por app)
│   ├── hericarealtor/
│   │   ├── application.yaml   # ArgoCD Application (app web)
│   │   ├── values.yaml        # Configuração do app web
│   │   └── jobs/
│   │       └── listings-updater/
│   │           ├── application.yaml   # ArgoCD Application (CronJob)
│   │           └── values.yaml        # Configuração do job
│   └── outro-app/
│       ├── application.yaml
│       └── values.yaml
└── charts/             # ← Helm charts reutilizáveis
    ├── app-base/       # Apps web (PHP-FPM + nginx sidecar)
    └── job-base/       # CronJobs / Workers
```

---

## Como funciona

```
ArgoCD root-app
    └── root/
        ├── apps.yaml      → monitora apps/*/application.yaml
        ├── services.yaml  → monitora services/*/application.yaml
        └── core.yaml      → monitora core/*/application.yaml
```

Cada `application.yaml` declara de qual chart e quais values o app usa.  
O ArgoCD sincroniza automaticamente qualquer push na branch `main`.

---

## Charts disponíveis

### `charts/app-base`

Para aplicações web com PHP-FPM + nginx sidecar.

**Inclui (todos opcionais via values):**
- Deployment com nginx sidecar (HTTP → FastCGI)
- InitContainer que roda `migrate` antes de subir
- InitContainer que copia `public/` para volume compartilhado com nginx
- ConfigMap para envs não-sensíveis
- SealedSecret para envs sensíveis
- PostgreSQL StatefulSet
- Redis Deployment
- Service + Ingress com TLS automático (cert-manager)
- ServiceAccount + RBAC para gestão de Jobs

### `charts/job-base`

Para CronJobs (scraping, workers, tarefas agendadas).

**Inclui:**
- CronJob com schedule, timezone e concurrencyPolicy configuráveis
- `/dev/shm` expansível (necessário para Chrome/Selenium)
- ConfigMap + SealedSecret

---

## Quick Start — Novo App Web

### 1. Criar `apps/<nome-do-app>/values.yaml` no infra

```yaml
# apps/meu-app/values.yaml

replicaCount: 1

image:
  repository: ghcr.io/justgu1/meu-app
  tag: latest

ingress:
  enabled: true
  hosts:
    - host: meu-app.justgui.dev
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: meu-app-tls
      hosts:
        - meu-app.justgui.dev

configMap:
  data:
    APP_ENV: production
    APP_URL: https://meu-app.justgui.dev
    DB_HOST: meu-app-postgres
    # ... demais envs não-sensíveis

postgres:
  enabled: true
  database: meu_app
  username: meu_app
  storage: 5Gi

redis:
  enabled: true

initContainers:
  migrate:
    enabled: true

sealedSecret:
  enabled: true
  encryptedData:
    APP_KEY: <kubeseal output>
    DB_PASSWORD: <kubeseal output>
    REDIS_PASSWORD: <kubeseal output>
```

### 2. Selar os secrets

```bash
# Na raiz do repo infra
kubectl create secret generic meu-app-secrets \
  --namespace=meu-app \
  --from-literal=APP_KEY="base64:..." \
  --from-literal=DB_PASSWORD="senha" \
  --from-literal=REDIS_PASSWORD="senha" \
  --dry-run=client -o yaml \
  | kubeseal --cert sealed-secrets-pub.pem --format yaml
```

Cole cada campo `encryptedData.<chave>` no `values.yaml`.

### 3. Criar `apps/<nome-do-app>/application.yaml`

```yaml
# apps/meu-app/application.yaml

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: meu-app
  namespace: argocd
spec:
  project: apps
  sources:
    - repoURL: git@github.com:justgu1/infra.git
      targetRevision: main
      path: charts/app-base
      helm:
        releaseName: meu-app
        valueFiles:
          - $values/apps/meu-app/values.yaml
    - repoURL: git@github.com:justgu1/infra.git
      targetRevision: main
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: meu-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 4. Commit e push → ArgoCD deploya automaticamente

```bash
git add apps/meu-app/
git commit -m "feat: add meu-app"
git push
```

---

## Quick Start — Novo CronJob (job de um app existente)

Jobs que pertencem a um app ficam dentro da pasta do app:
```
apps/<app-pai>/
├── application.yaml
├── values.yaml
└── jobs/
    └── meu-job/
        ├── application.yaml
        └── values.yaml
```

### 1. Criar `apps/<app-pai>/jobs/<meu-job>/values.yaml`

```yaml
image:
  repository: ghcr.io/justgu1/<app-pai>-meu-job
  tag: latest

schedule: "0 3 * * *"
timeZone: "America/Sao_Paulo"

configMap:
  data:
    LOG_LEVEL: INFO

sealedSecret:
  enabled: true
  encryptedData:
    API_KEY: <kubeseal output>
```

### 2. Criar `apps/<app-pai>/jobs/<meu-job>/application.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: meu-job
  namespace: argocd
spec:
  project: apps
  sources:
    - repoURL: git@github.com:justgu1/infra.git
      targetRevision: main
      path: charts/job-base
      helm:
        releaseName: meu-job
        valueFiles:
          - $values/apps/<app-pai>/jobs/meu-job/values.yaml
    - repoURL: git@github.com:justgu1/infra.git
      targetRevision: main
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: <app-pai>    # mesmo namespace do app pai
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 3. Commit e push

---

## Sealed Secrets

A chave pública do cluster está em `sealed-secrets-pub.pem`.  
Use sempre ela para selar — assim pode rodar offline sem acesso ao cluster:

```bash
kubeseal --cert sealed-secrets-pub.pem --format yaml < secret.yaml > sealed.yaml
```

> Os valores selados são **seguros para commit**. Só o cluster consegue descriptografar.

---

## Fluxo de atualização de imagem

```
1. Push no repo da app
2. CI builda e publica nova imagem (ghcr.io/justgu1/<app>:<tag>)
3. Atualiza values.yaml → image.tag: <nova-tag>
4. Push no infra → ArgoCD re-deploya automaticamente
```

---

## Testando charts localmente

```bash
# Renderizar templates sem aplicar
helm template meu-app charts/app-base -f apps/meu-app/values.yaml

# Validar sintaxe
helm lint charts/app-base -f apps/meu-app/values.yaml
```

---

## Convenções

| Item | Padrão |
|---|---|
| Namespace | mesmo nome do app |
| Secret name | `<release>-secrets` |
| ConfigMap name | `<release>-config` |
| Postgres service | `<release>-postgres` |
| Redis service | `<release>-redis` |
| Imagem | `ghcr.io/justgu1/<app>:<tag>` |
| TLS secret | `<app>-tls` |
| Ingress annotations | `cert-manager.io/cluster-issuer: letsencrypt-prod` |
