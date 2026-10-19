#!/usr/bin/env python3
"""Bounded Godot checks: fail promptly, record results, support seeded replay."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import json
import os
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
CHECKS = ["battle_rules", "card_definitions", "sigil_playback", "bones_flow",
          "draw_phase", "end_state", "ritual_flow", "run_flow", "living_table",
          "starvation_and_bone_damage", "balance_simulation", "survival_items_rules",
          "survival_items_flow", "rule_permutations", "randomized_battles", "randomized_run_flow"]
QUICK = ["battle_rules", "card_definitions", "draw_phase", "run_flow",
         "survival_items_rules", "rule_permutations", "randomized_battles"]
ERRORS = (b"SCRIPT ERROR", b"ERROR:")

def stop(process):
    if process.poll() is None:
        os.killpg(process.pid, signal.SIGTERM)
    try:
        return process.communicate(timeout=3)[0]
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        return process.communicate()[0]

def run(name, args):
    command = ["godot", "--headless", "--path", str(ROOT), "--script", f"res://tests/{name}.gd"]
    if name == "randomized_battles":
        command += ["--", f"--count={args.seeds}", f"--seed={args.seed}"]
        if args.replay:
            command.append(f"--replay={Path(args.replay).resolve()}")
    if name == "randomized_run_flow":
        command += ["--", f"--count={args.run_seeds}", f"--seed={args.seed}"]
    start = time.monotonic()
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               start_new_session=True)
    timed_out = False
    while True:
        try:
            output = process.communicate(timeout=0.2)[0]
            break
        except subprocess.TimeoutExpired as error:
            output = error.output or b""
            timed_out = time.monotonic() - start > args.timeout
            if timed_out or any(marker in output for marker in ERRORS):
                output = stop(process)
                break
    decoded = output.decode(errors="replace")
    passed = process.returncode == 0 and not timed_out and not any(marker in output for marker in ERRORS)
    return {"name": name, "passed": passed, "seconds": round(time.monotonic() - start, 2),
            "command": command, "timeout": timed_out, "output": decoded}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--quick", action="store_true", help="Skip long animation/balance runs")
    parser.add_argument("--only", help="Comma-separated exact check names")
    parser.add_argument("--seed", type=int, default=0, help="First randomized battle seed")
    parser.add_argument("--seeds", type=int, default=512, help="Number of mixed-deck battle seeds")
    parser.add_argument("--run-seeds", type=int, default=32, help="Number of real-scene map seeds")
    parser.add_argument("--replay", help="Replay a randomized battle failure artifact")
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--timeout", type=float, default=180)
    args = parser.parse_args()
    if min(args.seeds, args.run_seeds, args.jobs, args.timeout) <= 0:
        parser.error("Counts, jobs and timeout must be positive")
    names = ["randomized_battles"] if args.replay else (args.only.split(",") if args.only else (QUICK if args.quick else CHECKS))
    if len(set(names)) != len(names) or any(name not in CHECKS for name in names):
        parser.error("Unknown or repeated check name")
    results = []
    try:
        with ThreadPoolExecutor(max_workers=args.jobs) as pool:
            futures = [pool.submit(run, name, args) for name in names]
            for future in as_completed(futures):
                result = future.result()
                results.append(result)
                print(f"{'PASS' if result['passed'] else 'FAIL'}: {result['name']} ({result['seconds']:.2f}s)", flush=True)
                if not result["passed"]:
                    print(result["output"], flush=True)
    except FileNotFoundError:
        print("Godot executable was not found", file=sys.stderr)
        return 1
    results.sort(key=lambda result: names.index(result["name"]))
    report = ROOT / "reports" / "test-suite-latest.json"
    report.parent.mkdir(exist_ok=True)
    report.write_text(json.dumps({"checks": results, "seed": args.seed, "seeds": args.seeds,
                                  "run_seeds": args.run_seeds}, indent=2) + "\n")
    failures = sum(not result["passed"] for result in results)
    print(f"{len(results) - failures}/{len(results)} checks passed; {report}", flush=True)
    return int(bool(failures))

if __name__ == "__main__":
    sys.exit(main())
