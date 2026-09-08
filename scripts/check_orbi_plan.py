#!/usr/bin/env python3
"""Validate Orbi's implementation plan, never claim that the app is tested."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs" / "orbi_panel"
STATES = {"todo", "in_progress", "ready_for_review", "done", "blocked"}
REQUIRED_DOCS = (
    "README.md", "SPEC.md", "ARCHITECTURE.md", "CONTRACTS.md", "DESIGN.md",
    "NOTIFICATIONS.md", "EXTRACTION.md", "VALIDATION.md", "AGENTS.md",
    "REPORT_TEMPLATE.md",
)


def relative_path(base: Path, value: str) -> Path | None:
    """Accept only paths contained inside the specified repository/document root."""
    if not value or Path(value).is_absolute():
        return None
    candidate = (base / value).resolve()
    return candidate if candidate.is_relative_to(base.resolve()) else None


def validate(plan: dict, root: Path = ROOT, docs: Path = DOCS) -> list[str]:
    errors: list[str] = []
    if plan.get("schema_version") != 1:
        errors.append("schema_version must be 1")
    tasks = plan.get("tasks")
    if not isinstance(tasks, list) or not tasks:
        return errors + ["tasks must be a nonempty list"]
    if any(not isinstance(task, dict) for task in tasks):
        return errors + ["each task must be an object"]
    ids = [task.get("id") for task in tasks]
    if any(not isinstance(item, str) or not re.fullmatch(r"[A-Z]\d{2}", item)
           for item in ids):
        return errors + ["each task ID must match A00"]
    if len(set(ids)) != len(ids):
        return errors + ["duplicate task IDs"]
    by_id = {task["id"]: task for task in tasks}
    for name in REQUIRED_DOCS:
        if not (docs / name).is_file():
            errors.append(f"missing document: {name}")

    for task in tasks:
        tid = task["id"]
        for field in ("title", "owner"):
            if not isinstance(task.get(field), str) or not task[field].strip():
                errors.append(f"{tid}: missing {field}")
        if task.get("status") not in STATES:
            errors.append(f"{tid}: invalid status")
        deps = task.get("depends_on")
        if not isinstance(deps, list) or any(not isinstance(d, str) for d in deps):
            errors.append(f"{tid}: depends_on must be a list of IDs")
            continue
        for dep in deps:
            if dep not in by_id or dep == tid:
                errors.append(f"{tid}: invalid dependency {dep}")
        for field in ("docs", "sources", "writes", "acceptance", "verify"):
            values = task.get(field)
            if not isinstance(values, list) or not values or any(
                not isinstance(value, str) or not value.strip() for value in values
            ):
                errors.append(f"{tid}: {field} must contain nonempty strings")
                continue
            if field in {"docs", "sources", "writes"}:
                base = docs if field == "docs" else root
                for value in values:
                    path = relative_path(base, value)
                    if path is None:
                        errors.append(f"{tid}: path outside {field} root: {value}")
                    elif field != "writes" and not path.exists():
                        errors.append(f"{tid}: missing {field} path: {value}")
        if task.get("status") in {"in_progress", "ready_for_review", "done"}:
            unfinished = [d for d in deps if by_id.get(d, {}).get("status") != "done"]
            if unfinished:
                errors.append(f"{tid}: unfinished prerequisites: {', '.join(unfinished)}")
        if task.get("status") == "blocked" and not task.get("blocked_reason"):
            errors.append(f"{tid}: blocked_reason is required")
        if task.get("status") in {"ready_for_review", "done"}:
            report = task.get("report")
            path = relative_path(docs, report) if isinstance(report, str) else None
            if path is None or not path.is_file():
                errors.append(f"{tid}: existing report path is required")
        if task.get("status") == "done":
            if not task.get("reviewed_by") or not task.get("reviewed_at"):
                errors.append(f"{tid}: integrator review metadata is required")

    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(tid: str) -> None:
        if tid in visiting:
            errors.append(f"dependency cycle involving {tid}")
            return
        if tid in visited:
            return
        visiting.add(tid)
        deps = by_id[tid].get("depends_on", [])
        if isinstance(deps, list):
            for dep in deps:
                if isinstance(dep, str) and dep in by_id:
                    visit(dep)
        visiting.remove(tid)
        visited.add(tid)

    for tid in by_id:
        visit(tid)
    return errors


def ready_tasks(plan: dict) -> list[dict]:
    by_id = {task["id"]: task for task in plan["tasks"]}
    return [task for task in plan["tasks"] if task["status"] == "todo" and all(
        by_id[dep]["status"] == "done" for dep in task["depends_on"]
    )]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ready", action="store_true", help="list ready task IDs")
    args = parser.parse_args()
    try:
        plan = json.loads((DOCS / "tasks.json").read_text(encoding="utf-8"))
        if not isinstance(plan, dict):
            raise ValueError("plan root must be an object")
    except (OSError, ValueError) as error:
        print(f"PLAN ERROR: {error}", file=sys.stderr)
        return 1
    errors = validate(plan)
    if errors:
        for error in errors:
            print(f"PLAN ERROR: {error}", file=sys.stderr)
        return 1
    print(f"Plan structure OK: {len(plan['tasks'])} tasks. App/build/ERP2 NOT verified.")
    if args.ready:
        ready = ready_tasks(plan)
        for task in ready:
            print(f"{task['id']} [{task['owner']}] {task['title']}")
        if not ready:
            print("No pending tasks with all prerequisites completed.")
        print("Integrator must check write ownership before parallel assignment.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
