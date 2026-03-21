"""
Import/Dependency Drift Detector

Tracks and detects unexpected changes in imports/dependencies.

Features:
- Baseline import tracking
- Before/after comparison
- New dependency detection
- Drift reporting

Rule: Compare imports before/after, flag unexpected additions
"""

import ast
import json
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

from .core import Evidence, ValidationEngine, ValidationResult, ValidationStatus


@dataclass
class ImportEntry:
    """Single import entry"""

    module: str
    file_path: str
    line_number: int
    is_from_import: bool
    names: List[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "module": self.module,
            "file_path": self.file_path,
            "line_number": self.line_number,
            "is_from_import": self.is_from_import,
            "names": self.names,
        }

    def __hash__(self):
        return hash((self.module, self.file_path, self.line_number))


@dataclass
class DriftReport:
    """Drift detection report"""

    new_imports: List[ImportEntry] = field(default_factory=list)
    removed_imports: List[ImportEntry] = field(default_factory=list)
    new_dependencies: Set[str] = field(default_factory=set)
    removed_dependencies: Set[str] = field(default_factory=set)
    files_with_changes: Set[str] = field(default_factory=set)


class DriftDetector:
    """
    Import/dependency drift detector

    Rule: Compare imports before/after, flag unexpected additions
    """

    def __init__(self, workspace_root: Path):
        self.workspace_root = workspace_root
        self.engine = ValidationEngine(workspace_root)
        self.baseline_dir = workspace_root / "pronto-scripts" / ".validation-baseline"
        self.baseline_dir.mkdir(parents=True, exist_ok=True)

    def extract_imports_from_file(self, file_path: Path) -> List[ImportEntry]:
        """Extract all imports from a Python file using AST"""
        imports = []

        try:
            with open(file_path, "r", encoding="utf-8") as f:
                source = f.read()

            tree = ast.parse(source, filename=str(file_path))

            for node in ast.walk(tree):
                if isinstance(node, ast.Import):
                    for alias in node.names:
                        imports.append(
                            ImportEntry(
                                module=alias.name,
                                file_path=str(file_path),
                                line_number=node.lineno or 0,
                                is_from_import=False,
                                names=[alias.name],
                            )
                        )
                elif isinstance(node, ast.ImportFrom):
                    module = node.module or ""
                    names = [alias.name for alias in node.names]
                    imports.append(
                        ImportEntry(
                            module=module,
                            file_path=str(file_path),
                            line_number=node.lineno or 0,
                            is_from_import=True,
                            names=names,
                        )
                    )

        except Exception as e:
            # Skip files that can't be parsed
            pass

        return imports

    def extract_imports_from_files(self, file_paths: List[Path]) -> List[ImportEntry]:
        """Extract imports from multiple files"""
        all_imports = []

        for file_path in file_paths:
            if file_path.suffix == ".py" and "__pycache__" not in str(file_path):
                imports = self.extract_imports_from_file(file_path)
                all_imports.extend(imports)

        return all_imports

    def get_baseline_path(self, name: str) -> Path:
        """Get baseline file path"""
        return self.baseline_dir / f"{name}-imports.json"

    def save_baseline(self, imports: List[ImportEntry], name: str = "baseline") -> Path:
        """Save imports as baseline"""
        baseline_path = self.get_baseline_path(name)

        data = {
            "imports": [imp.to_dict() for imp in imports],
            "dependencies": list(set(imp.module.split(".")[0] for imp in imports)),
            "file_count": len(set(imp.file_path for imp in imports)),
            "import_count": len(imports),
        }

        with open(baseline_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)

        return baseline_path

    def load_baseline(self, name: str = "baseline") -> Optional[Dict]:
        """Load baseline imports"""
        baseline_path = self.get_baseline_path(name)

        if not baseline_path.exists():
            return None

        with open(baseline_path, "r", encoding="utf-8") as f:
            return json.load(f)

    def detect_drift(
        self,
        current_imports: List[ImportEntry],
        baseline: Dict,
    ) -> DriftReport:
        """
        Detect drift between current imports and baseline

        Returns:
            DriftReport with new/removed imports and dependencies
        """
        # Convert to sets for comparison
        baseline_imports = {
            (imp["module"], imp["file_path"], imp["line_number"])
            for imp in baseline["imports"]
        }

        current_import_tuples = {
            (imp.module, imp.file_path, imp.line_number) for imp in current_imports
        }

        # Find differences
        new_import_tuples = current_import_tuples - baseline_imports
        removed_import_tuples = baseline_imports - current_import_tuples

        # Build reports
        report = DriftReport()

        # New imports
        for imp in current_imports:
            if (imp.module, imp.file_path, imp.line_number) in new_import_tuples:
                report.new_imports.append(imp)
                report.new_dependencies.add(imp.module.split(".")[0])
                report.files_with_changes.add(imp.file_path)

        # Removed imports
        baseline_modules = {
            (imp["module"], imp["file_path"], imp["line_number"]): imp
            for imp in baseline["imports"]
        }

        for tup in removed_import_tuples:
            if tup in baseline_modules:
                imp_data = baseline_modules[tup]
                report.removed_imports.append(
                    ImportEntry(
                        module=imp_data["module"],
                        file_path=imp_data["file_path"],
                        line_number=imp_data["line_number"],
                        is_from_import=imp_data["is_from_import"],
                        names=imp_data.get("names", []),
                    )
                )
                report.removed_dependencies.add(imp_data["module"].split(".")[0])

        return report

    def check_drift(
        self,
        file_paths: List[Path],
        baseline_name: str = "baseline",
        allowed_new_deps: Optional[List[str]] = None,
    ) -> ValidationResult:
        """
        Check for import drift compared to baseline

        Rule: Must provide raw diff output and counts
        """
        allowed_new_deps = allowed_new_deps or []

        # Load baseline
        baseline = self.load_baseline(baseline_name)

        if not baseline:
            # No baseline exists - create one
            imports = self.extract_imports_from_files(file_paths)
            baseline_path = self.save_baseline(imports, baseline_name)

            evidence = Evidence(
                stdout=f"Baseline created: {baseline_path}",
                file_count=len(set(imp.file_path for imp in imports)),
                match_count=len(imports),
                raw_output=f"Baseline saved to {baseline_path}",
            )

            result = ValidationResult(
                name="drift-check-baseline",
                status=ValidationStatus.PASSED,
                message=f"No baseline existed - created new baseline with {len(imports)} imports",
                evidence=evidence,
                severity="info",
                suggestions=["Run drift-check again after establishing baseline"],
            )

            self.engine.add_result(result)
            return result

        # Extract current imports
        current_imports = self.extract_imports_from_files(file_paths)

        # Detect drift
        report = self.detect_drift(current_imports, baseline)

        # Check for unapproved new dependencies
        unapproved_new_deps = set(report.new_dependencies) - set(allowed_new_deps)

        # Build evidence
        diff_lines = []

        if report.new_imports:
            diff_lines.append(f"NEW IMPORTS ({len(report.new_imports)}):")
            for imp in report.new_imports[:20]:  # Limit output
                diff_lines.append(
                    f"  + {imp.module} ({imp.file_path}:{imp.line_number})"
                )
            if len(report.new_imports) > 20:
                diff_lines.append(f"  ... and {len(report.new_imports) - 20} more")

        if report.removed_imports:
            diff_lines.append(f"\nREMOVED IMPORTS ({len(report.removed_imports)}):")
            for imp in report.removed_imports[:20]:
                diff_lines.append(
                    f"  - {imp.module} ({imp.file_path}:{imp.line_number})"
                )
            if len(report.removed_imports) > 20:
                diff_lines.append(f"  ... and {len(report.removed_imports) - 20} more")

        if report.new_dependencies:
            diff_lines.append(
                f"\nNEW DEPENDENCIES: {', '.join(report.new_dependencies)}"
            )

        if report.removed_dependencies:
            diff_lines.append(
                f"REMOVED DEPENDENCIES: {', '.join(report.removed_dependencies)}"
            )

        evidence = Evidence(
            stdout=f"Files checked: {len(file_paths)}\nFiles with changes: {len(report.files_with_changes)}",
            diff_output="\n".join(diff_lines) if diff_lines else "No drift detected",
            match_count=len(report.new_imports) + len(report.removed_imports),
            file_count=len(report.files_with_changes),
            raw_output="\n".join(diff_lines) if diff_lines else "No drift detected",
        )

        # Determine status
        if unapproved_new_deps:
            status = ValidationStatus.FAILED
            message = f"UNAPPROVED NEW DEPENDENCIES: {', '.join(unapproved_new_deps)}"
            severity = "error"
        elif report.new_imports or report.removed_imports:
            status = ValidationStatus.WARNING
            message = f"Import drift detected: {len(report.new_imports)} new, {len(report.removed_imports)} removed"
            severity = "warning"
        else:
            status = ValidationStatus.PASSED
            message = f"No import drift detected (baseline: {baseline['import_count']} imports)"
            severity = "info"

        result = ValidationResult(
            name="drift-check",
            status=status,
            message=message,
            evidence=evidence,
            severity=severity,
            suggestions=[
                f"Review new dependencies: {', '.join(unapproved_new_deps)}",
                "Update baseline with 'pronto-drift-detect --save-baseline' if changes are approved",
            ]
            if unapproved_new_deps
            else [],
        )

        self.engine.add_result(result)
        return result

    def save_current_baseline(self, name: str = "baseline") -> Path:
        """Save current state as new baseline"""
        # Scan all Python files in workspace
        all_py_files = []
        for pattern in [
            "pronto-api",
            "pronto-client",
            "pronto-employees",
            "pronto-libs",
            "pronto-scripts",
        ]:
            all_py_files.extend((self.workspace_root / pattern).rglob("*.py"))

        imports = self.extract_imports_from_files(all_py_files)
        return self.save_baseline(imports, name)
