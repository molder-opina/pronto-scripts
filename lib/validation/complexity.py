"""
Complexity Checker

Enforces complexity limits to prevent over-engineering.

Rules:
- Max +30% lines per file
- No new layers without justification
- No new concepts without documentation

Rule: Detect silent complexity creep
"""

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from .core import Evidence, ValidationEngine, ValidationResult, ValidationStatus


@dataclass
class FileMetrics:
    """File complexity metrics"""

    file_path: str
    line_count: int
    function_count: int
    class_count: int
    import_count: int
    comment_count: int
    blank_lines: int
    max_line_length: int
    avg_line_length: float


@dataclass
class ComplexityChange:
    """Complexity change between versions"""

    file_path: str
    old_lines: int
    new_lines: int
    line_delta: int
    percent_change: float
    exceeds_threshold: bool
    threshold: float = 30.0  # 30% max increase


class ComplexityChecker:
    """
    Complexity validator

    Rule: Detect silent complexity creep
    """

    def __init__(self, workspace_root: Path):
        self.workspace_root = workspace_root
        self.engine = ValidationEngine(workspace_root)
        self.baseline_dir = workspace_root / "pronto-scripts" / ".validation-baseline"
        self.baseline_dir.mkdir(parents=True, exist_ok=True)

    def analyze_file(self, file_path: Path) -> Optional[FileMetrics]:
        """Analyze complexity metrics for a single file"""
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                lines = f.readlines()

            line_count = len(lines)
            function_count = sum(
                1 for line in lines if line.strip().startswith(("def ", "async def "))
            )
            class_count = sum(1 for line in lines if line.strip().startswith("class "))
            import_count = sum(
                1 for line in lines if line.strip().startswith(("import ", "from "))
            )
            comment_count = sum(1 for line in lines if line.strip().startswith("#"))
            blank_lines = sum(1 for line in lines if not line.strip())

            line_lengths = [len(line.rstrip()) for line in lines]
            max_line_length = max(line_lengths) if line_lengths else 0
            avg_line_length = (
                sum(line_lengths) / len(line_lengths) if line_lengths else 0.0
            )

            return FileMetrics(
                file_path=str(file_path),
                line_count=line_count,
                function_count=function_count,
                class_count=class_count,
                import_count=import_count,
                comment_count=comment_count,
                blank_lines=blank_lines,
                max_line_length=max_line_length,
                avg_line_length=avg_line_length,
            )

        except Exception as e:
            return None

    def get_baseline_path(self, name: str = "complexity") -> Path:
        """Get baseline file path"""
        return self.baseline_dir / f"{name}-baseline.json"

    def save_baseline(
        self, metrics: Dict[str, FileMetrics], name: str = "complexity"
    ) -> Path:
        """Save complexity baseline"""
        import json

        baseline_path = self.get_baseline_path(name)

        data = {
            path: {
                "line_count": m.line_count,
                "function_count": m.function_count,
                "class_count": m.class_count,
                "import_count": m.import_count,
            }
            for path, m in metrics.items()
        }

        with open(baseline_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)

        return baseline_path

    def load_baseline(self, name: str = "complexity") -> Optional[Dict]:
        """Load complexity baseline"""
        import json

        baseline_path = self.get_baseline_path(name)

        if not baseline_path.exists():
            return None

        with open(baseline_path, "r", encoding="utf-8") as f:
            return json.load(f)

    def calculate_complexity_change(
        self,
        old_metrics: Dict,
        new_metrics: FileMetrics,
        threshold: float = 30.0,
    ) -> Optional[ComplexityChange]:
        """Calculate complexity change for a file"""
        file_path = new_metrics.file_path

        if file_path not in old_metrics:
            # New file - no baseline to compare
            return None

        old_lines = old_metrics[file_path].get("line_count", 0)
        new_lines = new_metrics.line_count

        if old_lines == 0:
            return None

        line_delta = new_lines - old_lines
        percent_change = (line_delta / old_lines) * 100

        exceeds_threshold = percent_change > threshold

        return ComplexityChange(
            file_path=file_path,
            old_lines=old_lines,
            new_lines=new_lines,
            line_delta=line_delta,
            percent_change=percent_change,
            exceeds_threshold=exceeds_threshold,
            threshold=threshold,
        )

    def check_complexity(
        self,
        file_paths: List[Path],
        threshold: float = 30.0,
    ) -> ValidationResult:
        """
        Check file complexity changes

        Rule: Max +30% lines per file without justification

        Args:
            file_paths: Files to check
            threshold: Maximum allowed line increase percentage (default: 30%)

        Returns:
            ValidationResult with evidence
        """
        import json

        # Load baseline
        baseline = self.load_baseline()

        # Analyze files
        changes: List[ComplexityChange] = []
        new_files: List[str] = []
        metrics_map: Dict[str, FileMetrics] = {}

        for file_path in file_paths:
            if file_path.suffix == ".py" and "__pycache__" not in str(file_path):
                metrics = self.analyze_file(file_path)
                if metrics:
                    metrics_map[metrics.file_path] = metrics

                    if baseline and metrics.file_path in baseline:
                        change = self.calculate_complexity_change(
                            baseline, metrics, threshold
                        )
                        if change and change.exceeds_threshold:
                            changes.append(change)
                    else:
                        new_files.append(metrics.file_path)

        # Build evidence
        evidence_lines = []

        if changes:
            evidence_lines.append(f"FILES EXCEEDING {threshold}% INCREASE:")
            for change in changes:
                evidence_lines.append(
                    f"  {change.file_path}: "
                    f"{change.old_lines} → {change.new_lines} lines "
                    f"({change.percent_change:+.1f}%)"
                )

        if new_files:
            evidence_lines.append(f"\nNEW FILES (no baseline): {len(new_files)}")
            for path in new_files[:10]:
                evidence_lines.append(f"  + {path}")
            if len(new_files) > 10:
                evidence_lines.append(f"  ... and {len(new_files) - 10} more")

        # Auto-save new baseline if none exists
        if not baseline and metrics_map:
            self.save_baseline(metrics_map)
            evidence_lines.append("\nBaseline created for future comparisons")

        evidence = Evidence(
            stdout=f"Files analyzed: {len(metrics_map)}\nFiles with excessive growth: {len(changes)}",
            diff_output="\n".join(evidence_lines)
            if evidence_lines
            else "No complexity issues detected",
            match_count=len(changes),
            file_count=len(metrics_map),
            raw_output="\n".join(evidence_lines)
            if evidence_lines
            else "No complexity issues detected",
        )

        # Determine status
        if changes:
            status = ValidationStatus.FAILED
            message = f"COMPLEXITY VIOLATION: {len(changes)} files exceed {threshold}% line increase"
            severity = "warning"
            suggestions = [
                "Consider splitting large files into modules",
                "Extract reusable functions/classes",
                "Document justification for complexity increase",
                "Review for code duplication",
            ]
        else:
            status = ValidationStatus.PASSED
            message = f"Complexity OK: No files exceed {threshold}% growth threshold"
            severity = "info"
            suggestions = []

        result = ValidationResult(
            name="complexity-check",
            status=status,
            message=message,
            evidence=evidence,
            severity=severity,
            suggestions=suggestions,
        )

        self.engine.add_result(result)
        return result

    def check_new_layers(self, file_paths: List[Path]) -> ValidationResult:
        """
        Check for new architectural layers (directories at root level)

        Rule: No new layers without justification
        """
        # Get existing top-level directories
        existing_dirs = {
            d.name
            for d in self.workspace_root.iterdir()
            if d.is_dir() and not d.name.startswith(".")
        }

        # Known directories
        known_dirs = {
            "pronto-api",
            "pronto-client",
            "pronto-employees",
            "pronto-static",
            "pronto-libs",
            "pronto-tests",
            "pronto-scripts",
            "pronto-docs",
            "pronto-audit",
            "pronto-prompts",
            "tmp",
        }

        # Check for new directories in changed files
        new_dirs = set()
        for file_path in file_paths:
            rel_path = file_path.relative_to(self.workspace_root)
            parts = rel_path.parts
            if len(parts) > 0:
                top_dir = parts[0]
                if top_dir not in known_dirs and top_dir not in existing_dirs:
                    new_dirs.add(top_dir)

        # Build evidence
        evidence = Evidence(
            stdout=f"Existing directories: {len(existing_dirs)}\nNew directories detected: {len(new_dirs)}",
            match_count=len(new_dirs),
            raw_output=f"New directories: {', '.join(new_dirs)}"
            if new_dirs
            else "No new directories",
        )

        if new_dirs:
            status = ValidationStatus.WARNING
            message = f"NEW LAYERS DETECTED: {', '.join(new_dirs)}"
            severity = "warning"
            suggestions = [
                "Document new layer in AGENTS.md section 1 (Architecture)",
                "Justify why new layer is necessary",
                "Update pronto-docs/architecture/",
            ]
        else:
            status = ValidationStatus.PASSED
            message = "No new architectural layers detected"
            severity = "info"
            suggestions = []

        result = ValidationResult(
            name="layer-check",
            status=status,
            message=message,
            evidence=evidence,
            severity=severity,
            suggestions=suggestions,
        )

        self.engine.add_result(result)
        return result
