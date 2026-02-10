# AGENT.md — Centia BaaS Agent Guide

> Last updated: 2026-02-10 · v1.1

This repository is designed to be used with AI coding agents such as Claude Code and Junie.

Follow this guide strictly.

---

# 1) Prime Directive

When working with Centia BaaS:

- Prefer MCP tools when available.
- Use the official SDK `@centia-io/sdk` for all TypeScript/JavaScript application runtime code.
- Use raw HTTP only for provisioning tasks not covered by MCP.
- Never re-implement SDK functionality using fetch/axios in JS/TS apps.

---

# 2) Tool Priority (Hard Rule)

Interaction priority order:

1. Centia MCP tools  
2. `@centia-io/sdk`  
3. OpenAPI HTTP calls  
4. Docs-backed HTTP calls  

Never invent endpoints or payloads.

---

# 3) Capability Split

## A) Application Runtime Code

Use ONLY:

`@centia-io/sdk`

Applies to (verify availability against installed SDK version):

- Auth
- Database CRUD
- Queries & filtering
- Pagination
- Client initialization

Forbidden:

- Direct REST calls
- Custom fetch wrappers
- Reverse-engineered payloads

If SDK lacks functionality:

Create fallback in:

`src/baas/http.ts`

Document why it exists.

---

## B) Platform / Schema Provisioning

Provisioning includes:

- Schemas
- Tables
- Columns
- Indexes
- Constraints
- Policies
- Relations
- Seed data
- Migrations

Provisioning must use:

1. MCP tools (preferred)  
2. OpenAPI  
3. Docs-backed endpoints  

Provisioning is NOT runtime logic.

---

# 4) Schema Lifecycle Policy (Hard Rule)

Schema changes must occur during code-generation / provisioning — never at app runtime.

Allowed during code-generation:

- Create/alter/drop tables
- Modify columns/indexes/constraints
- Configure policies
- Seed initial data

Forbidden at runtime:

- Creating tables dynamically
- Auto-migrations on startup
- Schema ensure logic
- Policy changes
- Index creation

Runtime apps must assume schema already exists.

---

# 5) Provisioning Output Structure

All provisioning artifacts must be stored locally.

Allowed locations:

provision/  
migrations/  
schema/plan.json  
schema/plan.md  

Example:

```
provision/
  apply.ts

schema/
  plan.json

migrations/
  001_create_tables.ts
```

Runner:

```sh
npx tsx provision/apply.ts
npx tsx migrations/001_create_tables.ts
```

Application runtime code must never call provisioning endpoints.

---

# 6) SDK Usage Standard

All JS/TS apps must initialize SDK centrally.

File:

src/baas/client.ts

Example (server / provisioning context):

```ts
import { Sql } from "@centia-io/sdk";

export const sql = new Sql();
```

Example (browser / SPA context — see Section 8A):

```ts
import { createClient } from "@centia-io/sdk";

export const baas = createClient({
  baseUrl: import.meta.env.VITE_BAAS_BASE_URL,
});
```

Rules:

- Single shared client
- No hardcoded credentials
- Env-driven config
- Use `Sql` for server-side / direct SQL access
- Use `createClient` for browser apps that need OAuth

---

# 7) HTTP Fallback Layer

If needed, create:

src/baas/http.ts

Purpose:

- SDK gaps
- Docs-backed endpoints
- Provisioning helpers

Rules:

- Centralize headers
- Typed payloads
- No token leakage
- Document source

Comment example:

Fallback to HTTP: not supported in @centia-io/sdk yet  
Source: https://centia.io/docs/…

---

# 8) Authentication Model Policy

Authentication depends on runtime environment.

Agents must detect whether the app is:

- Browser / SPA
- Server / Backend
- Provisioning script

---

## A) Browser Applications (SPA / Frontend)

Examples:

- React
- Next.js (client)
- Vue
- Vite
- Svelte

Hard rules:

- Do NOT use `BAAS_ACCESS_TOKEN`
- Do NOT embed service tokens
- Do NOT store long-lived tokens in source
- Do NOT call provisioning APIs

Browser apps must use OAuth Authorization Code Flow (PKCE) via SDK.

Required implementation:

Use `@centia-io/sdk` OAuth helpers.

Agents must NOT implement OAuth manually.

Example pattern:

```ts
import { createClient } from "@centia-io/sdk";

const baas = createClient({
  baseUrl: import.meta.env.VITE_BAAS_BASE_URL,
});

await baas.auth.signInWithOAuth({
  provider: "keycloak",
});
```

Token storage must be SDK-managed.

Forbidden:

- Hardcoded tokens
- Tokens in frontend `.env`
- Tokens committed to repo

---

## B) Server / Backend Applications

Examples:

- Node.js
- Serverless
- CLI
- MCP servers
- Provisioning scripts

Allowed auth method:

BAAS_ACCESS_TOKEN

Stored in:

.env

Used for:

- Provisioning
- Admin operations
- Service-to-service calls

---

## C) Provisioning Scripts

Provisioning always runs server-side.

Allowed:

- Access tokens
- MCP tools
- OpenAPI calls

Forbidden:

- OAuth flows
- Browser auth patterns

---

# 9) Auth Responsibility Split

