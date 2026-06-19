# Brief: Fix the export timeout

The CSV export endpoint times out on large datasets (>100k rows). Fix it — stream the
results instead of buffering them in memory — and open a PR with the fix.
