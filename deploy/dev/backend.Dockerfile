# Citra dev backend: konteks build = checkout lumbung-backend-service.
FROM rust:1-bookworm AS build
WORKDIR /src
COPY . .
RUN cargo build --release --locked

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl && rm -rf /var/lib/apt/lists/*
COPY --from=build /src/target/release/lumbung-backend-service /usr/local/bin/lumbung-backend-service
USER nobody
EXPOSE 8080
CMD ["lumbung-backend-service"]
