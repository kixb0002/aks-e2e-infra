# aks-e2e-infra

Infrastructure Azure en Terraform. Voir le README parent pour l'architecture et la feuille de route.

- `bootstrap/` : lancé une seule fois en local (state + identité GitHub OIDC)
- `modules/` : modules réutilisables
- `envs/main/` : composition des modules
