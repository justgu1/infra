# minio-provisioner

Chart que cria buckets e políticas no MinIO compartilhado de forma declarativa.

## Como funciona

- Roda como **Job PostSync** no ArgoCD
- Lê credenciais root do Vault via ExternalSecret (`secret/cluster/minio`)
- Usa `minio/mc` para criar buckets com a política correta
- É **idempotente** — seguro rodar múltiplas vezes

## Adicionar novo bucket

Em `services/minio-provisioner/values.yaml`, adicione:

```yaml
buckets:
  - name: meu-novo-app
    policy: none   # none | download | upload | public
```

Políticas:
| Valor | Significado |
|-------|-------------|
| `public` | Leitura anônima total (ideal para assets/CDN) |
| `download` | Alias para public (leitura) |
| `upload` | Apenas escrita anônima |
| `none` | Bucket privado (padrão seguro) |

## Buckets atuais

| Bucket | Política | Uso |
|--------|----------|-----|
| `hericarealtor` | public | Assets/imagens públicas |
| `tyer-chatwoot` | none | Arquivos do Chatwoot |
| `justgui` | none | Uso geral privado |
