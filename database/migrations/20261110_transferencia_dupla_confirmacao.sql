-- Transferência com dupla confirmação: origem e destino livres.
--   pendente  -> aguarda a liberação do responsável do setor de origem
--   liberada  -> aguarda a confirmação de recebimento (com foto) do responsável do destino
--   aprovada  -> concluída; o bem muda de local
--   recusada  -> recusada por origem ou destino, com motivo
--   cancelada -> o almoxarifado (ou o patrimônio) interveio, com motivo
-- Registros antigos ficam com fluxo 'simples' e seguem a regra anterior.
BEGIN;

ALTER TABLE movimentacoes DROP CONSTRAINT IF EXISTS movimentacoes_status_check;
ALTER TABLE movimentacoes ADD CONSTRAINT movimentacoes_status_check
    CHECK (status IN ('pendente', 'liberada', 'aprovada', 'recusada', 'cancelada'));

ALTER TABLE movimentacoes ADD COLUMN IF NOT EXISTS fluxo VARCHAR(10) NOT NULL DEFAULT 'simples';
ALTER TABLE movimentacoes DROP CONSTRAINT IF EXISTS movimentacoes_fluxo_check;
ALTER TABLE movimentacoes ADD CONSTRAINT movimentacoes_fluxo_check
    CHECK (fluxo IN ('simples', 'duplo'));

COMMIT;