| Context | Auth Method | Interface |
|--------|--------------|-----------|
| Browser app | OAuth Code Flow (PKCE) | SDK |
| Backend app | Access token | SDK / HTTP |
| Provisioning | Access token | MCP / HTTP |
| CLI tools | Access token | SDK / HTTP |

---

# 10) OpenAPI Access Policy

Preferred sources:

1. Local file: openapi/openapi.json  
2. URL: BAAS_OPENAPI_URL  
3. User-provided JSON  

If allowed, fetch automatically:

```sh
mkdir -p openapi
if [ -n "$BAAS_OPENAPI_URL" ] && [ ! -f "openapi/openapi.fetched.json" ]; then
  curl -fsSL \
    -H "Authorization: Bearer $BAAS_ACCESS_TOKEN" \
    "$BAAS_OPENAPI_URL" -o openapi/openapi.fetched.json
fi
```

OpenAPI is the contract for all endpoints it describes.

---

# 11) Documentation Access Policy

Primary docs:

https://centia.io/docs/intro

GitHub docs:

https://github.com/centia-io/website/tree/main/docs

If terminal + internet access is allowed:

```sh
mkdir -p vendor
if [ ! -d "vendor/centia-docs/docs" ]; then
  git clone --depth 1 --filter=blob:none --sparse https://github.com/centia-io/website.git vendor/centia-docs
  cd vendor/centia-docs
  git sparse-checkout set docs
  cd ../..
fi
```

Note: This assumes the repository is public. If the clone fails due to authentication, fall back to the web docs at https://centia.io/docs/intro.

Docs-backed endpoints allowed only when fully specified.

---

# 12) Safety Rules (Provisioning)

Before destructive changes, present plan:

- Method
- MCP tool / endpoint
- Purpose

Destructive includes:

- DROP TABLE
- TRUNCATE
- Column deletion
- Policy overwrite
- MCP `postSql` calls containing destructive SQL (DROP, TRUNCATE, DELETE without WHERE)
- MCP `deleteTable`, `deleteColumn`, `deleteSchema`, `deleteConstraint`, `deleteIndex`

Proceed only if explicitly requested.

---

# 13) Project Structure Standard

```
src/
  baas/
    client.ts
    http.ts
    types.ts
  features/

provision/
schema/
migrations/
docs/

.env.example
openapi/
vendor/
```

---

# 14) Code Quality Rules

- TypeScript strict mode preferred
- Centralize schema/table names
- Avoid magic strings
- Provide runnable examples
- Handle API errors clearly

Error handling pattern:

```ts
const { data, error } = await sql.from("users").select();
if (error) throw new Error(`Query failed: ${error.message}`);
```

---

# 15) Delivery Requirements

Every generated solution must include:

- Setup steps
- Env vars
- Install + run commands
- SDK usage explanation
- Provisioning steps
- Validation steps
- HTTP calls made (no secrets)

---

# 16) Available MCP Tools Reference

Schema management:

- `getSchema`, `postSchema`, `patchSchema`, `deleteSchema`

Table management:

- `getTable`, `postTable`, `patchTable`, `deleteTable`

Column management:

- `getColumn`, `postColumn`, `patchColumn`, `deleteColumn`

Constraints:

- `getConstraint`, `postConstraint`, `deleteConstraint`

Indexes:

- `getIndex`, `postIndex`, `deleteIndex`

Sequences:

- `getSequence`, `postSequence`, `patchSequence`, `deleteSequence`

Query execution:

- `postSql` — Execute arbitrary SQL (SELECT, INSERT, UPDATE, DELETE, MERGE)
- `postGraphQL` — Run GraphQL queries/mutations

RPC:

- `getRpc`, `postRpc`, `patchRpc`, `deleteRpc`
- `postCall` — Call an RPC method

Auth & users:

- `postOauth`, `postDevice`
- `getUser`, `postUser`, `patchUser`, `deleteUsers`

Access control:

- `getRule`, `postRule`, `patchRule`, `deleteRule`
- `getPrivileges`, `patchPrivileges`

Clients:

- `getClient`, `postClient`, `patchClient`, `deleteClient`

File import:

- `postFileUpload`, `postFileProcess`

Other:

- `postCommit` — Commit schema changes to Git
- `getStats` — Get database statistics
- `getTypeScript` — Get TypeScript interfaces for RPC methods

---

# 17) Environment Variables

| Variable | Context | Required | Description |
|----------|---------|----------|-------------|
| `BAAS_ACCESS_TOKEN` | Server / provisioning | Yes | Auth token for backend and provisioning operations |
| `BAAS_OPENAPI_URL` | Development | No | URL to fetch OpenAPI spec from |
| `VITE_BAAS_BASE_URL` | Browser apps (Vite) | Yes | Base URL for the Centia BaaS instance |

Never commit `.env` files containing secrets. Provide a `.env.example` with placeholder values.

---

# 18) Agent Self-Check

Before finishing:

- MCP tools used when available
- SDK used for JS/TS runtime code
- Provisioning separated from runtime
- No schema changes at startup
- OAuth used in browser apps
- No access token embedded in frontend
- Secrets protected
- OpenAPI followed where applicable
- Docs-backed endpoints fully specified
- Run instructions included
