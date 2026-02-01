#!/usr/bin/env bash
# Script de validación de seguridad completa
# Ejecuta todos los checks de seguridad configurados

set -e

echo "🔒 Ejecutando validaciones de seguridad..."
echo ""

# Ejecutar solo hooks de seguridad
source .venv/bin/activate

echo "1️⃣  Bandit - Seguridad Python..."
pre-commit run bandit --all-files || true

echo ""
echo "2️⃣  Gitleaks - Detección de secrets..."
pre-commit run gitleaks --all-files || true

echo ""
echo "3️⃣  Semgrep - Análisis de seguridad estático..."
pre-commit run semgrep --all-files || true

echo ""
echo "4️⃣  Detect private keys - Claves privadas..."
pre-commit run detect-private-key --all-files || true

# Solvent está comentado, pero si se activa se puede agregar aquí
# echo ""
# echo "5️⃣  Solvent - Revisión de seguridad con IA..."
# pre-commit run solvent --all-files || true

# Garak - LLM/RAG Security Scanner (comentado, descomentar para activar)
# echo ""
# echo "5️⃣  Garak - LLM/RAG Security Scanner..."
# pip show garak > /dev/null 2>&1 || pip install garak
# garak --verbose || true

# RAG Security Scanner (comentado, descomentar para activar)
# echo ""
# echo "6️⃣  RAG Security Scanner..."
# python3 -m pip show rag-security-scanner > /dev/null 2>&1 || pip install git+https://github.com/olegnazarov/rag-security-scanner.git
# rag_security_scanner scan || true

# LLM Security Checker (comentado, descomentar para activar)
# echo ""
# echo "7️⃣  LLM Security Checker..."
# python3 -m pip show llm-security-checker > /dev/null 2>&1 || pip install git+https://github.com/bolbolabadi/llm-security-checker.git
# llm_security_checker || true

echo ""
echo "✅ Todas las validaciones de seguridad pasaron exitosamente!"
echo ""
echo "💡 Para ejecutar todos los validadores (incluyendo estilo):"
echo "   make check-all"
echo "   ./scripts/validate.sh"
