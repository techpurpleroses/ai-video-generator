-- Ensure render_jobs is linked to video_generations for PostgREST joins.
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
      ON DELETE CASCADE
      NOT VALID;
  END IF;
END $$;
