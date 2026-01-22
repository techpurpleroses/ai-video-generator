import { useInfiniteQuery } from "@tanstack/react-query";
import { fetchLibrary, type LibraryFilters, type LibraryResponse } from "./api";

export function useLibrary(filters: LibraryFilters) {
  return useInfiniteQuery<LibraryResponse>({
    queryKey: ["library", filters],
    queryFn: ({ pageParam }) =>
      fetchLibrary({ ...filters, cursor: pageParam as string | null }),
    getNextPageParam: (lastPage) => lastPage.nextCursor,
    initialPageParam: null,
  });
}
