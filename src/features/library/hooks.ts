import { useInfiniteQuery } from "@tanstack/react-query";
import { fetchLibrary, type LibraryFilters } from "./api";

export function useLibrary(filters: LibraryFilters) {
  return useInfiniteQuery({
    queryKey: ["library", filters],
    queryFn: ({ pageParam }) =>
      fetchLibrary({ ...filters, cursor: pageParam ?? null }),
    getNextPageParam: (lastPage) => lastPage.nextCursor,
    initialPageParam: null,
  });
}
