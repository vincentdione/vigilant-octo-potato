#!/bin/bash
set -eu


# Le nom du projet doit correspondre à celui défini dans le fichier <pipeine.yml>
# au niveau du Job de déploiement du pipeline (jobs > name > plan > put > params > pipelines > name)
NOM_PIPELINE="my_app_pipeline"
NOM_FICHIER_PIPELINE="pipeline.yaml"
NOM_FICHIER_VARIABLE="pipeline-vars.yaml"
# Ici <feder> correspond à l'équipe déclarée dans le projet http://git-scm.pole-emploi.intra/plateforme/k8s/build/equipes
EQUIPE="test"
CONCOURSE_URL="http://localhost:8080"
USERNAME="test"
PASSWORD="test"
# Doit correspondre au fichier où sont stockés les versions de production
FICHIER_VERSIONS_PROD="changement/versions-prod.json"
# Map pour associer la resource concourse avec le fichier de sauvegarde de la version
VERSIONS=("version-pn364-ihm")


REPERTOIRE_PROJET=$(dirname "$0")
REPERTOIRE_SCRIPT=$(basename "$0")



# ------------------------------------------- Functions -------------------------------------------
usage() {
    cat <<EOF
Usage:
    $REPERTOIRE_SCRIPT help
    $REPERTOIRE_SCRIPT init
    $REPERTOIRE_SCRIPT validate
    $REPERTOIRE_SCRIPT pin-versions
    $REPERTOIRE_SCRIPT unpin-versions
    $REPERTOIRE_SCRIPT unpin-version "resource version"
EOF
}

fly_sync() {
    fly -t $EQUIPE sync
}

fly_login() {
    #fly -t test login -c http://localhost:8080 -u test -p test
    fly -t $EQUIPE status || {
        echo "Tentative de connexion à Concourse..."
        fly -t $EQUIPE login -c $CONCOURSE_URL -u $USERNAME -p $PASSWORD --team-name $EQUIPE || {
            echo "Synchronisation de fly avec la version du serveur..."
            fly_sync
            fly -t $EQUIPE login -c $CONCOURSE_URL -u $USERNAME -p $PASSWORD --team-name $EQUIPE
        }
    }
    #fly -t $EQUIPE status || fly -t $EQUIPE login -c http://localhost:8080 -u $USERNAME -p $PASSWORD --team-name $EQUIPE  && return 0
}





fly_set_pipeline() {
    fly -t $EQUIPE set-pipeline -c "$REPERTOIRE_PROJET/$NOM_FICHIER_PIPELINE" -p "$NOM_PIPELINE" -l "$REPERTOIRE_PROJET/$NOM_FICHIER_VARIABLE" -v "changement_check_interval=24h" -n
    fly -t $EQUIPE unpause-pipeline -p "$NOM_PIPELINE"
}


fly_validate_pipeline() {
    fly  -t $EQUIPE validate-pipeline --config "$REPERTOIRE_PROJET/$NOM_FICHIER_PIPELINE" -l "$REPERTOIRE_PROJET/$NOM_FICHIER_VARIABLE" -v "changement_check_interval=24h"
}


fly_unpin_resource() {
    echo "- fly unpin-resource : $1"
    case "${VERSIONS[@]}" in  *"$1"*) ;;
      *)
      echo "  ==> Ressource $1 inconnue. Valeurs possibles : ${VERSIONS[@]}"
      exit 1
      ;;
    esac
    fly -t $EQUIPE unpin-resource --resource "$NOM_PIPELINE"/"$1" 2>/dev/null  \
    || echo -e "  ==> INFO : $1 non figée \n---------------------------------------------"
}


fly_pin_resource() {
    echo "- fly pin-resource : $1"
    GIT_USER_NAME=$(git config user.name || echo -n "anonymous")
    DATE=$(date '+%Y-%m-%d %H:%M:%S')
by $GIT_USER_NAME
at $DATE"
    fly -t $EQUIPE pin-resource --resource "$NOM_PIPELINE"/"$1" \
        --version number:$2"
}


recupere_version() {
    key=$1
    fichier=$2
    version=$(git show origin/master:$fichier | jq ".\"${key}\"" --raw-output)
    [[ $version = null ]] && echo -e "La valeur pour la clé $key non trouvée dans le fichier $fichier \n $(git show origin/master:$fichier | jq . -C)" >&2 && exit 1
    [[ -z $version ]] && echo $version >&2 && exit 1
    echo $version
}
# ------------------------------------------- Main -------------------------------------------
[ $# -ne 1 ] && usage && exit 0


fly_login


case "$1" in
help)
    usage && exit 0
    ;;
init)
    [ $# -ne 1 ] && usage && exit 1
    fly_set_pipeline
    ;;
validate)
    [ $# -ne 1 ] && usage && exit 1
    fly_validate_pipeline
    ;;
pin-versions)
    ([ $# -lt 2 ] || [ $# -gt 3 ]) && usage && exit 1
    git fetch origin master
    fichierVersion=$FICHIER_VERSIONS_PROD
    for k in "${VERSIONS[@]}"; do
        version=$( recupere_version $k $fichierVersion)
        fly_pin_resource $k $version $2
    done
    ;;
unpin-versions)
    [ "$#" -ne 1 ] && usage && exit 1
    for k in "${VERSIONS[@]}"; do
        fly_unpin_resource $k
    done
    ;;
unpin-version)
    [ "$#" -ne 2 ] && usage && exit 1
    fly_unpin_resource $2
    ;;
*)
    usage && exit 1
    ;;
esac


exit 0

