-- W05: fotos vinculadas a registros (conferência, aceite de transferência,
-- bem não cadastrado). O arquivo fica no disco (FOTOS_DIR); o banco guarda
-- os metadados. Fotos são imutáveis: nenhuma linha pode ser alterada ou apagada.
-- Executar uma vez, após a migração W05 de usuários.
BEGIN;

CREATE TABLE IF NOT EXISTS fotos (
    id              SERIAL PRIMARY KEY,
    registro_tipo   VARCHAR(40) NOT NULL
        CHECK (registro_tipo IN ('conferencia', 'aceite_transferencia', 'bem_nao_cadastrado')),
    registro_id     INTEGER NOT NULL CHECK (registro_id > 0),
    arquivo         VARCHAR(255) NOT NULL UNIQUE,
    content_type    VARCHAR(60) NOT NULL,
    tamanho_bytes   INTEGER NOT NULL CHECK (tamanho_bytes > 0),
    enviado_por     INTEGER NOT NULL REFERENCES usuarios(id),
    enviado_em      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS fotos_registro_idx ON fotos (registro_tipo, registro_id);

CREATE OR REPLACE FUNCTION impedir_alteracao_foto() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Fotos não podem ser alteradas nem apagadas. Envie uma foto nova.';
END;
$$;

DROP TRIGGER IF EXISTS fotos_imutaveis ON fotos;
CREATE TRIGGER fotos_imutaveis
BEFORE UPDATE OR DELETE ON fotos
FOR EACH ROW EXECUTE FUNCTION impedir_alteracao_foto();

COMMIT;
