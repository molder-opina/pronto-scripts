"""
PRONTO Validation Library

Core validation utilities for enforcing architectural guardrails,
database invariants, and code quality standards.
"""

from .core import ValidationResult, ValidationEngine, Evidence
from .layering import LayeringChecker
from .invariants import InvariantChecker
from .drift import DriftDetector
from .complexity import ComplexityChecker

__version__ = "1.0.0"
__all__ = [
    "ValidationResult",
    "ValidationEngine",
    "Evidence",
    "LayeringChecker",
    "InvariantChecker",
    "DriftDetector",
    "ComplexityChecker",
]
