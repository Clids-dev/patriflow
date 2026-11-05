-- Recomendações de governança e regras de patrimônio:
--  * auditoria: registro imutável de criação, edição, baixa e reativação de bens
--  * bens: garantia, vida útil e valor residual (base para depreciação linear)
-- Executar uma vez, após a migração de fotos (W05).
BEGIN;

CREATE TABLE IF NOT EXISTS auditoria (
    id          SERIAL PRIMARY KEY,
    entidade    VARCHAR(40) NOT NULL,
    registro_id INTEGER NOT NULL,
    acao        VARCHAR(20) NOT NULL CHECK (acao IN ('criar', 'editar', 'baixar', 'reativar')),
    usuario_id  INTEGER REFERENCES usuarios(id),
    em          TIMESTAMP NOT NULL DEFAULT NOW(),
    antes       JSONB,
    depois      JSONB
);

CREATE INDEX IF NOT EXISTS auditoria_registro_idx ON auditoria (entidade, registro_id, em);

CREATE OR REPLACE FUNCTION impedir_alteracao_auditoria() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'O registro de auditoria é imutável.';
END;
$$;

DROP TRIGGER IF EXISTS auditoria_imutavel ON auditoria;
CREATE TRIGGER auditoria_imutavel
BEFORE UPDATE OR DELETE ON auditoria
FOR EACH ROW EXECUTE FUNCTION impedir_alteracao_auditoria();

ALTER TABLE bens ADD COLUMN IF NOT EXISTS garantia_fim DATE;
ALTER TABLE bens ADD COLUMN IF NOT EXISTS vida_util_meses INTEGER CHECK (vida_util_meses IS NULL OR vida_util_meses > 0);
ALTER TABLE bens ADD COLUMN IF NOT EXISTS valor_residual NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (valor_residual >= 0);

COMMIT;
