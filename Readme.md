# Kubernetes Infrastructure

Infraestrutura Kubernetes baseada em **k3s** e gerenciada via **GitOps com ArgoCD**.

O objetivo deste repositório é manter **toda a infraestrutura declarativa dentro do Git**, permitindo que qualquer ambiente seja recriado de forma consistente.

---

# Stack

| Componente               | Função                       |
| ------------------------ | ---------------------------- |
| Kubernetes (k3s)         | Orquestração de containers   |
| ArgoCD                   | GitOps / Deploy declarativo  |
| NGINX Ingress Controller | Entrada HTTP/HTTPS           |
| Prometheus               | Coleta de métricas           |
| Grafana                  | Dashboards e observabilidade |

---

# Arquitetura

Fluxo GitOps da infraestrutura:

```
Git
 ↓
ArgoCD
 ↓
Cluster Kubernetes
```

Toda alteração feita neste repositório é aplicada automaticamente no cluster.

---

# Estrutura do Repositório

```
infra/
 ├ apps
 │   └ aplicações deployadas no cluster
 │
 ├ argocd
 │   ├ projects.yaml
 │   └ root-app.yaml
 │
 ├ bootstrap
 │   └ argocd-install.yaml
 │
 ├ core
 │   ├ ingress
 │   │   └ nginx.yaml
 │   │
 │   ├ monitoring
 │   │   └ kube-prometheus-stack.yaml
 │   │
 │   └ namespaces
 │       ├ ingress.yaml
 │       └ monitoring.yaml
 │
 └ README.md
```

Descrição das pastas:

| Pasta     | Descrição                      |
| --------- | ------------------------------ |
| bootstrap | Recursos iniciais do cluster   |
| argocd    | Configuração GitOps            |
| core      | Infraestrutura base do cluster |
| apps      | Aplicações rodando no cluster  |

---

# Componentes do Cluster

## Ingress

Responsável por expor serviços HTTP/HTTPS para fora do cluster.

```
NGINX Ingress Controller
```

---

## Observabilidade

Stack de monitoramento:

```
Prometheus
Grafana
Alertmanager
Node Exporter
kube-state-metrics
```

---

# Ambiente Local

Cluster de desenvolvimento rodando em:

```
WSL
k3s
kubectl
```

Instalação do k3s:

```
curl -sfL https://get.k3s.io | sh -
```

Verificar cluster:

```
kubectl get nodes
```

Verificar pods:

```
kubectl get pods -A
```

---

# Bootstrap do Cluster

O bootstrap acontece em etapas.

## 1 Instalar ArgoCD

Criar namespace:

```
kubectl create namespace argocd
```

Instalar ArgoCD:

```
kubectl apply --server-side -n argocd \
-f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Verificar pods:

```
kubectl get pods -n argocd
```

---

## 2 Acessar ArgoCD

```
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Abrir:

```
https://localhost:8080
```

---

## 3 Login no ArgoCD

Usuário:

```
admin
```

Senha inicial:

```
kubectl -n argocd get secret argocd-initial-admin-secret \
-o jsonpath="{.data.password}" | base64 --decode
```

---

## 4 Aplicar configuração GitOps

Aplicar projeto:

```
kubectl apply -f argocd/projects.yaml
```

Aplicar root application:

```
kubectl apply -f argocd/root-app.yaml
```

O ArgoCD começará a gerenciar automaticamente:

```
core/
 ├ namespaces
 ├ ingress
 └ monitoring
```

---

# Verificações

Ver nodes:

```
kubectl get nodes
```

Ver pods:

```
kubectl get pods -A
```

Ver serviços:

```
kubectl get svc -A
```

Ver aplicações ArgoCD:

```
kubectl get applications -n argocd
```

---

# Comandos úteis

Logs de um pod:

```
kubectl logs <pod>
```

Descrever recurso:

```
kubectl describe pod <pod>
```

Executar shell em container:

```
kubectl exec -it <pod> -- /bin/sh
```

---

# Observabilidade

Acessar Grafana:

```
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
```

Abrir:

```
http://localhost:3000
```

Usuário:

```
admin
```

Senha padrão:

```
prom-operator
```

---

# Deploy de aplicações

Novas aplicações devem ser adicionadas em:

```
apps/
```

ArgoCD fará o deploy automaticamente.

---

# Ambiente de Produção

Esta infraestrutura foi projetada para rodar também em:

* servidor dedicado
* bare metal
* cloud (AWS / GCP / Azure)

Instalação recomendada:

```
Ubuntu Server
k3s
kubectl
helm
```

Instalar k3s:

```
curl -sfL https://get.k3s.io | sh -
```

Verificar cluster:

```
kubectl get nodes
```

Depois aplicar bootstrap:

```
kubectl apply -f bootstrap/
kubectl apply -f argocd/
```

---

# Escalabilidade

Esta infraestrutura permite:

* múltiplos ambientes
* múltiplos projetos
* deploy automático
* observabilidade completa
* infraestrutura versionada

---

# Roadmap

Próximos passos da plataforma:

* Expor ArgoCD via Ingress
* Expor Grafana via domínio
* TLS automático com cert-manager
* Deploy automático de aplicações
* Ambientes separados (dev / staging / prod)

---

# Licença

Uso interno para infraestrutura Kubernetes.
