#!/usr/bin/env python3

import csv
import json
import os
import sqlite3
import sys


def read_tsv(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def load_metadata(con, path):
    with open(path, newline="") as f:
        lines = [line for line in f if not line.startswith("#")]
    rows = list(csv.DictReader(lines, delimiter="\t"))
    for row in rows:
        con.execute(
            "INSERT INTO samples (sample_id, sex, population, family, father, mother,"
            " phenotype, is_synthetic_phenotype) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
            " ON CONFLICT (sample_id) DO NOTHING",
            (row["sample_id"], row["sex"], row["population"], row["family"],
             row["father"], row["mother"], row["phenotype"], row["is_synthetic_phenotype"]))
    return len(rows)


def ensure_sample(con, sample_id):
    con.execute(
        "INSERT INTO samples (sample_id) VALUES (?) ON CONFLICT (sample_id) DO NOTHING",
        (sample_id,))


def number(text):
    if text is None or text == "" or text == "NA":
        return None
    return float(text)


def load_run(con, folder):
    with open(os.path.join(folder, "manifest.json")) as f:
        manifest = json.load(f)
    pipeline = manifest["pipeline"]
    run_id = pipeline["run_id"]

    if con.execute("SELECT 1 FROM runs WHERE run_id = ?", (run_id,)).fetchone():
        return f"{run_id}: already in the database, skipped"

    version = (pipeline["name"], pipeline["version"], pipeline["implementation"])
    con.execute(
        "INSERT INTO pipelines (name, version, implementation) VALUES (?, ?, ?)"
        " ON CONFLICT (name, version, implementation) DO NOTHING", version)
    pipeline_id = con.execute(
        "SELECT pipeline_id FROM pipelines WHERE name = ? AND version = ? AND implementation = ?",
        version).fetchone()[0]

    params, platform = manifest["params"], manifest["platform"]
    con.execute(
        "INSERT INTO runs (run_id, pipeline_id, started_at, finished_at, exit_status,"
        " platform, executor, samplesheet, reference, region, folder)"
        " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (run_id, pipeline_id, pipeline["started_at"], pipeline["finished_at"],
         pipeline["exit_status"], platform.get("kind"), platform.get("executor"),
         params.get("samplesheet"), params.get("ref"), params.get("region"),
         os.path.abspath(folder)))

    for s in manifest["samples"]:
        ensure_sample(con, s["sample_id"])
        con.execute(
            "INSERT INTO run_samples (run_id, sample_id, condition, library_type)"
            " VALUES (?, ?, ?, ?)",
            (run_id, s["sample_id"], s["condition"], s["library_type"]))

    variants_path = os.path.join(folder, "variants.tsv")
    n_variants = 0
    if os.path.exists(variants_path):
        rows = read_tsv(variants_path)
        variants = []
        for r in rows:
            lower = {k.lower(): v for k, v in r.items()}
            variants.append((run_id, lower["chrom"], int(lower["pos"]), lower["ref"],
                              lower["alt"], number(lower.get("qual")), lower["filter"]))
        con.executemany(
            "INSERT INTO variants (run_id, chrom, pos, ref, alt, qual, filter)"
            " VALUES (?, ?, ?, ?, ?, ?, ?)", variants)
        n_variants = len(variants)

    outputs = [(run_id, o["path"], o["checksum"].removeprefix("sha256:"))
               for o in manifest["outputs"]]
    con.executemany(
        "INSERT INTO outputs (run_id, path, sha256) VALUES (?, ?, ?)", outputs)

    return (f"{run_id}: loaded {len(manifest['samples'])} samples, "
            f"{n_variants} variants, {len(outputs)} files")


def main():
    database, metadata, folders = sys.argv[1], sys.argv[2], sys.argv[3:]
    con = sqlite3.connect(database)
    con.execute("PRAGMA foreign_keys = ON")
    with con:
        n = load_metadata(con, metadata)
    print(f"metadata: {n} samples")
    for folder in folders:
        with con:
            print(load_run(con, folder))


if __name__ == "__main__":
    main()
