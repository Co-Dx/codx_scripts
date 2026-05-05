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
#   -r, --repository : the repository for which the SBOM is being generated (e.g. 
#                      pcr_dart_server, pcr_analysis, pcr_internal_website, hasura_engine)
#   -v, --version    : the version of the image for which the SBOM is being generated (e.g. 1.0.0)
#   -p, --path       : the path to the apk or aab file for which the SBOM is being generated
#       --pipeline   : if set, outputs the version in a format compatible with Azure DevOps 
#                      pipeline variables and logs
#
# EXAMPLE
######################################################################################

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'; ORANGE='\033[0;33m'; WHITE='\033[0;37m'; NC='\033[0m'
CRITICAL="$RED[CRITICAL]$NC"; WARNING="$YELLOW[WARNING]$NC"; INFO="$BLUE[INFO]$NC"; PASS="$GREEN[PASS]$NC"

# ====================================================================================
# Functions
# ====================================================================================

function generateSBOM_container() {
    local path="$1"
    printf "\n======================================================================================\n"
    printf "Generating SBOM for container...\n"
    if [[ "$path" == "NONE" ]]; then
        printf "$CRITICAL No path specified. Exiting.\n"
        exit 1
    fi
    cdxgen -p -o SBOM/SBOM_container.json -t docker ${cdxgen_flags[@]+"${cdxgen_flags[@]}"} "$path:$version"
}

function generateSBOM_apk() {
    local path="$1"
    printf "\n======================================================================================\n"
    printf "Generating SBOM for apk...\n"
    if [[ "$path" == "NONE" ]]; then
        printf "$CRITICAL No path to apk specified. Exiting.\n"
        exit 1
    fi
    local apk_file
    apk_file=$(find "$path" -maxdepth 1 -name "*.apk" | head -n 1)
    if [[ -n "$apk_file" ]]; then
        cdxgen -p -o SBOM/SBOM_apk.json -t apk ${cdxgen_flags[@]+"${cdxgen_flags[@]}"} "$apk_file"
    else
        printf "$INFO No apk artifacts found at '$path', skipping SBOM generation for apk.\n"
    fi
}

function generateSBOM_aab() {
    local path="$1"
    printf "\n======================================================================================\n"
    printf "Generating SBOM for aab...\n"
    if [[ "$path" == "NONE" ]]; then
        printf "$CRITICAL No path to aab specified. Exiting.\n"
        exit 1
    fi
    local aab_file
    aab_file=$(find "$path" -maxdepth 1 -name "*.aab" | head -n 1)
    if [[ -n "$aab_file" ]]; then
        cdxgen -p -o SBOM/SBOM_aab.json -t aab ${cdxgen_flags[@]+"${cdxgen_flags[@]}"} "$aab_file"
    else
        printf "$INFO No aab artifacts found at '$path', skipping SBOM generation for aab.\n"
    fi
}

function generateSBOM_python() {
    printf "\n======================================================================================\n"
    printf "Generating SBOM for python...\n"
    cdxgen -p -o SBOM/SBOM_python.json -t python ${cdxgen_flags[@]+"${cdxgen_flags[@]}"} .
}

function generateSBOM_dart() {
    printf "\n======================================================================================\n"
    printf "Generating SBOM for dart...\n"
    cdxgen -p -o SBOM/SBOM_dart.json -t dart ${cdxgen_flags[@]+"${cdxgen_flags[@]}"} .
}

function generateSBOM_flutter() {
    printf "\n======================================================================================\n"
    printf "Generating SBOM for flutter...\n"
    cdxgen -p -o SBOM/SBOM_flutter.json -t flutter ${cdxgen_flags[@]+"${cdxgen_flags[@]}"} .
}

# ====================================================================================
# Arguments
# ====================================================================================
repository=""
version=""
path="NONE"
json_pretty=1

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
        --no-pretty)
            json_pretty=0
            ;;
        --pipeline)
            WARNING="##vso[task.logissue type=warning]"
            CRITICAL="##vso[task.logissue type=error]"
            ;;
        *)
            printf "$CRITICAL Unknown parameter passed: $1\n"
            exit 1
            ;;
    esac
    shift
done

if [[ -z $repository ]]; then
    repository=$(basename "$(pwd)")
fi

cdxgen_flags=()
[[ -n "$version" ]]        && cdxgen_flags+=("--project-version" "$version")
[[ "$json_pretty" -eq 1 ]] && cdxgen_flags+=("--json-pretty")

# ====================================================================================
# Functionality
# ====================================================================================
printf "\n======================================================================================\n"
printf "Preping repo...\n"
mkdir -p SBOM

if [[ "$repository" == "pcr_analysis" ]]; then
    rm requirements_notebook.txt
    rm requirements-test.txt
    generateSBOM_python
    generateSBOM_container "$path"

elif [[ "$repository" == "pcr_dart_server" ]]; then
    generateSBOM_dart
    generateSBOM_container "$path"
    
elif [[ "$repository" == "pcr_internal_website" ]]; then
    generateSBOM_flutter
    generateSBOM_container "$path"

elif [[ "$repository" == "pcr_tech_app" ]]; then
    generateSBOM_flutter
    generateSBOM_apk "$path"
    generateSBOM_aab "$path"

else
    printf "$WARNING Not implemented yet for $repository.\n"

fi
