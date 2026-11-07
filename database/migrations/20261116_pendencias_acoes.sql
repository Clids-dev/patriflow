-- Decisão D6 do idealizador (07/11/2026): resolver uma pendência é uma ação guiada por tipo
-- (ex.: abrir baixa por extravio, cadastrar o bem encontrado), sempre com o texto da resolução.
-- A ação escolhida e o registro que ela gerou (baixa, bem) ficam guardados junto da resolução.
BEGIN;

ALTER TABLE pendencias ADD COLUMN IF NOT EXISTS acao VARCHAR(30);
ALTER TABLE pendencias ADD COLUMN IF NOT EXISTS referencia_id INTEGER;
CREATE INDEX IF NOT EXISTS pendencias_bem_resolvidas_idx ON pendencias (bem_id, resolvida_em DESC)
    WHERE resolvida_em IS NOT NULL;

COMMIT;
