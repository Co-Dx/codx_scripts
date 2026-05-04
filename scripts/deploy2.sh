######################################################################################
# Deploy 2 
#
# SYNOPSIS
#   ./deploy2.sh -d [android|ios] | -c <version> [apk|aab|ios] | -h
#
# DESCRIPTION
#   This script is used to deploy the project through the pipeline.
#
#   -d, --deploy     : deploy the project to the specified environments.
#   -c, --custom     : create a custom build of the project with the specified version and deploy to the specified environments.
#   -h, --help       : display this help message.
#
# EXAMPLE
#   ./deploy2.sh -c my_custom_version apk
#       Create a custom build of the project with the version "my_custom_version" and compile the apk.
#
#   ./deploy2.sh -d android ios
#       Deploy the project to the android and ios environments.
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

combine_envs() {
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

envs=()
tag=""
version=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--deploy)
            tag="plzDeploy2"
            shift
            while [[ $# -gt 0 && ! $1 =~ ^- ]]; do
                envs+=("$1")
                shift
            done
            ;;
        -c|--custom)
            tag="plzBuild2"
            version="$2"
            shift 2
            while [[ $# -gt 0 && ! $1 =~ ^- ]]; do
                envs+=("$1")
                shift
            done
            ;;
        -h|--help)
            echo " "
            awk '/^#{80,}/{flag=!flag; next} flag' $0 | sed 's/#//g'
            echo " "
            exit 0
            ;;
        *)
            printf "$CRITICAL Unknown argument: $1\n"
            exit 1
            ;;
    esac
done

if [[ -z $tag ]]; then
    printf "$CRITICAL No deployment type specified. Use -h for options.\n"
    exit 1
fi
if [[ ${#envs[@]} -eq 0 ]]; then
    printf "$CRITICAL No environments specified for deployment or no build types specified for custom build. Use -h for options.\n"
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

combined_envs=$(combine_envs "${envs[@]}")
if [[ $tag == "plzDeploy2" ]]; then
    tag="$tag-${combined_envs}"
elif [[ $tag == "plzBuild2" ]]; then
    tag="$tag-${combined_envs}-${version}"
    if [[ $(git tag -l "$version") ]]; then
        printf "$WARNING Version $version already exists. Your deployment will likely fail silently.\n"
        if ! ask_confirmation "          Continue?"; then
            exit 0
        fi
    fi
fi

tag_in_git "$tag"