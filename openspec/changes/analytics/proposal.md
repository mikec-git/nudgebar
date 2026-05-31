## Why

We want privacy-friendly, self-hosted product analytics for nudgebar.io so we can measure traffic and, critically, **download conversions** — without third-party trackers or per-event SaaS costs. Cloudflare Web Analytics cannot record custom conversion events, so we self-host Umami, which gives first-party, cookie-free pageviews plus a custom `Download clicked` event.

## What Changes

- Stand up self-hosted **Umami** (Docker app + Postgres) on the Hetzner host `atelier`, served at `analytics.nudgebar.io` behind the public Cloudflare-fronted Caddy established by the `website` change.
- Provision the `nudgebar.io` website inside Umami via its REST API (scripted, non-interactive) and emit the resulting **website-ID** for the marketing site to consume.
- Define the **`Download clicked`** custom conversion event contract that the marketing site fires (event name and any properties).
- Add a **nightly `pg_dump`** backup of the Umami Postgres database, with simple retention.
- Keep all secrets (`APP_SECRET`, database password) in a server-side env file, never committed.

## Capabilities

### New Capabilities

- `analytics-service`: the Umami app + Postgres deployment on atelier — Docker compose stack, data persistence under `/srv`, the `analytics.nudgebar.io` Caddy site block (Cloudflare-fronted, origin locked to Cloudflare), and lifecycle (start/stop/upgrade).
- `analytics-provisioning`: scripted, idempotent website creation via the Umami API, the website-ID handoff to the `website` change, and the `Download clicked` event contract.
- `analytics-backup`: nightly `pg_dump` of the Umami database with retention and a documented restore path.

### Modified Capabilities

<!-- None. Greenfield worktree (openspec/specs/ is empty). -->

## Impact

- **New files (this worktree):** to be authored during apply — `compose.yaml` (Umami + Postgres), a `Caddyfile` snippet/vhost for `analytics.nudgebar.io`, `scripts/provision.sh` (Umami API), `scripts/backup.sh` (pg_dump + cron/systemd timer), and a `.env.example` template (real `.env` with `APP_SECRET`/DB password never committed).
- **External systems:** Hetzner host `atelier` (Docker 29.5 + Compose v5 present; data under `/srv`; public IP discovered programmatically, never hardcoded); Cloudflare DNS A/CNAME for `analytics.nudgebar.io`; public 80/443 are free.
- **Do not disturb:** the existing eval-runs-dashboard Caddy bound only to the Tailscale IP `100.100.26.126:443`.
- **Cross-change dependency:** produces the website-ID and `analytics.nudgebar.io` script endpoint consumed by the `website` change (owned by Claude). The two changes share the Cloudflare zone and the public Caddy on atelier; the `website` change owns the base Caddy container/config, and this change adds the `analytics.nudgebar.io` site block.
