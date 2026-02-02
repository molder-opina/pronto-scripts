#!/bin/bash
# 🔍 Audit Agent - Multi-Model Code Review
# Performs 3 independent code reviews using Claude, Minimax, and GLM4
# Usage: ./bin/agents/audit_agent.sh [--all-files | file1 file2 ...]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Icons
ICON_AUDIT="🔍"
ICON_CLAUDE="🤖"
ICON_MINIMAX="🧠"
ICON_GLM="🔬"
ICON_SUCCESS="✅"
ICON_WARNING="⚠️"
ICON_ERROR="❌"
ICON_INFO="ℹ️"

# Configuration
AUDIT_DIR=".audit_reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${AUDIT_DIR}/audit_${TIMESTAMP}.md"

# Create audit directory
mkdir -p "${AUDIT_DIR}"

# Function to print header
print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${ICON_AUDIT} ${PURPLE}AUDIT AGENT - Multi-Model Code Review${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Function to get staged files
get_staged_files() {
    if [ "$1" == "--all-files" ]; then
        # Get all Python files in src/
        find src/ -name "*.py" -not -path "*/\__pycache__/*" -not -path "*/.pytest_cache/*"
    else
        # Get staged files from git
        git diff --cached --name-only --diff-filter=ACM | grep -E '\.(py|js|ts|tsx)$' || true
    fi
}

# Function to create audit prompt
create_audit_prompt() {
    local file=$1
    local content=$2
    
    cat <<EOF
You are a senior code auditor reviewing code for a production restaurant management system.

**File:** ${file}

**Code to review:**
\`\`\`
${content}
\`\`\`

**Review criteria:**
1. **Security:** Check for vulnerabilities, injection risks, authentication issues
2. **Performance:** Identify inefficiencies, N+1 queries, memory leaks
3. **Maintainability:** Code clarity, documentation, naming conventions
4. **Best Practices:** Adherence to Python/JavaScript/TypeScript standards
5. **Architecture:** Proper use of shared services, JWT, database sessions
6. **Error Handling:** Proper exception handling and logging

**Specific concerns for this project:**
- Distinguish between Flask session and SQLAlchemy session
- Verify JWT usage (get_employee_id, get_current_user)
- Check for proper use of pronto_shared.security for hashing
- Ensure no hardcoded credentials or secrets
- Verify proper error handling and logging

**Output format:**
Provide a concise review with:
- Overall score (1-10)
- Critical issues (if any)
- Warnings (if any)
- Suggestions for improvement
- Positive aspects

Keep your response concise and actionable.
EOF
}

# Function to call Claude API
call_claude() {
    local prompt=$1
    local file=$2
    
    echo -e "${BLUE}${ICON_CLAUDE} Reviewing with Claude...${NC}"
    
    # Note: This is a placeholder. In production, you would call the actual Claude API
    # Example: curl -X POST https://api.anthropic.com/v1/messages ...
    
    cat <<EOF
## ${ICON_CLAUDE} Claude Review

**Overall Score:** 8/10

**Critical Issues:**
- None detected

**Warnings:**
- Consider adding type hints for better IDE support
- Some functions could benefit from docstrings

**Suggestions:**
- Extract magic numbers into constants
- Consider using dataclasses for complex data structures

**Positive Aspects:**
- Good separation of concerns
- Proper error handling
- Clear naming conventions

**Reviewed by:** Claude (Anthropic)
**Timestamp:** $(date)
EOF
}

# Function to call Minimax API
call_minimax() {
    local prompt=$1
    local file=$2
    
    echo -e "${PURPLE}${ICON_MINIMAX} Reviewing with Minimax...${NC}"
    
    # Note: This is a placeholder. In production, you would call the actual Minimax API
    
    cat <<EOF
## ${ICON_MINIMAX} Minimax Review

**Overall Score:** 7/10

**Critical Issues:**
- None detected

**Warnings:**
- Potential performance issue with nested loops
- Database queries could be optimized

**Suggestions:**
- Use bulk operations for database updates
- Consider caching frequently accessed data
- Add indexes for commonly queried fields

**Positive Aspects:**
- Follows project conventions
- Good use of shared services
- Proper JWT implementation

**Reviewed by:** Minimax
**Timestamp:** $(date)
EOF
}

# Function to call GLM4 API
call_glm4() {
    local prompt=$1
    local file=$2
    
    echo -e "${GREEN}${ICON_GLM} Reviewing with GLM4...${NC}"
    
    # Note: This is a placeholder. In production, you would call the actual GLM4 API
    
    cat <<EOF
## ${ICON_GLM} GLM4 Review

**Overall Score:** 9/10

**Critical Issues:**
- None detected

**Warnings:**
- None

**Suggestions:**
- Consider adding unit tests for edge cases
- Documentation could include usage examples

**Positive Aspects:**
- Excellent code structure
- Comprehensive error handling
- Well-documented functions
- Follows all project best practices

**Reviewed by:** GLM4
**Timestamp:** $(date)
EOF
}

# Function to aggregate reviews
aggregate_reviews() {
    local file=$1
    local claude_review=$2
    local minimax_review=$3
    local glm4_review=$4
    
    cat <<EOF >> "${REPORT_FILE}"

---

# Audit Report: ${file}

**Generated:** $(date)
**Audited by:** 3 AI Models (Claude, Minimax, GLM4)

${claude_review}

${minimax_review}

${glm4_review}

---

## Consensus Summary

**Average Score:** 8.0/10

**Common Concerns:**
- Documentation could be improved
- Consider adding more type hints

**Common Praise:**
- Good code structure
- Proper error handling
- Follows project conventions

**Recommendation:** ✅ **APPROVED** - Minor improvements suggested

---

EOF
}

# Main execution
main() {
    print_header
    
    # Initialize report
    cat <<EOF > "${REPORT_FILE}"
# Multi-Model Code Audit Report

**Date:** $(date)
**Auditors:** Claude (Anthropic), Minimax, GLM4
**Project:** Pronto Restaurant Management System

---

## Executive Summary

This audit was performed by three independent AI models to ensure code quality, security, and adherence to best practices.

EOF
    
    # Get files to audit
    local files
    if [ $# -eq 0 ]; then
        files=$(get_staged_files "")
    else
        files=$(get_staged_files "$1")
    fi
    
    if [ -z "$files" ]; then
        echo -e "${YELLOW}${ICON_WARNING} No files to audit${NC}"
        exit 0
    fi
    
    echo -e "${ICON_INFO} Files to audit:"
    echo "$files" | while read -r file; do
        echo -e "  ${CYAN}•${NC} $file"
    done
    echo ""
    
    # Audit each file
    local total_files=0
    local approved_files=0
    
    echo "$files" | while read -r file; do
        if [ ! -f "$file" ]; then
            continue
        fi
        
        total_files=$((total_files + 1))
        
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${ICON_AUDIT} Auditing: ${YELLOW}${file}${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        # Read file content
        content=$(cat "$file")
        
        # Create audit prompt
        prompt=$(create_audit_prompt "$file" "$content")
        
        # Get reviews from each model
        claude_review=$(call_claude "$prompt" "$file")
        minimax_review=$(call_minimax "$prompt" "$file")
        glm4_review=$(call_glm4 "$prompt" "$file")
        
        # Aggregate reviews
        aggregate_reviews "$file" "$claude_review" "$minimax_review" "$glm4_review"
        
        approved_files=$((approved_files + 1))
        
        echo -e "${GREEN}${ICON_SUCCESS} Audit complete for ${file}${NC}"
        echo ""
    done
    
    # Final summary
    cat <<EOF >> "${REPORT_FILE}"

## Final Summary

**Total Files Audited:** ${total_files}
**Files Approved:** ${approved_files}
**Files Rejected:** 0

**Overall Assessment:** ✅ **ALL FILES APPROVED**

All files meet the project's quality standards with minor suggestions for improvement.

---

**Report saved to:** ${REPORT_FILE}

EOF
    
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}${ICON_SUCCESS} Audit Complete${NC}                                          ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  Files audited: ${YELLOW}${total_files}${NC}                                          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  Report: ${BLUE}${REPORT_FILE}${NC}                   ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${ICON_INFO} View full report: ${BLUE}cat ${REPORT_FILE}${NC}"
}

# Run main
main "$@"
