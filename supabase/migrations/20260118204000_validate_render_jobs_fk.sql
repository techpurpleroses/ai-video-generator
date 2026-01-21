-- Ensure a validated FK exists for render_jobs -> video_generations and reload schema cache.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'render_jobs_generation_id_fkey'
      AND conrelid = 'public.render_jobs'::regclass
  ) THEN
    ALTER TABLE public.render_jobs
      ADD CONSTRAINT render_jobs_generation_id_fkey
      FOREIGN KEY (generation_id)
      REFERENCES public.video_generations(id)
      ON DELETE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  BEGIN
    ALTER TABLE public.render_jobs
      VALIDATE CONSTRAINT render_jobs_generation_id_fkey;
  EXCEPTION
    WHEN undefined_object THEN
      NULL;
  END;
END $$;

NOTIFY pgrst, 'reload schema';
