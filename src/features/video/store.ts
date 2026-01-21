"use client";

import { create } from "zustand";
import type { GenerationSettings } from "@/lib/types";

type GeneratorDraft = GenerationSettings & {
  title?: string;
};

type GeneratorStore = {
  draft?: GeneratorDraft;
  setDraft: (draft: GeneratorDraft) => void;
  clearDraft: () => void;
};

export const useGeneratorStore = create<GeneratorStore>((set) => ({
  draft: undefined,
  setDraft: (draft) => set({ draft }),
  clearDraft: () => set({ draft: undefined }),
}));
