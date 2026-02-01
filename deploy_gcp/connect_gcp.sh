#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 1) CONFIGURATION GÉNÉRALE (À ADAPTER UNE SEULE FOIS)
###############################################################################

# ID du projet GCP (obligatoire)
PROJECT_ID="mybulb-back-prod"

# Région par défaut pour les ressources régionales
# (Cloud Run, Artifact Registry, Cloud SQL, etc.)
REGION="europe-west1"

###############################################################################
# 2) AUTHENTIFICATION GCP
###############################################################################

echo "==> Connexion à Google Cloud (ouvre un navigateur si nécessaire)"
gcloud auth login

# Vérification rapide
ACCOUNT="$(gcloud config get-value account 2>/dev/null || true)"
if [ -z "$ACCOUNT" ]; then
  echo "❌ Aucune session gcloud active."
  exit 1
fi

echo "✅ Connecté avec le compte : $ACCOUNT"

###############################################################################
# 3) CONTEXTE PROJET
###############################################################################

echo "==> Sélection du projet GCP : $PROJECT_ID"
gcloud config set project "$PROJECT_ID" >/dev/null

CURRENT_PROJECT="$(gcloud config get-value project 2>/dev/null)"
if [ "$CURRENT_PROJECT" != "$PROJECT_ID" ]; then
  echo "❌ Le projet actif n'est pas correct."
  exit 1
fi

echo "✅ Projet actif : $CURRENT_PROJECT"

###############################################################################
# 4) RÉGIONS PAR DÉFAUT (IMPORTANT POUR LES AUTRES SCRIPTS)
###############################################################################

echo "==> Définition des régions par défaut"

# Cloud Run
gcloud config set run/region "$REGION" >/dev/null

# Artifact Registry
gcloud config set artifacts/location "$REGION" >/dev/null

echo "✅ Région par défaut définie : $REGION"

###############################################################################
# 5) (OPTIONNEL) DOCKER AUTH POUR ARTIFACT REGISTRY
###############################################################################

# Utile seulement si un jour tu build/push en local.
# Inutile pour Cloud Build, mais sans danger.
echo "==> (Optionnel) Configuration Docker pour Artifact Registry"
gcloud auth configure-docker "${REGION}-docker.pkg.dev" -q

###############################################################################
# 6) RÉCAP FINAL
###############################################################################

echo
echo "================================================="
echo "✅ gcloud prêt à l'emploi"
echo "Compte       : $ACCOUNT"
echo "Projet       : $PROJECT_ID"
echo "Région       : $REGION"
echo "================================================="
echo
echo "➡️  Tu peux maintenant lancer :"
echo "   - 01_setup_gcp.sh"
echo "   - deploy_env_gcp.sh"
echo "   - deploy_backend.sh"
echo