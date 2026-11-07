-- Empréstimo e manutenção de bens, e eventos que não podem ser apagados.
--
-- Empréstimo: o bem sai com alguém (tomador) por um motivo e com devolução prevista, mas continua
--   sob a guarda do setor de origem (a localização não muda). Atraso = aberto e prazo vencido.
-- Manutenção: o bem vai para um serviço (destino) e volta com o serviço realizado e o novo estado
--   de conservação. Enquanto está fora, o bem fica com status "Manutenção".
-- Cada bem tem no máximo um empréstimo e uma manutenção abertos (índices únicos parciais).
--
-- Trilha imutável: nenhum evento pode ser apagado. Empréstimo e manutenção só podem ser encerrados
-- uma vez, sem mudar os dados de saída. A auditoria não aceita alteração nem exclusão.
BEGIN;

CREATE TABLE IF NOT EXISTS emprestimos (
    id                   SERIAL PRIMARY KEY,
    bem_id               INTEGER NOT NULL REFERENCES bens(id),
    tomador              VARCHAR(120) NOT NULL CHECK (length(btrim(tomador)) >= 3),
    motivo               VARCHAR(500) NOT NULL CHECK (length(btrim(motivo)) >= 3),
    saida_em             TIMESTAMP NOT NULL DEFAULT NOW(),
    devolucao_prevista   DATE NOT NULL,
    registrado_por       INTEGER NOT NULL REFERENCES usuarios(id),
    devolvido_em         TIMESTAMP,
    recebido_por         INTEGER REFERENCES usuarios(id),
    observacao_devolucao VARCHAR(500),
    CONSTRAINT emprestimos_prazo_valido CHECK (devolucao_prevista >= saida_em::date),
    CONSTRAINT emprestimos_devolucao_completa CHECK ((devolvido_em IS NULL) = (recebido_por IS NULL)),
    CONSTRAINT emprestimos_devolucao_apos_saida CHECK (devolvido_em IS NULL OR devolvido_em >= saida_em)
);

CREATE UNIQUE INDEX IF NOT EXISTS emprestimos_um_aberto_por_bem ON emprestimos (bem_id) WHERE devolvido_em IS NULL;
CREATE INDEX IF NOT EXISTS emprestimos_bem_idx ON emprestimos (bem_id, saida_em DESC);
CREATE INDEX IF NOT EXISTS emprestimos_abertos_prazo_idx ON emprestimos (devolucao_prevista) WHERE devolvido_em IS NULL;

CREATE TABLE IF NOT EXISTS manutencoes (
    id                SERIAL PRIMARY KEY,
    bem_id            INTEGER NOT NULL REFERENCES bens(id),
    descricao         VARCHAR(500) NOT NULL CHECK (length(btrim(descricao)) >= 3),
    destino           VARCHAR(160) NOT NULL CHECK (length(btrim(destino)) >= 2),
    enviado_em        TIMESTAMP NOT NULL DEFAULT NOW(),
    enviado_por       INTEGER NOT NULL REFERENCES usuarios(id),
    status_anterior   VARCHAR(20) NOT NULL,
    retorno_em        TIMESTAMP,
    recebido_por      INTEGER REFERENCES usuarios(id),
    servico_realizado VARCHAR(500),
    estado_retorno    VARCHAR(20) CHECK (estado_retorno IN ('novo', 'bom', 'regular', 'ruim', 'inservivel')),
    CONSTRAINT manutencoes_retorno_completo CHECK (
        (retorno_em IS NULL AND recebido_por IS NULL AND servico_realizado IS NULL AND estado_retorno IS NULL)
        OR (retorno_em IS NOT NULL AND recebido_por IS NOT NULL
            AND length(btrim(servico_realizado)) >= 3 AND estado_retorno IS NOT NULL)),
    CONSTRAINT manutencoes_retorno_apos_envio CHECK (retorno_em IS NULL OR retorno_em >= enviado_em)
);

CREATE UNIQUE INDEX IF NOT EXISTS manutencoes_uma_aberta_por_bem ON manutencoes (bem_id) WHERE retorno_em IS NULL;
CREATE INDEX IF NOT EXISTS manutencoes_bem_idx ON manutencoes (bem_id, enviado_em DESC);

-- A auditoria passa a registrar o envio e o retorno de manutenção (mudam status e estado do bem).
ALTER TABLE auditoria DROP CONSTRAINT IF EXISTS auditoria_acao_check;
ALTER TABLE auditoria ADD CONSTRAINT auditoria_acao_check
    CHECK (acao IN ('criar', 'editar', 'baixar', 'reativar', 'enviar_manutencao', 'retorno_manutencao'));

