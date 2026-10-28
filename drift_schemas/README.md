# Drift Schema Snapshots

This directory stores versioned Drift schema snapshots.

## Schema Version History

- **v1 (M2.1-R / M2.1-FINAL)**: `drift_schemas/app_database/drift_schema_v1.json`
  - Approved incremental tables: `areas` and `items`.
  - SQLite foreign key integrity enforced: `items.area_id REFERENCES areas(id) ON DELETE RESTRICT ON UPDATE CASCADE`.
  - Declarative `@TableIndex.sql` captures in schema snapshot:
    - `idx_areas_name_active ON areas(LOWER(name)) WHERE is_archived = 0` (unique)
    - `idx_areas_order ON areas(display_order) WHERE is_archived = 0`
    - `idx_items_area ON items(area_id, is_archived)`
    - `idx_items_status ON items(stock_status, is_archived)`
  - Columns and types:
    - `areas.is_system` (`bool`, default false) marks default seeded areas vs user-created areas.
    - `items.package_count` (`int?`, check `>= 0`) replaces floating-point quantities.
    - Canonical `behavior_profile` check (`replenishable`, `countableReplenishable`, `durable`).
    - Factual `stock_status` check (`inStock`, `outOfStock`).
  - Table-level SQLite `CHECK` constraints:
    - Factual consistency: `CHECK (package_count IS NULL OR (package_count > 0 AND stock_status = 'inStock') OR (package_count = 0 AND stock_status = 'outOfStock'))`.
    - Durable items restriction: `CHECK (behavior_profile != 'durable' OR package_count IS NULL)`.
  - Original v1 first-launch seed contained six areas. Current first-launch seeding uses Kitchen, Bathroom, Bedroom and Living Room; existing catalogs are never reseeded.

- **v2**: `app_database/drift_schema_v2.json`
  - Adds only `lifecycle_cycles` and `lifecycle_checkpoints`; v1 tables and indexes are unchanged.
  - Canonical calendar dates use `YYYY-MM-DD` text and the existing LocalDate range (1900-2200), with calendar-validity checks.
  - A partial unique index enforces one unfinished cycle per item. Completed cycles may overlap, and same-day Start/Finish is valid.
  - Checkpoints support `aboutHalf` / `nearlyFinished`, unique per cycle and kind.
  - Item-to-cycle and cycle-to-checkpoint foreign keys cascade on explicit permanent deletion. Area-to-item deletion remains restrictive.
  - No duration, prediction, confidence or generic event ledger is persisted.

## Validation Responsibilities

SQLite enforces row-local date validity/ordering, foreign keys and uniqueness.
Lifecycle commands must additionally validate eligible/active items, effective dates
against the injected current LocalDate, checkpoint dates against their parent cycle,
and explicit reconciliation when corrections invalidate checkpoints. These are
transaction-time domain checks for the application work unit; a row CHECK does not
inspect a parent table. The existing item-management behavior is unchanged.

## Migration Policy

1. `schemaVersion` starts at 1.
2. Retain each immutable version snapshot in `app_database/`; the current schema is v2.
3. Migration-test infrastructure is established before `schemaVersion` can advance beyond 1.
4. Every future version increment (v1 -> v2+) must include representative pre-migration test data, migration execution, data-preservation assertions, and foreign-key integrity verification.
5. Production migration failures must never silently wipe or reset user household data.

## Generation and Verification

Using the pinned Drift tools:

```sh
dart run build_runner build
dart run drift_dev make-migrations --no-test
dart run drift_dev schema generate drift_schemas/app_database test/core/database/migrations/generated
flutter test test/core/database
```

`app_database.steps.dart` fixes the v1-to-v2 migration to its target snapshot.
The upgrade creates only the new tables/indexes inside one transaction, including
the schema-version update and foreign-key integrity check. Errors propagate;
there is no reset, destructive fallback, legacy-row rewrite or upgrade reseeding.
