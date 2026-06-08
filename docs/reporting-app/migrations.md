# Database migrations

OSCER is open source. A downstream deployment keeps its own copy and
periodically syncs upstream OSCER changes in, a process that ends with `bin/rails
db:migrate` against the deployment's own production database, which may be years
of versions behind and hold a dataset that looks nothing like Nava's.

That replay model is the reason this convention exists. A migration that works
fine on Nava's environments can still fail when an external deployment replays
it later: it might reference a model class that has since been renamed, or
couple a schema change to a data backfill that assumes a particular
intermediate state. The rules below keep migrations replayable and recoverable
for downstream deployments.

## The convention

These rules apply to **new** migrations. Migrations that predate the convention
are grandfathered (see [Audit of existing
migrations](#audit-of-existing-migrations)); they are not a backlog to rewrite.

### 1. Separate schema changes from data changes

Schema-only migrations (DDL) and data-only migrations (DML) live in separate
files. A common multi-step change such as "add a column, backfill it, drop the
old column" becomes a sequence of separate migrations, not one:

```
20260101120000_add_reasons_to_determinations.rb       # DDL: add_column :reasons
20260101120001_backfill_determination_reasons.rb      # DML: copy reason -> reasons
20260101120002_remove_reason_from_determinations.rb   # DDL: remove_column :reason
```

Separation gives a deployment a controlled order and a recovery point: if the
backfill fails against an unexpected dataset, the schema change has already
committed cleanly and the data step can be re-run or fixed in isolation, rather
than rolling back a half-applied combined migration.

### 2. Prefer reversible migrations

Use `change` when Rails can auto-reverse the operation. When it cannot, define
both `up` and `down`. Two common operations are **not** auto-reversible and
need explicit help:

- `drop_table` needs a block describing the table so it can be recreated on rollback.
- `remove_column` needs the column type (`remove_column :table, :col, :string`) so it can be re-added.

```ruby
# Reversible: each operation gives Rails what it needs to undo it
def change
  remove_column :activities, :note, :string  # type lets Rails re-add the column on rollback
  drop_table :legacy_widgets do |t|           # block lets Rails recreate the table on rollback
    t.string :name
    t.timestamps
  end
end
```

A `down` may be genuinely impractical for a destructive data migration (for
example, collapsing an array back to a scalar loses information). Document the
exception in the migration with a comment and define a `down` that restores the
schema even if it cannot restore every value.

### 3. No model-class references inside migrations

A migration must replay correctly on a fresh deployment install years from now,
when the app-level model it once referenced may have been renamed or deleted.
Referencing `Activity` or `ReviewActivityReportTask` inside a migration ties
that historical migration to today's code; a future rename breaks the replay at
constant-lookup time.

Use raw SQL, or a migration-local anonymous ActiveRecord class scoped to the table:

```ruby
# Bad: depends on the Activity constant still existing at replay time
Activity.where(type: nil).update_all(type: "WorkActivity")

# Good: raw SQL, no app-code dependency
execute <<~SQL
  UPDATE activities SET type = 'WorkActivity' WHERE type IS NULL
SQL

# Good: migration-local class, decoupled from app code
klass = Class.new(ActiveRecord::Base) { self.table_name = "activities" }
klass.where(type: nil).update_all(type: "WorkActivity")
```

### 4. Document required upgrade stops

When a data migration assumes a specific intermediate state (for example, "the
backfill only works if you are already on `v2026.2.0`"), an implementer who
jumps several versions at once can land in that state without the migration
that produced it. Call out the required stop, flagged as a migration note, in
the release notes for the gating version.

OSCER versions are CalVer (`v2026.N.0`), not SemVer, so there is no "major
version bump" to signal a breaking upgrade. Required upgrade stops are how a
breaking migration boundary is communicated instead.

### 5. Deployment-owned migrations and `db/schema.rb`

Deployments add their own migrations for deployment-specific schema (for
example, adding a `county` column). These are files OSCER itself never ships,
and Rails migration filenames are timestamp-prefixed, so they don't collide by
name with OSCER's migrations. A `*_custom_*` marker in the filename (for
example, `20260301120000_custom_add_county_to_members.rb`) is a *recommended
naming convention* for keeping deployment migrations visually distinct from
OSCER's; configure your upstream-sync process to preserve these
deployment-owned files.

`db/schema.rb` is the one real friction point. Rails regenerates it from the
full migration history, so after a sync that brings in new OSCER migrations, the
schema file may not reflect your deployment-added tables. The fix is the same
however your sync handles the file: run `bin/rails db:migrate` afterward, which
regenerates `schema.rb` from the complete migration history (OSCER's migrations
plus your own). Whatever version of `schema.rb` the sync leaves in place does
not matter as long as you migrate after. (Deployments that sync via a git merge
can add a `db/schema.rb merge=ours` rule to `.gitattributes`, with
`git config merge.ours.driver true`, so git auto-keeps their version; then
migrate.)

## Migration and code-change sequencing

This is an OSCER development convention for anyone contributing to OSCER. It is
not enforced by tooling. We recommend downstream deployments follow the same
pattern for their own migrations, but it is not a requirement; a deployment is
free to adopt whatever workflow fits its team.

OSCER keeps schema migrations in their own pull request, separate from the
application code that depends on them. The payoff is focused review of schema
changes on their own, and the ability to revert a buggy feature PR without
unwinding a schema change that may already hold data.

The landing order follows expand/contract, keyed to whether the change adds or
removes capability:

- **Additive (expand)** changes (`add_column`, a new table, `add_index`): the
  migration lands first, then the code that uses the new schema. Code cannot
  reference a column that does not exist yet.
- **Subtractive (contract)** changes (`remove_column`, `drop_table`): the code
  that stops referencing the column or table lands first, then the migration
  removes it. During a rolling deploy the previous version is still running, so
  dropping a column that live code still reads breaks those instances.

Renames, column-type changes, and adding a `NOT NULL` constraint are multi-step
cases of the same principle: expand the new shape, backfill, switch the code
over, then contract the old shape.

## Fresh setup vs. incremental migration

A fresh database setup and an incremental migration use different database entry
points, and the distinction matters for replay safety:

| Path | Command | Behavior |
|------|---------|----------|
| Fresh setup / boot | `db:prepare` (`bin/docker-entrypoint`, `bin/setup`) | On a fresh DB: creates it and loads `db/schema.rb`, then seeds (never replays the full migration history). On an existing DB: applies only pending migrations (equivalent to `db:migrate`). |
| Incremental migrate | `db:migrate` (`make db-migrate`, `bin/db-migrate`) | Applies only pending migrations incrementally. |
| Full local recreate | `db:reset` (`make db-reset`) | Drops and recreates from `db/schema.rb`, then reseeds. |

This split is deliberate: a fresh deployment loads the current schema in one
shot from `db/schema.rb` rather than replaying every historical migration, so
the grandfathered pre-convention migrations are never executed on a new
install. Migration-replay safety therefore matters on the **incremental-migration
path only**, which narrows the surface this convention has to protect. When adding a new
database entry point (a deploy script, a Dockerfile stage), confirm it uses
`db:prepare`/`db:schema:load` for fresh setup and `db:migrate` only for
incremental migration; do not introduce a fresh-setup path that replays the
full migration history with `db:migrate`.

## Enforcement

Several `rubocop-rails` cops are enabled in `.rubocop.yml`. They apply to new
migrations; pre-convention violations of `Rails/ReversibleMigration` are
grandfathered in `.rubocop_todo.yml` (documented exceptions, not a backlog to
burn down).

Reversibility (convention rule 2):

- [`Rails/ReversibleMigration`](https://docs.rubocop.org/rubocop-rails/latest/cops_rails.html#railsreversiblemigration) flags `change`-method operations that cannot be auto-reversed (such as `drop_table` without a block).
- [`Rails/ReversibleMigrationMethodDefinition`](https://docs.rubocop.org/rubocop-rails/latest/cops_rails.html#railsreversiblemigrationmethoddefinition) requires every migration to define `change`, or both `up` and `down`.

Additional safety and hygiene (no pre-existing violations, so enabled without grandfathering):

- [`Rails/NotNullColumn`](https://docs.rubocop.org/rubocop-rails/latest/cops_rails.html#railsnotnullcolumn) flags adding a `null: false` column without a default, which fails against a table that already holds rows (the same data-safety concern behind rule 1).
- [`Rails/AddColumnIndex`](https://docs.rubocop.org/rubocop-rails/latest/cops_rails.html#railsaddcolumnindex) catches `add_column(..., index: true)`, where the `index` option is silently ignored and no index is actually created.
- [`Rails/DangerousColumnNames`](https://docs.rubocop.org/rubocop-rails/latest/cops_rails.html#railsdangerouscolumnnames) flags column names that overwrite ActiveRecord methods.
- [`Rails/MigrationClassName`](https://docs.rubocop.org/rubocop-rails/latest/cops_rails.html#railsmigrationclassname) requires the migration class name to match its filename.

Rules 1 (schema/data separation) and 3 (no model-class references) are **not**
enforced by a cop. No `rubocop-rails` or `rubocop-migration` cop covers either,
and `strong_migrations` is built for runtime zero-downtime checks rather than
the structural source patterns these rules describe. They are enforced by PR
review and this document. If violations recur, a project-specific custom RuboCop
cop (static analysis over the migration body, with a model/constant allowlist)
is a better fit than a runtime gem; revisit then.

## Audit of existing migrations

Audited against the 55 OSCER-authored migrations in `db/migrate/` as of this
convention (61 files total; the other 6 are framework-generated and out of
scope, see Notes).
Disposition for every violation is **grandfather**: each has already run on
Nava environments without incident, fresh installs load `db/schema.rb` rather
than replaying them, and rewriting historical migrations risks worse problems
than it solves. The convention applies forward.

| Migration | Convention(s) violated | Disposition |
|-----------|------------------------|-------------|
| `20251021141137_convert_activity_to_sti.rb` | 1 (mixed schema+data), 3 (references `Activity`) | Grandfather |
| `20251031214909_update_determination_reasons.rb` | 1 (add column, backfill, drop old column in one `up`) | Grandfather |
| `20260305120000_add_uploader_constraint_by_source_type.rb` | 1 (data `UPDATE` then `ADD CONSTRAINT` in one `up`) | Grandfather |
| `20260522182945_add_application_form_id_to_strata_tasks.rb` | 1 (mixed schema+data), 3 (references `ReviewExemptionClaimTask`, `ReviewActivityReportTask`, and `application_form_class`) | Grandfather |
| `20251009120656_remove_activity_report_case.rb` | 2 (`drop_table` without block) | Grandfather (`.rubocop_todo.yml`) |
| `20251010203944_remove_exemption_case.rb` | 2 (`drop_table` without block) | Grandfather (`.rubocop_todo.yml`) |
| `20251020141545_add_unique_indices_on_application_forms.rb` | 2 (`remove_column` without type) | Grandfather (`.rubocop_todo.yml`) |

Notes:

- `20250310140241_add_service_name_to_active_storage_blobs.active_storage.rb` mixes DDL and a data update but is **framework-generated** by the Active Storage engine (`.active_storage.rb` suffix). It is out of scope for this convention, which governs OSCER-authored migrations.
- The `.flex.rb` migrations (from the Strata SDK) are likewise framework-generated and out of scope, on the same basis as the Active Storage migration above.
- `20250903020916_add_case_type_values_to_flex_tasks.rb` looks like a model reference on a grep, but the reference is commented out; the migration is an empty `change` (a no-op). Not a violation.
- `20251009164541_migrate_reporting_period_to_reporting_periods.rb` is the model the convention points to: a pure data migration using raw SQL only, no model references, with both `up` and `down` defined.