-- Índices para montar a linha do tempo do bem sem varrer tabelas inteiras.
CREATE INDEX IF NOT EXISTS baixas_bem_idx ON baixas (bem_id, criada_em DESC);

-- ---------------------------------------------------------------------------------------------
-- Trilha imutável
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION impedir_exclusao_evento() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Eventos do histórico não podem ser apagados (tabela %).', TG_TABLE_NAME
        USING ERRCODE = 'restrict_violation';
END;
$$;

CREATE OR REPLACE FUNCTION impedir_alteracao_auditoria() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'A auditoria não pode ser alterada nem apagada.' USING ERRCODE = 'restrict_violation';
END;
$$;

-- Empréstimo: só o encerramento (devolução) pode ser gravado, uma única vez.
CREATE OR REPLACE FUNCTION encerrar_emprestimo_uma_vez() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.devolvido_em IS NOT NULL THEN
        RAISE EXCEPTION 'Este empréstimo já foi encerrado e não pode ser alterado.' USING ERRCODE = 'restrict_violation';
    END IF;
    IF (NEW.bem_id, NEW.tomador, NEW.motivo, NEW.saida_em, NEW.devolucao_prevista, NEW.registrado_por)
       IS DISTINCT FROM
       (OLD.bem_id, OLD.tomador, OLD.motivo, OLD.saida_em, OLD.devolucao_prevista, OLD.registrado_por) THEN
        RAISE EXCEPTION 'Os dados de saída do empréstimo não podem ser alterados.' USING ERRCODE = 'restrict_violation';
    END IF;
    RETURN NEW;
END;
$$;

-- Manutenção: só o retorno pode ser gravado, uma única vez.
CREATE OR REPLACE FUNCTION encerrar_manutencao_uma_vez() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.retorno_em IS NOT NULL THEN
        RAISE EXCEPTION 'Esta manutenção já foi encerrada e não pode ser alterada.' USING ERRCODE = 'restrict_violation';
    END IF;
    IF (NEW.bem_id, NEW.descricao, NEW.destino, NEW.enviado_em, NEW.enviado_por, NEW.status_anterior)
       IS DISTINCT FROM
       (OLD.bem_id, OLD.descricao, OLD.destino, OLD.enviado_em, OLD.enviado_por, OLD.status_anterior) THEN
        RAISE EXCEPTION 'Os dados de envio da manutenção não podem ser alterados.' USING ERRCODE = 'restrict_violation';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS emprestimos_sem_exclusao ON emprestimos;
CREATE TRIGGER emprestimos_sem_exclusao BEFORE DELETE ON emprestimos
    FOR EACH ROW EXECUTE FUNCTION impedir_exclusao_evento();
DROP TRIGGER IF EXISTS emprestimos_encerra_uma_vez ON emprestimos;
CREATE TRIGGER emprestimos_encerra_uma_vez BEFORE UPDATE ON emprestimos
    FOR EACH ROW EXECUTE FUNCTION encerrar_emprestimo_uma_vez();

DROP TRIGGER IF EXISTS manutencoes_sem_exclusao ON manutencoes;
CREATE TRIGGER manutencoes_sem_exclusao BEFORE DELETE ON manutencoes
    FOR EACH ROW EXECUTE FUNCTION impedir_exclusao_evento();
DROP TRIGGER IF EXISTS manutencoes_encerra_uma_vez ON manutencoes;
CREATE TRIGGER manutencoes_encerra_uma_vez BEFORE UPDATE ON manutencoes
    FOR EACH ROW EXECUTE FUNCTION encerrar_manutencao_uma_vez();

DROP TRIGGER IF EXISTS movimentacoes_sem_exclusao ON movimentacoes;
CREATE TRIGGER movimentacoes_sem_exclusao BEFORE DELETE ON movimentacoes
    FOR EACH ROW EXECUTE FUNCTION impedir_exclusao_evento();

DROP TRIGGER IF EXISTS baixas_sem_exclusao ON baixas;
CREATE TRIGGER baixas_sem_exclusao BEFORE DELETE ON baixas
    FOR EACH ROW EXECUTE FUNCTION impedir_exclusao_evento();

DROP TRIGGER IF EXISTS auditoria_imutavel ON auditoria;
CREATE TRIGGER auditoria_imutavel BEFORE UPDATE OR DELETE ON auditoria
    FOR EACH ROW EXECUTE FUNCTION impedir_alteracao_auditoria();

COMMIT;
