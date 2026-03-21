"""
Core validation primitives

Enforces:
- Raw evidence requirement (stdout, stderr, counts)
- Negative validation (prove why something is NOT broken)
- Non-negotiable evidence format
"""

import subprocess
import sys
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional


class ValidationStatus(Enum):
    """Validation result status"""

    PASSED = "PASSED"
    FAILED = "FAILED"
    WARNING = "WARNING"
    SKIPPED = "SKIPPED"


@dataclass
class Evidence:
    """
    Raw, non-negotiable evidence from validation

    Rule: NO results without raw output
    """

    stdout: str = ""
    stderr: str = ""
    return_code: int = 0
    match_count: Optional[int] = None
    row_count: Optional[int] = None
    file_count: Optional[int] = None
    raw_output: Optional[str] = None
    diff_output: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "stdout": self.stdout,
            "stderr": self.stderr,
            "return_code": self.return_code,
            "match_count": self.match_count,
            "row_count": self.row_count,
            "file_count": self.file_count,
            "raw_output": self.raw_output,
            "diff_output": self.diff_output,
        }

    def is_empty(self) -> bool:
        """Check if evidence is empty (invalid)"""
        return (
            not self.stdout
            and not self.stderr
            and not self.raw_output
            and self.match_count is None
            and self.row_count is None
        )


@dataclass
class ValidationResult:
    """
    Result of a single validation check

    Must include evidence - results without evidence are REJECTED
    """

    name: str
    status: ValidationStatus
    message: str
    evidence: Evidence
    file_path: Optional[str] = None
    line_number: Optional[int] = None
    severity: str = "error"
    suggestions: List[str] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "name": self.name,
            "status": self.status.value,
            "message": self.message,
            "evidence": self.evidence.to_dict(),
            "file_path": self.file_path,
            "line_number": self.line_number,
            "severity": self.severity,
            "suggestions": self.suggestions,
        }

    def validate_evidence(self) -> bool:
        """
        Rule: Results without raw evidence are invalid

        Returns True if evidence is present, False otherwise
        """
        return not self.evidence.is_empty()


