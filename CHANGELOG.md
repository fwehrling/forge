# Changelog

All notable changes to FORGE are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-23

### Added

- Core FORGE framework (`/forge` main skill) with comprehensive reference document
- 12 specialized agent personas in `skills/forge/references/agents/`
- 23 skills covering the full development lifecycle:
  - Pipeline: `/forge-analyze`, `/forge-plan`, `/forge-architect`, `/forge-ux`, `/forge-stories`, `/forge-build`, `/forge-verify`, `/forge-deploy`
  - Orchestration: `/forge-auto` (autopilot), `/forge-team` (Agent Teams), `/forge-party` (multi-agent debate), `/forge-loop` (autonomous iteration)
  - Tools: `/forge-quick-spec`, `/forge-quick-test`, `/forge-review`, `/forge-audit`, `/forge-audit-skill`, `/forge-memory`, `/forge-init`, `/forge-resume`, `/forge-status`, `/forge-update`
- Persistent memory system (Markdown-based, two-layer: long-term + session)
- Vector memory search: SQLite + `all-MiniLM-L6-v2` embeddings, hybrid retrieval (70% vector + 30% FTS5 BM25)
- `forge-memory` CLI: sync, search, log, consolidate, status, reset
- Autonomous loop runner (`forge-loop.sh`) with cost caps, circuit breakers, rate limiting, sandbox isolation, and rollback checkpoints
- Token Saver: output filtering hooks to reduce shell output token consumption
- Cross-platform installer (`install.sh`) with OS detection (macOS, Linux, WSL)
- Update check hook (`forge-update-check.sh`) with 24h cache TTL
- Skill security auditor (`audit-skill.py`)
- Scale-adaptive intelligence (Quick / Standard / Enterprise tracks)
- Test-driven pipeline (SM specifies, Dev writes TDD, QA audits)
- 5-layer security model (input validation, sandbox, credentials, audit/rollback, human gates)
- ADR support in `/forge-architect` (Enterprise track)
- Three execution modes: Manual, Autopilot (with checkpoint flags), Agent Teams
- `CONTRIBUTING.md` with skill creation guide and testing procedures
- n8n workflow integration patterns (conceptual)
- MCP server integration patterns (conceptual)

[1.0.0]: https://github.com/fwehrling/forge/releases/tag/v1.0.0
