"""
AST-based Layering Checker

Enforces architectural layering rules using Python AST parsing.
Detects:
- Cross-layer imports
- Unexpected dependencies
- Architecture drift

Rule: AST-based, not regex (for accuracy)
"""

import ast
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

from .core import Evidence, ValidationEngine, ValidationResult, ValidationStatus


@dataclass
class LayerConfig:
    """Configuration for a layer"""

    name: str
    path_pattern: str
    module_prefix: str  # Module prefix for this layer (e.g., "pronto_shared")
    allowed_imports: List[str]  # Layers this layer can import from
    description: str = ""


# PRONTO Architecture Layers
PRONTO_LAYERS = {
    "api": LayerConfig(
        name="api",
        path_pattern="pronto-api/src/api_app",
        module_prefix="pronto_api",
        allowed_imports=["libs", "shared"],
        description="API layer - business logic and routes",
    ),
    "client": LayerConfig(
        name="client",
        path_pattern="pronto-client/src/pronto_clients",
        module_prefix="pronto_clients",
        allowed_imports=[
            "shared",
            "libs",
        ],  # Can import shared infra from libs (logging, error_handlers, etc.)
        description="Client SSR layer",
    ),
    "employees": LayerConfig(
        name="employees",
        path_pattern="pronto-employees/src/pronto_employees",
        module_prefix="pronto_employees",
        allowed_imports=[
            "shared",
            "libs",
        ],  # Can import shared infra from libs (logging, error_handlers, etc.)
        description="Employees SSR layer",
    ),
    "static": LayerConfig(
        name="static",
        path_pattern="pronto-static/src/vue",
        module_prefix="pronto_static",
        allowed_imports=["shared"],
        description="Frontend Vue layer",
    ),
    "libs": LayerConfig(
        name="libs",
        path_pattern="pronto-libs/src/pronto_shared",
        module_prefix="pronto_shared",
        allowed_imports=["libs"],  # Can only import within libs
        description="Shared library layer",
    ),
    "scripts": LayerConfig(
        name="scripts",
        path_pattern="pronto-scripts",
        module_prefix="pronto_scripts",
        allowed_imports=["libs", "shared"],
        description="Automation scripts layer",
    ),
}

# Forbidden imports (hard dependencies that should never appear)
FORBIDDEN_IMPORTS = [
    "flask.session",
    "legacy_mysql",
    "callbacks",  # SQLAlchemy deprecated callbacks
]

# Cross-console imports (employees isolation)
EMPLOYEE_CONSOLES = ["waiter", "chef", "cashier", "admin", "system"]


@dataclass
class ImportInfo:
    """Information about an import statement"""

    module: str
    line_number: int
    column: int
    is_from_import: bool
    names: List[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "module": self.module,
            "line_number": self.line_number,
            "column": self.column,
            "is_from_import": self.is_from_import,
            "names": self.names,
        }


@dataclass
class LayerViolation:
    """Layering rule violation"""

    file_path: str
    layer: str
    imported_module: str
    target_layer: Optional[str]
    violation_type: str  # "cross_layer", "forbidden", "cross_console"
    line_number: int
    message: str


class ASTImportExtractor(ast.NodeVisitor):
    """Extract all imports from Python AST"""

    def __init__(self, file_path: str):
        self.file_path = file_path
        self.imports: List[ImportInfo] = []

    def visit_Import(self, node: ast.Import) -> None:
        for alias in node.names:
            self.imports.append(
                ImportInfo(
                    module=alias.name,
                    line_number=node.lineno or 0,
                    column=node.col_offset or 0,
                    is_from_import=False,
                    names=[alias.name],
                )
            )
        self.generic_visit(node)

    def visit_ImportFrom(self, node: ast.ImportFrom) -> None:
        module = node.module or ""
        names = [alias.name for alias in node.names]

        self.imports.append(
            ImportInfo(
                module=module,
                line_number=node.lineno or 0,
                column=node.col_offset or 0,
                is_from_import=True,
                names=names,
            )
        )
        self.generic_visit(node)


