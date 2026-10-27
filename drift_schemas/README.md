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
  - First-launch default seed: 6 solo-living areas (`Kitchen`, `Bathroom`, `Pantry`, `Living Room`, `Bedroom`, `Storage`) with `is_system = true`.

## Migration Policy

1. `schemaVersion` starts at 1.
2. The schema snapshot is stored in `app_database/drift_schema_v1.json`.
3. Migration-test infrastructure is established before `schemaVersion` can advance beyond 1.
4. Every future version increment (v1 -> v2+) must include representative pre-migration test data, migration execution, data-preservation assertions, and foreign-key integrity verification.
5. Production migration failures must never silently wipe or reset user household data.
