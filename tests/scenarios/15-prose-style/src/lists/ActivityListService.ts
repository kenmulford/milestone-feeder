export const ACTIVITY_PAGE_SIZE = 30;
export const ACTIVITY_EMPTY_COPY = "No account activity yet.";
export const ACTIVITY_LOAD_ERROR_COPY = "Account activity could not be loaded. Try again.";

export interface ActivityRow {
  id: string;
  kind: string;
  occurredAt: string;
}

export type ActivityPageFetcher = (
  page: number,
  pageSize: number,
) => Promise<{ rows: ActivityRow[]; total: number }>;

export type ActivityListState =
  | { status: "populated"; rows: ActivityRow[]; page: number; pageCount: number; paginationDisabled: boolean }
  | { status: "empty"; message: string }
  | { status: "error"; message: string };

export function isSinglePage(pageCount: number): boolean {
  return pageCount <= 1;
}

export async function loadActivityPage(
  page: number,
  fetchPage: ActivityPageFetcher,
): Promise<ActivityListState> {
  let result: { rows: ActivityRow[]; total: number };
  try {
    result = await fetchPage(page, ACTIVITY_PAGE_SIZE);
  } catch {
    return { status: "error", message: ACTIVITY_LOAD_ERROR_COPY };
  }
  if (result.total === 0) {
    return { status: "empty", message: ACTIVITY_EMPTY_COPY };
  }
  const pageCount = Math.ceil(result.total / ACTIVITY_PAGE_SIZE);
  const rows = [...result.rows].sort((a, b) => b.occurredAt.localeCompare(a.occurredAt));
  return { status: "populated", rows, page, pageCount, paginationDisabled: isSinglePage(pageCount) };
}
