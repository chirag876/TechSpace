"""
============================================================
🚀 Hidden Python Gems - Daily Useful + Visualization Toolkit
By: Chirag Gupta
============================================================

This file showcases a curated set of Python libraries that are hidden gems — meaning not everyone uses them daily,
but they can save huge time in real-world tasks, especially for data analysis, APIs, visualization, logging, retries, etc.

Each section includes:
- A brief description with use-case (docstring)
- Example/demo code that runs or generates output
- Separation for readability

⚡ To install required libraries at once:
pip install pendulum structlog tenacity orjson httpx \
            altair bokeh holoviews panel plotnine pygal \
            yellowbrick sweetviz ydata-profiling dtale lux
"""

# 1. PENDULUM – Clean datetime handling
import pendulum

def demo_pendulum():
    """
    Pendulum: A powerful datetime library.
    Use-case: Simplifies timezone handling, date math, and human-readable diffs.
    """
    print("\n--- 1. Pendulum Demo ---")
    dt = pendulum.now("Asia/Kolkata")
    print("Current time:", dt)
    print("5 days later:", dt.add(days=5))
    print("Diff humanized:", dt.diff_for_humans())


# 2. STRUCTLOG – Clean structured logging
import structlog
log = structlog.get_logger()

def demo_structlog():
    """
    Structlog: Enhances Python logging with structured JSON-like output.
    Use-case: Better readability in logs, perfect for debugging and production logging.
    """
    print("\n--- 2. Structlog Demo ---")
    log.info("user_event", user="Chirag", action="login", success=True)
    log.warning("balance_warning", account="savings", balance=150)


# 3. TENACITY – Retry logic easily
from tenacity import retry, wait_exponential, stop_after_attempt
count = {"tries": 0}

@retry(wait=wait_exponential(multiplier=1, min=1, max=4), stop=stop_after_attempt(3))
def risky_action():
    """Simulates flaky action that fails first few tries."""
    count["tries"] += 1
    print(f"Trying: {count['tries']}")
    if count["tries"] < 3:
        raise Exception("Unlucky failure")
    return "Finally succeeded!"

def demo_tenacity():
    """
    Tenacity: Automatically retries operations with backoff.
    Use-case: Network/API/DB operations where failures are transient.
    """
    print("\n--- 3. Tenacity Demo ---")
    try:
        print("Result:", risky_action())
    except Exception as e:
        print("Still failed:", e)


# 4. ORJSON – Lightning-fast JSON
import orjson

def demo_orjson():
    """
    orjson: Fast JSON serializer/deserializer with datetime support.
    Use-case: Performance-critical JSON handling.
    """
    print("\n--- 4. orjson Demo ---")
    payload = {"id": 1, "items": [1, 2, 3], "valid": True}
    jb = orjson.dumps(payload)
    print("Bytes:", jb)
    print("Back to object:", orjson.loads(jb))


# 5. HTTPX – Modern, async-ready HTTP client
import httpx

def demo_httpx():
    """
    HTTPX: Modern HTTP lib with sync and async support.
    Use-case: API requests, better than requests library.
    """
    print("\n--- 5. HTTPX Demo ---")
    resp = httpx.get("https://httpbin.org/get")
    print("Status:", resp.status_code, "| Type:", resp.headers.get("Content-Type"))


# 6. ALTAIR – Declarative plots (declarative + supports Vega-Lite)
import altair as alt
import pandas as pd

def demo_altair():
    """
    Altair: Declarative plotting tool.
    Use-case: Build interactive plots with minimal syntax.
    """
    print("\n--- 6. Altair Demo ---")
    df = pd.DataFrame({"x": list(range(10)), "y": [v**1.5 for v in range(10)]})
    chart = alt.Chart(df).mark_line(point=True).encode(x="x", y="y").properties(title="Altair Plot")
    chart.save("altair_demo.html")
    print("Saved: altair_demo.html")


# 7. BOKEH – Interactive web plots
from bokeh.plotting import figure, output_file, save

def demo_bokeh():
    """
    Bokeh: Create interactive web visualizations.
    Use-case: Embed charts into dashboards or apps.
    """
    print("\n--- 7. Bokeh Demo ---")
    output_file("bokeh_demo.html")
    p = figure(title="Bokeh Line", x_axis_label="x", y_axis_label="y")
    p.line([1,2,3,4,5], [6,5,4,3,2], line_width=2)
    save(p)
    print("Saved: bokeh_demo.html")


# 8. HOLOVIEWS + PANEL – Quick dashboards
import holoviews as hv
import panel as pn
hv.extension("bokeh")

def demo_holoviews_panel():
    """
    Holoviews + Panel: Build dashboards quickly with less boilerplate.
    Use-case: Rapid dashboard prototyping.
    """
    print("\n--- 8. Holoviews + Panel Demo ---")
    curve = hv.Curve([(1,2), (2,4), (3,1)])
    pn.panel(curve).save("holoviews_panel_demo.html")
    print("Saved: holoviews_panel_demo.html")


