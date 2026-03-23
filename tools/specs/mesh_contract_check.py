#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


class ValidationError(Exception):
    pass


def validate(schema: dict[str, Any], instance: Any, path: str = "$") -> None:
    if "const" in schema and instance != schema["const"]:
      raise ValidationError(f"{path}: expected const {schema['const']!r}, got {instance!r}")
    if "enum" in schema and instance not in schema["enum"]:
      raise ValidationError(f"{path}: expected one of {schema['enum']!r}, got {instance!r}")

    schema_type = schema.get("type")
    if schema_type == "object":
        if not isinstance(instance, dict):
            raise ValidationError(f"{path}: expected object, got {type(instance).__name__}")
        required = schema.get("required", [])
        for key in required:
            if key not in instance:
                raise ValidationError(f"{path}: missing required key {key!r}")
        properties = schema.get("properties", {})
        for key, value in instance.items():
            if key in properties:
                validate(properties[key], value, f"{path}.{key}")
            elif schema.get("additionalProperties", True) is False:
                raise ValidationError(f"{path}: unexpected property {key!r}")
        return

    if schema_type == "array":
        if not isinstance(instance, list):
            raise ValidationError(f"{path}: expected array, got {type(instance).__name__}")
        min_items = schema.get("minItems")
        if min_items is not None and len(instance) < min_items:
            raise ValidationError(f"{path}: expected at least {min_items} items, got {len(instance)}")
        item_schema = schema.get("items")
        if item_schema is not None:
            for idx, item in enumerate(instance):
                validate(item_schema, item, f"{path}[{idx}]")
        return

    if schema_type == "string":
        if not isinstance(instance, str):
            raise ValidationError(f"{path}: expected string, got {type(instance).__name__}")
        min_length = schema.get("minLength")
        if min_length is not None and len(instance) < min_length:
            raise ValidationError(f"{path}: expected string length >= {min_length}, got {len(instance)}")
        return

    if schema_type == "integer":
        if not isinstance(instance, int) or isinstance(instance, bool):
            raise ValidationError(f"{path}: expected integer, got {type(instance).__name__}")
        return

    if schema_type == "boolean":
        if not isinstance(instance, bool):
            raise ValidationError(f"{path}: expected boolean, got {type(instance).__name__}")
        return


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate mesh contract JSON instances with the local lightweight checker."
    )
    parser.add_argument("--schema", required=True, help="Path to the schema JSON file.")
    parser.add_argument("--instance", required=True, help="Path to the JSON instance to validate.")
    args = parser.parse_args()

    schema_path = Path(args.schema)
    instance_path = Path(args.instance)

    schema = load_json(schema_path)
    instance = load_json(instance_path)
    validate(schema, instance)

    print(json.dumps({
        "status": "ok",
        "schema": str(schema_path),
        "instance": str(instance_path),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
