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
- Database CRUD (SQL, SQL builder)
- Queries & filtering
- Pagination
- JSON-RPC
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

Available exports:

```ts
import { CodeFlow, PasswordFlow, SignUp, Sql, Rpc, createApi, createSqlBuilder } from "@centia-io/sdk";
import type { RpcRequest, RpcResponse, PgTypes, DBSchema, RowOfSelect } from "@centia-io/sdk";
```

### SQL execution (server & browser):

```ts
import { Sql } from "@centia-io/sdk";

export const sql = new Sql();

const res = await sql.exec({
  q: "SELECT * FROM users WHERE id = :id::int",
  params: { id: 1 },
});
console.log(res.data);
```

### Type-safe SQL builder:

```ts
import { createSqlBuilder, Sql } from "@centia-io/sdk";
import type { DBSchema, RowOfSelect } from "@centia-io/sdk";

const schema = { /* ... */ } as const satisfies DBSchema;
const b = createSqlBuilder(schema);
const sql = new Sql();

// SELECT
const selectReq = b.table("users").select(["id", "name"]).andWhere({ id: [1, 2] }).limit(10);
type Row = RowOfSelect<typeof selectReq>;
const rows: Row[] = (await sql.exec(selectReq.toSql())).data;

// INSERT
const insertReq = b.table("users").insert({ name: "Alice" }).returning(["id"]);

// UPDATE
const updateReq = b.table("users").update({ name: "Bob" }).where({ id: 1 });

// DELETE
const deleteReq = b.table("users").delete().where({ id: 2 });
```

### JSON-RPC:

```ts
import { Rpc } from "@centia-io/sdk";

const rpc = new Rpc();

const res = await rpc.call({
  jsonrpc: "2.0",
  method: "myMethod",
  params: { key: "value" },
  id: 1,
});
```

### Typed RPC with createApi:

```ts
import { createApi } from "@centia-io/sdk";

interface MyApi {
  getUserById(params: { user_id: number }): Promise<Array<{ name: string }>>;
}

const api = createApi<MyApi>();
const users = await api.getUserById({ user_id: 1 });
```

### Browser auth — CodeFlow (see Section 9A):

```ts
import { CodeFlow } from "@centia-io/sdk";

export const codeFlow = new CodeFlow({
  host: import.meta.env.VITE_CENTIA_HOST,
  clientId: import.meta.env.VITE_CENTIA_CLIENT_ID,
  redirectUri: window.location.origin + "/auth/callback",
});
```

### Server auth — PasswordFlow (see Section 9B):

```ts
import { PasswordFlow } from "@centia-io/sdk";

export const flow = new PasswordFlow({
  host: process.env.CENTIA_HOST!,
  clientId: process.env.CENTIA_CLIENT_ID!,
  username: process.env.CENTIA_USERNAME!,
  password: process.env.CENTIA_PASSWORD!,
  database: process.env.CENTIA_DATABASE!,
});

await flow.signIn();
```

Rules:

- Single shared client instances
- No hardcoded credentials
- Env-driven config
- Use `Sql` / `createSqlBuilder` for database queries
- Use `Rpc` / `createApi` for JSON-RPC calls
- Use `CodeFlow` for browser OAuth
- Use `PasswordFlow` for server/CLI auth

---

# 7) GraphQL API

The Centia GraphQL API is auto-generated from your database schema. It is NOT part of `@centia-io/sdk`.

Endpoint: `POST https://api.centia.io/api/graphql/schema/{schema_name}`

Access methods (in priority order):

1. MCP `postGraphQL` tool (agents / provisioning)
2. `graphql-request` library (runtime app code)
3. Plain `fetch` (lightweight / no dependencies)

### Agent / MCP usage:

```ts
postGraphQL({
  schema: "my_schema",
  query: "{ getArtists { artist_id legal_name } }",
});
```

### Runtime app usage:

