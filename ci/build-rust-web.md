# CI — Build Rust dan Web

Implementasi: workflow reusable di `.github/workflows/` (`build-rust.yml`, `build-web.yml`, `deploy.yml`).

## Cara memanggil

```yaml
# lumbung-backend-service: .github/workflows/ci.yml
on: [push, pull_request]
jobs:
  ci:
    uses: Coding-Skuy/lumbung-infra-devops/.github/workflows/build-rust.yml@main
```

```yaml
# lumbung-web: .github/workflows/ci.yml
on: [push, pull_request]
jobs:
  ci:
    uses: Coding-Skuy/lumbung-infra-devops/.github/workflows/build-web.yml@main
```

## Backend Rust (`lumbung-backend-service`)

1. Runner: `ubuntu-latest` + Rust stabil + service container Postgres (DB `lumbung`, kredensial CI sekali pakai).
2. Urutan: larang `#[ignore]` (QA-002) -> `sqlx migrate run` -> `cargo sqlx prepare --check -- --all-targets` -> `cargo fmt --check` + `clippy -D warnings` -> `cargo test --locked` (`#[sqlx::test]` terhadap Postgres asli) -> `cargo build --release --locked`.
3. Build gagal bila tes merah atau ada tes yang di-skip.
4. Direktori `.sqlx/` hasil `cargo sqlx prepare` di-commit di repo backend (format `sqlx-data.json` sudah usang).

## Web (`lumbung-web`)

1. Runner: `ubuntu-latest` + Bun (default `1.4.x`, dapat diganti lewat input `bun-version`).
2. Urutan: `bun install --frozen-lockfile` -> `bun run check` (svelte-check) -> `bun test` (larang `.skip`) -> `bun run build`.
3. Artefak: direktori `build/` SvelteKit.

## Deploy per environment

`deploy.yml` (environment `staging`/`prod`) menjalankan `deploy/scripts/deploy.sh`; lihat `deploy/prod/README.md` dan `deploy/staging/README.md`.
