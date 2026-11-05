-- REQ-EX-02: bloqueio temporário após tentativas erradas e registro de acessos.
-- A senha nunca é gravada no registro de acessos.
BEGIN;

ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS tentativas_falhas INTEGER NOT NULL DEFAULT 0;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS bloqueado_ate TIMESTAMP;

CREATE TABLE IF NOT EXISTS acessos (
    id          SERIAL PRIMARY KEY,
    usuario     VARCHAR(50) NOT NULL,
    sucesso     BOOLEAN NOT NULL,
    motivo      VARCHAR(40),
    em          TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS acessos_usuario_idx ON acessos (usuario, em);

COMMIT;
