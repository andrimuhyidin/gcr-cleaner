# !/bin/bash
# Prerequisites: setup the environment variables (env.ini)

main() {
    init
    auth_gcr
    run_cleaner
}

init() {
    echo "[info] -- Load env config"
    source ./config/gcr-cleaner.ini
}

auth_gcr() {
    echo "[info] -- Authenticating to GCR"
    echo $GCR_CRED | base64 -d > gcr-user.json
    gcloud auth activate-service-account $SERVICE_ACCOUNT --key-file=gcr-user.json
    gcloud auth print-access-token | docker login -u oauth2accesstoken --password-stdin $GCR_URL_REGION
}

run_cleaner() {
    local C=0
    NUMBER_OF_IMAGES_TO_REMAIN=$((${RETAIN_IMAGE} - 1))
    
    echo "[info] -- Run GCR Cleaner"
    for IMAGE_TAG in ${IMAGE_TAGS[@]}; do
    (
        # 1. Get date and time the image want to retain
        CUTOFF=$(
            gcloud container images list-tags $IMAGE_NAME \
            --limit=unlimited \
            --sort-by=~TIMESTAMP \
            --flatten="[].tags[]" \
            --filter="tags~$IMAGE_TAG" \
            --format=json | TZ=/usr/share/zoneinfo/UTC jq -r '.['$NUMBER_OF_IMAGES_TO_REMAIN'].timestamp.datetime | sub("(?<before>.*):"; .before ) | strptime("%Y-%m-%d %H:%M:%S%z") | mktime | strftime("%Y-%m-%d %H:%M:%S%z")'		
        )
        # output: 2022-03-29 00:40:05+0000

        # 2. Get the image list (digest format)
        IMAGE_TAG_LIST=$(
            gcloud container images list-tags $IMAGE_NAME \
            --limit=unlimited \
            --sort-by=~TIMESTAMP \
            --flatten="[].tags[]" \
            --filter="tags~$IMAGE_TAG AND timestamp.datetime < '${CUTOFF}'" \
            --format="get(digest)"
        )
        # output: sha256:d72e2d383f2d5fb1e8186ebfd1fbb22a87c04f52ac12fc379d21abb368d373df

        # 3. List of images digest want to delete
        for digest in $IMAGE_TAG_LIST; do
            (
                set -x
                gcloud container images delete -q --force-delete-tags "${IMAGE_NAME}@${digest}"
            )
            let C=C+1
        done
        echo "Deleted ${C} images in ${IMAGE_NAME}:$IMAGE_TAG~." >&2
    )
    done
}

main; exit