class LayeringChecker:
    """
    AST-based layering validator

    Rule: AST-based, not regex (for accuracy)
    """

    def __init__(self, workspace_root: Path):
        self.workspace_root = workspace_root.resolve()
        self.engine = ValidationEngine(workspace_root)
        self.violations: List[LayerViolation] = []
        self._import_cache: Dict[str, Optional[Path]] = {}

        # Build module_prefix → layer mapping
        self._module_to_layer = {
            config.module_prefix: name for name, config in PRONTO_LAYERS.items()
        }

    def detect_layer(self, file_path: Path) -> Optional[str]:
        """Detect which layer a file belongs to"""
        try:
            resolved = file_path.resolve()
            rel_path = str(resolved.relative_to(self.workspace_root))

            for layer_name, config in PRONTO_LAYERS.items():
                if config.path_pattern in rel_path:
                    return layer_name
        except ValueError:
            pass  # File outside workspace

        return None

    def get_layer_from_path(self, file_path: Path) -> Optional[str]:
        """Determine layer from actual file path"""
        try:
            resolved = file_path.resolve()
            rel_path = str(resolved.relative_to(self.workspace_root))

            for layer_name, config in PRONTO_LAYERS.items():
                if config.path_pattern in rel_path:
                    return layer_name
        except ValueError:
            pass  # File outside workspace

        return None

    def resolve_import_to_path(
        self, import_module: str, source_file: Path
    ) -> Optional[Path]:
        """
        Resolve import module to actual file path.

        Handles:
        - Absolute imports (pronto_shared.x)
        - Relative imports (.services.x)
        - External imports (returns None)
        """
        # Check cache first
        cache_key = f"{import_module}:{source_file.resolve()}"
        if cache_key in self._import_cache:
            return self._import_cache[cache_key]

        result: Optional[Path] = None

        try:
            # Case 1: Relative imports
            if import_module.startswith("."):
                levels = len(import_module) - len(import_module.lstrip("."))
                relative_part = import_module.lstrip(".")

                base = source_file.parent
                for _ in range(levels - 1):
                    base = base.parent

                if relative_part:
                    file_path = base / relative_part.replace(".", "/")
                    if file_path.with_suffix(".py").exists():
                        result = file_path.with_suffix(".py")
                    elif (file_path / "__init__.py").exists():
                        result = file_path / "__init__.py"
                else:
                    result = base / "__init__.py"

                self._import_cache[cache_key] = result
                return result

            # Case 2: Absolute internal imports
            base_module = import_module.split(".")[0]
            layer_name = self._module_to_layer.get(base_module)

            if not layer_name:
                # External import (requests, jwt, etc.)
                self._import_cache[cache_key] = None
                return None

            layer_config = PRONTO_LAYERS.get(layer_name)
            if not layer_config:
                self._import_cache[cache_key] = None
                return None

            base_path = self.workspace_root / layer_config.path_pattern

            # Handle "from pronto_shared import x" vs "from pronto_shared.x import y"
            if base_module == import_module:
                # from pronto_shared import x
                # Use names from import to resolve submodule
                result = base_path / "__init__.py"
            else:
                # from pronto_shared.submodule import x
                relative_path = ".".join(import_module.split(".")[1:])
                file_path = base_path / relative_path.replace(".", "/")

                if file_path.with_suffix(".py").exists():
                    result = file_path.with_suffix(".py")
                elif (file_path / "__init__.py").exists():
                    result = file_path / "__init__.py"
                else:
                    # Try direct path
                    result = None

        except Exception:
            result = None

        self._import_cache[cache_key] = result
        return result

    def resolve_import_target_layer(
        self, import_module: str, source_file: Path
    ) -> Optional[str]:
        """
        Determine target layer by resolving import to ACTUAL file path.

        NO string matching - uses physical file location.
        """
        # Relative imports are always same layer
        if import_module.startswith("."):
            return self.detect_layer(source_file)

        # Resolve to physical path
        resolved_path = self.resolve_import_to_path(import_module, source_file)

        if not resolved_path:
            # External import or unresolvable - not an internal layer
            return None

        # Determine layer from physical location
        return self.get_layer_from_path(resolved_path)

    def check_cross_console_import(
        self, file_path: Path, import_info: ImportInfo
    ) -> Optional[LayerViolation]:
        """Check for forbidden cross-console imports in employees layer"""
        try:
            rel_path = str(file_path.resolve().relative_to(self.workspace_root))
        except ValueError:
            return None

        if "pronto-employees" not in rel_path:
            return None

        # Detect source console
        source_console = None
        for console in EMPLOYEE_CONSOLES:
            if f"/{console}/" in rel_path or f"\\{console}\\" in rel_path:
                source_console = console
                break

        if not source_console:
            return None

        # Check if importing from another console
        import_path = import_info.module.replace(".", "/")

        for console in EMPLOYEE_CONSOLES:
            if console != source_console and f"/{console}/" in import_path:
                return LayerViolation(
                    file_path=rel_path,
                    layer="employees",
                    imported_module=import_info.module,
                    target_layer=console,
                    violation_type="cross_console",
                    line_number=import_info.line_number,
                    message=f"Cross-console import forbidden: {source_console} → {console}",
                )

        return None

    def check_file(self, file_path: Path) -> List[LayerViolation]:
        """Check a single file for layering violations"""
        violations = []

        try:
            with open(file_path, "r", encoding="utf-8") as f:
                source = f.read()

            tree = ast.parse(source, filename=str(file_path))
            extractor = ASTImportExtractor(str(file_path))
            extractor.visit(tree)

            source_layer = self.detect_layer(file_path)

            for import_info in extractor.imports:
                # Check forbidden imports
                for forbidden in FORBIDDEN_IMPORTS:
                    if forbidden in import_info.module:
                        violations.append(
                            LayerViolation(
                                file_path=str(
                                    file_path.resolve().relative_to(self.workspace_root)
                                ),
                                layer=source_layer or "unknown",
                                imported_module=import_info.module,
                                target_layer=None,
                                violation_type="forbidden",
                                line_number=import_info.line_number,
                                message=f"Forbidden import: {forbidden}",
                            )
                        )

                # Check cross-console imports
                cross_console = self.check_cross_console_import(file_path, import_info)
                if cross_console:
                    violations.append(cross_console)

                # Check cross-layer imports
                if source_layer:
                    target_layer = self.resolve_import_target_layer(
                        import_info.module, file_path
                    )

                    # Only report if we can resolve the layer AND it's different
                    if target_layer is not None and target_layer != source_layer:
                        layer_config = PRONTO_LAYERS.get(source_layer)
                        if (
                            layer_config
                            and target_layer not in layer_config.allowed_imports
                        ):
                            violations.append(
                                LayerViolation(
                                    file_path=str(
                                        file_path.resolve().relative_to(
                                            self.workspace_root
                                        )
                                    ),
                                    layer=source_layer,
                                    imported_module=import_info.module,
                                    target_layer=target_layer,
                                    violation_type="cross_layer",
                                    line_number=import_info.line_number,
                                    message=f"Cross-layer import forbidden: {source_layer} → {target_layer}",
                                )
                            )

        except SyntaxError as e:
            violations.append(
                LayerViolation(
                    file_path=str(file_path.resolve().relative_to(self.workspace_root)),
                    layer="unknown",
                    imported_module="",
                    target_layer=None,
                    violation_type="syntax_error",
                    line_number=e.lineno or 0,
                    message=f"Syntax error: {str(e)}",
                )
            )
        except Exception as e:
            violations.append(
                LayerViolation(
                    file_path=str(file_path.resolve().relative_to(self.workspace_root)),
                    layer="unknown",
                    imported_module="",
                    target_layer=None,
                    violation_type="error",
                    line_number=0,
                    message=f"Check failed: {str(e)}",
                )
            )

        return violations

    def check_files(self, file_paths: List[Path]) -> ValidationResult:
        """
        Check multiple files for layering violations

        Rule: Must provide raw evidence (violation list, counts)
        """
        all_violations = []
        files_checked = 0

        for file_path in file_paths:
            if file_path.suffix == ".py":
                violations = self.check_file(file_path)
                all_violations.extend(violations)
                files_checked += 1

        self.violations = all_violations

        # Build evidence
        evidence = Evidence(
            stdout=f"Files checked: {files_checked}\nViolations found: {len(all_violations)}",
            match_count=len(all_violations),
            file_count=files_checked,
            raw_output="\n".join(
                [
                    f"{v.file_path}:{v.line_number} [{v.violation_type}] {v.message}"
                    for v in all_violations
                ]
            )
            if all_violations
            else "No violations found",
        )

        # Determine status
        if all_violations:
            status = ValidationStatus.FAILED
            message = f"Found {len(all_violations)} layering violations"
            severity = "error"
        else:
            status = ValidationStatus.PASSED
            message = f"No layering violations (checked {files_checked} files)"
            severity = "info"

        result = ValidationResult(
            name="layering-check",
            status=status,
            message=message,
            evidence=evidence,
            severity=severity,
            suggestions=[
                "Review PRONTO_LAYERS configuration in layering.py",
                "Ensure imports follow allowed_imports rules",
                "Use dependency injection instead of direct imports for cross-layer needs",
            ]
            if all_violations
            else [],
        )

        self.engine.add_result(result)
        return result

    def check_project(self) -> ValidationResult:
        """
        Check entire project for layering violations

        Rule: Negative validation - prove why architecture is NOT broken
        """
        all_violations = []
        files_checked = 0

        # Directories to exclude (virtual envs, build artifacts, etc.)
        excluded_dirs = {
            "__pycache__",
            "venv",
            ".venv",
            "node_modules",
            ".git",
            "build",
            "dist",
            ".eggs",
            "*.egg-info",
        }

        for layer_name, config in PRONTO_LAYERS.items():
            layer_path = self.workspace_root / config.path_pattern
            if layer_path.exists():
                for py_file in layer_path.rglob("*.py"):
                    file_str = str(py_file)
                    # Skip excluded directories
                    if any(excluded in file_str for excluded in excluded_dirs):
                        continue

                    violations = self.check_file(py_file)
                    all_violations.extend(violations)
                    files_checked += 1

        self.violations = all_violations

        # Build evidence
        evidence = Evidence(
            stdout=f"Files checked: {files_checked}\nViolations found: {len(all_violations)}",
            match_count=len(all_violations),
            file_count=files_checked,
            raw_output="\n".join(
                [
                    f"{v.file_path}:{v.line_number} [{v.violation_type}] {v.message}"
                    for v in all_violations
                ]
            )
            if all_violations
            else "No violations found",
        )

        # Negative validation message
        if not all_violations:
            message = (
                f"Architecture verified: No cross-layer violations detected. "
                f"Checked {files_checked} files across {len(PRONTO_LAYERS)} layers. "
                f"All imports comply with architectural boundaries."
            )
        else:
            message = f"Architecture violation: Found {len(all_violations)} cross-layer imports"

        result = ValidationResult(
            name="layering-check-full",
            status=ValidationStatus.PASSED
            if not all_violations
            else ValidationStatus.FAILED,
            message=message,
            evidence=evidence,
            severity="error" if all_violations else "info",
            suggestions=[
                "Run 'pronto-layering-check --fix' for auto-fix suggestions",
                "Review architectural boundaries in AGENTS.md section 1",
            ]
            if all_violations
            else [],
        )

        self.engine.add_result(result)
        return result

    def get_violations_summary(self) -> Dict:
        """Get summary of violations by type"""
        by_type = {}
        by_layer = {}

        for v in self.violations:
            by_type[v.violation_type] = by_type.get(v.violation_type, 0) + 1
            by_layer[v.layer] = by_layer.get(v.layer, 0) + 1

        return {
            "total": len(self.violations),
            "by_type": by_type,
            "by_layer": by_layer,
            "violations": [
                {
                    "file": v.file_path,
                    "line": v.line_number,
                    "type": v.violation_type,
                    "message": v.message,
                }
                for v in self.violations
            ],
        }
