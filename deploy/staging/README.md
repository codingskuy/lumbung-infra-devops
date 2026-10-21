# Deploy Staging Lumbung

Sama dengan [prod](../prod/README.md), dengan environment GitHub `staging`, DB logis `lumbung` terpisah milik staging,
dan tanpa Required reviewers. Rilis ke prod hanya setelah staging hijau (`healthz` ok + halaman `/ops`, `/rute`, `/papan-harga`).

Jalankan: Actions > "Deploy per environment" > `environment=staging`, `version=<tag>`.
