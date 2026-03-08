import json
import re
import os
import sys


def check_models():
    # Load OpenAPI spec
    try:
        try:
            with open("docs/api_contract.json", "r", encoding="utf-8") as f:
                api_spec = json.load(f)
        except UnicodeDecodeError:
            with open("docs/api_contract.json", "r", encoding="utf-16") as f:
                api_spec = json.load(f)
    except Exception as e:
        print(f"Error loading api_contract.json: {e}")
        return

    schemas = api_spec.get("components", {}).get("schemas", {})

    dart_dir = "mobile/lib/models"
    dart_files = (
        [
            f
            for f in os.listdir(dart_dir)
            if f.endswith(".dart") and os.path.isfile(os.path.join(dart_dir, f))
        ]
        if os.path.exists(dart_dir)
        else []
    )
    if not dart_files:
        print("No dart files found.")

    # Simple mapping from dart class name to schema name
    # e.g. AuditLogEntry -> AuditLogEntry, Order -> OrderRecord or whatever

    # Iterate through dart files manually or print all string fields
    results = []
    for filename in os.listdir(dart_dir):
        if not filename.endswith(".dart"):
            continue
        filepath = os.path.join(dart_dir, filename)
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()

        # Find class name
        class_match = re.search(r"class\s+([A-Za-z0-9_]+)", content)
        if not class_match:
            continue
        class_name = class_match.group(1)

        # Find all String fields
        # final String fieldName;
        string_fields = re.findall(r"final\s+String\s+([A-Za-z0-9_]+)\s*;", content)
        if not string_fields:
            continue

        # Look up in OpenAPI
        # Try to find exactly class_name, or something similar
        schema = schemas.get(class_name)
        if not schema:
            # try fuzzy matching or print all
            schema_keys = [
                k for k in schemas.keys() if k.lower().startswith(class_name.lower())
            ]
            if schema_keys:
                schema = schemas.get(schema_keys[0])
                class_name = schema_keys[0]  # assume

        if not schema:
            results.append(
                f"Schema not found for {class_name} (from {filename}), but it has string fields: {string_fields}"
            )
            continue

        properties = schema.get("properties", {})
        for field in string_fields:
            # camelCase to snake_case?
            snake_field = re.sub(r"(?<!^)(?=[A-Z])", "_", field).lower()

            prop = properties.get(snake_field) or properties.get(field)
            if not prop:
                results.append(f"[{class_name}] Field '{field}' not found in OpenAPI")
                continue

            # Check if nullable
            is_nullable = False
            if "anyOf" in prop:
                types = [t.get("type") for t in prop["anyOf"]]
                if "null" in types:
                    is_nullable = True
            if prop.get("type") == "null":
                is_nullable = True
            if prop.get("nullable") == True:
                is_nullable = True

            # Check if required
            is_required = snake_field in schema.get(
                "required", []
            ) or field in schema.get("required", [])

            if is_nullable or not is_required:
                results.append(
                    f"MISMATCH: [{class_name}] Dart 'String {field}' <-> API 'Optional/Nullable'"
                )
            else:
                pass  # results.append(f"MATCH: [{class_name}] Dart 'String {field}' === API Required String")

    with open("check_results.txt", "w", encoding="utf-8") as f:
        f.write("\n".join(results))


if __name__ == "__main__":
    check_models()
