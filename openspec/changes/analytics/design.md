## Context

The marketing site (`website` change, owned by Claude) needs first-party analytics with a custom download-conversion event. Cloudflare Web Analytics cannot record custom events, so we self-host Umami on the existing Hetzner host `atelier`:

- Docker 29.5 + Compose v5 installed; persistent data under `/srv`.
- Public 80/443 are free; the eval-runs-dashboard Caddy binds only the Tailscale IP and must not be disturbed.
- `nudgebar.io` is fronted by Cloudflare (zone + base public Caddy established by the `website` change). This change adds the `analytics.nudgebar.io` host and consumes the same Cloudflare zone.

## Goals / Non-Goals

**Goals:**

- Self-hosted Umami (app + Postgres) reachable at `https://analytics.nudgebar.io`, Cloudflare-fronted, origin locked to Cloudflare.
- A scripted, idempotent provisioning that creates the `nudgebar.io` website in Umami and emits its **website-ID** for the site to consume.
- A documented `Download clicked` event contract.
- Nightly `pg_dump` backups with retention and a documented restore.
- All secrets in a server-side env file, never committed.

**Non-Goals:**

- The marketing page and its analytics snippet (owned by the `website` change — this change only defines the event contract and hands off the website-ID).
- Creating the Cloudflare zone or the base public Caddy container (owned by the `website` change; this change contributes only the `analytics.nudgebar.io` site block).
- The macOS app or any in-app telemetry.

## Decisions

**1. Umami (not Plausible, GoatCounter, or Cloudflare Web Analytics).**
Umami is self-hostable, cookie-free/GDPR-friendly, lightweight (Node + Postgres), and — decisively — supports **custom events** via `umami.track()`, which Cloudflare Web Analytics does not. It also exposes a REST API suitable for scripted, non-interactive provisioning.

**2. Postgres backing store (not MySQL).**
Umami supports both; Postgres is chosen for straightforward `pg_dump`/`pg_restore` backups. A dedicated Postgres instance (not shared with other apps) keeps isolation and backup scope clean.

**3. Docker Compose stack under `/srv`.**
`compose.yaml` runs `umami` + `postgres`, with the database persisted to a bind/volume under `/srv` so data survives container recreation. Umami listens on a local port only; it is not published to the public interface directly.

**4. Served via the shared public Caddy, not a second proxy.**
The `website` change owns the public Caddy container. This change contributes a self-contained `analytics.nudgebar.io` Caddy site block that `reverse_proxy`es to the local Umami port, Cloudflare-fronted and origin-locked the same way as the apex. Coordination: the public Caddy must be up first; the analytics block is installed into the shared config and Caddy reloaded.

**5. Idempotent provisioning via the Umami API.**
A script logs in with admin credentials from env, rotates the default admin password, checks whether a `nudgebar.io` website already exists, creates it if not, and writes the resulting website-ID to a stable server-side path for the `website` change to read. Re-running is safe.

**6. `Download clicked` event contract.**
The event name is exactly `Download clicked`, no required properties (optional `platform`/`cta` properties allowed). Documented here and in the spec so the site fires the matching name.

**7. Nightly backup via a scheduled `pg_dump`.**
A systemd timer (or cron) dumps the Umami database nightly to `/srv` backups with simple daily retention; restore is documented.

## Risks / Trade-offs

- **[Shared Caddy coupling]** → Two changes touch one Caddy. Mitigation: ship a self-contained site block; document install order (public Caddy from `website` up first) and that this change only adds/reloads its own block.
- **[Default admin credentials]** → Umami ships `admin/umami`. Mitigation: the provisioning script rotates the admin password from env on first run and fails if the default is still active afterward.
- **[Public dashboard exposure]** → The Umami dashboard is internet-facing. Mitigation: Cloudflare front + origin lock + admin auth; optionally Cloudflare Access in front of the dashboard (Open Question).
- **[Data loss]** → DB corruption or host loss. Mitigation: persistent volume + nightly `pg_dump` with retention and a tested restore path.
- **[Handoff timing]** → The site can't fire real events before Umami exists. Mitigation: emit the website-ID to a stable path; the `website` change wires it once analytics is live.

## Migration Plan

1. **DNS:** add `analytics.nudgebar.io` (proxied) in the Cloudflare zone pointing at atelier's current public IP (discovered programmatically).
2. **Stack:** place `compose.yaml` + `.env` (secrets) under `/srv`; `docker compose up -d`; verify Umami + Postgres healthy.
3. **Proxy:** install the `analytics.nudgebar.io` Caddy block into the shared public Caddy; reload; verify HTTPS.
4. **Provision:** run the script — rotate admin password, create the `nudgebar.io` website, emit the website-ID.
5. **Backup:** install the nightly `pg_dump` timer; run once to confirm a dump is produced.
6. **Verify:** dashboard reachable over HTTPS; a test `Download clicked` event records; direct-to-origin refused; backup file present.
   **Rollback:** `docker compose down` (retain the data volume), remove the Caddy block + reload, remove the DNS record. Restore from the latest dump if needed.

## Open Questions

- **Cloudflare Access on the dashboard?** Putting the Umami UI behind Cloudflare Access would gate it to authorized identities beyond Umami's own login. Default to Umami auth + origin lock now; add Access if the dashboard needs stronger protection.
- **Version pinning / upgrade cadence** for the Umami and Postgres images — pin to a known-good tag and document the upgrade + backup-first step.
