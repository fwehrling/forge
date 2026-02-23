#!/usr/bin/env python3
"""
FORGE Skill Security Auditor
Scans Claude Code skills for potential security threats.
Based on Cisco's research on OpenClaw/Moltbot vulnerabilities.

Usage:
    python3 audit-skill.py <path-to-skill-folder>
    python3 audit-skill.py <path-to-skill-folder> --strict
"""

import os
import re
import sys
import json
from pathlib import Path
from dataclasses import dataclass, field
from typing import List

# ─── Risk Patterns ──────────────────────────────────────────────

NETWORK_PATTERNS = [
    (r'curl\s', "Shell curl command detected"),
    (r'wget\s', "Shell wget command detected"),
    (r'requests\.(get|post|put|delete|patch)', "Python requests library usage"),
    (r'fetch\(', "JavaScript fetch API usage"),
    (r'http\.get|http\.post|https\.get|https\.post', "Node.js HTTP module usage"),
    (r'urllib\.request', "Python urllib usage"),
    (r'aiohttp', "Python aiohttp usage"),
    (r'socket\.connect', "Raw socket connection"),
]

CREDENTIAL_PATTERNS = [
    (r'(api[_-]?key|apikey)\s*[=:]\s*["\'][^"\']+["\']', "Hardcoded API key"),
    (r'(password|passwd|pwd)\s*[=:]\s*["\'][^"\']+["\']', "Hardcoded password"),
    (r'(secret|token)\s*[=:]\s*["\'][^"\']+["\']', "Hardcoded secret/token"),
    (r'(sk-|ghp_|gho_|glpat-|xoxb-|xoxp-)', "Known API key prefix"),
    (r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', "Bearer token in code"),
    (r'Basic\s+[A-Za-z0-9+/]+=*', "Basic auth credential"),
]

INJECTION_PATTERNS = [
    (r'ignore\s+(previous|all|above)\s+instructions', "Prompt injection: instruction override"),
    (r'you\s+are\s+now\s+a', "Prompt injection: role manipulation"),
    (r'system\s*:\s*', "Prompt injection: system role attempt"),
    (r'<\s*/?\s*system\s*>', "Prompt injection: system tag"),
    (r'IMPORTANT:\s*override', "Prompt injection: override attempt"),
]

FILE_ACCESS_PATTERNS = [
    (r'\.\./', "Path traversal attempt"),
    (r'~/', "Home directory access"),
    (r'/etc/', "System config access"),
    (r'/root/', "Root directory access"),
    (r'os\.environ', "Environment variable reading"),
    (r'process\.env', "Node.js env reading"),
    (r'subprocess\.(run|call|Popen)', "Subprocess execution"),
    (r'os\.system\(', "OS system call"),
    (r'child_process', "Node.js child process"),
]

DANGEROUS_PATTERNS = [
    (r'\beval\s*\(', "Dynamic code evaluation (eval)"),
    (r'\bexec\s*\(', "Dynamic code execution (exec)"),
    (r'Function\s*\(', "Dynamic function creation"),
    (r'__import__', "Python dynamic import"),
    (r'importlib', "Python dynamic import via importlib"),
    (r'rm\s+-rf', "Destructive file deletion"),
    (r'chmod\s+777', "Overly permissive file permissions"),
    (r'dd\s+if=', "Disk manipulation command"),
]


@dataclass
class Finding:
    severity: str  # critical, high, medium, low, info
    category: str
    message: str
    file: str
    line: int = 0
    pattern: str = ""


@dataclass
class AuditResult:
    skill_path: str
    risk_score: int = 0
    findings: List[Finding] = field(default_factory=list)
    
    @property
    def verdict(self) -> str:
        if self.risk_score <= 20:
            return "LOW RISK — Auto-approved"
        elif self.risk_score <= 50:
            return "MEDIUM RISK — Review recommended"
        elif self.risk_score <= 80:
            return "HIGH RISK — Manual review required"
        else:
            return "CRITICAL RISK — Do not install without thorough review"


def scan_file(filepath: str, patterns: list, category: str, severity: str) -> List[Finding]:
    """Scan a single file against a set of patterns."""
    findings = []
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            for line_num, line in enumerate(f, 1):
                for pattern, message in patterns:
                    if re.search(pattern, line, re.IGNORECASE):
                        findings.append(Finding(
                            severity=severity,
                            category=category,
                            message=message,
                            file=filepath,
                            line=line_num,
                            pattern=pattern,
                        ))
    except (IOError, PermissionError):
        findings.append(Finding(
            severity="info",
            category="access",
            message=f"Could not read file: {filepath}",
            file=filepath,
        ))
    return findings


def audit_skill(skill_path: str, strict: bool = False) -> AuditResult:
    """Perform security audit on a skill directory."""
    result = AuditResult(skill_path=skill_path)
    path = Path(skill_path)
    
    # Check SKILL.md exists
    skill_md = path / "SKILL.md"
    if not skill_md.exists():
        result.findings.append(Finding(
            severity="critical",
            category="structure",
            message="No SKILL.md found — not a valid skill",
            file=str(skill_md),
        ))
        result.risk_score = 100
        return result
    
    # Scan all files
    for filepath in path.rglob("*"):
        if filepath.is_file():
            rel_path = str(filepath.relative_to(path))
            ext = filepath.suffix.lower()
            
            # Skip binary files
            if ext in ('.png', '.jpg', '.jpeg', '.gif', '.webp', '.ico',
                       '.woff', '.woff2', '.ttf', '.eot', '.pdf', '.zip'):
                continue
            
            str_path = str(filepath)
            
            # Scan for network calls
            result.findings.extend(
                scan_file(str_path, NETWORK_PATTERNS, "network", "high")
            )
            
            # Scan for credentials
            result.findings.extend(
                scan_file(str_path, CREDENTIAL_PATTERNS, "credentials", "critical")
            )
            
            # Scan for prompt injection
            result.findings.extend(
                scan_file(str_path, INJECTION_PATTERNS, "injection", "critical")
            )
            
            # Scan for file access
            result.findings.extend(
                scan_file(str_path, FILE_ACCESS_PATTERNS, "file_access",
                         "high" if strict else "medium")
            )
            
            # Scan for dangerous operations
            result.findings.extend(
                scan_file(str_path, DANGEROUS_PATTERNS, "dangerous", "critical")
            )
    
    # Calculate risk score
    severity_weights = {
        "critical": 25,
        "high": 15,
        "medium": 5,
        "low": 2,
        "info": 0,
    }
    
    total_weight = sum(
        severity_weights.get(f.severity, 0) for f in result.findings
    )
    result.risk_score = min(100, total_weight)
    
    return result


def print_report(result: AuditResult):
    """Print human-readable audit report."""
    print(f"\n{'='*60}")
    print(f"  FORGE Skill Security Audit")
    print(f"  Path: {result.skill_path}")
    print(f"{'='*60}\n")
    
    # Risk score
    score = result.risk_score
    if score <= 20:
        color = "\033[92m"  # Green
    elif score <= 50:
        color = "\033[93m"  # Yellow
    elif score <= 80:
        color = "\033[91m"  # Red
    else:
        color = "\033[91;1m"  # Bold Red
    
    reset = "\033[0m"
    print(f"  Risk Score: {color}{score}/100{reset}")
    print(f"  Verdict: {color}{result.verdict}{reset}\n")
    
    if not result.findings:
        print("  ✅ No security issues found.\n")
        return
    
    # Group findings by severity
    by_severity = {}
    for f in result.findings:
        by_severity.setdefault(f.severity, []).append(f)
    
    severity_order = ["critical", "high", "medium", "low", "info"]
    severity_icons = {
        "critical": "🔴",
        "high": "🟠",
        "medium": "🟡",
        "low": "🔵",
        "info": "ℹ️",
    }
    
    for sev in severity_order:
        findings = by_severity.get(sev, [])
        if not findings:
            continue
        
        icon = severity_icons[sev]
        print(f"  {icon} {sev.upper()} ({len(findings)} findings)")
        for f in findings:
            loc = f"{f.file}:{f.line}" if f.line else f.file
            print(f"     → {f.message}")
            print(f"       at {loc}")
        print()
    
    print(f"  Total findings: {len(result.findings)}")
    print()


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 audit-skill.py <path-to-skill> [--strict]")
        sys.exit(1)
    
    skill_path = sys.argv[1]
    strict = "--strict" in sys.argv
    
    if not os.path.isdir(skill_path):
        print(f"❌ Error: {skill_path} is not a directory")
        sys.exit(1)
    
    result = audit_skill(skill_path, strict=strict)
    print_report(result)
    
    # Exit code based on risk
    if result.risk_score > 80:
        sys.exit(2)  # Critical
    elif result.risk_score > 50:
        sys.exit(1)  # High
    else:
        sys.exit(0)  # OK


if __name__ == "__main__":
    main()
