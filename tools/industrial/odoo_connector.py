#!/usr/bin/env python3
"""Odoo Manufacturing connector — REST API client for MRP module.

Provides functions to interact with Odoo's Manufacturing module:
- Create Manufacturing Orders (MO)
- List/search work orders
- Update production status
- Read Bill of Materials (BoM)
- Get production analytics

Usage:
    export ODOO_URL=https://mycompany.odoo.com
    export ODOO_DB=mydb
    export ODOO_USERNAME=admin
    export ODOO_PASSWORD=admin
    python tools/industrial/odoo_connector.py --list-mo
    python tools/industrial/odoo_connector.py --create-mo --product "Widget A" --qty 100

Can also be imported as a library:
    from odoo_connector import OdooMRP
    odoo = OdooMRP("https://mycompany.odoo.com", "mydb", "admin", "admin")
    orders = odoo.list_manufacturing_orders()
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from typing import Any

try:
    import requests

    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

ODOO_URL = os.getenv("ODOO_URL", "http://localhost:8069")
ODOO_DB = os.getenv("ODOO_DB", "odoo")
ODOO_USERNAME = os.getenv("ODOO_USERNAME", "admin")
ODOO_PASSWORD = os.getenv("ODOO_PASSWORD", "admin")


# ---------------------------------------------------------------------------
# Odoo JSON-RPC client
# ---------------------------------------------------------------------------

class OdooRPC:
    """Low-level Odoo JSON-RPC client."""

    def __init__(self, url: str, db: str, username: str, password: str):
        self.url = url.rstrip("/")
        self.db = db
        self.username = username
        self.password = password
        self.uid: int | None = None
        self._req_id = 0

    def _call(self, service: str, method: str, *args: Any) -> Any:
        if not HAS_REQUESTS:
            raise RuntimeError("requests library not installed. pip install requests")
        self._req_id += 1
        payload = {
            "jsonrpc": "2.0",
            "method": "call",
            "id": self._req_id,
            "params": {
                "service": service,
                "method": method,
                "args": list(args),
            },
        }
        resp = requests.post(
            f"{self.url}/jsonrpc",
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=30,
        )
        resp.raise_for_status()
        result = resp.json()
        if "error" in result:
            err = result["error"]
            msg = err.get("data", {}).get("message", err.get("message", str(err)))
            raise RuntimeError(f"Odoo RPC error: {msg}")
        return result.get("result")

    def authenticate(self) -> int:
        """Authenticate and return uid."""
        self.uid = self._call("common", "authenticate", self.db, self.username, self.password, {})
        if not self.uid:
            raise RuntimeError(f"Authentication failed for {self.username}@{self.db}")
        return self.uid

    def execute(self, model: str, method: str, *args: Any, **kwargs: Any) -> Any:
        """Execute a method on an Odoo model."""
        if self.uid is None:
            self.authenticate()
        return self._call(
            "object", "execute_kw",
            self.db, self.uid, self.password,
            model, method,
            list(args),
            kwargs,
        )

    def search_read(
        self, model: str, domain: list | None = None,
        fields: list[str] | None = None, limit: int = 100, order: str = ""
    ) -> list[dict]:
        """Search and read records."""
        kwargs: dict[str, Any] = {"limit": limit}
        if fields:
            kwargs["fields"] = fields
        if order:
            kwargs["order"] = order
        return self.execute(model, "search_read", domain or [], **kwargs)

    def create(self, model: str, values: dict) -> int:
        """Create a record, return its ID."""
        return self.execute(model, "create", [values])

    def write(self, model: str, record_ids: list[int], values: dict) -> bool:
        """Update records."""
        return self.execute(model, "write", record_ids, values)


# ---------------------------------------------------------------------------
# MRP-specific high-level client
# ---------------------------------------------------------------------------

class OdooMRP:
    """High-level Odoo Manufacturing (MRP) connector."""

    def __init__(self, url: str = "", db: str = "", username: str = "", password: str = ""):
        self.rpc = OdooRPC(
            url=url or ODOO_URL,
            db=db or ODOO_DB,
            username=username or ODOO_USERNAME,
            password=password or ODOO_PASSWORD,
        )

    # --- Manufacturing Orders ---

    def list_manufacturing_orders(
        self,
        state: str | None = None,
        limit: int = 50,
    ) -> list[dict]:
        """List manufacturing orders, optionally filtered by state.

        States: draft, confirmed, progress, done, cancel
        """
        domain: list = []
        if state:
            domain.append(("state", "=", state))
        return self.rpc.search_read(
            "mrp.production",
            domain=domain,
            fields=[
                "name", "product_id", "product_qty", "product_uom_id",
                "state", "date_start", "date_finished",
                "origin", "priority",
            ],
            limit=limit,
            order="date_start desc",
        )

    def create_manufacturing_order(
        self,
        product_name: str,
        qty: float,
        bom_id: int | None = None,
        origin: str = "",
        notes: str = "",
    ) -> dict:
        """Create a new Manufacturing Order.

        Looks up product by name, finds its BoM, and creates the MO.
        """
        # Find product
        products = self.rpc.search_read(
            "product.product",
            domain=[("name", "ilike", product_name)],
            fields=["id", "name", "uom_id"],
            limit=1,
        )
        if not products:
            raise ValueError(f"Product not found: {product_name}")
        product = products[0]

        # Find BoM if not specified
        if not bom_id:
            boms = self.rpc.search_read(
                "mrp.bom",
                domain=[("product_tmpl_id.name", "ilike", product_name)],
                fields=["id", "product_tmpl_id"],
                limit=1,
            )
            if boms:
                bom_id = boms[0]["id"]

        values: dict[str, Any] = {
            "product_id": product["id"],
            "product_qty": qty,
            "product_uom_id": product["uom_id"][0] if isinstance(product.get("uom_id"), (list, tuple)) else 1,
        }
        if bom_id:
            values["bom_id"] = bom_id
        if origin:
            values["origin"] = origin
        if notes:
            values["note"] = notes

        mo_id = self.rpc.create("mrp.production", values)
        return {"id": mo_id, "product": product["name"], "qty": qty, "status": "created"}

    def confirm_manufacturing_order(self, mo_id: int) -> dict:
        """Confirm a draft manufacturing order."""
        self.rpc.execute("mrp.production", "action_confirm", [mo_id])
        return {"id": mo_id, "status": "confirmed"}

    def mark_done(self, mo_id: int, qty_produced: float | None = None) -> dict:
        """Mark a manufacturing order as done."""
        if qty_produced is not None:
            self.rpc.write("mrp.production", [mo_id], {"qty_produced": qty_produced})
        self.rpc.execute("mrp.production", "button_mark_done", [mo_id])
        return {"id": mo_id, "status": "done"}

    # --- Work Orders ---

    def list_work_orders(
        self,
        production_id: int | None = None,
        state: str | None = None,
        limit: int = 50,
    ) -> list[dict]:
        """List work orders, optionally filtered by MO or state."""
        domain: list = []
        if production_id:
            domain.append(("production_id", "=", production_id))
        if state:
            domain.append(("state", "=", state))
        return self.rpc.search_read(
            "mrp.workorder",
            domain=domain,
            fields=[
                "name", "production_id", "workcenter_id", "state",
                "date_start", "date_finished", "duration", "qty_produced",
            ],
            limit=limit,
            order="date_start desc",
        )

    def start_work_order(self, wo_id: int) -> dict:
        """Start a work order."""
        self.rpc.execute("mrp.workorder", "button_start", [wo_id])
        return {"id": wo_id, "status": "started"}

    def finish_work_order(self, wo_id: int) -> dict:
        """Finish a work order."""
        self.rpc.execute("mrp.workorder", "button_finish", [wo_id])
        return {"id": wo_id, "status": "finished"}

    # --- Bill of Materials ---

    def list_bom(self, product_name: str | None = None, limit: int = 50) -> list[dict]:
        """List Bills of Materials."""
        domain: list = []
        if product_name:
            domain.append(("product_tmpl_id.name", "ilike", product_name))
        return self.rpc.search_read(
            "mrp.bom",
            domain=domain,
            fields=[
                "product_tmpl_id", "product_qty", "type",
                "bom_line_ids", "operation_ids",
            ],
            limit=limit,
        )

    def get_bom_details(self, bom_id: int) -> dict:
        """Get full BoM with lines (components)."""
        bom = self.rpc.search_read(
            "mrp.bom",
            domain=[("id", "=", bom_id)],
            fields=["product_tmpl_id", "product_qty", "type", "bom_line_ids"],
            limit=1,
        )
        if not bom:
            raise ValueError(f"BoM not found: {bom_id}")

        lines = self.rpc.search_read(
            "mrp.bom.line",
            domain=[("bom_id", "=", bom_id)],
            fields=["product_id", "product_qty", "product_uom_id"],
        )

        return {**bom[0], "components": lines}

    # --- Analytics ---

    def production_summary(self, days_back: int = 30) -> dict:
        """Get production analytics summary."""
        from datetime import timedelta
        cutoff = (datetime.now(timezone.utc) - timedelta(days=days_back)).strftime("%Y-%m-%d")

        orders = self.rpc.search_read(
            "mrp.production",
            domain=[("date_start", ">=", cutoff)],
            fields=["state", "product_qty", "date_start", "date_finished"],
            limit=1000,
        )

        states: dict[str, int] = {}
        total_qty = 0
        completed = 0
        for o in orders:
            s = o.get("state", "unknown")
            states[s] = states.get(s, 0) + 1
            total_qty += o.get("product_qty", 0)
            if s == "done":
                completed += 1

        return {
            "period_days": days_back,
            "total_orders": len(orders),
            "by_state": states,
            "total_quantity": total_qty,
            "completion_rate": round(completed / max(len(orders), 1) * 100, 1),
        }

    # --- Update production status ---

    def update_production(self, mo_id: int, values: dict) -> dict:
        """Generic update of a manufacturing order's fields.

        Common fields: qty_produced, date_start, date_finished, origin, priority
        """
        self.rpc.write("mrp.production", [mo_id], values)
        return {"id": mo_id, "updated_fields": list(values.keys()), "status": "updated"}


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="Odoo Manufacturing Connector")
    parser.add_argument("--url", default="", help=f"Odoo URL (default: {ODOO_URL})")
    parser.add_argument("--db", default="", help=f"Database name (default: {ODOO_DB})")
    parser.add_argument("--user", default="", help=f"Username (default: {ODOO_USERNAME})")
    parser.add_argument("--password", default="", help="Password")

    sub = parser.add_subparsers(dest="command")

    # list-mo
    p_list = sub.add_parser("list-mo", help="List manufacturing orders")
    p_list.add_argument("--state", choices=["draft", "confirmed", "progress", "done", "cancel"])
    p_list.add_argument("--limit", type=int, default=20)

    # create-mo
    p_create = sub.add_parser("create-mo", help="Create a manufacturing order")
    p_create.add_argument("--product", required=True, help="Product name")
    p_create.add_argument("--qty", type=float, required=True, help="Quantity to produce")
    p_create.add_argument("--origin", default="", help="Source document reference")

    # list-wo
    p_wo = sub.add_parser("list-wo", help="List work orders")
    p_wo.add_argument("--mo-id", type=int, help="Filter by manufacturing order ID")
    p_wo.add_argument("--state", choices=["pending", "ready", "progress", "done", "cancel"])

    # list-bom
    p_bom = sub.add_parser("list-bom", help="List bills of materials")
    p_bom.add_argument("--product", help="Filter by product name")

    # summary
    p_sum = sub.add_parser("summary", help="Production analytics summary")
    p_sum.add_argument("--days", type=int, default=30, help="Days to look back")

    # update
    p_up = sub.add_parser("update-mo", help="Update a manufacturing order")
    p_up.add_argument("--mo-id", type=int, required=True, help="MO ID")
    p_up.add_argument("--qty-produced", type=float, help="Quantity produced")
    p_up.add_argument("--priority", choices=["0", "1", "2", "3"], help="Priority level")

    # confirm / done
    sub.add_parser("confirm-mo", help="Confirm a draft MO").add_argument("--mo-id", type=int, required=True)
    sub.add_parser("done-mo", help="Mark MO as done").add_argument("--mo-id", type=int, required=True)

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    if not HAS_REQUESTS:
        print("ERROR: requests library required. pip install requests")
        sys.exit(1)

    odoo = OdooMRP(
        url=args.url, db=args.db,
        username=args.user, password=args.password,
    )

    try:
        if args.command == "list-mo":
            result = odoo.list_manufacturing_orders(state=args.state, limit=args.limit)
        elif args.command == "create-mo":
            result = odoo.create_manufacturing_order(args.product, args.qty, origin=args.origin)
        elif args.command == "list-wo":
            result = odoo.list_work_orders(production_id=getattr(args, "mo_id", None), state=args.state)
        elif args.command == "list-bom":
            result = odoo.list_bom(product_name=args.product)
        elif args.command == "summary":
            result = odoo.production_summary(days_back=args.days)
        elif args.command == "update-mo":
            vals = {}
            if args.qty_produced is not None:
                vals["qty_produced"] = args.qty_produced
            if args.priority:
                vals["priority"] = args.priority
            result = odoo.update_production(args.mo_id, vals)
        elif args.command == "confirm-mo":
            result = odoo.confirm_manufacturing_order(args.mo_id)
        elif args.command == "done-mo":
            result = odoo.mark_done(args.mo_id)
        else:
            parser.print_help()
            sys.exit(1)

        print(json.dumps(result, indent=2, default=str))

    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
