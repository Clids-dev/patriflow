-- W05: perfil auditor (somente leitura) e aprovação de cadastros.
-- Executar uma vez, após a migração W04.
BEGIN;

ALTER TABLE usuarios DROP CONSTRAINT IF EXISTS usuarios_tipo_check;
ALTER TABLE usuarios ADD CONSTRAINT usuarios_tipo_check
    CHECK (tipo IN ('setor_patrimonio', 'agente_campo', 'responsavel_setor', 'auditor'));

-- Contas criadas pelo cadastro público passam a nascer inativas; o setor de
-- patrimônio ativa, define o perfil e o setor. Contas antigas não mudam.

COMMIT;
