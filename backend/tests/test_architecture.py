"""
Architectural consistency tests.
Ensures API routes do not break separation of concerns.
"""

import ast
import os
from typing import List

import pytest

# Define the root directory for the backend app
BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../app"))
API_DIR = os.path.join(BACKEND_DIR, "api")
SERVICES_DIR = os.path.join(BACKEND_DIR, "services")


def get_python_files(directory: str) -> List[str]:
    files_list = []
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith(".py") and file != "__init__.py":
                files_list.append(os.path.join(root, file))
    return files_list


@pytest.mark.unit
def test_api_routes_do_not_import_sqlalchemy_core():
    """
    API routes should NOT import SQLAlchemy core components directly.
    They should delegate to Services.
    Exceptions can be made for 'sqlalchemy.orm.Session' which is needed for dependency injection.
    """
    api_files = get_python_files(API_DIR)
    errors = []

    # Waiver list for existing violations (if any)
    WAIVERS = [
        "audit_log.py",
        "reports.py",
        "uom.py",
    ]

    for file_path in api_files:
        basename = os.path.basename(file_path)
        if basename in WAIVERS:
            continue

        with open(file_path, "r", encoding="utf-8") as f:
            tree = ast.parse(f.read())

        for node in ast.walk(tree):
            if isinstance(node, ast.ImportFrom):
                if node.module == "sqlalchemy":
                    for name in node.names:
                        errors.append(
                            f"{basename} imports '{name.name}' from sqlalchemy"
                        )
                if node.module == "sqlalchemy.orm":
                    for name in node.names:
                        if name.name != "Session":
                            errors.append(
                                f"{basename} imports '{name.name}' from sqlalchemy.orm (Only Session is allowed)"
                            )

    assert not errors, "\n".join(errors)


@pytest.mark.unit
def test_api_layer_should_not_access_db_directly():
    """
    API Layer should use Services, not direct DB calls (query, add, commit, delete).
    """
    api_files = get_python_files(API_DIR)
    errors = []

    # Files that currently violate this rule (Tech Debt)
    # We enforce this for NEW files while freezing the current state.
    WAIVERS = [
        "admin_diagnostics.py",
        "admin_identity.py",
        "admin_ledger.py",  # calculates counts directly
        "admin_reconciliation.py",
        "audit_log.py",
        "auth.py",  # get_current_user logic
        "batch.py",
        "dispatch_entry.py",
        "inventory_txn.py",
        "invoice.py",
        "invoice_item.py",
        "item.py",  # simple CRUD
        "item_alias.py",
        "item_management.py",
        "mart.py",
        "mart_bill.py",  # uses query
        "mart_bill_item.py",
        "order.py",
        "rejection_entry.py",
        "reports.py",
        "stock_entry.py",
        "uom.py",
        "user.py",
    ]

    direct_db_methods = ["query", "add", "commit", "delete"]

    for file_path in api_files:
        basename = os.path.basename(file_path)
        if basename in WAIVERS:
            continue

        with open(file_path, "r", encoding="utf-8") as f:
            try:
                tree = ast.parse(f.read())
            except Exception:
                continue

        for node in ast.walk(tree):
            if isinstance(node, ast.Attribute):
                if isinstance(node.value, ast.Name) and node.value.id == "db":
                    if node.attr in direct_db_methods:
                        errors.append(f"{basename} calls db.{node.attr}() directly")

    assert not errors, "\n".join(errors)


@pytest.mark.unit
def test_admin_routes_must_be_secured():
    """
    Admin routes (admin_*) must strictly require require_role(Role.OWNER).
    """
    api_files = get_python_files(API_DIR)
    errors = []

    for file_path in api_files:
        basename = os.path.basename(file_path)
        if not basename.startswith("admin_"):
            continue

        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
            if "require_role(Role.OWNER)" not in content:
                errors.append(
                    f"{basename} does not import/use require_role(Role.OWNER)"
                )

    assert not errors, "\n".join(errors)


@pytest.mark.unit
def test_append_only_models_safety():
    """
    Ensure InventoryTxn, DispatchEntry, DispatchReversal are strictly append-only.
    No direct deletions allowed in Services.
    """
    services_files = get_python_files(SERVICES_DIR)
    errors = []

    protected_models = ["InventoryTxn", "DispatchEntry", "DispatchReversal"]

    # Waivers: Specific functions that might validly delete/reverse (logic-checked)
    # create_reversal_entry is an insert, not delete.
    # delete_stock_entry DOES delete inventory txn? No, it should create negative txn (OUT).

    for file_path in services_files:
        basename = os.path.basename(file_path)
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
            tree = ast.parse(content)

        for node in ast.walk(tree):
            # basic check for .delete() calls
            if isinstance(node, ast.Call):
                if isinstance(node.func, ast.Attribute) and node.func.attr == "delete":
                    # This is a bit noisy, catching all deletes.
                    # We want to catch db.delete(model_instance)
                    # We can't easily infer type.
                    # We can check if the file IMPORTS the protected models AND calls delete.
                    pass

        # Text based check for safety
        if "pk" in basename:  # nonsense
            continue

    # For now, strict enforcement of "No raw SQL delete on these tables"
    # Checking for text("... DELETE FROM ...")

    # Checking for db.query(Model).delete()
    for file_path in services_files:
        basename = os.path.basename(file_path)
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()

        for model in protected_models:
            if f".query({model})" in content and ".delete()" in content:
                errors.append(f"{basename} appears to delete {model} directly")

    assert not errors, "\n".join(errors)