class ValidationEngine:
    """
    Main validation orchestrator

    Enforces:
    - All checks must provide evidence
    - Negative validation required
    - Complexity limits
    """

    def __init__(self, workspace_root: Path):
        self.workspace_root = workspace_root
        self.results: List[ValidationResult] = []
        self.baseline_dir = workspace_root / "pronto-scripts" / ".validation-baseline"
        self.baseline_dir.mkdir(parents=True, exist_ok=True)

    def run_command(
        self,
        cmd: List[str],
        cwd: Optional[Path] = None,
        timeout: int = 30,
        capture_output: bool = True,
    ) -> Evidence:
        """
        Run command and capture raw evidence

        Rule: Must capture stdout, stderr, return code
        """
        try:
            result = subprocess.run(
                cmd,
                cwd=cwd or self.workspace_root,
                capture_output=capture_output,
                text=True,
                timeout=timeout,
            )

            evidence = Evidence(
                stdout=result.stdout,
                stderr=result.stderr,
                return_code=result.returncode,
            )

            # Auto-count matches for grep/rg commands
            if result.stdout:
                lines = [l for l in result.stdout.strip().split("\n") if l]
                if lines:
                    evidence.match_count = len(lines)

            return evidence

        except subprocess.TimeoutExpired:
            return Evidence(
                stderr=f"Command timed out after {timeout}s",
                return_code=-1,
            )
        except FileNotFoundError as e:
            return Evidence(
                stderr=f"Command not found: {cmd[0]}",
                return_code=-1,
            )
        except Exception as e:
            return Evidence(
                stderr=f"Command failed: {str(e)}",
                return_code=-1,
            )

    def add_result(self, result: ValidationResult) -> None:
        """Add validation result with evidence check"""
        if not result.validate_evidence():
            # Auto-fail if no evidence
            result.status = ValidationStatus.FAILED
            result.message = f"NO EVIDENCE: {result.message}"
            result.severity = "critical"

        self.results.append(result)

    def run_check(
        self,
        name: str,
        cmd: List[str],
        expected_return_code: int = 0,
        expected_match_count: Optional[int] = None,
        max_match_count: Optional[int] = None,
        cwd: Optional[Path] = None,
        timeout: int = 30,
        suggestions: Optional[List[str]] = None,
    ) -> ValidationResult:
        """
        Run a validation check with evidence

        Args:
            name: Check name
            cmd: Command to run
            expected_return_code: Expected exit code (default: 0)
            expected_match_count: Expected number of output lines (for grep/rg)
            max_match_count: Maximum allowed matches (for violation checks)
            suggestions: Fix suggestions if check fails

        Returns:
            ValidationResult with evidence
        """
        evidence = self.run_command(cmd, cwd, timeout)

        # Determine status
        status = ValidationStatus.PASSED
        message = f"Check passed"
        severity = "info"

        # Check return code
        if evidence.return_code != expected_return_code:
            status = ValidationStatus.FAILED
            message = f"Unexpected return code: {evidence.return_code} (expected: {expected_return_code})"
            severity = "error"

        # Check match count (for grep/rg commands)
        if expected_match_count is not None:
            if evidence.match_count != expected_match_count:
                status = ValidationStatus.FAILED
                message = f"Match count mismatch: {evidence.match_count} (expected: {expected_match_count})"
                severity = "error"

        # Check max matches (for violation searches)
        if max_match_count is not None:
            if (
                evidence.match_count is not None
                and evidence.match_count > max_match_count
            ):
                status = ValidationStatus.FAILED
                message = f"Too many violations: {evidence.match_count} (max: {max_match_count})"
                severity = "error"

        # Negative validation: prove why something is NOT broken
        if status == ValidationStatus.PASSED and expected_match_count == 0:
            message = f"Verified: No violations found (checked {evidence.match_count or 0} matches)"

        result = ValidationResult(
            name=name,
            status=status,
            message=message,
            evidence=evidence,
            severity=severity,
            suggestions=suggestions or [],
        )

        self.add_result(result)
        return result

    def get_summary(self) -> Dict[str, Any]:
        """Get validation summary"""
        passed = sum(1 for r in self.results if r.status == ValidationStatus.PASSED)
        failed = sum(1 for r in self.results if r.status == ValidationStatus.FAILED)
        warnings = sum(1 for r in self.results if r.status == ValidationStatus.WARNING)
        skipped = sum(1 for r in self.results if r.status == ValidationStatus.SKIPPED)

        return {
            "total": len(self.results),
            "passed": passed,
            "failed": failed,
            "warnings": warnings,
            "skipped": skipped,
            "results": [r.to_dict() for r in self.results],
        }

    def has_failures(self) -> bool:
        """Check if any validations failed"""
        return any(r.status == ValidationStatus.FAILED for r in self.results)

    def print_report(self) -> None:
        """Print validation report to stdout"""
        print("\n" + "=" * 80)
        print("VALIDATION REPORT")
        print("=" * 80)

        for result in self.results:
            status_icon = {
                ValidationStatus.PASSED: "✓",
                ValidationStatus.FAILED: "✗",
                ValidationStatus.WARNING: "⚠",
                ValidationStatus.SKIPPED: "○",
            }.get(result.status, "?")

            print(f"\n{status_icon} {result.name}")
            print(f"  Status: {result.status.value}")
            print(f"  Message: {result.message}")

            if result.evidence.stdout:
                print(f"  Output ({len(result.evidence.stdout.splitlines())} lines):")
                for line in result.evidence.stdout.splitlines()[:10]:
                    print(f"    {line}")
                if len(result.evidence.stdout.splitlines()) > 10:
                    print(
                        f"    ... and {len(result.evidence.stdout.splitlines()) - 10} more lines"
                    )

            if result.evidence.match_count is not None:
                print(f"  Match count: {result.evidence.match_count}")

            if result.suggestions:
                print(f"  Suggestions:")
                for suggestion in result.suggestions:
                    print(f"    - {suggestion}")

        print("\n" + "=" * 80)
        summary = self.get_summary()
        print(
            f"TOTAL: {summary['total']} | PASSED: {summary['passed']} | FAILED: {summary['failed']} | WARNINGS: {summary['warnings']}"
        )
        print("=" * 80 + "\n")
