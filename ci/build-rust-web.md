# CI — Build Rust dan Web

## Backend Rust (`lumbung-backend-service`)

1. Runner: `ubuntu-latest` + toolchain Rust stabil.
2. Perintah:
   ```bash
   cargo test --locked
   cargo build --release --locked
   ```
3. Migrasi diperiksa dengan `sqlx migrate lint` bila tersedia; jalankan `cargo sqlx prepare` sebelum commit yang mengubah query.

## Web (`lumbung-web`)

1. Runner: `ubuntu-latest` + Bun `1.4.x`.
2. Perintah:
   ```bash
   bun install --frozen-lockfile
   bun run check
   bun run build
   ```
3. Artefak: direktori `build/` SvelteKit untuk deploy statis/Node.

## Uji kontrak (manual)

Workflow reusable `contract-schemathesis.yml` dan `contract-pact-provider.yml` (`workflow_dispatch`/`workflow_call`) memeriksa backend
terhadap `docs/api/openapi.yaml` dan pact konsumen. Keduanya checkout `lumbung-backend-service` pada `backend-ref`, membangun, menyalakan server
dengan Postgres uji + kunci sementara, lalu memanggil `contract/schemathesis.sh` (backend PR #17) atau `contract/pact/verifikasi.mjs` (backend PR #18).
Selama PR itu belum merge, isi `backend-ref` dengan branch PR (`test/lmb-be-test-schemathesis`, `test/lmb-be-test-pact`).

```yaml
jobs:
  schemathesis:
    uses: Coding-Skuy/lumbung-infra-devops/.github/workflows/contract-schemathesis.yml@main
    with: { backend-ref: main, max-examples: "50" }
    secrets: inherit   # BACKEND_REPO_TOKEN opsional bila repo backend privat dan beda repo
```
