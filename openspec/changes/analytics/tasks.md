## 1. Stack definition

- [ ] 1.1 Author `compose.yaml`: `umami` + `postgres` services, DB persisted under `/srv`, Umami on a local-only port, image tags pinned
- [ ] 1.2 Add `.env.example` (`APP_SECRET`, Postgres credentials/`DATABASE_URL`, `ADMIN_PASSWORD`) and confirm the real `.env` is gitignored
- [ ] 1.3 Author the `analytics.nudgebar.io` Caddy site block: `reverse_proxy` to the local Umami port, Cloudflare Origin Certificate, origin locked to Cloudflare

## 2. Cloudflare / DNS

- [ ] 2.1 Add `analytics.nudgebar.io` DNS (proxied) → atelier public IP discovered programmatically
- [ ] 2.2 Confirm the Origin Certificate and Authenticated Origin Pulls cover the analytics host (reuse the zone/cert from the `website` change)

## 3. Deploy on atelier

- [ ] 3.1 Discover atelier's current public IP; confirm the public Caddy from the `website` change is up first
- [ ] 3.2 Place `compose.yaml` + `.env` under `/srv`; `docker compose up -d`; verify Umami + Postgres healthy
- [ ] 3.3 Install the `analytics.nudgebar.io` block into the shared Caddy; reload; verify the dashboard over HTTPS

## 4. Provisioning

- [ ] 4.1 Author `scripts/provision.sh`: authenticate, rotate the admin password from env, create the `nudgebar.io` website if absent (idempotent)
- [ ] 4.2 Emit the website-ID to a stable server-side path for the `website` change; confirm it is not committed
- [ ] 4.3 Document the `Download clicked` event contract (exact name + optional `platform`/`cta` properties)

## 5. Backup

- [ ] 5.1 Author `scripts/backup.sh`: `pg_dump` to a `/srv` backup dir, timestamped, with retention pruning
- [ ] 5.2 Install a nightly systemd timer (or cron); run once to confirm a dump is produced
- [ ] 5.3 Document the restore procedure

## 6. Verification

- [ ] 6.1 `https://analytics.nudgebar.io` serves the dashboard over valid TLS; a direct-to-origin request is refused
- [ ] 6.2 The default `admin`/`umami` login no longer authenticates
- [ ] 6.3 A test `Download clicked` event records against the `nudgebar.io` website
- [ ] 6.4 The nightly backup produces a dump and prunes old ones; existing host services remain unaffected
