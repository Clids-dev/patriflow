-- Decisão D3 do idealizador (07/11/2026): o cadastro tem situação própria.
--   aguardando -> criado pelo cadastro público, esperando o setor de patrimônio
--   ativo      -> pode entrar no sistema
--   desativado -> já foi ativo e foi desativado
--   recusado   -> o patrimônio recusou o cadastro (fica registrado, não é apagado)
-- O campo "ativo" continua existindo e é mantido igual a (situacao = 'ativo') por trigger, para que o
-- código que só lê "ativo" siga funcionando.
BEGIN;

ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS situacao VARCHAR(12);
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS decidido_por INTEGER REFERENCES usuarios(id);
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS decidido_em TIMESTAMP;

-- Inativo que já entrou alguma vez foi desativado; o que nunca entrou aguarda aprovação.
UPDATE usuarios u SET situacao = CASE
        WHEN u.ativo THEN 'ativo'
        WHEN EXISTS (SELECT 1 FROM acessos a WHERE a.usuario = u.username AND a.sucesso) THEN 'desativado'
        ELSE 'aguardando' END
WHERE situacao IS NULL;

ALTER TABLE usuarios ALTER COLUMN situacao SET DEFAULT 'aguardando';
ALTER TABLE usuarios ALTER COLUMN situacao SET NOT NULL;
ALTER TABLE usuarios DROP CONSTRAINT IF EXISTS usuarios_situacao_check;
ALTER TABLE usuarios ADD CONSTRAINT usuarios_situacao_check
    CHECK (situacao IN ('aguardando', 'ativo', 'desativado', 'recusado'));

CREATE OR REPLACE FUNCTION sincronizar_situacao_usuario() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Na criação vale o "ativo"; uma conta inativa nasce aguardando (ou com a situação informada).
        NEW.situacao := CASE WHEN NEW.ativo THEN 'ativo'
                             ELSE COALESCE(NULLIF(NEW.situacao, 'ativo'), 'aguardando') END;
    ELSIF NEW.situacao IS DISTINCT FROM OLD.situacao THEN
        NEW.ativo := NEW.situacao = 'ativo';
    ELSIF NEW.ativo IS DISTINCT FROM OLD.ativo THEN
        NEW.situacao := CASE WHEN NEW.ativo THEN 'ativo' ELSE 'desativado' END;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS usuarios_situacao_sincronizada ON usuarios;
CREATE TRIGGER usuarios_situacao_sincronizada BEFORE INSERT OR UPDATE ON usuarios
    FOR EACH ROW EXECUTE FUNCTION sincronizar_situacao_usuario();

CREATE INDEX IF NOT EXISTS usuarios_aguardando_idx ON usuarios (id) WHERE situacao = 'aguardando';

COMMIT;
