# Changelog

Semua perubahan penting lumbung-infra-devops dicatat di sini. Format mengikuti Keep a Changelog; versi mengikuti versi milestone Lumbung.

## [Belum dirilis]

### Ditambahkan
- Smoke lintas-repo web/app -> backend nyata di dev-stack: `ci/scripts/smoke-dev.sh`, `make dev-smoke` (siklus 3, tanpa tiket).
- Dev-stack lokal Docker Compose (backend + Postgres), `make dev-up/dev-down/dev-reset/dev-logs/dev-seed`, `deploy/dev/gen-env.sh` (siklus 3, tanpa tiket).
- Secrets, rotasi kunci, backup dan uji restore: `docs/secrets.md`, `docs/rotasi-kunci.md`, `docs/backup-restore.md`, `deploy/backup/*.sh`, `ci/scripts/check-no-secrets.sh`, workflow `guard.yml` dan `restore-drill.yml`; runbook: pool `acquire_timeout` 3 dtk dan batas per replika (LMB-OPS-004).
- Fondasi AI-dev v1.0.0: `AGENTS.md`, `CLAUDE.md`, `docs/decisions/` (ADR-0001), `versions/v1.0.0/docs/40-TECHSTACK.md`, `versions/v1.0.0/docs/60-BLAST-RADIUS.md` (tiket LMB-OPS-001, 2026-10-14).
