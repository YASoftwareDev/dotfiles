#!/usr/bin/env bash
# Remove all local dotfiles test images and dangling layers.
#
# Usage:
#   bash clean-test-images.sh          # dry run — shows what would be removed
#   bash clean-test-images.sh --force  # actually remove images and prune layers

set -euo pipefail

IMAGE_REPO="dotfiles-test"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

FORCE=false
case "${1:-}" in
    --force|-f) FORCE=true ;;
    --help|-h)
        sed -n '2,7p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
        exit 0
        ;;
    "")  ;;
    *) echo "Usage: bash clean-test-images.sh [--force]" >&2; exit 1 ;;
esac

if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
    echo -e "${RED}Error: Docker not available or daemon not running.${NC}" >&2
    exit 1
fi

# Discover all images with this repository name
mapfile -t IMAGES < <(
    docker images --filter "reference=${IMAGE_REPO}" --format "{{.Repository}}:{{.Tag}}" \
        | grep -v '<none>'
)

if [ ${#IMAGES[@]} -eq 0 ]; then
    echo -e "  ${YELLOW}!${NC}  No ${IMAGE_REPO} images found — nothing to do."
    exit 0
fi

echo ""
echo -e "${BOLD}── ${IMAGE_REPO} images ──────────────────────────────${NC}"
for img in "${IMAGES[@]}"; do
    size=$(docker image inspect "$img" --format '{{.Size}}' 2>/dev/null \
           | awk '{printf "%.0f MB", $1/1024/1024}')
    echo -e "  ${BLUE}·${NC}  $img  ($size)"
done

# Also check for dangling layers
dangling=$(docker images -f "dangling=true" -q | wc -l | tr -d ' ')
[ "$dangling" -gt 0 ] && echo -e "  ${BLUE}·${NC}  $dangling dangling layer(s)"

echo ""
if ! $FORCE; then
    echo -e "  ${YELLOW}Dry run — pass --force to actually remove.${NC}"
    echo ""
    exit 0
fi

echo -e "${BOLD}── Removing ─────────────────────────────────────────${NC}"
failed=0
for img in "${IMAGES[@]}"; do
    if docker rmi "$img" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC}  removed $img"
    else
        echo -e "  ${RED}✗${NC}  could not remove $img (container still running?)"
        failed=$((failed + 1))
    fi
done

if [ "$dangling" -gt 0 ]; then
    docker image prune -f &>/dev/null \
        && echo -e "  ${GREEN}✓${NC}  $dangling dangling layer(s) pruned"
fi

echo ""
[ "$failed" -gt 0 ] && exit 1 || exit 0
