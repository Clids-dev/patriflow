-- W04: almoxarifado único como porta de entrada dos bens e autorização de
-- movimentações feitas por responsáveis de setor.
-- Executar uma vez, após as migrações W02 e W03.
BEGIN;

-- 1. Um único almoxarifado ativo.
--    Se nenhum setor estiver marcado, marca o primeiro cujo nome contém
--    "almoxarifado". Ajuste manualmente se o seu almoxarifado tiver outro nome.
UPDATE setores SET flag_almoxarifado = TRUE
WHERE id = (
    SELECT id FROM setores
    WHERE nome ILIKE '%almoxarifado%' AND ativo = TRUE
    ORDER BY id LIMIT 1
)
AND NOT EXISTS (SELECT 1 FROM setores WHERE flag_almoxarifado = TRUE AND ativo = TRUE);

-- Falha aqui se houver mais de um almoxarifado ativo. Corrija os dados antes.
CREATE UNIQUE INDEX IF NOT EXISTS setores_almoxarifado_unico
    ON setores (flag_almoxarifado)
    WHERE flag_almoxarifado = TRUE AND ativo = TRUE;

-- 2. Estado de aprovação das movimentações.
--    Registros antigos continuam valendo: entram como 'aprovada'.
ALTER TABLE movimentacoes ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'aprovada';
ALTER TABLE movimentacoes ADD COLUMN IF NOT EXISTS solicitante_id INTEGER REFERENCES usuarios(id);
ALTER TABLE movimentacoes ADD COLUMN IF NOT EXISTS decisor_id INTEGER REFERENCES usuarios(id);
ALTER TABLE movimentacoes ADD COLUMN IF NOT EXISTS data_decisao TIMESTAMP;

DO $$ BEGIN
    ALTER TABLE movimentacoes ADD CONSTRAINT movimentacoes_status_check
        CHECK (status IN ('pendente', 'aprovada', 'recusada'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS movimentacoes_bem_status_idx
    ON movimentacoes (bem_id, status, data_movimentacao DESC);

-- 3. Bens sem nenhuma movimentação aprovada não recebem localização
--    automaticamente. Não há backfill aqui: a entrada histórica deve ser
--    confirmada pelo almoxarifado.

COMMIT;
