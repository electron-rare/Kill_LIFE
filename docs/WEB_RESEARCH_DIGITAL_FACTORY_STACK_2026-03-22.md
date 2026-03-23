# Web Research — Digital Factory Stack References

Date: 2026-03-22
Scope: lightweight reference set to position `Kill_LIFE` against reusable open-source or official stack patterns

## 1. Selected references

### Odoo PLM

Source:
- [Odoo PLM](https://www.odoo.com/app/plm)

Useful signal:
- strong `PLM` pattern around engineering change orders, document management, and versioning tied to manufacturing

Inference for `Kill_LIFE`:
- useful as a reference for the `PLM -> MES` handoff discipline
- not a direct reuse target for runtime orchestration

### ERPNext Manufacturing

Sources:
- [ERPNext Manufacturing](https://docs.frappe.io/erpnext/v12/user/manual/en/manufacturing)
- [ERPNext Bill of Materials](https://docs.frappe.io/erpnext/user/manual/en/bill-of-materials)
- [ERPNext Manufacturing Dashboard](https://docs.frappe.io/erpnext/v14/user/manual/en/manufacturing/manufacturing-dashboard)

Useful signal:
- concrete example of an integrated `ERP + MES + BOM + dashboard` loop

Inference for `Kill_LIFE`:
- relevant as a model for turning `Ops` priorities into executable work objects and dashboards
- useful conceptually for the `ERP / L'electronrare Ops` layer, not as a runtime replacement

### OpenBoxes

Sources:
- [OpenBoxes GitHub](https://github.com/openboxes/openboxes)
- [OpenBoxes website](https://openboxes.com/)
- [OpenBoxes features](https://openboxes.com/features/)

Useful signal:
- good open-source reference for `WMS` and supply-chain visibility
- emphasizes multi-location stock tracking, audit trails, and operational visibility

Inference for `Kill_LIFE`:
- useful for the `artifact / log / dataset / handoff` indexing mindset
- a conceptual reference for `WMS`, not a direct drop-in for `Kill_LIFE`

### Node-RED

Sources:
- [Node-RED Documentation](https://nodered.org/docs)
- [Node-RED Flow structure](https://nodered.org/docs/developing-flows/flow-structure)
- [Node-RED Documenting flows](https://nodered.org/docs/developing-flows/documenting-flows)

Useful signal:
- strong reference for low-friction operational flow design, flow documentation, and readable execution graphs

Inference for `Kill_LIFE`:
- useful for documenting and structuring operator flows and dispatch flows
- especially relevant for `MES` and `DCS` surface simplification

## 2. Reading for Kill_LIFE

Current best-fit reading:

- `PLM`: closer to `Odoo PLM` discipline than to ad hoc docs
- `ERP`: closer to an `ERPNext` governance mindset, but leaner and ops-first
- `WMS`: closer to `OpenBoxes` in the sense of auditable operational storage and retrieval
- `MES + DCS`: closer to `Node-RED` style flow discipline, but with shell/TUI, SSH mesh, and runtime checks instead of low-code nodes

## 3. Recommendation

Do not try to import a full external platform into `Kill_LIFE`.

Recommended path:

1. keep `Kill_LIFE` as the execution and continuity layer
2. formalize `ERP / L'electronrare Ops`
3. strengthen `WMS` indexing and retrieval
4. borrow documentation and flow-structure discipline from these references

## 4. Next useful research step

Potential next pass:
- compare `Odoo / ERPNext` change governance vs the current `Ops -> Kill_LIFE` lot model
- compare `OpenBoxes` audit trail patterns vs current `artifacts/` conventions
- compare `Node-RED` flow legibility patterns vs current cockpit TUI surface

## 5. Additional references for WMS and cockpit indexing

### MLflow Artifact Store

Source:
- https://mlflow.org/docs/latest/self-hosting/architecture/artifact-store/

Useful signal:
- clear separation between tracking metadata and artifact storage
- useful for thinking about `Kill_LIFE` as `registry contract + filesystem artifacts`

Inference for `Kill_LIFE`:
- keep metadata light and local
- avoid turning `artifacts/` into an unindexed dump

### Dagster Data Catalog / Software-defined assets

Sources:
- https://dagster.io/platform-overview/data-catalog
- https://dagster.io/blog/software-defined-assets

Useful signal:
- an asset catalog is most useful when ownership and dependency context stay close to the assets

Inference for `Kill_LIFE`:
- the WMS index should stay close to `specs/contracts/` and `artifacts/`
- explicit `owner_agent` and `consumer_layer` metadata is the right direction

### DVC Data Registry

Source:
- https://doc.dvc.org/use-cases/data-registry

Useful signal:
- strong reference for addressable and versioned data registry patterns

Inference for `Kill_LIFE`:
- especially relevant for dataset and fine-tune staging under the `WMS` layer

### Backstage Software Catalog

Sources:
- https://backstage.io/docs/features/software-catalog/
- https://backstage.io/docs/overview/what-is-backstage

Useful signal:
- strong model for a centralized catalog of ownership and metadata across software components

Inference for `Kill_LIFE`:
- relevant for the future cockpit layer index
- not as a platform to import, but as a pattern for `module -> owner -> metadata -> links`

### Rundeck Runbook Automation

Sources:
- https://docs.rundeck.com/docs/
- https://docs.rundeck.com/docs/about/introduction.html

Useful signal:
- good reference for runbook execution, operator workflows, and distributed automation across environments

Inference for `Kill_LIFE`:
- relevant for `MES + DCS` convergence and for exposing a more explicit runbook-oriented cockpit entrypoint
