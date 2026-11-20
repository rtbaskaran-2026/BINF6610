import os
import sqlite3
import sys
from urllib.parse import parse_qs

import pandas as pd
import dash_ag_grid as dag
import plotly.express as px
from dash import Dash, dcc, html
from dash import Input, Output, callback, ctx

DB = sys.argv[1]
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8050


# The data: one SQL query, on a connection of its own
def query(sql, params=()):
    con = sqlite3.connect(DB)
    rows = pd.read_sql_query(sql, con, params=params)
    con.close()
    return rows


# A site's type, by the brief's rule (the class did not show this one):
# multiallelic if alt holds a comma; otherwise SNP if ref and alt are
# one base each; otherwise indel
def site_type(ref, alt):
    if "," in alt:
        return "multiallelic"
    if len(ref) == 1 and len(alt) == 1:
        return "SNP"
    return "indel"


# The two pages
def runs_page():
    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, "..", "db", "queries", "q1.sql")) as f:
        runs = query(f.read())
    links = [html.Li(dcc.Link(r, href=f"/results?run={r}"))
             for r in runs["run_id"]]
    return [html.H1(f"The runs in {DB}"),
            html.Ul(links),
            dag.AgGrid(id="runs-table",
                       rowData=runs.to_dict("records"),
                       columnDefs=[{"field": c} for c in runs.columns],
                       columnSize="sizeToFit")]


def results_page(run_id):
    samples = query("""
        SELECT sample_id, condition, phenotype, is_synthetic_phenotype
        FROM run_samples LEFT JOIN samples USING (sample_id)
        WHERE run_id = ?""", (run_id,))

    sites = query("""
        SELECT chrom, pos, ref, alt, qual, filter
        FROM variants
        WHERE run_id = ?""", (run_id,))
    sites["type"] = [site_type(r, a)
                     for r, a in zip(sites["ref"], sites["alt"])]

    filters = px.histogram(sites, x="filter",
                           title="How many sites passed, and why did the others fail?")
    quals = px.histogram(sites.dropna(subset=["qual"]), x="qual",
                         title="How confident are the calls?")
    types = px.histogram(sites, x="type",
                         title="How many SNPs, indels and multiallelic sites?")

    columns = ["chrom", "pos", "ref", "alt", "qual", "filter"]
    return [html.H1(f"Results of {run_id}"),
            dag.AgGrid(id="samples-table",
                       rowData=samples.to_dict("records"),
                       columnDefs=[{"field": c} for c in samples.columns],
                       columnSize="sizeToFit"),
            dcc.Graph(id="plot-filter", figure=filters),
            dcc.Graph(id="plot-qual", figure=quals),
            dcc.Graph(id="plot-type", figure=types),
            dag.AgGrid(id="sites-table", rowData=[],
                       columnDefs=[{"field": c} for c in columns],
                       columnSize="sizeToFit")]


# The layout: the address, and a box that the callback fills
app = Dash(__name__, suppress_callback_exceptions=True)
app.layout = [dcc.Location(id="url"), html.Div(id="page", children=[])]


# The callback: the address chooses the page
@callback(Output("page", "children"),
          Input("url", "pathname"), Input("url", "search"))
def draw_page(pathname, search):
    if pathname == "/results":
        run_id = parse_qs(search.lstrip("?"))["run"][0]
        return results_page(run_id)
    return runs_page()


# The callback: a click on a bar narrows the sites table
@callback(Output("sites-table", "rowData"),
          Input("plot-filter", "clickData"), Input("plot-type", "clickData"),
          Input("url", "search"))
def show_sites(filter_click, type_click, search):
    run_id = parse_qs(search.lstrip("?"))["run"][0]
    sites = query("""
        SELECT chrom, pos, ref, alt, qual, filter
        FROM variants
        WHERE run_id = ?""", (run_id,))
    if ctx.triggered_id == "plot-filter":
        value = filter_click["points"][0]["x"]
        rows = sites[sites["filter"] == value]
    elif ctx.triggered_id == "plot-type":
        kind = type_click["points"][0]["x"]
        kinds = [site_type(r, a) for r, a in zip(sites["ref"], sites["alt"])]
        rows = sites[[k == kind for k in kinds]]
    else:
        rows = sites
    return rows.to_dict("records")


app.run(port=PORT, debug=True)
