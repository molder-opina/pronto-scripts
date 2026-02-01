#!/usr/bin/env bash
# Script de validación de seguridad LLM/RAG
# Ejecuta todos los checks de seguridad para aplicaciones con IA/LLM

set -e

echo "🤖 Ejecutando validaciones de seguridad LLM/RAG..."
echo ""

# Verificar si hay archivos Python/TypeScript que usen LLM
llm_files=$(find src/ \( -name "*.py" -o -name "*.ts" \) -print0 | xargs -0 grep -l "openai\|anthropic\|llm\|langchain\|rag" 2>/dev/null || echo "")

if [ -z "$llm_files" ]; then
    echo "⚠️  No se encontraron archivos con LLM/RAG"
    echo "   Si no usas LLM/RAG en tu aplicación, puedes ignorar estos checks."
    exit 0
fi

echo "📋 Archivos con LLM/RAG detectados:"
echo "$llm_files"
echo ""

# Verificar instalación de herramientas
echo "🔧 Verificando herramientas..."
source .venv/bin/activate

# Garak - NVIDIA LLM Scanner
echo ""
echo "1️⃣  Garak - NVIDIA LLM/RAG Security Scanner..."
if ! pip show garak > /dev/null 2>&1; then
    echo "   📦 Instalando Garak..."
    pip install garak
fi
garak --verbose || true

# RAG Security Scanner
echo ""
echo "2️⃣  RAG Security Scanner..."
if ! python3 -m pip show rag-security-scanner > /dev/null 2>&1; then
    echo "   📦 Instalando RAG Security Scanner..."
    pip install git+https://github.com/olegnazarov/rag-security-scanner.git
fi
rag_security_scanner scan || true

# LLM Security Checker
echo ""
echo "3️⃣  LLM Security Checker..."
if ! python3 -m pip show llm-security-checker > /dev/null 2>&1; then
    echo "   📦 Instalando LLM Security Checker..."
    pip install git+https://github.com/bolbolabadi/llm-security-checker.git
fi
llm_security_checker || true

echo ""
echo "✅ Validaciones de seguridad LLM/RAG completadas!"
echo ""
echo "💡 Para ejecutar todas las validaciones de seguridad:"
echo "   make security-scan"
echo "   ./scripts/validate-security.sh"
