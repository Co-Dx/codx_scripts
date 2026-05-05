######################################################################################
# Build Secrets
# 2025-04-23
#
# NAME
#   buildSecrets.sh
#
# SYNOPSIS
#   ./buildSecrets.sh [-f] [-o] [-h]
#
# DESCRIPTION
#   This script will build out the secrets files from a single secret file specified
#   in yaml format. The script will wipe away any existing files in the specified 
#   output directory except yaml files and create new files for each secret in the 
#   secret file.
#
#   -f, --file   : Specify the secret file to build from. If not specified it will
#                  use the lib/secrets/secrets.yaml file by default.
#   -o, --output : Specify the output directory. If not specified, it will use the 
#                  directory in which the secrets.yaml file is located.
#   -h, --help   : Display this help message.
#
# EXAMPLE
#   ./buildSecrets.sh -f bin/secrets/secrets.yaml -o bin/secrets
#       Build secrets from the secrets.yaml file in the bin/secrets directory.
######################################################################################

RED='\x1B[31m'; GREEN='\x1B[32m'; YELLOW='\x1B[33m'; BLUE='\x1B[34m'; MAGENTA='\x1B[35m'; CYAN='\x1B[36m'; ORANGE='\x1B[33m'; WHITE='\x1B[37m'; NC='\x1B[0m'
CRITICAL="$RED[CRITICAL]$NC"; WARNING="$YELLOW[WARNING]$NC"; INFO="$BLUE[INFO]$NC"; 
PASS="$GREEN[PASS]$NC"; FAIL="$RED[FAIL]$NC"; SKIP="$YELLOW[SKIP]$NC"

# ====================================================================================
# Arguments
# ====================================================================================
outDir=""
secretsFile="lib/secrets/secrets.yaml"

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            secretsFile="$2"
            shift 2
            ;;
        -o|--output)
            outDir="$2"
            shift 2
            ;;
        -h|--help)
            echo " "
            awk '/^#{80,}/{flag=!flag; next} flag' $0 | sed 's/#//g'
            echo " "
            exit 0
            ;;
        *)
            printf "$CRITICAL Unknown option: $1\n"
            printf "    Use -h or --help for usage information.\n"
            exit 1
            ;;
    esac
done

if [[ -z $outDir ]]; then
    outDir=$(dirname $secretsFile)
fi

if [[ ! -f $secretsFile ]]; then
    printf "$CRITICAL The secret file $secretsFile does not exist.\n"
    exit 1
fi

if [[ ! -d $outDir ]]; then
    printf "$WARNING The output directory $outDir does not exist.\n It will be created.\n"
    mkdir -p $outDir
fi

# ============================================================================
# Build out the secrets
# ============================================================================
find "$outDir" -type f ! -name "*.yaml" -delete
find "$outDir" -mindepth 1 -type d -empty -delete

currentSection=""

while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Top-level key (no leading whitespace, ends with colon, no value after colon)
    if [[ "$line" =~ ^([A-Za-z0-9_-]+):[[:space:]]*$ ]]; then
        currentSection="${BASH_REMATCH[1]}"
        mkdir -p "$outDir/$currentSection"
        continue
    fi

    # Child key-value pair (has leading whitespace)
    if [[ -n "$currentSection" && "$line" =~ ^[[:space:]]+([A-Za-z0-9_-]+):[[:space:]]*(.+)$ ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        printf "$INFO $currentSection/$key : $value\n"
        printf '%s' "$value" > "$outDir/$currentSection/$key"
    fi
done < "$secretsFile"