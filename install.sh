######################################################################################
# install.sh — codx onboarding
#
# SYNOPSIS
#   bash <(curl -fsSL https://raw.githubusercontent.com/your-org/codx-scripts/main/install.sh)
#
# DESCRIPTION
#   One-liner developer onboarding script for codx.
#   Run once per machine to install the codx alias.
#
#   1. Detects your shell (zsh / bash) and the correct profile file.
#   2. Appends (or refreshes) the codx alias — safe to run multiple times.
#   3. Prints the source command needed to activate the alias immediately.
#
#   Supported environments: macOS, Linux, Git Bash, WSL.
#
# EXAMPLE
#   bash <(curl -fsSL https://raw.githubusercontent.com/your-org/codx-scripts/main/install.sh)
#       Install (or refresh) the codx alias in your shell profile.
#
#   CODX_PROFILE=~/.zshrc bash <(curl -fsSL ...install.sh)
#       Force a specific profile file instead of auto-detecting.
######################################################################################

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'; ORANGE='\033[0;33m'; WHITE='\033[0;37m'; NC='\033[0m'
CRITICAL="${RED}[CRITICAL]${NC}"; WARNING="${YELLOW}[WARNING]${NC}"; INFO="${BLUE}[INFO]${NC}"; COMPLETE="${GREEN}[COMPLETE]${NC}";
SUCCESS="${GREEN}[SUCCESS]${NC}"; FAIL="${RED}[FAIL]${NC}"
BOLD='\033[1m'

set -euo pipefail

# ====================================================================================
# Configuration
# ====================================================================================

CODX_ORG="${CODX_ORG:-Co-Dx}"
CODX_REPO="${CODX_REPO:-codx_scripts}"
CODX_BRANCH="${CODX_BRANCH:-main}"
RAW_BASE="https://raw.githubusercontent.com/${CODX_ORG}/${CODX_REPO}/${CODX_BRANCH}"

ALIAS_LINE="alias codx='bash <(curl -fsSL ${RAW_BASE}/codx.sh)'"
ALIAS_MARKER="# >>> codx alias — managed by install.sh <<<"

# ====================================================================================
# Detect shell profile
# ====================================================================================

detect_profile() {
    if [[ -n "${CODX_PROFILE:-}" ]]; then
        printf '%s' "$CODX_PROFILE"
        return
    fi

    local shell_name
    shell_name="$(basename "${SHELL:-bash}")"

    case "$shell_name" in
        zsh)
            printf '%s' "${ZDOTDIR:-$HOME}/.zshrc"
            ;;
        bash)
            if [[ "$(uname -s)" == "Darwin" ]]; then
                printf '%s' "$HOME/.bash_profile"
            else
                printf '%s' "$HOME/.bashrc"
            fi
            ;;
        *)
            printf '%s' "$HOME/.profile"
            ;;
    esac
}

PROFILE="$(detect_profile)"

# ====================================================================================
# Code
# ====================================================================================

printf "${BOLD}codx installer${NC}\n"
printf "Target profile : ${CYAN}${PROFILE}${NC}\n"
printf "Alias points to: ${CYAN}${RAW_BASE}/codx.sh${NC}\n\n"

if grep -qF "$ALIAS_MARKER" "$PROFILE" 2>/dev/null; then
    printf "$WARNING Existing codx alias found — refreshing…\n"
    TMPFILE="$(mktemp)"
    awk "/$ALIAS_MARKER/{found=1} found && /^$/{found=0; next} !found" \
        "$PROFILE" > "$TMPFILE"
    grep -vF "$ALIAS_MARKER" "$TMPFILE" > "$PROFILE.codxtmp" && mv "$PROFILE.codxtmp" "$PROFILE"
    rm -f "$TMPFILE"
fi

{
    printf '\n'
    printf '%s\n' "$ALIAS_MARKER"
    printf '%s\n' "$ALIAS_LINE"
} >> "$PROFILE"

printf "$SUCCESS Alias written to ${CYAN}${PROFILE}${NC}\n\n"
printf "${BOLD}To activate in your current shell, run:${NC}\n\n"
printf "    source \"${PROFILE}\"\n\n"
printf "Or open a new terminal tab.\n\n"
printf "$INFO Then test with: ${CYAN}codx list${NC}\n"
