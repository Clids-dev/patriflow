-- Execute uma vez em bases já existentes. As credenciais antigas ficam invalidadas;
-- redefina cada senha pela rotina administrativa que usa core.security.hash_password.
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS nome VARCHAR(120);
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS setor_id INTEGER REFERENCES setores(id);
UPDATE usuarios SET ativo = TRUE WHERE ativo IS NULL;
ALTER TABLE usuarios ALTER COLUMN ativo SET NOT NULL;
UPDATE usuarios SET senha = '!REDEFINIR-SENHA!' WHERE senha NOT LIKE 'pbkdf2_sha256$%';
UPDATE usuarios SET tipo = CASE lower(tipo)
    WHEN 'admin' THEN 'setor_patrimonio'
    WHEN 'comum' THEN 'agente_campo'
    ELSE lower(tipo)
END;
ALTER TABLE usuarios DROP CONSTRAINT IF EXISTS usuarios_tipo_check;
ALTER TABLE usuarios ADD CONSTRAINT usuarios_tipo_check
    CHECK (tipo IN ('setor_patrimonio', 'agente_campo', 'responsavel_setor')) NOT VALID;

-- Contas iniciais: admin / Admin@PatriFlow2026 e agente / Agente@PatriFlow2026.
-- ON CONFLICT garante a criação em bases existentes; neste caso redefine a senha padrão.
INSERT INTO usuarios (username, senha, tipo, ativo, nome)
VALUES
    ('admin', 'pbkdf2_sha256$310000$OalE7FohEaJD2Y94BKgSYA$nBmLl5eem4QqqiiK1XKr9tlN9nvW_AvpuKv956Ne8dk', 'setor_patrimonio', TRUE, 'Administrador PatriFlow'),
    ('agente', 'pbkdf2_sha256$310000$F68oo5MT37gxYPNPa7Z41A$8UwH5xW1LtLNjXBr7Qgn4FN92bX7mcRCWVpeBPCtwU4', 'agente_campo', TRUE, 'Agente Padrão')
ON CONFLICT (username) DO UPDATE SET
    senha = EXCLUDED.senha,
    tipo = EXCLUDED.tipo,
    ativo = TRUE,
    nome = EXCLUDED.nome;
