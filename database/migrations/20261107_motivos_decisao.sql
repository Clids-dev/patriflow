-- W06: quem decide a transferência registra o motivo (obrigatório na recusa),
-- para que quem solicitou receba a resposta e o porquê.
-- Executar uma vez, após a migração de auditoria/depreciação.
BEGIN;

ALTER TABLE movimentacoes ADD COLUMN IF NOT EXISTS motivo_decisao VARCHAR(500);

COMMIT;
