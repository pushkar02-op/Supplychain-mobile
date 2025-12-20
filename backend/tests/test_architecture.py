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


def get_python_files(directory: str) -> List[str]:
    files_list = []
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith(".py") and file != "__init__.py":
                files_list.append(os.path.join(root, file))
    return files_list


def check_imports_in_file(file_path: str, forbidden_modules: List[str]):
    with open(file_path, "r", encoding="utf-8") as f:
        tree = ast.parse(f.read(), filename=file_path)

    for node in ast.walk(tree):
        # Check 'from module import ...'
        if isinstance(node, ast.ImportFrom):
            if node.module in forbidden_modules:
                yield f"Forbidden import 'from {node.module} ...' in {os.path.basename(file_path)}"
        # Check 'import module'
        elif isinstance(node, ast.Import):
            for alias in node.names:
                if alias.name in forbidden_modules:
                    yield f"Forbidden import 'import {alias.name}' in {os.path.basename(file_path)}"


@pytest.mark.unit
def test_api_routes_do_not_import_sqlalchemy_query_builders():
    """
    API routes should NOT import SQLAlchemy query builders directly.
    They should delegate to Services.
    Exceptions can be made for 'sqlalchemy.orm.Session' which is needed for dependency injection.
    """
    api_files = get_python_files(API_DIR)

    # We want to forbid 'sqlalchemy' (core) usage like select, or_, and_, func
    # But allow 'sqlalchemy.orm' (Session)

    errors = []
    for file_path in api_files:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
            tree = ast.parse(content)

        for node in ast.walk(tree):
            if isinstance(node, ast.ImportFrom):
                # Forbid: from sqlalchemy import ...
                if node.module == "sqlalchemy":
                    # We might want to allow some exceptions?
                    # Generally API shouldn't touch sqlalchemy core.
                    # But exceptions might exist. Let's be strict first.
                    for name in node.names:
                        errors.append(
                            f"{os.path.basename(file_path)} imports '{name.name}' from sqlalchemy"
                        )

                # Forbid: from sqlalchemy.orm import ... (Except Session, joinedload might be leaky but maybe used?)
                # Actually, joinedload is definitely leaky logic. Session is OK.
                if node.module == "sqlalchemy.orm":
                    for name in node.names:
                        if name.name != "Session":
                            errors.append(
                                f"{os.path.basename(file_path)} imports '{name.name}' from sqlalchemy.orm (Only Session is allowed)"
                            )

    # Filter out known waivers if necessary (none for now)
    assert not errors, "\n".join(errors)
