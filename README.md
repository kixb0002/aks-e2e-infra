# AKS End-to-End DevOps Project

Projet DevOps de bout en bout sur **Azure Kubernetes Service**, construit pour ressembler à un environnement d'entreprise, contraint à **un seul Resource Group** : `RG-Taoufik-Mellah` (France Central).

## Choix d'architecture

| Domaine | Choix |
|---|---|
| IaC | Terraform (state distant dans un Storage Account) |
| CI/CD | GitHub Actions, OIDC vers Azure (aucun secret) |
| Déploiement | GitOps avec Argo CD (pull, rien n'est poussé vers le cluster) |
| Cluster | AKS **privé**, 3 zones, node pools system + user |
| Réseau | Hub-spoke simulé (2 VNets peerés), Private Endpoints, NAT Gateway pour l'egress |
| Exposition | Gateway API (Envoy Gateway), cert-manager + Let's Encrypt (DNS-01), external-dns, Azure DNS (domaine Namecheap délégué) |
| Sécurité | Workload Identity, Key Vault + CSI driver, Kyverno, Cosign, Trivy, Checkov |
| Observabilité | Prometheus, Grafana, Loki, Tempo, OpenTelemetry, SLO |
| Données | PostgreSQL Flexible Server privé, migrations Flyway |
| Environnements | `dev`, `staging`, `prod` = namespaces sur un seul cluster (coût). En entreprise, ce seraient des clusters ou subscriptions séparés. |

**Exclus volontairement** : Azure Firewall, multi-région, Front Door, Velero, Sentinel, Defender, Azure Managed Prometheus/Grafana (providers `Microsoft.Monitor` et `Microsoft.Dashboard` non enregistrés sur la subscription : Prometheus et Grafana tournent dans le cluster via `kube-prometheus-stack`).

## Pourquoi un runner self-hosted ?
Le cluster, l'ACR, le Key Vault et le state Terraform sont **privés**. Les runners hébergés par GitHub (sur Internet) ne peuvent donc pas les joindre. On place une petite VM **runner GitHub** dans le hub VNet. C'est exactement ce que font les entreprises.

## Les 3 dépôts

```
aks-e2e/
├── aks-e2e-infra/            # Tout ce qui est Azure (Terraform)
│   ├── bootstrap/            # Lancé 1 seule fois en local : Storage du state + identité GitHub OIDC
│   ├── modules/
│   │   ├── network/          # VNet hub + spoke, subnets, peering, NSG, NAT Gateway, Private DNS zones
│   │   ├── identity/         # Managed identities (AKS, kubelet, workloads) + role assignments
│   │   ├── acr/              # Container Registry Premium + Private Endpoint
│   │   ├── keyvault/         # Key Vault + Private Endpoint
│   │   ├── aks/              # Cluster privé, node pools, OIDC issuer, Workload Identity, maintenance
│   │   ├── dns/              # Zone Azure DNS publique (délégation Namecheap)
│   │   ├── postgres/         # PostgreSQL Flexible Server, accès privé (VNet integration)
│   │   ├── monitoring/       # Log Analytics, budgets
│   │   └── runner/           # VM runner GitHub self-hosted dans le hub
│   ├── envs/main/            # Composition des modules (root module)
│   └── .github/workflows/    # fmt/validate/checkov → plan en PR → apply après approbation, drift
│
├── aks-e2e-app/              # Le code applicatif
│   ├── services/api/         # FastAPI (Python) + tests + Dockerfile
│   ├── services/frontend/    # Frontend statique servi par nginx + Dockerfile
│   ├── db/migrations/        # Scripts Flyway (V1__init.sql, ...)
│   └── .github/workflows/    # test → scan → build → SBOM → signature → push ACR → PR vers gitops
│
└── aks-e2e-gitops/           # L'état désiré du cluster (source de vérité d'Argo CD)
    ├── bootstrap/            # Installation d'Argo CD + application racine (app-of-apps)
    ├── platform/             # Briques plateforme installées par Argo CD
    │   ├── gateway/          # Envoy Gateway + Gateway HTTPS
    │   ├── cert-manager/     # + ClusterIssuers Let's Encrypt staging/prod
    │   ├── external-dns/
    │   ├── kyverno/
    │   ├── monitoring/       # kube-prometheus-stack, alertes, dashboards
    │   └── observability/    # OpenTelemetry Collector, Loki, Tempo
    ├── policies/kyverno/     # Policies : images signées, pas de root, limits obligatoires...
    ├── charts/aks-e2e-app/   # Chart Helm de l'application
    └── apps/{dev,staging,prod}/  # values.yaml par environnement (tag d'image promu ici)
```

## Feuille de route

Chaque phase se termine par quelque chose de **vérifiable**.

- [ ] **Phase 0 — Prérequis** : outils locaux (az, terraform, kubectl, helm, gh, docker), 3 repos GitHub créés, nom de domaine choisi
- [ ] **Phase 1 — Bootstrap** : Storage Account du state, Managed Identity GitHub + federated credentials ✔ `terraform init` sur le backend distant
- [ ] **Phase 2 — Réseau** : hub/spoke, subnets, NSG, NAT Gateway, Private DNS zones ✔ peering « Connected »
- [ ] **Phase 3 — Services socle** : ACR, Key Vault, Log Analytics, zone DNS + délégation Namecheap ✔ `nslookup -type=NS`
- [ ] **Phase 4 — Runner** : VM runner self-hosted enregistrée sur GitHub ✔ runner « Idle » dans GitHub
- [ ] **Phase 5 — AKS** : cluster privé + identités ✔ `kubectl get nodes` depuis le runner
- [ ] **Phase 6 — Pipeline infra** : plan en PR, apply avec approbation, détection de drift
- [ ] **Phase 7 — GitOps** : Argo CD + app-of-apps ✔ UI Argo CD, apps « Synced »
- [ ] **Phase 8 — Exposition** : Envoy Gateway, external-dns, cert-manager ✔ `https://` avec un certificat valide
- [ ] **Phase 9 — Application** : API + frontend + tests + docker-compose local
- [ ] **Phase 10 — Données** : PostgreSQL privé, secret dans Key Vault, Flyway ✔ l'API lit/écrit en base
- [ ] **Phase 11 — CI app** : tests, Trivy, SBOM, Cosign, push ACR, PR auto vers gitops
- [ ] **Phase 12 — Promotion** : dev → staging → prod avec approbations (GitHub Environments)
- [ ] **Phase 13 — Sécurité runtime** : Kyverno (images signées, pas de root, limits), NetworkPolicies deny-all, quotas
- [ ] **Phase 14 — Observabilité** : métriques, logs, traces, SLO + alertes Teams/e-mail
- [ ] **Phase 15 — Day-2** : upgrades AKS, maintenance windows, budgets/OpenCost, tests de charge k6, runbooks

## Conventions
- Préfixe des ressources : `aks-e2e-` (ou abréviation CAF : `vnet-aks-e2e-hub`, `kv-akse2e-xxx`...)
- Tags obligatoires : `project=aks-e2e`, `env`, `owner`, `managed-by=terraform`
- Région : `francecentral`
