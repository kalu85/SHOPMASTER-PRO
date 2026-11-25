# SHOPMASTER PRO — Android + Web + Windows shared-data architecture

## Confirmed requirement
All three clients use the same shop data. Changes made on one signed-in client become visible to the other clients after synchronization.

## Architecture
- One Flutter application with Android, Web and Windows targets.
- Supabase Auth and PostgreSQL provide shared identity and cloud data.
- Local-first storage remains on every platform.
- A sync service queues local changes, uploads them when online, downloads remote changes and applies them transactionally.
- Shop-level tenancy is enforced by PostgreSQL row-level security (RLS).
- Soft deletes and server revisions allow tombstones and ordered synchronization.
- Attachment metadata syncs with records; file bytes require a private object-storage bucket and signed access URLs.

## Compatibility finding
The current app directly uses sqflite, path_provider, dart:io, flutter_secure_storage, file_picker and the native camera scanner. These native paths cannot be used unchanged in a browser. Android backup currently copies a SQLite file directly. Add platform-specific adapters behind repository interfaces; preserve Android behavior while adding browser and Windows storage. Camera scanning, file selection, printing, secure credential storage and backup need platform-specific implementations or graceful fallbacks.

## Cloud schema foundation
The migration in supabase/migrations/0001_shared_shop_data.sql creates:
- shops and shop_members for ownership and team access;
- shop_records for versioned, tenant-scoped records mapped from existing SQLite entities;
- RLS policies to prevent cross-shop access;
- server-managed update timestamps and revisions.

This migration is not a live connected backend. It must be applied to a Supabase project before clients can connect.

## Sync rules to implement
1. Commit every local mutation and a durable outbox entry in the same local transaction.
2. Upload outbox entries in dependency-safe order (products, parties and accounts before dependent invoices and transactions).
3. Use (shop_id, entity, record_id) as the idempotent cloud key and retain soft-delete tombstones.
4. Pull by server timestamp plus a stable tie-breaker; never trust device clocks.
5. Apply a remote update locally only when its revision is newer than the acknowledged local revision.
6. Surface concurrent edits as conflicts or apply an explicitly documented rule. Do not silently overwrite financial records with last-write-wins.
7. Sync invoices, invoice items, stock movements, serial status and account transactions as coherent business operations.
8. Preview the initial local-data import and require explicit owner confirmation before uploading existing data.
9. Ship only the Supabase publishable/anon key. Never ship the service-role key. RLS is mandatory.
10. Failed sync must preserve local data and retry idempotently.

## Delivery sequence
1. Shared cloud schema and tenant security (this PR).
2. Platform storage abstraction and Web/Windows build compatibility without changing Android behavior.
3. Authentication, shop creation/joining and secure session persistence.
4. Durable outbox, pull cursor, conflict handling and sync status UI.
5. Owner-approved first-time Android data migration to cloud.
6. Web and Windows clients connected to the same shop.
7. End-to-end tests: Android sale visible on Web/Windows; Windows stock update visible on Android; offline create syncs after reconnect without duplicates.

## Setup still required
A Supabase project must be created and the migration applied. Project URL and publishable key will be supplied as build-time configuration; no credentials belong in source control. Until configured, cloud sharing cannot activate. This change does not upload any existing local shop data.
