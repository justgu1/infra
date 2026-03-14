# Documentação Técnica — Infraestrutura Kubernetes

Documentação detalhada por componente. Destinada a desenvolvedores novos no time ou que precisam entender, operar ou estender a infraestrutura.

**Índice**

- [Local vs Produção — Diferenças e Considerações](#local-vs-produção--diferenças-e-considerações)
- [Kubernetes e k3s](#kubernetes-e-k3s)
- [ArgoCD — GitOps](#argocd--gitops)
- [NGINX Ingress Controller](#nginx-ingress-controller)
- [Prometheus](#prometheus)
- [Alertmanager](#alertmanager)
- [Grafana](#grafana)
- [Bootstrap — subindo do zero](#bootstrap--subindo-do-zero)
- [WSL — Limitações e Soluções](#wsl--limitações-e-soluções)
- [Troubleshooting Geral](#troubleshooting-geral)

---

## Local vs Produção — Diferenças e Considerações

Esta seção resume as principais diferenças entre rodar a infraestrutura localmente (WSL + k3s) e em um ambiente de produção real (bare metal, cloud, servidor dedicado). O objetivo é deixar claro o que precisa mudar antes de um deploy produtivo.

### Visão geral rápida

| Aspecto | Local (WSL + k3s) | Produção |
| --- | --- | --- |
| Distribuição Kubernetes | k3s | k3s, kubeadm, EKS, GKE, AKS |
| Nós | 1 (control-plane + workload) | Mínimo 1 control-plane + N workers |
| Alta disponibilidade | Não | Sim (multi-node, etcd replicado) |
| node-exporter | Desabilitado (WSL não suporta) | Habilitado |
| Admission webhooks | Desabilitados (TLS quebra no WSL) | Habilitados |
| Ingress | Funcional via localhost | Requer IP público ou LoadBalancer |
| TLS / HTTPS | Manual ou sem | cert-manager + Let's Encrypt |
| Persistência de dados | Perde ao resetar o WSL | PersistentVolumes em disco real |
| Acesso aos serviços | port-forward | Ingress com domínio real |
| Credenciais | Padrão (prom-operator, admin) | Secrets gerenciados (Vault, Sealed Secrets) |
| Recursos (CPU/RAM) | Compartilhados com o Windows | Dedicados |

---

### Kubernetes — k3s local vs produção

**Local:** Um único nó faz tudo — é control-plane e worker ao mesmo tempo. Se o nó cai, tudo cai. Aceitável para desenvolvimento.

**Produção:** Separar control-plane dos workers. Para alta disponibilidade, usar 3 control-planes (quórum do etcd). Workers escalam horizontalmente conforme a carga.

```bash
# k3s multi-node: no control-plane
curl -sfL https://get.k3s.io | sh -

# Pega o token para os workers
cat /var/lib/rancher/k3s/server/node-token

# Nos workers
curl -sfL https://get.k3s.io | K3S_URL=https://<IP-CONTROL-PLANE>:6443 \
  K3S_TOKEN=<TOKEN> sh -
```

---

### Monitoramento — diferenças de configuração

Em produção, habilitar o que está desabilitado no WSL:

```yaml
# core/monitoring/values.yaml — produção
kube-prometheus-stack:
  nodeExporter:
    enabled: true          # métricas de CPU, memória, disco, rede do host

  prometheusOperator:
    admissionWebhooks:
      enabled: true        # valida recursos antes de aplicar
    tls:
      enabled: true        # comunicação segura entre operator e API server

  prometheus:
    prometheusSpec:
      retention: 30d       # quanto tempo guardar métricas (padrão: 24h)
      storageSpec:
        volumeClaimTemplate:
          spec:
            storageClassName: local-path
            resources:
              requests:
                storage: 50Gi   # disco para as métricas

  alertmanager:
    alertmanagerSpec:
      storage:
        volumeClaimTemplate:
          spec:
            storageClassName: local-path
            resources:
              requests:
                storage: 5Gi
```

**Retenção de métricas:** localmente o padrão de 24h é suficiente. Em produção, definir conforme necessidade (30d é um bom ponto de partida).

**Storage:** localmente os dados somem ao reiniciar o WSL — aceitável para dev. Em produção, usar PersistentVolumes para que métricas e dados do Alertmanager sobrevivam a restarts.

---

### Ingress e TLS

**Local:** o Ingress funciona via `localhost` com entradas no `/etc/hosts`. Sem HTTPS real.

**Produção:** o cluster precisa ter um IP público (ou um LoadBalancer na cloud). O fluxo recomendado:

```
DNS (domínio.com) → IP público do servidor → NGINX Ingress Controller → Service → Pod
```

Para TLS automático, instalar o **cert-manager** com o issuer do Let's Encrypt:

```yaml
# Ingress com TLS automático
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - grafana.seudominio.com
      secretName: grafana-tls
  rules:
    - host: grafana.seudominio.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: monitoring-grafana
                port:
                  number: 80
```

---

### Credenciais e segurança

**Local:** senhas padrão são aceitáveis (`prom-operator`, `admin`). O cluster não é acessível externamente.

**Produção:** nunca usar senhas padrão. Opções para gerenciar secrets de forma segura:

**Sealed Secrets** — criptografa secrets com uma chave do cluster, permite commitar no Git:
```bash
# Instalar kubeseal
kubeseal --format yaml < secret.yaml > sealed-secret.yaml
# O sealed-secret.yaml pode ir pro Git com segurança
```

**Trocar senha do Grafana via values:**
```yaml
kube-prometheus-stack:
  grafana:
    adminPassword: "senha-forte-aqui"
    # Em produção, referenciar um Secret existente:
    admin:
      existingSecret: grafana-admin-secret
      userKey: admin-user
      passwordKey: admin-password
```

---

### Recursos computacionais

**Local:** k3s consome pouco. O stack de monitoring (Prometheus + Grafana + Alertmanager) usa aproximadamente 500MB de RAM e CPU mínima em idle.

**Produção:** dimensionar conforme o número de métricas coletadas. Referência para um cluster pequeno (até 10 nós):

```yaml
kube-prometheus-stack:
  prometheus:
    prometheusSpec:
      resources:
        requests:
          cpu: 500m
          memory: 2Gi
        limits:
          cpu: 2000m
          memory: 4Gi

  grafana:
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
```

---

### Checklist antes de ir para produção

```
[ ] Trocar todas as senhas padrão
[ ] Habilitar nodeExporter
[ ] Habilitar admissionWebhooks e TLS do operator
[ ] Configurar PersistentVolumes para Prometheus e Alertmanager
[ ] Definir retenção de métricas (retention)
[ ] Instalar cert-manager para TLS automático
[ ] Configurar DNS e Ingress com domínio real
[ ] Configurar receivers no Alertmanager (Slack, email)
[ ] Separar control-plane dos workers (multi-node)
[ ] Revisar resource requests/limits de todos os componentes
[ ] Configurar backups do etcd
```

---

## Kubernetes e k3s

### O que é

Kubernetes é um orquestrador de containers — ele decide onde cada container roda, reinicia quando falha, escala quando necessário e gerencia rede e armazenamento entre os serviços.

**k3s** é uma distribuição leve do Kubernetes mantida pela Rancher. Tem o mesmo comportamento do Kubernetes padrão mas com instalação simples e menos consumo de recursos, ideal para ambientes locais, edge e servidores menores.

### Conceitos fundamentais

**Pod** — menor unidade do Kubernetes. Um pod contém um ou mais containers que compartilham rede e armazenamento. Todo container roda dentro de um pod.

**Deployment** — descreve como um pod deve rodar: quantas réplicas, qual imagem, variáveis de ambiente, recursos. O Kubernetes garante que o estado declarado no Deployment sempre seja mantido.

**Service** — expõe um conjunto de pods numa rede estável. Pods têm IPs efêmeros (mudam ao reiniciar), o Service tem IP fixo e faz balanceamento entre os pods.

**Namespace** — separação lógica dentro do cluster. Recursos de namespaces diferentes não se enxergam por padrão. Usamos namespaces para separar: `argocd`, `monitoring`, `ingress-nginx`.

**ConfigMap / Secret** — forma de passar configurações e credenciais para os pods sem colocar dentro da imagem.

**DaemonSet** — garante que um pod rode em todos os nós do cluster. Usado pelo node-exporter (quando habilitado) e pelo svclb do ingress.

**StatefulSet** — como um Deployment, mas para serviços que precisam de identidade estável e armazenamento persistente. Usado pelo Prometheus e Alertmanager.

### Comandos do dia a dia

```bash
# Ver estado geral do cluster
kubectl get nodes
kubectl get pods -A
kubectl get svc -A

# Inspecionar um recurso
kubectl describe pod <nome-do-pod> -n <namespace>
kubectl describe deployment <nome> -n <namespace>

# Logs de um pod
kubectl logs <nome-do-pod> -n <namespace>
kubectl logs <nome-do-pod> -n <namespace> --tail=50 -f   # follow

# Entrar num container
kubectl exec -it <nome-do-pod> -n <namespace> -- /bin/sh

# Aplicar um arquivo
kubectl apply -f arquivo.yaml

# Deletar um recurso
kubectl delete pod <nome> -n <namespace>

# Ver eventos do namespace (útil para troubleshooting)
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Troubleshooting

**Pod em CrashLoopBackOff**
```bash
kubectl logs <pod> -n <namespace> --previous   # logs do container anterior
kubectl describe pod <pod> -n <namespace>       # ver eventos e motivo
```

**Pod em Pending**
```bash
kubectl describe pod <pod> -n <namespace>
# Procure em Events: geralmente é falta de recursos ou PVC não disponível
```

**Pod em Unknown**
```bash
# Estado residual comum no WSL após reinicialização
kubectl delete pod <pod> -n <namespace> --force --grace-period=0
```

---

## ArgoCD — GitOps

### O que é

ArgoCD é um operador GitOps para Kubernetes. Ele monitora um repositório Git e mantém o cluster sincronizado com o que está declarado nele. Quando um commit é feito, o ArgoCD detecta a diferença e aplica automaticamente.

**Por que GitOps?** Toda mudança passa por code review, tem histórico, pode ser revertida com `git revert`, e o estado do cluster é sempre auditável.

### Conceitos

**Application** — recurso central do ArgoCD. Define de onde vem o código (repo, path ou chart Helm) e para onde vai (cluster, namespace). Cada componente da infra tem uma Application.

**Project** — agrupa Applications e define permissões (quais repos, quais clusters, quais namespaces podem ser usados). Usamos o projeto `infrastructure` para todos os componentes de core.

**Root App (App of Apps)** — padrão onde uma Application gerencia outras Applications. O `argocd/root-app.yaml` aponta para `core/` e cria automaticamente as Applications de ingress, monitoring etc.

**Sync Status** — diferença entre o que está no Git e o que está no cluster:
- `Synced` — cluster igual ao Git
- `OutOfSync` — existem diferenças
- `Unknown` — ArgoCD não conseguiu comparar (geralmente o repo-server está com problema)

**Health Status** — saúde dos recursos do Kubernetes:
- `Healthy` — todos os recursos estão prontos
- `Progressing` — recursos ainda inicializando
- `Degraded` — algum recurso falhou
- `Missing` — recurso esperado não existe no cluster

### Estrutura no repositório

```
argocd/
 ├ projects.yaml      → define o projeto "infrastructure"
 └ root-app.yaml      → Application que aponta para core/ e cria as outras Applications
```

### Como fazer uma alteração na infra

1. Edite o arquivo desejado em `core/` ou `apps/`
2. Faça commit e push
3. O ArgoCD detecta em até 3 minutos e aplica
4. Acompanhe pela UI ou pelo comando:

```bash
kubectl get applications -n argocd -w
```

### Acessar a UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Abrir: `https://localhost:8080`

Usuário: `admin`

Senha:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 --decode && echo
```

### Forçar um sync manual

Via kubectl:
```bash
# Refresh (recarrega o estado do Git)
kubectl patch application <nome-da-app> -n argocd --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

Via UI: abra a Application → clique **Sync** → marque **Prune** se quiser remover recursos órfãos → **Synchronize**.

### Troubleshooting

**Application em Unknown após reinício do WSL**

O `argocd-repo-server` provavelmente ficou em estado `Unknown`:
```bash
kubectl get pods -n argocd
kubectl delete pod -n argocd -l app.kubernetes.io/name=argocd-repo-server --force --grace-period=0
kubectl get pods -n argocd -w   # aguarda voltar 1/1 Running
```

**Sync travado (operação em andamento infinita)**
```bash
kubectl patch application <nome> -n argocd --type json \
  -p '[{"op":"remove","path":"/operation"}]'
```

**ComparisonError: connection refused porta 8081**

O repo-server está down. Veja o item acima.

**OutOfSync em CRDs mesmo após sync**

CRDs têm campos gerenciados pelo API server que diferem do manifest original. Solução: usar `ServerSideApply=true` no `syncOptions` da Application.

---

## NGINX Ingress Controller

### O que é

O Ingress Controller é o ponto de entrada HTTP/HTTPS do cluster. Ele lê recursos `Ingress` do Kubernetes e configura o NGINX para rotear requisições externas para os Services internos corretos.

```
Requisição externa
 ↓
NGINX Ingress Controller
 ↓ lê regras dos recursos Ingress
 ↓ roteia por hostname ou path
Service do app destino
 ↓
Pod
```

### Expor um serviço via Ingress

Crie um arquivo em `apps/<sua-app>/ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minha-app
  namespace: minha-app
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - host: minha-app.localhost
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: minha-app-svc
                port:
                  number: 80
```

Para acessar localmente, adicione o hostname no `/etc/hosts` do WSL:
```bash
echo "127.0.0.1 minha-app.localhost" | sudo tee -a /etc/hosts
```

### Troubleshooting

**502 Bad Gateway**
```bash
# Verifica se o Service e os pods estão healthy
kubectl get pods -n <namespace>
kubectl get svc -n <namespace>
kubectl describe ingress <nome> -n <namespace>
```

**Ingress não roteando**
```bash
# Verifica se a ingressClassName está correta
kubectl get ingressclass
# Deve retornar "nginx"
```

---

## Prometheus

### O que é

Prometheus é um banco de dados de séries temporais focado em métricas de sistemas. Ele funciona no modelo **pull** — vai até cada serviço periodicamente e coleta as métricas disponíveis no endpoint `/metrics`.

### Como funciona a coleta

O Prometheus usa recursos do Kubernetes para descobrir o que monitorar:

**ServiceMonitor** — diz ao Prometheus para coletar métricas de um Service específico:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: minha-app
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: minha-app
  endpoints:
    - port: metrics
      interval: 30s
```

**PodMonitor** — similar ao ServiceMonitor, mas aponta diretamente para pods.

### Acessar o Prometheus

```bash
kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090
```

Abrir: `http://localhost:9090`

Abas úteis:
- **Graph** — execute queries PromQL
- **Targets** — veja todos os serviços sendo monitorados e o status do scrape
- **Alerts** — regras de alerta e estado atual
- **Status > Configuration** — configuração completa do Prometheus

### PromQL — Linguagem de query

PromQL é a linguagem para consultar métricas no Prometheus. Conceitos básicos:

**Selecionar uma métrica:**
```promql
container_cpu_usage_seconds_total
```

**Filtrar por label:**
```promql
container_cpu_usage_seconds_total{namespace="monitoring"}
container_cpu_usage_seconds_total{pod=~"grafana.*"}   # regex
container_cpu_usage_seconds_total{namespace!="kube-system"}  # negação
```

**Taxa de crescimento (para contadores):**
```promql
rate(container_cpu_usage_seconds_total[5m])
```

**Agregar:**
```promql
sum(rate(container_cpu_usage_seconds_total[5m])) by (namespace)
avg(container_memory_usage_bytes) by (pod)
```

**Queries úteis para o cluster:**
```promql
# CPU total por namespace
sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) by (namespace)

# Memória usada por pod
sum(container_memory_working_set_bytes{container!=""}) by (pod)

# Pods não Running
kube_pod_status_phase{phase!~"Running|Succeeded"} == 1

# Uso de CPU de um deployment específico
sum(rate(container_cpu_usage_seconds_total{
  namespace="monitoring",
  pod=~"monitoring-grafana.*"
}[5m]))

# Quantidade de restarts por pod (últimas 24h)
increase(kube_pod_container_status_restarts_total[24h]) > 0
```

### Adicionar métricas de uma nova aplicação

Para que o Prometheus colete métricas da sua app:

1. A aplicação precisa expor um endpoint `/metrics` no formato Prometheus (texto simples com `metric_name{labels} valor`)
2. Crie um `ServiceMonitor` ou `PodMonitor` apontando para ela
3. Commite em `apps/<sua-app>/` e o ArgoCD aplica

### Troubleshooting

**Target aparece como DOWN no Prometheus**
```bash
# Verifica se o endpoint /metrics está respondendo
kubectl exec -it <pod> -n <namespace> -- wget -qO- http://localhost:<porta>/metrics | head

# Verifica se o ServiceMonitor está sendo lido
kubectl get servicemonitor -n monitoring
kubectl describe servicemonitor <nome> -n monitoring
```

**Sem dados no Grafana para uma métrica**

Verifique primeiro no Prometheus → Targets se o scrape está funcionando. Se o target está UP mas a métrica não existe, o problema é na aplicação, não no Prometheus.

---

## Alertmanager

### O que é

O Alertmanager recebe alertas disparados pelo Prometheus e decide o que fazer com eles. Ele não avalia métricas — isso é função do Prometheus. O Alertmanager apenas gerencia o ciclo de vida dos alertas que chegam.

### Fluxo completo de um alerta

```
Prometheus avalia uma PrometheusRule a cada X segundos
 ↓ condição satisfeita por tempo suficiente (for: 5m)
Alerta muda de Pending → Firing
 ↓
Alertmanager recebe o alerta
 ↓ aplica grouping (agrupa alertas similares)
 ↓ aplica inibições (suprime alertas redundantes)
 ↓ aplica silêncios (supressão manual temporária)
 ↓ roteia para o receiver correto
Notificação enviada (Slack, email, PagerDuty, webhook...)
```

### Acessar o Alertmanager

```bash
kubectl port-forward svc/monitoring-kube-prometheus-alertmanager -n monitoring 9093:9093
```

Abrir: `http://localhost:9093`

A UI mostra alertas ativos, silêncios configurados e o status dos receivers.

### Criar uma regra de alerta

Crie um `PrometheusRule` no namespace `monitoring`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: alertas-app
  namespace: monitoring
  labels:
    release: monitoring   # label necessária para o Prometheus ler a regra
spec:
  groups:
    - name: app.rules
      rules:
        - alert: PodRestartsAltos
          expr: increase(kube_pod_container_status_restarts_total[1h]) > 5
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Pod {{ $labels.pod }} reiniciando muito"
            description: "O pod {{ $labels.pod }} no namespace {{ $labels.namespace }} reiniciou mais de 5 vezes na última hora."

        - alert: PodNaoRunning
          expr: kube_pod_status_phase{phase!~"Running|Succeeded|Pending"} == 1
          for: 10m
          labels:
            severity: critical
          annotations:
            summary: "Pod {{ $labels.pod }} não está Running"
```

### Configurar receivers (Slack, email)

Adicione no `core/monitoring/values.yaml`:

```yaml
kube-prometheus-stack:
  alertmanager:
    config:
      global:
        slack_api_url: 'https://hooks.slack.com/services/SEU/WEBHOOK/AQUI'
      route:
        group_by: ['alertname', 'namespace']
        group_wait: 30s
        group_interval: 5m
        repeat_interval: 4h
        receiver: 'slack'
        routes:
          - match:
              severity: critical
            receiver: 'slack-critico'
      receivers:
        - name: 'slack'
          slack_configs:
            - channel: '#alertas-infra'
              title: '[{{ .Status | toUpper }}] {{ .GroupLabels.alertname }}'
              text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
        - name: 'slack-critico'
          slack_configs:
            - channel: '#alertas-criticos'
              title: '🚨 [CRÍTICO] {{ .GroupLabels.alertname }}'
```

### Silenciar um alerta temporariamente

Via UI do Alertmanager: **Silences → New Silence** → defina os matchers e duração.

Via CLI:
```bash
# Instalar amtool
kubectl exec -it alertmanager-monitoring-kube-prometheus-alertmanager-0 \
  -n monitoring -- amtool silence add alertname=NomeDoAlerta \
  --duration=2h \
  --comment="Manutenção programada"
```

### Troubleshooting

**Alerta em Pending mas nunca vira Firing**

O campo `for:` define quanto tempo a condição precisa ser verdadeira antes de disparar. Se o alerta fica em Pending e some, a condição deixou de ser verdadeira antes do tempo.

**Alerta Firing mas notificação não chegou**

```bash
# Verifica logs do Alertmanager
kubectl logs -n monitoring \
  alertmanager-monitoring-kube-prometheus-alertmanager-0 \
  -c alertmanager --tail=50
```

Procure por erros de conexão com o receiver (Slack webhook inválido, timeout de email etc).

---

## Grafana

### O que é

Grafana é uma plataforma de visualização de métricas. Ele se conecta ao Prometheus como datasource e permite criar dashboards com gráficos de séries temporais, tabelas, gauges e alertas visuais.

### Acessar o Grafana

```bash
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
```

Abrir: `http://localhost:3000`

| Campo   | Valor         |
| ------- | ------------- |
| Usuário | `admin`       |
| Senha   | `prom-operator` |

### Dashboards pré-instalados

O `kube-prometheus-stack` instala automaticamente ~30 dashboards. Os mais úteis:

| Dashboard | O que mostra |
| --- | --- |
| Kubernetes / Compute Resources / Cluster | CPU e memória de todos os nós |
| Kubernetes / Compute Resources / Namespace | Recursos por namespace |
| Kubernetes / Compute Resources / Pod | Recursos de um pod específico |
| Kubernetes / Networking / Cluster | Tráfego de rede |
| Alertmanager / Overview | Alertas ativos e histórico |
| Prometheus / Overview | Saúde do próprio Prometheus |

Acesse em: **Dashboards → Browse → Default**.

### Criar um dashboard customizado

1. No Grafana: **Dashboards → New → New Dashboard**
2. **Add visualization**
3. Selecione o datasource **Prometheus**
4. Digite a query PromQL no campo **Metrics browser**
5. Ajuste o tipo de visualização (Time series, Gauge, Stat, Table)
6. Salve o dashboard

**Exemplo — painel de restarts de pods:**
```promql
# Query
sum(increase(kube_pod_container_status_restarts_total[24h])) by (pod, namespace)
# Tipo: Table
# Útil para identificar pods instáveis
```

### Provisionar dashboards via GitOps

Para que dashboards sejam versionados no Git, adicione no `values.yaml`:

```yaml
kube-prometheus-stack:
  grafana:
    dashboardProviders:
      dashboardproviders.yaml:
        apiVersion: 1
        providers:
          - name: 'custom'
            folder: 'Custom'
            type: file
            options:
              path: /var/lib/grafana/dashboards/custom
    dashboardsConfigMaps:
      custom: "grafana-dashboards-custom"
```

E crie um ConfigMap com o JSON do dashboard exportado do Grafana (Export → JSON).

### Alterar a senha do admin

```bash
kubectl exec -it deployment/monitoring-grafana -n monitoring \
  -c grafana -- grafana-cli admin reset-admin-password NOVA_SENHA
```

Ou via `values.yaml` para persistir via GitOps:
```yaml
kube-prometheus-stack:
  grafana:
    adminPassword: "sua-senha-aqui"
```

### Troubleshooting

**Grafana sem dados / "No data"**

1. Verifique se o datasource está configurado: **Configuration → Data Sources → Prometheus → Test**
2. Verifique se a query está correta rodando no Prometheus primeiro
3. Verifique o time range do dashboard (canto superior direito) — pode estar fora do período com dados

**Grafana não inicia (CrashLoopBackOff)**
```bash
kubectl logs deployment/monitoring-grafana -n monitoring -c grafana --tail=50
```

---

## Bootstrap — Subindo do Zero

Sequência completa para subir o ambiente em uma máquina nova.

### 1. Instalar k3s

```bash
curl -sfL https://get.k3s.io | sh -

# Copia o kubeconfig para o usuário atual
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER ~/.kube/config

# Verifica
kubectl get nodes
```

### 2. Instalar ArgoCD

```bash
kubectl create namespace argocd

kubectl apply --server-side -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Aguarda todos os pods ficarem Ready
kubectl get pods -n argocd -w
```

### 3. Aplicar GitOps

```bash
# Clone o repositório
git clone https://github.com/justgu1/infra.git
cd infra

# Aplica o projeto e o root app
kubectl apply -f argocd/projects.yaml
kubectl apply -f argocd/root-app.yaml
```

A partir daqui o ArgoCD sincroniza automaticamente `core/` (namespaces, ingress, monitoring).

### 4. Verificar

```bash
# Applications sendo sincronizadas
kubectl get applications -n argocd

# Pods de todos os namespaces
kubectl get pods -A
```

---

## WSL — Limitações e Soluções

O WSL2 tem restrições de mount namespace que afetam alguns componentes do Kubernetes. Esta seção documenta os problemas encontrados e as soluções aplicadas.

### node-exporter desabilitado

**Problema:** O node-exporter é um DaemonSet que monta o filesystem raiz do host para coletar métricas do sistema operacional. No WSL2, o mount namespace não é `shared` ou `slave`, então o container não consegue ser criado:

```
failed to generate spec: path "/" is mounted on "/" but it is not a shared or slave mount
```

**Solução:** Desabilitado no `values.yaml` com `nodeExporter: enabled: false`. Em produção (bare metal, cloud), pode e deve ser habilitado.

### Admission webhooks desabilitados

**Problema:** O `kube-prometheus-stack` instala um `ValidatingWebhookConfiguration` para validar recursos do Prometheus Operator. O job `admission-patch` injeta o CA do webhook após gerar o certificado. No WSL2, após reinicializações, o certificado gerado não é reconhecido pelo API server:

```
http: TLS handshake error: remote error: tls: bad certificate
```

Isso impede o Prometheus Operator de criar os StatefulSets do Prometheus e Alertmanager.

**Solução:** Desabilitado no `values.yaml`:
```yaml
kube-prometheus-stack:
  prometheusOperator:
    admissionWebhooks:
      enabled: false
    tls:
      enabled: false
```

Em produção, manter habilitado para segurança.

### argocd-repo-server em Unknown após restart

**Problema:** Após reinicialização do WSL, o pod `argocd-repo-server` pode ficar em estado `Unknown` — o processo foi encerrado mas o objeto Kubernetes não foi atualizado. Isso bloqueia todo o ArgoCD pois é o repo-server que processa os manifests.

**Solução:**
```bash
kubectl delete pod -n argocd -l app.kubernetes.io/name=argocd-repo-server --force --grace-period=0
kubectl get pods -n argocd -w   # aguarda 1/1 Running
```

### Resumo das diferenças WSL vs Produção

| Configuração | WSL (atual) | Produção |
| --- | --- | --- |
| `nodeExporter.enabled` | `false` | `true` |
| `admissionWebhooks.enabled` | `false` | `true` |
| `prometheusOperator.tls.enabled` | `false` | `true` |

---

## Troubleshooting Geral

### Checklist quando algo não está funcionando

```bash
# 1. Estado geral
kubectl get pods -A | grep -v Running | grep -v Completed

# 2. Eventos recentes com erros
kubectl get events -A --sort-by='.lastTimestamp' | grep -i warning | tail -20

# 3. Status das applications ArgoCD
kubectl get applications -n argocd

# 4. Logs do componente com problema
kubectl logs <pod> -n <namespace> --tail=50
```

### ArgoCD está com alguma Application em OutOfSync após reinício

```bash
# 1. Verifica se o repo-server está rodando
kubectl get pods -n argocd

# 2. Se repo-server estiver Unknown, força delete
kubectl delete pod -n argocd -l app.kubernetes.io/name=argocd-repo-server --force --grace-period=0

# 3. Aguarda subir e força refresh
kubectl get pods -n argocd -w
kubectl patch application <nome> -n argocd --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### Monitoring não sobe após reinício do WSL

```bash
# 1. Verifica pods
kubectl get pods -n monitoring

# 2. Se Prometheus ou Alertmanager não existirem (StatefulSets)
kubectl get statefulset -n monitoring

# 3. Verifica logs do operator
kubectl logs deployment/monitoring-kube-prometheus-operator -n monitoring --tail=30

# 4. Se tiver erro de TLS/webhook, deleta o webhook e reinicia o operator
kubectl delete validatingwebhookconfiguration monitoring-kube-prometheus-admission 2>/dev/null || true
kubectl rollout restart deployment monitoring-kube-prometheus-operator -n monitoring
```

### Sync travado em "waiting for healthy state"

Ocorre quando um recurso nunca fica Healthy durante o sync e bloqueia os próximos recursos.

```bash
# Cancela a operação travada
kubectl patch application <nome> -n argocd --type json \
  -p '[{"op":"remove","path":"/operation"}]'

# Deleta o recurso problemático manualmente se necessário
kubectl delete <tipo> <nome> -n <namespace>

# Força novo sync via UI: Sync → Force + Prune → Synchronize
```

### Porta já em uso no port-forward

```bash
# Descobre qual processo está usando a porta
lsof -i :<porta>

# Mata o processo
kill <PID>

# Ou usa outra porta local
kubectl port-forward svc/monitoring-grafana -n monitoring 3001:80
```