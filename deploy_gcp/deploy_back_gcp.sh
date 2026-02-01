#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 1) CONFIGURATION (à personnaliser si besoin)
###############################################################################

PROJECT_ID="mybulb-back-prod"
REGION="europe-west1"

SERVICE_NAME="mybulb-back"
AR_REPO="mybulb"

# Image Artifact Registry (base)
IMAGE_BASE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/${SERVICE_NAME}"

# Fichier généré par deploy_env_gcp.sh (bindings secrets Cloud Run)
BINDINGS_FILE="deploy_gcp/_cloudrun_secrets_bindings.txt"

# (Optionnel) Variables NON secrètes (tu peux laisser vide)
# Ex: "NODE_ENV=production"
ENV_VARS=""

###############################################################################
# 2) VÉRIFICATIONS
###############################################################################

command -v gcloud >/dev/null 2>&1 || { echo "❌ gcloud introuvable."; exit 1; }
[ -f "Dockerfile" ] || { echo "❌ Dockerfile introuvable à la racine du repo."; exit 1; }
[ -f "$BINDINGS_FILE" ] || { echo "❌ $BINDINGS_FILE introuvable. Lance d'abord deploy_env_gcp.sh"; exit 1; }

echo "==> Projet: $PROJECT_ID"
gcloud config set project "$PROJECT_ID" >/dev/null

###############################################################################
# 3) BUILD & PUSH (Cloud Build -> Artifact Registry)
###############################################################################

TAG="$(date +%Y%m%d-%H%M%S)"
IMAGE="${IMAGE_BASE}:${TAG}"

echo "==> Build + push via Cloud Build: $IMAGE"
gcloud builds submit --tag "$IMAGE" .

###############################################################################
# 4) DÉPLOIEMENT CLOUD RUN (nouvelle révision)
###############################################################################

# On lit les bindings secrets générés (format: KEY=KEY:latest,...)
SECRET_BINDINGS="$(cat "$BINDINGS_FILE")"

# Sécurité: on enlève un éventuel PORT si jamais il traîne encore
# (Cloud Run gère PORT tout seul)
SECRET_BINDINGS="$(echo "$SECRET_BINDINGS" \
  | sed -E 's/(^|,)PORT=PORT:latest(,|$)/\1/g' \
  | sed -E 's/,,/,/g' \
  | sed -E 's/^,|,$//g')"

echo "==> Deploy Cloud Run service: $SERVICE_NAME (region: $REGION)"
if [ -n "$ENV_VARS" ]; then
  gcloud run deploy "$SERVICE_NAME" \
    --image "$IMAGE" \
    --region "$REGION" \
    --no-invoker-iam-check \
    --set-env-vars "$ENV_VARS" \
    --set-secrets "$SECRET_BINDINGS"
else
  gcloud run deploy "$SERVICE_NAME" \
    --image "$IMAGE" \
    --region "$REGION" \
    --no-invoker-iam-check \
    --set-secrets "$SECRET_BINDINGS"
fi

###############################################################################
# 4bis) ACCÈS AU SERVICE (INVOCATION)
# - On tente "allUsers" (public)
# - Si bloqué par une policy d'organisation, fallback sur "domain:my-bulb.com"
###############################################################################

echo "==> Configuration accès (invoker)"

if gcloud run services add-iam-policy-binding "$SERVICE_NAME" \
  --region "$REGION" \
  --member="allUsers" \
  --role="roles/run.invoker" >/dev/null 2>&1; then
  echo "✅ Service rendu public (allUsers)."
else
  echo "⚠️  allUsers bloqué par une policy. Fallback sur domain:my-bulb.com"
  gcloud run services add-iam-policy-binding "$SERVICE_NAME" \
    --region "$REGION" \
    --member="domain:my-bulb.com" \
    --role="roles/run.invoker" >/dev/null || true
  echo "✅ Service accessible aux comptes @my-bulb.com"
fi

###############################################################################
# 5) RÉCAP + URL
###############################################################################

SERVICE_URL="$(gcloud run services describe "$SERVICE_NAME" --region "$REGION" --format='value(status.url)')"
echo
echo "================================================="
echo "✅ Déploiement terminé"
echo "Service : $SERVICE_NAME"
echo "URL     : $SERVICE_URL"
echo "Image   : $IMAGE"
echo "================================================="