# Migration Tests

Drift Schema v1 baseline is established in `drift_schemas/app_database/drift_schema_v1.json`.

Per M2.1 scope:
- Step-by-step migration infrastructure is ready for future evolutions.
- No synthetic or fabricated v1-to-v2 migration is introduced before genuine schema changes are needed.
- Every future schema evolution after version 1 must include representative pre-migration test data, migration execution, data-preservation assertions, and foreign-key integrity verification.
