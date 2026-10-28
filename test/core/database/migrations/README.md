# Migration Tests

The retained v1 and current v2 snapshots live in `drift_schemas/app_database/`.
`generated/` is produced by the pinned Drift schema generator, and supplies the
actual historical v1 schema independently of the current table definitions.

`lifecycle_migration_test.dart` tests the production v1-to-v2 upgrade with active
and archived items, null/zero/positive counts, legacy six-area and custom catalogs,
relocated items, and an empty catalog after deleted defaults. It compares every
stored household column and existing autoincrement sequence, validates the final
schema and foreign keys, and checks that no lifecycle history is fabricated.

File-backed fixtures cover close/reopen, controlled mid-migration DDL failure,
complete rollback of schema/version, preserved household data, and a successful
retry after removing only the deliberately injected test collision. A separate
fixture verifies that pre-existing foreign-key corruption fails closed without
silently repairing or deleting household facts. Tests use only isolated fixtures.

Run `flutter test test/core/database` and the established `tool/quality.sh` gate.
Generation commands and the database/domain validation split are documented in
`drift_schemas/README.md`. Application lifecycle commands and concurrent command
revalidation belong to the next work unit.
