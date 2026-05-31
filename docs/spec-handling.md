# Spec Handling

Local design/spec artifacts should be committed only when they are finalized and sanitized. Specs often contain prompts, implementation notes, account details, provider setup notes, or copied API examples that can accidentally include secrets.

## Storage Rule

- Keep raw Claude/Codex/design working specs outside the repo in `../nudgebar-specs/`.
- Do not commit archived working specs.
- Commit finalized OpenSpec/project specs only after sanitizing them.
- Keep committed docs limited to sanitized architecture decisions and implementation guidance.

The sibling archive folder is intentionally gitignored with a deny-by-default `.gitignore`.

## Secret Rule

Before sharing, archiving, promoting, or committing a spec, run:

```sh
Scripts/check-spec-secrets.sh ../nudgebar-specs
```

The script prints only filenames with potential secret patterns. It does not print matched values.

Specs must not contain:

- OAuth access or refresh tokens.
- API keys.
- CalDAV passwords or app-specific passwords.
- Basic Auth headers.
- PKCE verifiers.
- Client secrets.
- Private keys.
- Raw event bodies, attendee lists, private notes, or meeting links unless explicitly sanitized.
