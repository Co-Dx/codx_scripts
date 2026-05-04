######################################################################################
# Generate SBOM for the container and the repo
# 2026-05-01
#
# SYNOPSIS
#   ./pipeline/genSBOM.sh -r <repository> -v <image version> [-a <alpha env>]
#
# DESCRIPTION
#   This script is used to generate the SBOM for the container and the repository. 
#   It is used in the CI/CD pipeline to ensure that we have a record of the dependencies 
#   and vulnerabilities of our software. The script takes in several arguments that are 
#   used to determine the environment and repository being deployed, as well as the image 
#   being used.
#
#   -r, --repository : the repository for which the SBOM is being generated (e.g. pcr_dart_server, pcr_analysis, pcr_internal_website, hasura_engine)
#   -v, --version    : the version of the image for which the SBOM is being generated (e.g. 1.0.0)
#   -p, --path       : the path to the apk or aab file for which the SBOM is being generated
#   -h, --help       : display this help message.
#
# EXAMPLE
######################################################################################

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'; ORANGE='\033[0;33m'; WHITE='\033[0;37m'; NC='\033[0m'
CRITICAL="$RED[CRITICAL]$NC"; WARNING="$YELLOW[WARNING]$NC"; INFO="$BLUE[INFO]$NC"; PASS="$GREEN[PASS]$NC"

WARNING="##vso[task.logissue type=warning]"
CRITICAL="##vso[task.logissue type=error]"

# ====================================================================================
# Functions
# ====================================================================================

function generateSBOM_container() {
    local version="$1"
    local path="$2"

    if [[ "$path" == "NONE" ]]; then
        printf "$CRITICAL No path specified. Exiting.\n"
        exit 1
    fi

    printf "\n======================================================================================\n"
    printf "Generating SBOM for container...\n"
    cdxgen -p -o SBOM/SBOM_container.json -t docker --project-version "$version" --json-pretty "$path:$version"
}

function generateSBOM_apk() {
    local version="$1"
    local path="$2"

    if [[ "$path" == "NONE" ]]; then
        printf "$CRITICAL No path to apk specified. Exiting.\n"
        exit 1
    fi

    printf "\n======================================================================================\n"
    printf "Generating SBOM for apk...\n"
    if ls "$path"/*.apk > /dev/null 2>&1; then
        cdxgen -p -o SBOM/SBOM_apk.json -t apk --project-version "$version" --json-pretty "$(ls "$path"/*.apk | head -n 1)"
    else
        printf "$INFO No apk artifacts found at '$path', skipping SBOM generation for apk.\n"
    fi
}

function generateSBOM_aab() {
    local version="$1"
    local path="$2"

    if [[ "$path" == "NONE" ]]; then
        printf "$CRITICAL No path to aab specified. Exiting.\n"
        exit 1
    fi

    printf "\n======================================================================================\n"
    printf "Generating SBOM for aab...\n"
    if ls "$path"/*.aab > /dev/null 2>&1; then
        cdxgen -p -o SBOM/SBOM_aab.json -t aab --project-version "$version" --json-pretty "$(ls "$path"/*.aab | head -n 1)"
    else
        printf "$INFO No aab artifacts found at '$path', skipping SBOM generation for aab.\n"
    fi
}

function generateSBOM_python() {
    local version="$1"

    printf "\n======================================================================================\n"
    printf "Generating SBOM for python...\n"
    cdxgen -p -o SBOM/SBOM_python.json -t python --project-version "$version" --json-pretty .
}

function generateSBOM_dart() {
    local version="$1"

    printf "\n======================================================================================\n"
    printf "Generating SBOM for dart...\n"
    cdxgen -p -o SBOM/SBOM_dart.json -t dart --project-version "$version" --json-pretty .
}

function generateSBOM_flutter() {
    local version="$1"

    printf "\n======================================================================================\n"
    printf "Generating SBOM for flutter...\n"
    cdxgen -p -o SBOM/SBOM_flutter.json -t flutter --project-version "$version" --json-pretty .
}

# ====================================================================================
# Arguments
# ====================================================================================
repository=""
version=""
path="."

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --repository|-r)
            repository="$2"
            shift
            ;;
        --version|-v)
            version="$2"
            shift
            ;;
        --path|-p)
            path="$2"
            shift
            ;;
        --help|-h)
            printf "\n"
            awk '/^#{80,}/{flag=!flag; next} flag' $0 | sed 's/#//g'
            printf "\n"
            exit 0
            ;;
        *)
            printf "$CRITICAL Unknown parameter passed: $1\n"
            exit 1
            ;;
    esac
    shift
done

if [[ -z $repository || -z $version ]]; then
    printf "$CRITICAL Missing required arguments.\n"
    exit 1
fi

# ====================================================================================
# Functionality
# ====================================================================================
printf "\n======================================================================================\n"
printf "Preping repo...\n"
mkdir SBOM

if [[ "$repository" == "pcr_analysis" ]]; then
    rm requirements_notebook.txt
    rm requirements-test.txt
    generateSBOM_python "$version"
    generateSBOM_container "$version" "$path"

elif [[ "$repository" == "pcr_dart_server" ]]; then
    generateSBOM_dart "$version"
    generateSBOM_container "$version" "$path"
    
elif [[ "$repository" == "pcr_internal_website" ]]; then
    generateSBOM_flutter "$version"
    generateSBOM_container "$version" "$path"

elif [[ "$repository" == "pcr_tech_app" ]]; then
    generateSBOM_flutter "$version"
    generateSBOM_apk "$version" "$path"
    generateSBOM_aab "$version" "$path"

else
    printf "$WARNING Not implemented yet for $repository.\n"

fi
