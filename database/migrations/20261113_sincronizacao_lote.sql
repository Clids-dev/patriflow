-- Sincronização em lote do aplicativo (trabalho feito sem rede).
--
-- Cada operação chega com um identificador gerado no aparelho. O par (dispositivo, operação) é único:
-- reenviar o mesmo lote não grava nada duas vezes, e a resposta repete o resultado da primeira vez.
-- Toda operação recebida fica registrada com o desfecho (aceita, recusada, conflito ou erro) e o motivo;
-- nada é descartado em silêncio. Conflitos viram pendência para o setor de patrimônio decidir.
BEGIN;

CREATE TABLE IF NOT EXISTS sincronizacoes (
    id             SERIAL PRIMARY KEY,
    dispositivo_id VARCHAR(64) NOT NULL CHECK (length(btrim(dispositivo_id)) >= 8),
    usuario_id     INTEGER NOT NULL REFERENCES usuarios(id),
    recebida_em    TIMESTAMP NOT NULL DEFAULT NOW(),
    concluida_em   TIMESTAMP,
    total          INTEGER NOT NULL DEFAULT 0,
    aceitas        INTEGER NOT NULL DEFAULT 0,
    recusadas      INTEGER NOT NULL DEFAULT 0,
    conflitos      INTEGER NOT NULL DEFAULT 0,
    repetidas      INTEGER NOT NULL DEFAULT 0,
    erros          INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS sincronizacoes_dispositivo_idx ON sincronizacoes (dispositivo_id, recebida_em DESC);

CREATE TABLE IF NOT EXISTS sync_operacoes (
    id               SERIAL PRIMARY KEY,
    dispositivo_id   VARCHAR(64) NOT NULL,
    operacao_id      VARCHAR(64) NOT NULL CHECK (length(btrim(operacao_id)) >= 8),
    usuario_id       INTEGER NOT NULL REFERENCES usuarios(id),
    sincronizacao_id INTEGER NOT NULL REFERENCES sincronizacoes(id),
    tipo             VARCHAR(40) NOT NULL,
    criada_em        TIMESTAMP NOT NULL,          -- horário do aparelho, quando a operação foi feita
    dados            JSONB NOT NULL,
    status           VARCHAR(12) NOT NULL DEFAULT 'processando'
        CHECK (status IN ('processando', 'aceita', 'recusada', 'conflito', 'erro')),
    mensagem         VARCHAR(500),
    resultado        JSONB,
    recebida_em      TIMESTAMP NOT NULL DEFAULT NOW(),
    processada_em    TIMESTAMP,
    CONSTRAINT sync_operacoes_unica UNIQUE (dispositivo_id, operacao_id)
);
CREATE INDEX IF NOT EXISTS sync_operacoes_sincronizacao_idx ON sync_operacoes (sincronizacao_id);
CREATE INDEX IF NOT EXISTS sync_operacoes_conflitos_idx ON sync_operacoes (recebida_em) WHERE status = 'conflito';

-- Uma operação concluída (aceita, recusada ou conflito) não muda mais. Só "erro" pode ser reprocessada.
CREATE OR REPLACE FUNCTION proteger_operacao_sincronizada() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.status IN ('aceita', 'recusada', 'conflito') THEN
        RAISE EXCEPTION 'Operação sincronizada já concluída não pode ser alterada.' USING ERRCODE = 'restrict_violation';
    END IF;
    IF (NEW.dispositivo_id, NEW.operacao_id, NEW.usuario_id) IS DISTINCT FROM (OLD.dispositivo_id, OLD.operacao_id, OLD.usuario_id) THEN
        RAISE EXCEPTION 'A identificação da operação não pode ser alterada.' USING ERRCODE = 'restrict_violation';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_operacoes_protegidas ON sync_operacoes;
CREATE TRIGGER sync_operacoes_protegidas BEFORE UPDATE ON sync_operacoes
    FOR EACH ROW EXECUTE FUNCTION proteger_operacao_sincronizada();
DROP TRIGGER IF EXISTS sync_operacoes_sem_exclusao ON sync_operacoes;
CREATE TRIGGER sync_operacoes_sem_exclusao BEFORE DELETE ON sync_operacoes
    FOR EACH ROW EXECUTE FUNCTION impedir_exclusao_evento();
DROP TRIGGER IF EXISTS sincronizacoes_sem_exclusao ON sincronizacoes;
CREATE TRIGGER sincronizacoes_sem_exclusao BEFORE DELETE ON sincronizacoes
    FOR EACH ROW EXECUTE FUNCTION impedir_exclusao_evento();

-- Conflitos de sincronização entram na caixa de pendências.
ALTER TABLE pendencias ADD COLUMN IF NOT EXISTS sync_operacao_id INTEGER REFERENCES sync_operacoes(id);
ALTER TABLE pendencias DROP CONSTRAINT IF EXISTS pendencias_tipo_check;
ALTER TABLE pendencias ADD CONSTRAINT pendencias_tipo_check
    CHECK (tipo IN ('bem_nao_localizado', 'bem_nao_cadastrado', 'conflito_sincronizacao'));
CREATE UNIQUE INDEX IF NOT EXISTS pendencias_uma_por_operacao ON pendencias (sync_operacao_id) WHERE sync_operacao_id IS NOT NULL;

CREATE OR REPLACE FUNCTION resolver_pendencia_uma_vez() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.resolvida_em IS NOT NULL THEN
        RAISE EXCEPTION 'Esta pendência já foi resolvida.' USING ERRCODE = 'restrict_violation';
    END IF;
    IF (NEW.tipo, NEW.inventario_item_id, NEW.sync_operacao_id, NEW.bem_id, NEW.setor_id, NEW.descricao,
        NEW.criada_por, NEW.criada_em)
       IS DISTINCT FROM
       (OLD.tipo, OLD.inventario_item_id, OLD.sync_operacao_id, OLD.bem_id, OLD.setor_id, OLD.descricao,
        OLD.criada_por, OLD.criada_em) THEN
        RAISE EXCEPTION 'O registro da pendência não pode ser alterado.' USING ERRCODE = 'restrict_violation';
    END IF;
    RETURN NEW;
END;
$$;

COMMIT;
