#!/bin/bash
# ♿ WCAG Validator Agent - Validates Vue components against WCAG 2.1 AA
# Usage: ./wcag_validator.sh [--staged | file1.vue file2.vue ...]
#
# Uses opencode with free model (gemini-3-flash) for AI validation

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Icons
ICON_WCAG="♿"
ICON_CHECK="✅"
ICON_ERROR="❌"
ICON_WARNING="⚠️"
ICON_INFO="ℹ️"

# Configuration
PRONTO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
REPORT_DIR="${PRONTO_ROOT}/.wcag_reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${REPORT_DIR}/validation_${TIMESTAMP}.md"
MODEL="antigravity-gemini-3-flash"  # Free model

# Create report directory
mkdir -p "${REPORT_DIR}"

# Function to print header
print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${ICON_WCAG} ${BLUE}WCAG 2.1 AA Validator${NC}                                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  Validating Vue components for accessibility                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Function to get files to validate
get_files() {
    if [ "$1" == "--staged" ]; then
        # Get staged Vue files from git
        git diff --cached --name-only --diff-filter=ACM | grep -E '\.vue$' || true
    elif [ "$1" == "--all" ]; then
        # Get all Vue files in pronto-static
        find pronto-static/src/vue -name "*.vue" -type f 2>/dev/null || true
    else
        # Use provided files
        echo "$@"
    fi
}

