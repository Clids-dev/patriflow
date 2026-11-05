-- REQ-EX-01: baixa de bem com motivo e documento; acima de um valor, exige aprovação de outro servidor
-- do setor de patrimônio. Uma única baixa pendente por bem.
BEGIN;

CREATE TABLE IF NOT EXISTS baixas (
    id              SERIAL PRIMARY KEY,
    bem_id          INTEGER NOT NULL REFERENCES bens(id),
    motivo          VARCHAR(20) NOT NULL
        CHECK (motivo IN ('doacao', 'inservivel', 'extravio', 'venda', 'sinistro', 'descarte')),
    justificativa   VARCHAR(500) NOT NULL,
    documento_ref   VARCHAR(120) NOT NULL,
    valor_bem       NUMERIC(12, 2) NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'pendente'
        CHECK (status IN ('pendente', 'aprovada', 'recusada')),
    solicitante_id  INTEGER NOT NULL REFERENCES usuarios(id),
    decisor_id      INTEGER REFERENCES usuarios(id),
    motivo_decisao  VARCHAR(500),
    criada_em       TIMESTAMP NOT NULL DEFAULT NOW(),
    decidida_em     TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS baixas_pendente_por_bem ON baixas (bem_id) WHERE status = 'pendente';

COMMIT;
