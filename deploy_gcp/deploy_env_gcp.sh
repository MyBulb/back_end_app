#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 1) CONFIGURATION
###############################################################################

PROJECT_ID="mybulb-back-prod"
ENV_FILE=".env.prod"

# Fichier généré pour Cloud Run:
# KEY=KEY:latest,OTHER=OTHER:latest
OUT_BINDINGS_FILE="deploy_gcp/_cloudrun_secrets_bindings.txt"

###############################################################################
# 2) VÉRIFICATIONS PRÉALABLES
###############################################################################

command -v gcloud >/dev/null 2>&1 || { echo "❌ gcloud introuvable."; exit 1; }

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ Fichier $ENV_FILE introuvable (attendu à la racine du repo)."
  echo "   Chemin actuel: $(pwd)"
  exit 1
fi

echo "==> Projet GCP: ${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}" >/dev/null

# Active Secret Manager (safe à relancer)
gcloud services enable secretmanager.googleapis.com >/dev/null

###############################################################################
# 3) SYNC .env.prod -> SECRET MANAGER (CREATE/UPDATE)
###############################################################################

echo "==> Sync .env.prod -> Secret Manager (les valeurs ne seront jamais affichées)"

# Fonction trim (compatible bash 3)
trim() {
  echo "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# Fichier temporaire qui va collecter les clés (pour générer ensuite les bindings)
TMP_KEYS="$(mktemp)"
cleanup() { rm -f "$TMP_KEYS"; }
trap cleanup EXIT

while IFS= read -r line || [ -n "$line" ]; do
  line="$(trim "$line")"

  # ignore vides + commentaires
  [ -z "$line" ] && continue
  echo "$line" | grep -qE '^[[:space:]]*#' && continue

  # supporte "export KEY=VALUE"
  line="$(echo "$line" | sed -E 's/^export[[:space:]]+//')"

  # ignore si pas de '='
  echo "$line" | grep -q '=' || { echo "⚠️  Ignoré (pas de '='): $line"; continue; }

  key="$(trim "${line%%=*}")"
  value="${line#*=}"

  # clé valide ?
  echo "$key" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*$' || { echo "⚠️  Ignoré (clé invalide): $key"; continue; }

  # CREATE si nécessaire
  if ! gcloud secrets describe "$key" >/dev/null 2>&1; then
    echo "  • Création du secret: $key"
    gcloud secrets create "$key" >/dev/null
  else
    echo "  • Mise à jour du secret: $key (nouvelle version)"
  fi

  # UPDATE (nouvelle version) — valeur via stdin, jamais affichée
  printf "%s" "$value" | gcloud secrets versions add "$key" --data-file=- >/dev/null

  # stocke la key (pour bindings)
  echo "$key" >> "$TMP_KEYS"

done < "$ENV_FILE"

###############################################################################
# 4) GÉNÉRATION DES BINDINGS CLOUD RUN (sans doublons)
###############################################################################

mkdir -p "$(dirname "$OUT_BINDINGS_FILE")"

# unique + format KEY=KEY:latest,OTHER=OTHER:latest
# (trie + supprime doublons)
BINDINGS="$(sort "$TMP_KEYS" | uniq | awk '
  BEGIN { first=1 }
  {
    binding=$0"="$0":latest"
    if (first) { printf "%s", binding; first=0 }
    else { printf ",%s", binding }
  }
')"

printf "%s" "$BINDINGS" > "$OUT_BINDINGS_FILE"

echo
echo "✅ Secrets synchronisés dans Secret Manager."
echo "✅ Bindings Cloud Run générés dans: $OUT_BINDINGS_FILE"
echo "   (format: KEY=KEY:latest,OTHER=OTHER:latest)"