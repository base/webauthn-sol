#!/usr/bin/env python3
import csv
import os
import argparse
import json

DEF_CSV = os.path.join(os.path.dirname(__file__), "../test/fixtures/fcl_gas_profile.csv")


def bin_data(values, bins):
    lo = min(values)
    hi = max(values)
    if lo == hi:
        return [lo], [len(values)]
    width = (hi - lo) / bins
    edges = [int(lo + i * width) for i in range(bins)] + [hi]
    counts = [0] * bins
    for v in values:
        idx = int((v - lo) / width)
        if idx >= bins:
            idx = bins - 1
        counts[idx] += 1
    labels = [f"{edges[i]}-{edges[i+1]}" for i in range(bins)]
    return labels, counts


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default=DEF_CSV, help="Path to fcl_gas_profile.csv")
    ap.add_argument("--bins", type=int, default=30, help="Number of histogram bins")
    ap.add_argument("--out", default="fcl_gas_hist.html", help="Output HTML filename")
    args = ap.parse_args()

    gas_values = []
    with open(args.csv, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                gas_values.append(int(row["gas"]))
            except Exception:
                pass

    if not gas_values:
        print("No gas values found in CSV", args.csv)
        return

    labels, counts = bin_data(gas_values, args.bins)

    html = f"""
<!doctype html>
<html>
<head>
  <meta charset=\"utf-8\" />
  <title>FCL verify gas distribution</title>
  <script src=\"https://cdn.jsdelivr.net/npm/chart.js\"></script>
  <style>body{{font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif; margin:20px}}</style>
</head>
<body>
  <h3>FCL verify gas distribution</h3>
  <p><button id=\"save\">Download PNG</button></p>
  <canvas id=\"chart\" width=\"1000\" height=\"500\"></canvas>
  <script>
    const labels = {json.dumps(labels)};
    const data = {json.dumps(counts)};
    const ctx = document.getElementById('chart').getContext('2d');
    const chart = new Chart(ctx, {{
      type: 'bar',
      data: {{ labels, datasets: [{{ label: 'Count', data, backgroundColor: 'rgba(54, 162, 235, 0.5)' }}] }},
      options: {{
        responsive: false,
        scales: {{
          x: {{ title: {{ display: true, text: 'Gas range' }}, ticks: {{ maxRotation: 45, minRotation: 45, autoSkip: true, maxTicksLimit: 20 }} }},
          y: {{ title: {{ display: true, text: 'Count' }}, beginAtZero: true }}
        }}
      }}
    }});
    document.getElementById('save').addEventListener('click', () => {{
      const a = document.createElement('a');
      a.href = chart.toBase64Image('image/png', 1.0);
      a.download = 'fcl_gas_hist.png';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
    }});
  </script>
</body>
</html>
"""

    out_path = args.out
    with open(out_path, "w") as f:
        f.write(html)
    print("Saved", out_path)


if __name__ == "__main__":
    main()
