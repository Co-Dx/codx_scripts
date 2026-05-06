######################################################################################
# Deploy
#
# SYNOPSIS
#   ./deployApp.sh -b <version> -t <type1> <type2> ... -f <flavor1> <flavor2> ...
#   ./deployApp.sh -d <os1> <os2> ... -f <flavor1> <flavor2> ...
#
# DESCRIPTION
#   This script is used to deploy the project through the pipeline.
#
#     -b, --build  : specify a custom version to build.
#     -t, --type   : specify the type of build for custom versions (apk, aab, ipa).
#     -f, --flavor : specify the flavor of the build.
#     -d, --deploy : deploy the project to the specified OS (android, ios).
#
# EXAMPLE
######################################################################################

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'; ORANGE='\033[0;33m'; WHITE='\033[0;37m'; NC='\033[0m'
CRITICAL="$RED[CRITICAL]$NC"; WARNING="$YELLOW[WARNING]$NC"; INFO="$BLUE[INFO]$NC"; COMPLETE="$GREEN[COMPLETE]$NC"; 
SUCCESS="$GREEN[SUCCESS]$NC"; FAIL="$RED[FAIL]$NC"

tag_in_git() {
    local tag_name="$1"
    if [[ $(git tag -l "$tag_name") ]]; then
        git push origin --delete "refs/tags/$tag_name" || true
        git fetch -pPf
    fi
    git tag "$tag_name"
    git push origin "$tag_name" || true
    printf "\n$SUCCESS Tag ${YELLOW}$tag_name${NC} created and pushed to remote.\n\n"
}

combine_array() {
    local env_array=("$@")
    local combined=""
    for env in "${env_array[@]}"; do
        if [[ -z "$combined" ]]; then
            combined="$env"
        else
            combined="${combined}_${env}"
        fi
    done
    echo "$combined"
}

ask_confirmation() {
    local prompt="$1"
    while true; do
        read -rp "$prompt (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;
            * ) return 1;;
        esac
    done
}

# ====================================================================================
# Arguments
# ====================================================================================

types=()
version=""
tag="plzDeploy2"

while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--build)
            tag="plzBuild2"
            version="$2"
            shift 2
            ;;
        -t|--type)
            shift
            while [[ $# -gt 0 && ! $1 =~ ^- ]]; do
                types+=("$1")
                shift
            done
            ;;
        -f|--flavor)
            shift
            while [[ $# -gt 0 && ! $1 =~ ^- ]]; do
                types+=("$1")
                shift
            done
            ;;
        -d|--deploy)
            shift
            while [[ $# -gt 0 && ! $1 =~ ^- ]]; do
                types+=("$1")
                shift
            done
            ;;
        *)
            printf "$CRITICAL Unknown argument: $1\n"
            exit 1
            ;;
    esac
done


if [[ ${#types[@]} -eq 0 ]]; then
    printf "$CRITICAL No build types specified for custom build or no environments specified for deployment. Use -h for options.\n"
    exit 1
fi
if [[ $tag == "plzBuild2" ]]; then
    if [[ -z $version ]]; then
        printf "$CRITICAL No version specified for build. Use -h for options.\n"
        exit 1
    fi
    if [[ $version =~ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
        printf "$CRITICAL Version cannot be in SemVer format (x.y.z) for custom builds. Use -h for options.\n"
        exit 1
    fi
fi

# ====================================================================================
# Code
# ====================================================================================
git fetch -pPf

combined_types=$(combine_array "${types[@]}")
if [[ $tag == "plzDeploy2" ]]; then
    tag="$tag-${combined_types}"

elif [[ $tag == "plzBuild2" ]]; then
    if [[ $(git tag -l "$version") ]]; then
        printf "$WARNING Version $version already exists. Your deployment will likely fail silently.\n"
        if ! ask_confirmation "          Continue?"; then
            exit 0
        fi
    fi
    tag="$tag-${combined_types}-${version}"

fi

tag_in_git "$tag"