For JS/TS application code, use [`graphql-request`](https://github.com/graffle-js/graphql-request):

```sh
npm install graphql-request
```

```ts
import { GraphQLClient, gql } from "graphql-request";

const client = new GraphQLClient(
  `${process.env.CENTIA_HOST}/api/graphql/schema/my_schema`,
  { headers: { Authorization: `Bearer ${token}` } }
);

const query = gql`
  {
    getArtists(where: { instrument: { eq: "guitar" } }, limit: 10) {
      artist_id
      legal_name
    }
  }
`;

const data = await client.request(query);
```

### Query naming convention:

Query and mutation names are auto-generated from table names in camelCase:

| Operation | Pattern | Example |
|-----------|---------|---------|
| Select | `get[TableName]` | `getArtists` |
| Insert | `insert[TableName]` | `insertArtists` |
| Update | `update[TableName]` | `updateArtists` |
| Delete | `delete[TableName]` | `deleteArtists` |

### Filtering operators:

Comparison: `eq`, `neq`, `gt`, `gte`, `lt`, `lte`, `in`, `like`, `ilike`

Logical: `and`, `or`, `not`

```graphql
{
  getArtists(where: {
    and: [
      { legal_name: { ilike: "%Linus%" } }
      { instrument: { eq: "guitar" } }
    ]
  }) {
    artist_id
    legal_name
  }
}
```

### Pagination:

```graphql
{ getArtists(limit: 10, offset: 20) { artist_id } }
```

### Mutations:

```graphql
# Insert (single or batch via objects array)
mutation {
  insertArtists(objects: [{ legal_name: "Alice", instrument: "drums" }]) {
    artist_id
  }
}

# Update
mutation {
  updateArtists(where: { artist_id: { eq: 1 } }, data: { instrument: "bass" }) {
    artist_id
  }
}

# Delete
mutation {
  deleteArtists(where: { artist_id: { eq: 1 } }) {
    artist_id
  }
}
```

### Nested queries (via foreign keys):

```graphql
{
  getAlbums {
    title
    bands {
      name
      subgenre
    }
  }
}
```

**Introspection** is supported via standard `__schema` queries.

---

# 8) HTTP Fallback Layer

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

# 9) Authentication Model Policy

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

- Do NOT use `CENTIA_ACCESS_TOKEN`
- Do NOT embed service tokens
- Do NOT store long-lived tokens in source
- Do NOT call provisioning APIs

Browser apps must use OAuth Authorization Code Flow (PKCE) via SDK.

Required implementation:

Use `CodeFlow` from `@centia-io/sdk`.

Agents must NOT implement OAuth manually.

Example pattern:

```ts
import { CodeFlow } from "@centia-io/sdk";

const codeFlow = new CodeFlow({
  host: import.meta.env.VITE_CENTIA_HOST,
  clientId: import.meta.env.VITE_CENTIA_CLIENT_ID,
  redirectUri: window.location.origin + "/auth/callback",
});

// Handle redirect callback (call on page load)
codeFlow.redirectHandle().then((signedIn) => {
  if (signedIn) console.log("User signed in");
});

// Trigger login
function onLoginClick() {
  codeFlow.signIn();
}

// Trigger logout
function onLogoutClick() {
  codeFlow.signOut();
}
```

Token storage is SDK-managed via `CodeFlow`.

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

Allowed auth methods:

- `PasswordFlow` from `@centia-io/sdk`
- `CENTIA_ACCESS_TOKEN` env var (for MCP / HTTP fallback)

Example:

```ts
import { PasswordFlow } from "@centia-io/sdk";

const flow = new PasswordFlow({
  host: process.env.CENTIA_HOST!,
  clientId: process.env.CENTIA_CLIENT_ID!,
  username: process.env.CENTIA_USERNAME!,
  password: process.env.CENTIA_PASSWORD!,
  database: process.env.CENTIA_DATABASE!,
});

await flow.signIn();
```

Credentials stored in:

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

# 10) Auth Responsibility Split

| Context | Auth Method | SDK Class |
|--------|--------------|-----------|
| Browser app | OAuth Code Flow (PKCE) | `CodeFlow` |
| Browser signup | OAuth redirect | `SignUp` |
| Backend app | Username/password | `PasswordFlow` |
| Provisioning | Access token / password | `PasswordFlow` / MCP / HTTP |
| CLI tools | Username/password | `PasswordFlow` |

---

# 11) OpenAPI Access Policy

Preferred sources:

1. Local file: openapi/openapi.json  
2. URL: CENTIA_OPENAPI_URL  
3. User-provided JSON  

If allowed, fetch automatically:

```sh
mkdir -p openapi
if [ -n "$CENTIA_OPENAPI_URL" ] && [ ! -f "openapi/openapi.fetched.json" ]; then
  curl -fsSL \
    -H "Authorization: Bearer $CENTIA_ACCESS_TOKEN" \
    "$CENTIA_OPENAPI_URL" -o openapi/openapi.fetched.json
fi
```

OpenAPI is the contract for all endpoints it describes.

---

# 12) Documentation Access Policy

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

# 13) Safety Rules (Provisioning)

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

# 14) Project Structure Standard

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

# 15) Code Quality Rules

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

# 16) Delivery Requirements

Every generated solution must include:

- Setup steps
- Env vars
- Install + run commands
- SDK usage explanation
- Provisioning steps
- Validation steps
- HTTP calls made (no secrets)

---

# 17) Available MCP Tools Reference

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

# 18) Environment Variables

| Variable | Context | Required | Description |
|----------|---------|----------|-------------|
| `CENTIA_HOST` | Server / provisioning | Yes | Centia API host (e.g. `https://api.centia.io`) |
| `CENTIA_CLIENT_ID` | Server / provisioning | Yes | OAuth client ID |
| `CENTIA_USERNAME` | Server / provisioning | Yes | Database username for `PasswordFlow` |
| `CENTIA_PASSWORD` | Server / provisioning | Yes | Database password for `PasswordFlow` |
| `CENTIA_DATABASE` | Server / provisioning | Yes | Parent database name |
| `CENTIA_ACCESS_TOKEN` | MCP / HTTP fallback | No | Pre-issued access token (alternative to `PasswordFlow`) |
| `CENTIA_OPENAPI_URL` | Development | No | URL to fetch OpenAPI spec from |
| `VITE_CENTIA_HOST` | Browser apps (Vite) | Yes | Centia API host for frontend |
| `VITE_CENTIA_CLIENT_ID` | Browser apps (Vite) | Yes | OAuth client ID for frontend |

Never commit `.env` files containing secrets. Provide a `.env.example` with placeholder values.

---

# 19) Agent Self-Check

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
