## ADDED Requirements

### Requirement: Self-hosted Umami stack

The system SHALL run self-hosted Umami (application + Postgres) on the host `atelier` via Docker Compose, with the database persisted under `/srv` so data survives container recreation.

#### Scenario: Stack starts and is healthy

- **WHEN** `docker compose up -d` is run for the analytics stack
- **THEN** the Umami app and its Postgres database start and report healthy
- **AND** the Umami app listens on a local port that is not published directly to the public interface

#### Scenario: Data persists across recreation

- **WHEN** the Umami and Postgres containers are recreated without removing volumes
- **THEN** previously recorded analytics data is still present

### Requirement: Public HTTPS at analytics subdomain

Umami SHALL be reachable at `https://analytics.nudgebar.io`, served through the shared public Caddy with a `reverse_proxy` to the local Umami port, Cloudflare-fronted with the origin locked to Cloudflare.

#### Scenario: Dashboard reachable over HTTPS

- **WHEN** a request is made to `https://analytics.nudgebar.io`
- **THEN** the Umami login/dashboard is served over valid TLS

#### Scenario: Direct-to-origin refused

- **WHEN** a client connects directly to the origin public IP for the analytics host, bypassing Cloudflare
- **THEN** the connection is refused or rejected before any content is served

### Requirement: Admin credentials rotated from defaults

The deployment SHALL NOT leave Umami's default admin credentials active; the admin password SHALL be set from server-side configuration.

#### Scenario: Default credentials no longer valid

- **WHEN** provisioning has completed
- **THEN** the default `admin`/`umami` login no longer authenticates
- **AND** the admin password matches the value supplied via server-side configuration

### Requirement: Coexistence with existing host services

The analytics deployment SHALL NOT disturb the existing eval-runs-dashboard Caddy bound to the Tailscale IP, and SHALL only add its own `analytics.nudgebar.io` site block to the shared public Caddy.

#### Scenario: Existing services unaffected

- **WHEN** the analytics stack and its Caddy block are installed and Caddy is reloaded
- **THEN** the apex site and the Tailscale-only eval-runs-dashboard Caddy continue serving unchanged
