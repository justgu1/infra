# app-base

Helm chart base para aplicações web (PHP-FPM + nginx sidecar).

## Valores principais

| Chave | Padrão | Descrição |
|---|---|---|
| `image.repository` | `""` | Imagem da aplicação |
| `image.tag` | `latest` | Tag da imagem |
| `replicaCount` | `1` | Número de réplicas |
| `postgres.enabled` | `false` | Habilita PostgreSQL embutido |
| `redis.enabled` | `false` | Habilita Redis embutido |
| `nginx.enabled` | `true` | Habilita nginx sidecar |
| `rbac.enabled` | `false` | Cria Role para gerenciar Jobs (kubectl) |
| `initContainers.migrate.enabled` | `false` | Roda `php artisan migrate` antes de subir |
| `sealedSecret.enabled` | `false` | Cria SealedSecret com `encryptedData` dos values |
| `ingress.enabled` | `false` | Habilita Ingress |

Veja `values.yaml` para a lista completa.

## Nomes gerados

Todos os recursos usam `{{ .Release.Name }}` como prefixo:

- ConfigMap: `<release>-config`
- Secret: `<release>-secrets`
- Postgres: `<release>-postgres`
- Redis: `<release>-redis`
- Nginx ConfigMap: `<release>-nginx`

## Testar localmente

```bash
helm template hericarealtor . -f ../../apps/hericarealtor/values.yaml
helm lint . -f ../../apps/hericarealtor/values.yaml
```
