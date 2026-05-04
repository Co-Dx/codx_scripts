######################################################################################
# codx
#
# SYNOPSIS
#   codx <script> [args...] | -h
#
# DESCRIPTION
#   Central dispatcher for codx-scripts. Fetches and executes a named script
#   from the shared codx-scripts GitHub repository.
#   The repo must be public for raw HTTPS access.
#
#   list             : list all available scripts in the remote repo.
#   version          : show the repo version.
#   update           : re-run the installer to refresh the alias.
#   help             : display this help message.
#
# EXAMPLE
#   codx deploy2 -c c110 apk
#       Fetch and run the deploy2 script with a custom config.
#
#   codx versioner --bump minor
#       Fetch and run the versioner script to bump the minor version.
######################################################################################

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'; ORANGE='\033[0;33m'; WHITE='\033[0;37m'; NC='\033[0m'
CRITICAL="${RED}[CRITICAL]${NC}"; WARNING="${YELLOW}[WARNING]${NC}"; INFO="${BLUE}[INFO]${NC}"; COMPLETE="${GREEN}[COMPLETE]${NC}";
SUCCESS="${GREEN}[SUCCESS]${NC}"; FAIL="${RED}[FAIL]${NC}"

set -euo pipefail

# ====================================================================================
# Configuration
# ====================================================================================

CODX_ORG="${CODX_ORG:-Co-Dx}"
CODX_REPO="${CODX_REPO:-codx_scripts}"
CODX_BRANCH="${CODX_BRANCH:-main}"
BASE_URL="https://raw.githubusercontent.com/${CODX_ORG}/${CODX_REPO}/${CODX_BRANCH}"

# Allowlist of scripts developers can run via codx.
# Add or remove entries here to control access.
ALLOWED_SCRIPTS=(
    "deploy2"
    "genSBOM"
    "versioner2"
)

# ====================================================================================
# Arguments
# ====================================================================================

if [[ $# -eq 0 ]]; then
    awk '/^#{80,}/{flag=!flag; next} flag' "$0" | sed 's/#//g'
    exit 1
fi

SCRIPT="$1"; shift

case "$SCRIPT" in
    help|--help|-h)
        echo " "
        awk '/^#{80,}/{flag=!flag; next} flag' $0 | sed 's/#//g'
        echo " "
        exit 0
        ;;
    version|--version|-v)
        VERSION_URL="${BASE_URL}/VERSION"
        if curl -fsSL --max-time 5 "$VERSION_URL" 2>/dev/null; then
            printf '\n'
        else
            printf "$WARNING No VERSION file found in ${CODX_ORG}/${CODX_REPO}@${CODX_BRANCH}\n"
        fi
        exit 0
        ;;
    list)
        printf "$INFO Available scripts:\n"
        for s in "${ALLOWED_SCRIPTS[@]}"; do
            printf "  ${CYAN}%s${NC}\n" "$s"
        done
        exit 0
        ;;
    update)
        printf "$INFO Re-running installer…\n"
        bash <(curl -fsSL "${BASE_URL}/install.sh")
        exit 0
        ;;
esac

# ====================================================================================
# Code
# ====================================================================================

SCRIPT_URL="${BASE_URL}/scripts/${SCRIPT}.sh"

# Check against the allowlist
ALLOWED=false
for s in "${ALLOWED_SCRIPTS[@]}"; do
    [[ "$s" == "$SCRIPT" ]] && ALLOWED=true && break
done

if ! $ALLOWED; then
    printf "$CRITICAL Unknown script: '${SCRIPT}'.\n"
    printf "$INFO Available scripts: ${YELLOW}%s${NC}\n" "${ALLOWED_SCRIPTS[*]}"
    exit 1
fi

bash <(curl -fsSL "$SCRIPT_URL") "$@"
