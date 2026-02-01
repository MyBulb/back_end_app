#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 1) CONFIGURATION (à personnaliser)
###############################################################################

PROJECT_ID="mybulb-back-prod"
REGION="europe-west1"

# Repo Docker Artifact Registry (nom du "dossier" d'images)
AR_REPO="mybulb"

###############################################################################
# 2) CONTEXTE GCP (projet + région) + vérifs
###############################################################################

echo "==> Vérification gcloud"
command -v gcloud >/dev/null 2>&1 || { echo "❌ gcloud introuvable. Installe Google Cloud SDK."; exit 1; }

echo "==> Sélection du projet : ${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}" >/dev/null

ACTIVE_PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
if [ "${ACTIVE_PROJECT}" != "${PROJECT_ID}" ]; then
  echo "❌ Projet actif incorrect: ${ACTIVE_PROJECT}"
  exit 1
fi

echo "==> Définition région par défaut : ${REGION}"
gcloud config set run/region "${REGION}" >/dev/null
gcloud config set artifacts/location "${REGION}" >/dev/null

echo "✅ Projet & région OK (${PROJECT_ID} / ${REGION})"

###############################################################################
# 3) ACTIVATION DES APIs NÉCESSAIRES (setup projet)
###############################################################################

echo "==> Activation des APIs (Cloud Run, Cloud Build, Artifact Registry, Secret Manager)"
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  logging.googleapis.com >/dev/null

echo "✅ APIs activées"

###############################################################################
# 3bis) PERMISSIONS CLOUD BUILD (bucket source)
# Objectif: éviter l'erreur 403 sur gs://<project>_cloudbuild lors de `gcloud builds submit`
###############################################################################

echo "==> Configuration des permissions Cloud Build (bucket source)"

PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
BUCKET="gs://${PROJECT_ID}_cloudbuild"

CLOUDBUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

echo "Project number     : ${PROJECT_NUMBER}"
echo "Cloud Build SA     : ${CLOUDBUILD_SA}"
echo "Compute default SA : ${COMPUTE_SA}"
echo "Bucket             : ${BUCKET}"

# Le bucket est généralement créé automatiquement au premier build,
# mais selon certaines policies/permissions, l'accès peut être bloqué.
# On tente d'ajouter les permissions ; si le bucket n'existe pas encore,
# on n'échoue pas (on réessaiera après le premier build).
add_bucket_binding() {
  local member="$1"
  local role="$2"

  if gcloud storage buckets describe "${BUCKET}" >/dev/null 2>&1; then
    gcloud storage buckets add-iam-policy-binding "${BUCKET}" \
      --member="${member}" \
      --role="${role}" >/dev/null || true
  else
    echo "⚠️  Bucket ${BUCKET} introuvable pour l'instant (il sera créé au premier build)."
    echo "   Relance setup_gcp.sh après un premier build si nécessaire."
    return 0
  fi
}

# Accès lecture/écriture objets (suffisant pour upload & fetch des sources Cloud Build)
add_bucket_binding "serviceAccount:${CLOUDBUILD_SA}" "roles/storage.objectAdmin"
add_bucket_binding "serviceAccount:${COMPUTE_SA}"   "roles/storage.objectAdmin"

echo "✅ Permissions Cloud Build configurées (ou en attente de création du bucket)"

###############################################################################
# 4) CRÉATION DU REPO ARTIFACT REGISTRY (Docker)
###############################################################################

echo "==> Création/validation du repo Artifact Registry (docker) : ${AR_REPO}"

if gcloud artifacts repositories describe "${AR_REPO}" --location="${REGION}" >/dev/null 2>&1; then
  echo "✅ Repo Artifact Registry existe déjà : ${AR_REPO} (${REGION})"
else
  echo "==> Création du repo ${AR_REPO} en ${REGION}"
  gcloud artifacts repositories create "${AR_REPO}" \
    --repository-format=docker \
    --location="${REGION}" \
    --description="Docker repo for MyBulb backend" >/dev/null
  echo "✅ Repo créé : ${AR_REPO}"
fi

###############################################################################
# 4bis) PERMISSIONS ARTIFACT REGISTRY + CLOUD LOGGING (pour Cloud Build)
# Objectif:
# - autoriser le push d'images sur Artifact Registry (uploadArtifacts)
# - autoriser l'écriture des logs dans Cloud Logging
###############################################################################

echo "==> Configuration des permissions Artifact Registry + Cloud Logging"

# (On réutilise PROJECT_NUMBER / CLOUDBUILD_SA / COMPUTE_SA déjà calculés)
echo "Artifact Registry repo : ${AR_REPO} (${REGION})"
echo "Cloud Build SA         : ${CLOUDBUILD_SA}"
echo "Compute default SA     : ${COMPUTE_SA}"

# Autoriser le push d'images Docker dans Artifact Registry
# (fix: Permission 'artifactregistry.repositories.uploadArtifacts' denied)
gcloud artifacts repositories add-iam-policy-binding "${AR_REPO}" \
  --location="${REGION}" \
  --member="serviceAccount:${CLOUDBUILD_SA}" \
  --role="roles/artifactregistry.writer" >/dev/null || true

gcloud artifacts repositories add-iam-policy-binding "${AR_REPO}" \
  --location="${REGION}" \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/artifactregistry.writer" >/dev/null || true

# Autoriser l'écriture de logs dans Cloud Logging
# (fix: "does not have permission to write logs to Cloud Logging")
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${CLOUDBUILD_SA}" \
  --role="roles/logging.logWriter" >/dev/null || true

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/logging.logWriter" >/dev/null || true

echo "✅ Permissions Artifact Registry + Logging configurées"
###############################################################################
# 4ter) PERMISSIONS SECRET MANAGER (pour Cloud Run runtime)
# Objectif: autoriser le service account à lire les secrets au runtime
###############################################################################

echo "==> Configuration des permissions Secret Manager (secretAccessor)"

# Donne l'accès lecture des secrets au runtime (Cloud Run révision)
# Ici Cloud Run utilise le Compute default SA dans ton projet
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/secretmanager.secretAccessor" >/dev/null || true

# Bonus: au cas où Cloud Build/Cloud Run utiliserait le Cloud Build SA
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${CLOUDBUILD_SA}" \
  --role="roles/secretmanager.secretAccessor" >/dev/null || true

echo "✅ Secret Manager accessor OK"
###############################################################################
# 5) CHECKS RAPIDES (confort)
###############################################################################

echo "==> Vérification Cloud Build (liste des builds, peut être vide)"
gcloud builds list --limit=1 >/dev/null 2>&1 || true
echo "✅ Cloud Build OK"

echo
echo "================================================="
echo "✅ Setup GCP terminé"
echo "Projet : ${PROJECT_ID}"
echo "Région : ${REGION}"
echo "Repo   : ${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}"
echo "Bucket : gs://${PROJECT_ID}_cloudbuild"
echo "================================================="
echo
echo "➡️  Prochaine étape :"
echo "   - sync tes secrets depuis .env vers Secret Manager (deploy_env_gcp.sh)"
echo "   - puis build+deploy Cloud Run (deploy_back_gcp.sh)"
echo