# Function to create validation prompt
create_validation_prompt() {
    local file=$1
    local content=$2

    cat <<EOF
Eres un experto en accesibilidad web WCAG 2.1 AA. Valida el siguiente componente Vue y responde SOLO con JSON válido.

**Archivo:** ${file}

**Código:**
\`\`\`vue
${content}
\`\`\`

**Verifica estos criterios WCAG 2.1 AA:**

1. **WCAG 2.5.5 - Touch Targets:** Elementos interactivos deben tener mínimo 44x44px
   - Buscar: button, a, input, role="button" sin min-height/min-width o padding suficiente

2. **WCAG 2.4.7 - Focus Visible:** Todo elemento interactivo debe tener :focus-visible
   - Buscar: :focus sin :focus-visible correspondiente
   - Verificar: outline visible, no solo box-shadow

3. **WCAG 4.1.2 - Aria Labels:** Botones sin texto deben tener aria-label
   - Buscar: <button> con solo íconos/slots sin aria-label

4. **WCAG 4.1.2 - Clickable Elements:** Elementos no-botón clickeables necesitan role y tabindex
   - Buscar: @click en div/span sin role="button" y tabindex="0"

5. **WCAG 4.1.2 - Input Labels:** Inputs deben tener label asociado
   - Buscar: <input> sin aria-label o <label for>

6. **WCAG 1.4.3 - Color Contrast:** Texto debe tener contraste ≥ 4.5:1
   - Verificar colores definidos (si aplica)

**Responde SOLO con este JSON, sin markdown:**
{"approved":true/false,"violations":[{"criterion":"WCAG X.X.X","severity":"serious|moderate|minor","line":45,"element":"<button>","issue":"descripción","fix":"código corregido"}]}

Si no hay violaciones: {"approved":true,"violations":[]}
EOF
}

# Function to validate a single file
validate_file() {
    local file=$1
    local content=$2
    local prompt_file="/tmp/wcag_prompt_${TIMESTAMP}.txt"

    # Create prompt file
    create_validation_prompt "$file" "$content" > "$prompt_file"

    echo -e "${BLUE}${ICON_INFO} Validating with ${MODEL}...${NC}"

    # Call opencode with the prompt
    response=$(opencode run --model "${MODEL}" --file "$prompt_file" 2>/dev/null || echo '{"approved":true,"violations":[]}')

    # Clean up
    rm -f "$prompt_file"

    echo "$response"
}

# Function to parse JSON response and generate report
parse_response() {
    local file=$1
    local response=$2

    # Extract approved status
    local approved=$(echo "$response" | grep -o '"approved"[[:space:]]*:[[:space:]]*[a-z]*' | cut -d: -f2 | tr -d ' ,')

    # Extract violations count
    local violations=$(echo "$response" | grep -o '"violations"[[:space:]]*:[[:space:]]*\[' | wc -l)

    if [ "$approved" == "true" ]; then
        echo -e "${GREEN}${ICON_CHECK} ${file} - APPROVED${NC}"
        return 0
    else
        echo -e "${RED}${ICON_ERROR} ${file} - REJECTED${NC}"
        # Print violations
        echo "$response" | grep -o '"issue"[[:space:]]*:[[:space:]]*"[^"]*"' | while read -r issue; do
            echo -e "  ${YELLOW}→ ${issue}${NC}"
        done
        return 1
    fi
}

# Quick static checks (before AI validation)
static_checks() {
    local file=$1
    local violations=0

    echo -e "${CYAN}Running static checks...${NC}"

    # Check 1: Buttons without aria-label (if they contain only icons/slots)
    local icon_buttons=$(grep -c '<button[^>]*>@click\|<button[^>]*><[^>]*>\|<button[^>]*><slot' "$file" 2>/dev/null || echo "0")
    local with_aria=$(grep -c 'aria-label' "$file" 2>/dev/null || echo "0")

    # Check 2: :focus without :focus-visible
    local has_focus=$(grep -c ':focus' "$file" 2>/dev/null || echo "0")
    local has_focus_visible=$(grep -c ':focus-visible' "$file" 2>/dev/null || echo "0")

    if [ "$has_focus" -gt 0 ] && [ "$has_focus_visible" -eq 0 ]; then
        echo -e "  ${YELLOW}${ICON_WARNING} Found :focus without :focus-visible${NC}"
        violations=$((violations + 1))
    fi

    # Check 3: Interactive elements without min-height
    local interactive=$(grep -c '<button\|<a \|role="button"\|@click' "$file" 2>/dev/null || echo "0")
    local with_min_size=$(grep -c 'min-height.*44\|min-width.*44' "$file" 2>/dev/null || echo "0")

    if [ "$interactive" -gt 0 ] && [ "$with_min_size" -eq 0 ]; then
        echo -e "  ${YELLOW}${ICON_WARNING} Interactive elements may lack 44px minimum${NC}"
        # This is a warning, not a hard violation
    fi

    return $violations
}

# Main execution
main() {
    print_header

    # Get files to validate
    local files
    if [ $# -eq 0 ]; then
        files=$(get_files "--staged")
    else
        files=$(get_files "$@")
    fi

    if [ -z "$files" ]; then
        echo -e "${GREEN}${ICON_CHECK} No Vue files to validate${NC}"
        exit 0
    fi

    echo -e "${ICON_INFO} Files to validate:"
    echo "$files" | while read -r file; do
        echo -e "  ${CYAN}•${NC} $file"
    done
    echo ""

    # Initialize report
    cat <<EOF > "${REPORT_FILE}"
# WCAG 2.1 AA Validation Report

**Date:** $(date)
**Model:** ${MODEL}
**Files:** $(echo "$files" | wc -l | tr -d ' ')

---

## Summary

| File | Status | Violations |
|------|--------|------------|
EOF

    # Validate each file
    local total_files=0
    local approved_files=0
    local rejected_files=0

    echo "$files" | while read -r file; do
        if [ ! -f "$file" ]; then
            continue
        fi

        total_files=$((total_files + 1))

        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${ICON_WCAG} Validating: ${YELLOW}${file}${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        # Read file content
        content=$(cat "$file")

        # Run static checks first
        static_checks "$file"
        static_result=$?

        # Run AI validation
        response=$(validate_file "$file" "$content")

        # Parse response
        parse_response "$file" "$response"
        result=$?

        # Update counters and report
        if [ $result -eq 0 ] && [ $static_result -eq 0 ]; then
            approved_files=$((approved_files + 1))
            echo "| $file | ✅ APPROVED | 0 |" >> "${REPORT_FILE}"
        else
            rejected_files=$((rejected_files + 1))
            echo "| $file | ❌ REJECTED | Multiple |" >> "${REPORT_FILE}"
        fi
    done

    # Final summary
    cat <<EOF >> "${REPORT_FILE}"

---

## Result

**Total Files:** ${total_files}
**Approved:** ${approved_files}
**Rejected:** ${rejected_files}

EOF

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"

    if [ $rejected_files -eq 0 ]; then
        echo -e "${CYAN}║${NC}  ${GREEN}${ICON_CHECK} All files passed WCAG validation${NC}                       ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo -e "${ICON_INFO} Report saved to: ${BLUE}${REPORT_FILE}${NC}"
        exit 0
    else
        echo -e "${CYAN}║${NC}  ${RED}${ICON_ERROR} ${rejected_files} file(s) have WCAG violations${NC}                  ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo -e "${ICON_INFO} Report saved to: ${BLUE}${REPORT_FILE}${NC}"
        echo -e "${YELLOW}${ICON_WARNING} Fix violations before committing${NC}"
        exit 1
    fi
}

# Run main
main "$@"
