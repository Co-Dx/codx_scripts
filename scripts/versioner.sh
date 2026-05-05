######################################################################################
# Versioner
# 2026-03-12
#
# SYNOPSIS
#   ./versioner2.sh [ -p <source> | -b <source> | -d | -m <major> <minor> ] [-h]
#
# DESCRIPTION
#   This script will select the version number to use for a particular commit. If
#   running in a pipeline, it will also set the version as a pipeline variable.
#   if the source branch is a PR, the version will be "pr<PR number>_YYYYMMDD_hhmmss".
#   For a plzBuild-*-* tag the version will be set the the last part of the tag.
#   For a plzDeploy-* tag the version will be set to the version defined by the
#   tag on the current commit. If the pipeline is running on the main branch the
#   version will be set to "<major.minor>.<patch>" where patch is automatically
#   incremented from the last known tag for the given major.minor version.
#   
#   -p, --pr       : Set version for PR builds (source branch format: refs/pull/<number>).
#   -b, --build    : Set version for plzBuild tag.
#   -d, --deploy   : Set version for deploy tag (must be on a commit with a valid semver tag already).
#   -m, --main     : Set version for main branch commit.
#       --pipeline : (Optional) If set, outputs the version in a format compatible with 
#                    Azure DevOps pipeline variables and logs.
#
# EXAMPLE
#   ./versioner2.sh -p refs/pull/123
#       Set version for a PR build with source branch refs/pull/123.
#
#   ./versioner2.sh -b refs/tags/plzBuild2-dev-1.2.3
#       Set version for a plzBuild tag with version 1.2.3.
#
#   ./versioner2.sh -d
#       Set version for a deploy tag. The current commit must have a valid semver tag.
#
#   ./versioner2.sh -m 1 2
#       Set version for a main branch commit with major version 1 and minor version 2. 
#       Patch version will be auto-incremented.
######################################################################################

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'; ORANGE='\033[0;33m'; WHITE='\033[0;37m'; NC='\033[0m'
CRITICAL="$RED[CRITICAL]$NC"; WARNING="$YELLOW[WARNING]$NC"; INFO="$BLUE[INFO]$NC"; COMPLETE="$GREEN[COMPLETE]$NC"; SUCCESS="$GREEN[SUCCESS]$NC"; FAIL="$RED[FAIL]$NC"

# ====================================================================================
# Arguments
# ====================================================================================
verType=0 # 1=PR, 2=build tag, 3=deploy tag, 4=main branch
source="NONE"
major="NONE"
minor="NONE"
pipeline=0

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -p|--pr) 
            verType=1
            source="$2"
            shift
            ;;
        -b|--build)
            verType=2
            source="$2"
            shift
            ;;
        -d|--deploy)
            verType=3
            ;;
        -m|--main)
            verType=4
            major="$2"
            minor="$3"
            shift 2
            ;;
        --pipeline) 
            pipeline=1
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

# ====================================================================================
# Functionality
# ====================================================================================
printf "========================================================================\n"
if [[ $verType -eq 1 ]]; then
    printf "Setting version for PR source: ${CYAN}$source${NC}\n"
    if [[ -z $source ]] || ! echo "$source" | grep -Eq "^refs/pull/[0-9]+/.*$" > /dev/null; then
        printf "$CRITICAL Invalid or missing source for PR versioning. Expected format: refs/pull/<number>/...\n"
        exit 1
    fi
    version="pr$(echo "$source" | cut -d '/' -f3)_$(date +%Y%m%dT%H%M%S)"

elif [[ $verType -eq 2 ]]; then
    printf "Setting version for build tag source: ${CYAN}$source${NC}\n"
    if [[ -z $source ]] || ! echo "$source" | grep -Eq "^refs/tags/plzBuild2-" > /dev/null; then
        printf "$CRITICAL Invalid or missing source for build tag versioning. Expected format: refs/tags/plzBuild2-<env1_env2>-<version>.\n"
        exit 1
    fi
    version=$( echo $source | sed -E 's|refs/tags/plzBuild2-||' | cut -d'-' -f2-100 )
    if [[ $version == "" ]]; then
        printf "$CRITICAL Invalid custom release tag format. Expected plzBuild2-<env1_env2>-<version>.\n"
        exit 1
    elif echo "$version" | grep -Eq "[0-9]+\.[0-9]+\.[0-9]+" > /dev/null; then
        printf "$CRITICAL Custom release version '$version' matches standard versioning format. This is not allowed.\n"
        exit 1
    fi

elif [[ $verType -eq 3 ]]; then
    printf "Setting version for deploy tag.\n"
    if git tag --points-at $(git rev-parse HEAD) | grep -Eq "^[0-9]+\.[0-9]+\.[0-9]+$" > /dev/null; then
        printf "$INFO Git tag found, setting version from tag.\n"
        majorC=$(git tag --points-at $(git rev-parse HEAD) | grep -Ex "^[0-9]+\.[0-9]+\.[0-9]+$" | cut -d '.' -f1 | sort -n | tail -1)
        minorC=$(git tag --points-at $(git rev-parse HEAD) | grep -Ex "^$majorC\.[0-9]+\.[0-9]+$" | cut -d '.' -f2 | sort -n | tail -1)
        patchC=$(git tag --points-at $(git rev-parse HEAD) | grep -Ex "^$majorC\.$minorC\.[0-9]+$" | cut -d '.' -f3 | sort -n | tail -1)
        version="$majorC.$minorC.$patchC"
    else 
        printf "$CRITICAL No valid git tag found for deploy. Exiting.\n"
        exit 1
    fi

elif [[ $verType -eq 4 ]]; then
    printf "Setting version for main branch with ${CYAN}major=$major${NC} and ${CYAN}minor=$minor${NC}\n"
    if [[ -z $major || -z $minor ]]; then
        printf "$CRITICAL Major and minor version must be specified for main branch versioning. Exiting.\n"
        exit 1
    fi
    if [[ $(git tag --list "$major.$minor.*") ]]; then
        patch=$(git tag --list "$major.$minor.*" | cut -d '.' -f3 | sort -n | tail -1)
        patch=$((patch + 1))
    else
        patch=0
    fi
    version="$major.$minor.$patch"

else
    printf "$CRITICAL No versioning type specified. Use -h for options.\n"
    exit 1

fi

printf "\n$INFO Version set to ${YELLOW}$version${NC}.\n\n"
if [[ $pipeline -eq 1 ]]; then
    printf "$INFO Setting pipeline variable 'version' to '$version'.\n"
    echo "##vso[task.setvariable variable=version;isOutput=true]$version"
fi