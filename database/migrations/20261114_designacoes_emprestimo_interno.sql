-- Decisões D1 e D9 do idealizador (07/11/2026).
--
-- D1: o setor de patrimônio designa setores a cada agente de campo. Nos setores designados (e no
--     próprio) o agente baixa o acervo, confere e empresta. Fora deles, só num imprevisto, com motivo:
--     a operação fica registrada e vira aviso (pendência "operacao_imprevista") para o patrimônio.
-- D9: o bem não sai da instituição. Todo empréstimo novo identifica quem leva pela matrícula e diz o
--     setor de destino. Empréstimos antigos ficam sem esses dados (a obrigatoriedade está na API).
BEGIN;

CREATE TABLE IF NOT EXISTS agente_setores (
    usuario_id    INTEGER NOT NULL REFERENCES usuarios(id),
    setor_id      INTEGER NOT NULL REFERENCES setores(id),
    designado_por INTEGER NOT NULL REFERENCES usuarios(id),
    designado_em  TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (usuario_id, setor_id)
);
CREATE INDEX IF NOT EXISTS agente_setores_setor_idx ON agente_setores (setor_id);

ALTER TABLE emprestimos ADD COLUMN IF NOT EXISTS matricula VARCHAR(30);
ALTER TABLE emprestimos ADD COLUMN IF NOT EXISTS setor_destino_id INTEGER REFERENCES setores(id);

-- Os dados de saída novos também ficam fixos depois de gravados.
CREATE OR REPLACE FUNCTION encerrar_emprestimo_uma_vez() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.devolvido_em IS NOT NULL THEN
        RAISE EXCEPTION 'Este empréstimo já foi encerrado e não pode ser alterado.' USING ERRCODE = 'restrict_violation';
    END IF;
    IF (NEW.bem_id, NEW.tomador, NEW.motivo, NEW.saida_em, NEW.devolucao_prevista, NEW.registrado_por,
        NEW.matricula, NEW.setor_destino_id)
       IS DISTINCT FROM
       (OLD.bem_id, OLD.tomador, OLD.motivo, OLD.saida_em, OLD.devolucao_prevista, OLD.registrado_por,
        OLD.matricula, OLD.setor_destino_id) THEN
        RAISE EXCEPTION 'Os dados de saída do empréstimo não podem ser alterados.' USING ERRCODE = 'restrict_violation';
    END IF;
    RETURN NEW;
END;
$$;

ALTER TABLE pendencias DROP CONSTRAINT IF EXISTS pendencias_tipo_check;
ALTER TABLE pendencias ADD CONSTRAINT pendencias_tipo_check
    CHECK (tipo IN ('bem_nao_localizado', 'bem_nao_cadastrado', 'conflito_sincronizacao', 'operacao_imprevista'));

COMMIT;
