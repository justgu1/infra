# Infraestrutura Kubernetes — justgu1

Infraestrutura completa baseada em **k3s**, gerenciada via **GitOps com ArgoCD**.

Tudo que roda no cluster está declarado neste repositório. Nenhuma alteração manual no cluster — toda mudança passa pelo Git.

---

## Stack

| Componente               | Função                                        |
| ------------------------ | --------------------------------------------- |
| k3s                      | Distribuição leve do Kubernetes               |
| ArgoCD                   | Sincroniza o cluster com este repositório     |
| NGINX Ingress Controller | Roteamento HTTP/HTTPS para os serviços        |
| Prometheus               | Coleta e armazena métricas do cluster         |
| Alertmanager             | Gerencia e roteia alertas                     |
| Grafana                  | Dashboards de observabilidade                 |
| kube-state-metrics       | Métricas de estado dos recursos do Kubernetes |

---

## Estrutura

```
infra/
 ├ apps/          → aplicações deployadas no cluster
 ├ argocd/        → configuração do GitOps (projetos e root app)
 ├ bootstrap/     → instalação inicial do ArgoCD
 └ core/          → infraestrutura base
     ├ ingress/       → NGINX Ingress Controller
     ├ monitoring/    → Prometheus + Grafana + Alertmanager
     └ namespaces/    → namespaces do cluster
```

---

## Como funciona o GitOps

O ArgoCD monitora este repositório continuamente. Quando um commit é feito, ele detecta a diferença entre o estado desejado (Git) e o estado atual do cluster, e aplica as mudanças automaticamente.

```
Commit no Git → ArgoCD detecta → Aplica no cluster
```

Para fazer qualquer alteração na infraestrutura: **edite os arquivos, faça commit e push**. Não use `kubectl apply` diretamente em recursos gerenciados pelo ArgoCD.

---

## Primeiros passos

Para subir o ambiente do zero, consulte o [docs.md](./docs.md) — seção **Bootstrap**.

Para entender cada tecnologia, troubleshooting e uso no dia a dia, consulte o [docs.md](./docs.md).

---

## Acesso rápido (ambiente local)

```bash
# ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# https://localhost:8080

# Grafana
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
# http://localhost:3000  →  admin / prom-operator

# Prometheus
kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090
# http://localhost:9090

# Alertmanager
kubectl port-forward svc/monitoring-kube-prometheus-alertmanager -n monitoring 9093:9093
# http://localhost:9093
```

---

## Ambiente local (WSL + k3s)

Este repositório foi desenvolvido e testado em WSL2 com k3s. Algumas funcionalidades estão desabilitadas por limitações do WSL — veja a seção **WSL — Limitações e Soluções** no [docs.md](./docs.md).

---

## Roadmap

- Expor serviços via Ingress (ArgoCD, Grafana)
- TLS automático com cert-manager
- Receivers no Alertmanager (Slack / email)
- Regras de alerta customizadas
- Ambientes separados (dev / staging / prod)