# 9. PLOTNINE – ggplot2-style plotting
from plotnine import ggplot, aes, geom_line

def demo_plotnine():
    """
    Plotnine: Python equivalent of ggplot2.
    Use-case: Grammar of Graphics lovers, more declarative plotting.
    """
    print("\n--- 9. Plotnine Demo ---")
    df = pd.DataFrame({"x": range(10), "y": [v**0.5 for v in range(10)]})
    plot = ggplot(df, aes("x", "y")) + geom_line()
    plot.save("plotnine_demo.png")
    print("Saved: plotnine_demo.png")


# 10. YELLOWBRICK – Visual diagnostics for ML
from yellowbrick.classifier import ConfusionMatrix
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.datasets import load_digits

def demo_yellowbrick():
    """
    Yellowbrick: ML model visualization toolkit.
    Use-case: Evaluate models visually (confusion matrix, ROC, etc.).
    """
    print("\n--- 10. Yellowbrick Demo ---")
    X, y = load_digits(return_X_y=True)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)
    model = LogisticRegression(max_iter=2000)
    cm = ConfusionMatrix(model, classes=list(range(10)))
    cm.fit(X_train, y_train)
    cm.score(X_test, y_test)
    cm.show(outpath="yellowbrick_cm.png")
    print("Saved: yellowbrick_cm.png")


# 11. SWEETVIZ – Auto EDA reports
import sweetviz as sv

def demo_sweetviz():
    """
    Sweetviz: Automatically generates EDA reports.
    Use-case: Quick dataset insights in one command.
    """
    print("\n--- 11. Sweetviz Demo ---")
    df = pd.DataFrame({"age": [21,25,30,35], "salary": [3000,5000,7000,9000]})
    report = sv.analyze(df)
    report.show_html("sweetviz_demo.html")
    print("Saved: sweetviz_demo.html")
    


# 12. PANDAS PROFILING – Quick full EDA
from ydata_profiling import ProfileReport

def demo_profiling():
    """
    Pandas Profiling: Produces detailed EDA report.
    Use-case: Data overview, missing values, distributions in one go.
    """
    print("\n--- 12. Pandas Profiling Demo ---")
    df = pd.DataFrame({"col1": range(5), "col2": [10,20,None,30,40]})
    profile = ProfileReport(df, title="Profiling Report")
    profile.to_file("profiling_demo.html")
    print("Saved: profiling_demo.html")
    


# 13. DTALE – Interactive pandas GUI
import dtale

def demo_dtale():
    """
    Dtale: Runs interactive pandas GUI in browser.
    Use-case: Browse/filter/analyze DataFrame quickly.
    """
    print("\n--- 13. Dtale Demo ---")
    df = pd.DataFrame({"x": range(10), "y": [x**2 for x in range(10)]})
    instance = dtale.show(df, ignore_duplicate=True)
    print("Open GUI at:", instance._main_url())
    instance.open_browser()  # Opens in default web browser
    print("Note: Close the browser tab to stop the server.")
    


# 14. LUX – AI-powered viz suggestions
import lux

def demo_lux():
    """
    Lux: Suggests charts automatically from DataFrame.
    Use-case: Smart viz recommendations in notebooks.
    """
    print("\n--- 14. Lux Demo ---")
    df = pd.DataFrame({"a": range(50), "b": [x**1.2 for x in range(50)]})
    print("Use in notebook: just display df to get chart suggestions.")
    df._repr_html_()  # In Jupyter, this would show suggestions
    print("In script, no direct output. Use in Jupyter for best experience.")
    

import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt

def demo_dataflair_style():
    """
    DataFlair Style Mini-EDA:
    Guided walkthrough (like tutorial) with real use-case for quick dataset exploration.
    Use-case: Step-by-step EDA and visualization.
    """
    print("\n--- 15. DataFlair-Style EDA Demo ---")
    df = pd.DataFrame({
        "Age": np.random.randint(20, 60, 100),
        "Salary": np.random.randint(30000, 100000, 100),
        "Dept": np.random.choice(["IT", "HR", "Finance"], 100)
    })
    print("Head:\n", df.head())
    print("Stats:\n", df.describe(include="all"))

    # Distribution
    sns.histplot(df["Salary"], kde=True)
    plt.title("Salary Distribution")
    plt.savefig("dataflair_salary_dist.png")

    # Boxplot by Dept
    sns.boxplot(x="Dept", y="Salary", data=df)
    plt.title("Salary by Department")
    plt.savefig("dataflair_boxplot.png")

    print("Saved: dataflair_salary_dist.png, dataflair_boxplot.png")


# Run all demos
if __name__ == "__main__":
    demo_pendulum()
    demo_structlog()
    demo_tenacity()
    demo_orjson()
    demo_httpx()
    demo_altair()
    demo_bokeh()
    demo_holoviews_panel()
    demo_plotnine()
    demo_yellowbrick()
    demo_sweetviz()
    demo_profiling()
    demo_dtale()
    demo_lux()
    demo_dataflair_style()

    print("\n✅ All demos done! Check the generated files for visuals/outputs.")
