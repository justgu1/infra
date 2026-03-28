# job-base

Helm chart base para CronJobs (workers, scrapers, tarefas agendadas).

## Valores principais

| Chave | Padrão | Descrição |
|---|---|---|
| `image.repository` | `""` | Imagem do job |
| `image.tag` | `latest` | Tag da imagem |
| `schedule` | `"0 0 * * *"` | Cron schedule |
| `timeZone` | `"UTC"` | Timezone do CronJob |
| `concurrencyPolicy` | `Forbid` | Impede execuções simultâneas |
| `shm.enabled` | `true` | Monta `/dev/shm` expandido (Chrome/Selenium) |
| `shm.size` | `"2Gi"` | Tamanho do `/dev/shm` |
| `sealedSecret.enabled` | `false` | Cria SealedSecret |

## Executar manualmente

Para disparar o job fora do horário agendado:

```bash
kubectl create job <nome>-manual --from=cronjob/<nome> -n <namespace>
```

Ou via Artisan (se o app `hericarealtor` estiver no mesmo namespace):

```bash
php artisan listings:sync
```

## Testar localmente

```bash
helm template listings-updater . -f ../../apps/listings-updater/values.yaml
helm lint . -f ../../apps/listings-updater/values.yaml
```
