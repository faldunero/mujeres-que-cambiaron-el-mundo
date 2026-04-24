#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# deploy.sh — Publica el sitio estático "Mujeres que Cambiaron el Mundo"
#             a GitHub + Firebase Hosting. Sin build, son solo HTMLs + PNGs.
#
# Uso:
#   ./deploy.sh                 # commit+push + firebase deploy
#   ./deploy.sh --firebase-only # solo redeploy a Firebase
#   ./deploy.sh --github-only   # solo commit + push
# ---------------------------------------------------------------------------
set -euo pipefail

REPO_NAME="${REPO_NAME:-mujeres-que-cambiaron-el-mundo}"
GH_VISIBILITY="${GH_VISIBILITY:-public}"   # public | private
FIREBASE_PROJECT="${FIREBASE_PROJECT:-mujeres-que-cambiaron-el-mundo}"

MODE="${1:-normal}"

c_info()  { printf "\033[1;34m==>\033[0m %s\n" "$*"; }
c_ok()    { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
c_warn()  { printf "\033[1;33m!\033[0m %s\n" "$*"; }
c_err()   { printf "\033[1;31m✗\033[0m %s\n" "$*" >&2; }

need() {
  command -v "$1" >/dev/null 2>&1 || { c_err "Falta '$1' en PATH. Instálalo antes de continuar."; exit 1; }
}

cd "$(dirname "$0")"

# Sanity: debemos estar en la carpeta con los 4 items del juego
if [[ ! -f index.html || ! -f detalle.html || ! -d logo || ! -d Set_Completo_60_Tarjetas_Mujeres ]]; then
  c_err "Corre este script desde /mujeres (debe tener index.html, detalle.html, logo/, Set_Completo_60_Tarjetas_Mujeres/)."
  exit 1
fi

# ---------------------------------------------------------------------------
# 1) GitHub — init + commit + crear repo la primera vez / push después
# ---------------------------------------------------------------------------
if [[ "$MODE" != "--firebase-only" ]]; then
  need git
  need gh

  if [[ ! -d .git ]]; then
    c_info "git init + primer commit"
    git init -b main
    git add .
    git commit -m "chore: sitio estático inicial (index + detalle + 60 cartas + trucos)"
  else
    c_info "commit de cambios pendientes (si hay)"
    git add .
    git diff --cached --quiet || git commit -m "chore: update"
  fi

  if ! git remote get-url origin >/dev/null 2>&1; then
    c_info "Creando repo en GitHub ($GH_VISIBILITY): $REPO_NAME"
    gh auth status >/dev/null 2>&1 || gh auth login
    gh repo create "$REPO_NAME" --"$GH_VISIBILITY" --source=. --remote=origin --push
    c_ok "Repo creado: $(gh repo view --json url -q .url)"
  else
    c_info "git push a origin ($(git remote get-url origin))"
    git push -u origin main
    c_ok "Push OK"
  fi
fi

# ---------------------------------------------------------------------------
# 2) Firebase Hosting — deploy directo (sin build)
# ---------------------------------------------------------------------------
if [[ "$MODE" != "--github-only" ]]; then
  need firebase

  # Si se pasa FIREBASE_PROJECT por env, sobrescribe .firebaserc
  if [[ -n "$FIREBASE_PROJECT" ]]; then
    c_info "Usando proyecto Firebase: $FIREBASE_PROJECT"
    cat > .firebaserc <<EOF
{
  "projects": {
    "default": "$FIREBASE_PROJECT"
  }
}
EOF
  fi

  c_info "firebase deploy --only hosting"
  firebase deploy --only hosting

  c_ok "Firebase OK → https://${FIREBASE_PROJECT}.web.app/"
fi

c_ok "Listo."
