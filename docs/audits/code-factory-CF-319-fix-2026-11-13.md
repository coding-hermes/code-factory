# CF-319 fixture transcript

All arms used a local HTTP stub through `--api-base`; no network or real credentials were used.

## Arm A — unreadable repo (403)

```text
  PASS  private_key_file — <scratch>/cf-319/github-app.pem, mode 600, parses as RSA 2048-bit
  PASS  token_mint — installation 123 answered 201; token expires 2099-01-01T00:00:00Z (permissions read back, never the token)
  PASS  permission:contents — write (need write — clone and push commits; a push is a contents write)
  PASS  permission:metadata — read (need read — mandatory for every App; resolves the repo and the installation)
  PASS  permission:pull_requests — write (need write — open the PR a protected main requires (CF-163))
  PASS  app_slug — /apps/fixture-app -> 200 (declared permissions: contents:write,metadata:read,pull_requests:write)
  PASS  installation_covers — installation grants fixture-owner/fixture-repo (of 1 repositories)
  FAIL  repo_read — GET /repos/fixture-owner/fixture-repo -> 403 — the installation cannot read the repo: either it does not cover it, or contents is not granted

GITHUB APP: FAIL (1)
EXIT=1
```

## Arm B — readable repo (200)

```text
  PASS  private_key_file — <scratch>/cf-319/github-app.pem, mode 600, parses as RSA 2048-bit
  PASS  token_mint — installation 123 answered 201; token expires 2099-01-01T00:00:00Z (permissions read back, never the token)
  PASS  permission:contents — write (need write — clone and push commits; a push is a contents write)
  PASS  permission:metadata — read (need read — mandatory for every App; resolves the repo and the installation)
  PASS  permission:pull_requests — write (need write — open the PR a protected main requires (CF-163))
  PASS  app_slug — /apps/fixture-app -> 200 (declared permissions: contents:write,metadata:read,pull_requests:write)
  PASS  installation_covers — installation grants fixture-owner/fixture-repo (of 1 repositories)
  PASS  repo_read — GET /repos/fixture-owner/fixture-repo with a fresh token -> 200

GITHUB APP: PASS — every piece measured, a fresh token reads fixture-owner/fixture-repo -> 200
EXIT=0
```

## Arm C — no repo named

```text
  PASS  private_key_file — <scratch>/cf-319/github-app.pem, mode 600, parses as RSA 2048-bit
  PASS  token_mint — installation 123 answered 201; token expires 2099-01-01T00:00:00Z (permissions read back, never the token)
  PASS  permission:contents — write (need write — clone and push commits; a push is a contents write)
  PASS  permission:metadata — read (need read — mandatory for every App; resolves the repo and the installation)
  PASS  permission:pull_requests — write (need write — open the PR a protected main requires (CF-163))
  PASS  app_slug — /apps/fixture-app -> 200 (declared permissions: contents:write,metadata:read,pull_requests:write)
  FAIL  repo_read — no repository named, so the read was not measured (pass --repo OWNER/NAME or set GITHUB_APP_REPO)

GITHUB APP: FAIL (1)
EXIT=1
```
