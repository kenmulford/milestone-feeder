# Brief: CSV export for the Reports page

Add user-facing CSV export to the existing Reports page.

In scope:
- A backend export endpoint that streams the current report's rows as CSV.
- A "Download CSV" action on the Reports page that calls the endpoint and saves the file.
- A per-user rate limit on the export endpoint (exports are expensive).

Out of scope:
- New report types or columns.
- Scheduled or emailed exports.
