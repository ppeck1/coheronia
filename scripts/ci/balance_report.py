#!/usr/bin/env python3
"""R-09.3 deterministic contract balance report.

The in-engine smoke pins the Godot-side ContractBalanceReport logic. This driver
owns artifact generation for CI/local closeout: it reads data authorities,
plays the same named fixed-seed policy twice, compares normalized payloads, and
verifies that data JSON files were not mutated.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import random
import sys
import tempfile
import time
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_JSON = ROOT / "build" / "balance_report.json"
DEFAULT_MD = ROOT / "build" / "balance_report.md"

SCENARIO_ID = "r09_fixed_seed_steward_policy"
POLICY_NAME = "Steward bootstrap: store stone, build workbench, craft torches, survive and hunt"
WORLD_SEED = 90240724
DAYS = 4
ITEM_VALUE = {"torch": 3, "food": 2, "crop_seeds": 2}


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def data_hashes() -> dict[str, str]:
    out: dict[str, str] = {}
    for path in sorted((ROOT / "data").rglob("*.json")):
        out[path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    return out


def normalized(report: dict[str, Any]) -> dict[str, Any]:
    out = copy.deepcopy(report)
    out.get("metadata", {}).pop("generated_at", None)
    return out


def policy_inflow(day: int, rng: random.Random) -> dict[str, int]:
    variance = rng.randint(0, 0)
    if day == 1:
        return {"wood": 10, "stone": 12 + variance, "coal": 2, "food": 3}
    if day == 2:
        return {"wood": 8, "stone": 15, "food": 2}
    if day == 3:
        return {"stone": 4, "coal": 1, "food": 4}
    if day == 4:
        return {"wood": 4, "stone": 3, "food": 3}
    return {}


def sorted_dict(data: dict[str, Any]) -> dict[str, Any]:
    return {k: data[k] for k in sorted(data)}


def add_items(target: dict[str, int], items: dict[str, int]) -> None:
    for item_id, count in items.items():
        target[item_id] = int(target.get(item_id, 0)) + int(count)


def spend_items(stockpile: dict[str, int], cost: dict[str, int], outflow: dict[str, int]) -> None:
    for item_id, count in cost.items():
        stockpile[item_id] = max(0, int(stockpile.get(item_id, 0)) - int(count))
        if stockpile[item_id] <= 0:
            del stockpile[item_id]
        outflow[item_id] = int(outflow.get(item_id, 0)) + int(count)


def objective_progress(contract: dict[str, Any], stockpile: dict[str, int],
                       stations: dict[str, bool], day_count: int,
                       progress: dict[str, int]) -> tuple[int, int]:
    obj = contract["objective"]
    otype = obj["type"]
    if otype == "stockpile_at_least":
        return int(stockpile.get(obj["item"], 0)), int(obj["count"])
    if otype == "station_built":
        return (1 if stations.get(obj["station"], False) else 0), 1
    if otype == "survive_to_day":
        return day_count, int(obj["day"])
    if otype in {"defeat_enemies", "craft_items"}:
        return int(progress.get(obj["oid"], 0)), int(obj["count"])
    return 0, 0


def evaluate(contracts: list[dict[str, Any]], records: dict[str, dict[str, Any]],
             stockpile: dict[str, int], stations: dict[str, bool], day_count: int) -> None:
    for contract in contracts:
        cid = contract["id"]
        rec = records.get(cid)
        if not rec or rec["status"] != "active":
            continue
        current, target = objective_progress(
            contract, stockpile, stations, day_count, rec.get("progress", {}))
        if current >= target:
            rec["status"] = "completed"


def note_event(contracts: list[dict[str, Any]], records: dict[str, dict[str, Any]],
               event_type: str, key: str = "") -> None:
    for contract in contracts:
        cid = contract["id"]
        rec = records.get(cid)
        if not rec or rec["status"] != "active":
            continue
        obj = contract["objective"]
        if obj["type"] != event_type:
            continue
        if event_type == "craft_items" and obj.get("recipe", "") != key:
            continue
        oid = obj["oid"]
        rec.setdefault("progress", {})[oid] = int(rec.setdefault("progress", {}).get(oid, 0)) + 1
        if int(rec["progress"][oid]) >= int(obj["count"]):
            rec["status"] = "completed"


def claim_rewards(contracts: list[dict[str, Any]], records: dict[str, dict[str, Any]],
                  inventory: dict[str, int], xp_totals: dict[str, int], base_xp: int,
                  xp_events: dict[str, dict[str, Any]], claimed_day: dict[str, int],
                  day: int) -> tuple[list[dict[str, Any]], int]:
    rewards: list[dict[str, Any]] = []
    for contract in contracts:
        cid = contract["id"]
        rec = records[cid]
        if rec["status"] != "completed" or cid in claimed_day:
            continue
        reward = contract["reward"]
        before_inv = dict(inventory)
        before_xp = dict(xp_totals)
        before_base = base_xp
        if reward["type"] == "grant_items":
            add_items(inventory, reward.get("items", {}))
        elif reward["type"] == "grant_xp":
            ev = xp_events[reward["event_id"]]
            xp_type = ev["xp_type"]
            xp_totals[xp_type] = int(xp_totals.get(xp_type, 0)) + int(ev.get("base_amount", 0))
            base_xp += int(ev.get("also_awards", {}).get("base_xp", 0))
        rec["status"] = "claimed"
        claimed_day[cid] = day
        rewards.append({
            "contract": cid,
            "items": sorted_dict({k: inventory[k] - before_inv.get(k, 0)
                                  for k in inventory if inventory[k] - before_inv.get(k, 0)}),
            "xp": sorted_dict({k: xp_totals[k] - before_xp.get(k, 0)
                               for k in xp_totals if xp_totals[k] - before_xp.get(k, 0)}),
            "base_xp": base_xp - before_base,
        })
    return rewards, base_xp


def reward_value(rewards: list[dict[str, Any]]) -> int:
    total = 0
    for reward in rewards:
        total += sum(int(count) * ITEM_VALUE.get(item_id, 1)
                     for item_id, count in reward["items"].items())
        total += sum(int(count) for count in reward["xp"].values())
        total += int(reward["base_xp"])
    return total


def statuses(contracts: list[dict[str, Any]], records: dict[str, dict[str, Any]]) -> dict[str, str]:
    return {contract["id"]: records[contract["id"]]["status"] for contract in contracts}


def pressure_snapshot(day: int, stockpile: dict[str, int], stations: dict[str, bool],
                      records: dict[str, dict[str, Any]]) -> dict[str, float]:
    total_stock = sum(int(v) for v in stockpile.values())
    active_count = sum(1 for rec in records.values() if rec["status"] == "active")
    threat = 8.0 if day == 2 else (12.0 if day == 3 else 2.0)
    resilience = max(0.0, min(100.0, 35.0 + total_stock * 1.5 - threat))
    load = max(0.0, min(100.0, 18.0 + active_count * 8.0 + threat * 0.5))
    coherence = max(
        0.0,
        min(100.0, 42.0 + stockpile.get("food", 0) * 3.0
            + (10.0 if stations.get("workbench", False) else 0.0) - active_count * 2.0),
    )
    return {"coherence": round(coherence, 1), "resilience": round(resilience, 1),
            "load": round(load, 1), "threat": threat}


def build_report() -> dict[str, Any]:
    contracts = read_json(ROOT / "data/contracts.json")["contracts"]
    xp_events = {ev["event_id"]: ev for ev in read_json(ROOT / "data/progression/player_xp.json")["xp_events"]}
    records: dict[str, dict[str, Any]] = {}
    accepted_day: dict[str, int] = {}
    completed_day: dict[str, int] = {}
    claimed_day: dict[str, int] = {}
    stockpile: dict[str, int] = {}
    inventory: dict[str, int] = {}
    stations = {"workbench": False, "furnace": False, "anvil": False}
    xp_totals: dict[str, int] = {}
    base_xp = 0

    for contract in contracts:
        obj = contract["objective"]
        rec: dict[str, Any] = {"status": "active"}
        if obj["type"] in {"defeat_enemies", "craft_items"}:
            rec["progress"] = {obj["oid"]: 0}
        records[contract["id"]] = rec
        accepted_day[contract["id"]] = 1

    days: list[dict[str, Any]] = []
    rng = random.Random(WORLD_SEED)
    for day in range(1, DAYS + 1):
        inflow = policy_inflow(day, rng)
        outflow: dict[str, int] = {}
        actions: list[str] = []
        add_items(stockpile, inflow)
        if day == 1:
            spend_items(stockpile, {"wood": 1, "coal": 1}, outflow)
            note_event(contracts, records, "craft_items", "craft_torch")
            actions.append("craft_torch")
        elif day == 2:
            spend_items(stockpile, {"wood": 12, "stone": 6}, outflow)
            stations["workbench"] = True
            actions.append("build_workbench")
            evaluate(contracts, records, stockpile, stations, day)
            spend_items(stockpile, {"wood": 1, "coal": 1}, outflow)
            note_event(contracts, records, "craft_items", "craft_torch")
            actions.append("craft_torch")
            note_event(contracts, records, "defeat_enemies")
            actions.append("defeat_enemy")
        elif day == 3:
            note_event(contracts, records, "defeat_enemies")
            actions.append("defeat_enemy")
        elif day == 4:
            actions.append("stabilize_stockpile")
        evaluate(contracts, records, stockpile, stations, day)
        for contract in contracts:
            cid = contract["id"]
            if records[cid]["status"] in {"completed", "claimed"} and cid not in completed_day:
                completed_day[cid] = day
        rewards, base_xp = claim_rewards(
            contracts, records, inventory, xp_totals, base_xp, xp_events, claimed_day, day)
        day_bottlenecks = [
            cid for cid, rec in records.items()
            if rec["status"] == "active" and day - accepted_day[cid] >= 2
        ]
        days.append({
            "day": day,
            "inflow": sorted_dict(inflow),
            "outflow": sorted_dict(outflow),
            "actions": actions,
            "stockpile": sorted_dict(stockpile),
            "contracts": statuses(contracts, records),
            "pressure": pressure_snapshot(day, stockpile, stations, records),
            "rewards_claimed": rewards,
            "reward_value": reward_value(rewards),
            "bottlenecks": day_bottlenecks,
        })

    latencies = {
        contract["id"]: (
            completed_day[contract["id"]] - accepted_day[contract["id"]]
            if contract["id"] in completed_day else None
        )
        for contract in contracts
    }
    final_status = statuses(contracts, records)
    bottlenecks = [
        f"{cid} did not reach claimed" for cid, status in final_status.items()
        if status != "claimed"
    ] + [
        f"{cid} completed slowly ({latency} days)"
        for cid, latency in latencies.items()
        if latency is not None and latency > 2
    ]
    proposed = (
        [
            f"No automatic balance mutation. Under this policy every R-09.2 contract reaches claimed by day {DAYS}.",
            "Keep `first_hunt` at 2 defeats for now; it completes later than the setup contracts and supplies the intended combat pacing contrast.",
        ]
        if not bottlenecks
        else ["Review contracts listed as bottlenecks before changing reward values; this report is evidence only."]
    )
    return {
        "metadata": {
            "scenario_id": SCENARIO_ID,
            "policy": POLICY_NAME,
            "world_seed": WORLD_SEED,
            "days": DAYS,
            "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
            "scope": "Deterministic evidence under one scripted policy; not global balance proof.",
        },
        "days": days,
        "contract_completion_latency_days": latencies,
        "final_contract_status": final_status,
        "reward_totals": {
            "items": sorted_dict(inventory),
            "xp": sorted_dict(xp_totals),
            "base_xp": base_xp,
        },
        "bottlenecks": bottlenecks,
        "proposed_tuning": proposed,
    }


def compact_dict(data: dict[str, Any]) -> str:
    return ", ".join(f"{k}:{data[k]}" for k in sorted(data)) if data else "-"


def markdown_for(report: dict[str, Any]) -> str:
    meta = report["metadata"]
    lines = [
        "# R-09.3 Contract Balance Report",
        "",
        f"- Scenario: `{meta['scenario_id']}`",
        f"- Policy: {meta['policy']}",
        f"- World seed: `{meta['world_seed']}`",
        f"- Days simulated: `{meta['days']}`",
        f"- Scope: {meta['scope']}",
        "",
        "## Daily Summary",
        "",
        "| Day | Inflow | Outflow | Actions | Pressure C/R/L/T | Reward value | Bottlenecks |",
        "|---|---|---|---|---|---|---|",
    ]
    for day in report["days"]:
        p = day["pressure"]
        lines.append(
            f"| {day['day']} | {compact_dict(day['inflow'])} | {compact_dict(day['outflow'])} | "
            f"{', '.join(day['actions'])} | {p['coherence']:.1f} / {p['resilience']:.1f} / "
            f"{p['load']:.1f} / {p['threat']:.1f} | {day['reward_value']} | "
            f"{', '.join(day['bottlenecks']) or '-'} |"
        )
    lines += [
        "",
        "## Completion Latency",
        "",
        "| Contract | Days from activation to completion | Final status |",
        "|---|---|---|",
    ]
    for cid in sorted(report["contract_completion_latency_days"]):
        latency = report["contract_completion_latency_days"][cid]
        lines.append(f"| `{cid}` | {'N/A' if latency is None else latency} | `{report['final_contract_status'][cid]}` |")
    lines += ["", "## Proposed Tuning", ""]
    lines.extend(f"- {note}" for note in report["proposed_tuning"])
    return "\n".join(lines) + "\n"


def write_report(report: dict[str, Any], out_json: Path, out_md: Path) -> None:
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_md.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    out_md.write_text(markdown_for(report), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Run deterministic R-09.3 balance report")
    parser.add_argument("--godot", default="", help="Accepted for verify.py compatibility; not required.")
    parser.add_argument("--out-json", default=str(DEFAULT_JSON))
    parser.add_argument("--out-md", default=str(DEFAULT_MD))
    args = parser.parse_args()

    before = data_hashes()
    first = build_report()
    second = build_report()
    if normalized(first) != normalized(second):
        print("BALANCE REPORT: normalized payload mismatch")
        return 1

    with tempfile.TemporaryDirectory(prefix="coheronia_balance_") as _tmp:
        write_report(second, Path(_tmp) / "balance_report_second.json", Path(_tmp) / "balance_report_second.md")
    write_report(first, Path(args.out_json), Path(args.out_md))

    after = data_hashes()
    if before != after:
        changed = sorted(k for k in set(before) | set(after) if before.get(k) != after.get(k))
        print("BALANCE REPORT: data files mutated ->", ", ".join(changed))
        return 1

    print(f"BALANCE REPORT: PASS scenario={SCENARIO_ID} days={DAYS} -> {args.out_json}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
