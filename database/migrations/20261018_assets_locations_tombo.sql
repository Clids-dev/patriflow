-- W03: execute uma vez após a migração W02.
BEGIN;

CREATE TABLE IF NOT EXISTS predios (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(120) NOT NULL UNIQUE,
    endereco VARCHAR(250)
);

CREATE TABLE IF NOT EXISTS andares (
    id SERIAL PRIMARY KEY,
    predio_id INTEGER NOT NULL REFERENCES predios(id),
    identificacao VARCHAR(80) NOT NULL,
    UNIQUE (predio_id, identificacao)
);

CREATE TABLE IF NOT EXISTS salas (
    id SERIAL PRIMARY KEY,
    andar_id INTEGER NOT NULL REFERENCES andares(id),
    identificacao VARCHAR(80) NOT NULL,
    UNIQUE (andar_id, identificacao)
);

ALTER TABLE setores ADD COLUMN IF NOT EXISTS sala_id INTEGER;
INSERT INTO predios (nome) VALUES ('Prédio não informado') ON CONFLICT (nome) DO NOTHING;
INSERT INTO andares (predio_id, identificacao)
SELECT id, 'Andar não informado' FROM predios WHERE nome = 'Prédio não informado'
ON CONFLICT (predio_id, identificacao) DO NOTHING;
INSERT INTO salas (andar_id, identificacao)
SELECT a.id, 'Sala não informada'
FROM andares a JOIN predios p ON p.id = a.predio_id
WHERE p.nome = 'Prédio não informado' AND a.identificacao = 'Andar não informado'
ON CONFLICT (andar_id, identificacao) DO NOTHING;
UPDATE setores SET sala_id = s.id
FROM salas s JOIN andares a ON a.id = s.andar_id JOIN predios p ON p.id = a.predio_id
WHERE setores.sala_id IS NULL AND p.nome = 'Prédio não informado'
  AND a.identificacao = 'Andar não informado' AND s.identificacao = 'Sala não informada';
ALTER TABLE setores ALTER COLUMN sala_id SET NOT NULL;
DO $$ BEGIN
    ALTER TABLE setores ADD CONSTRAINT setores_sala_id_fkey FOREIGN KEY (sala_id) REFERENCES salas(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE bens ADD COLUMN IF NOT EXISTS marca VARCHAR(120);
ALTER TABLE bens ADD COLUMN IF NOT EXISTS modelo VARCHAR(120);
ALTER TABLE bens ADD COLUMN IF NOT EXISTS numero_serie VARCHAR(120);
ALTER TABLE bens ADD COLUMN IF NOT EXISTS valor_aquisicao NUMERIC(12, 2);
ALTER TABLE bens ADD COLUMN IF NOT EXISTS nota_fiscal VARCHAR(120);
ALTER TABLE bens ADD COLUMN IF NOT EXISTS data_entrada DATE;
ALTER TABLE bens ADD COLUMN IF NOT EXISTS estado_conservacao VARCHAR(20) NOT NULL DEFAULT 'novo';
ALTER TABLE bens ALTER COLUMN codigo_tombamento TYPE VARCHAR(60);
UPDATE bens SET valor_aquisicao = valor WHERE valor_aquisicao IS NULL;
ALTER TABLE bens ALTER COLUMN valor_aquisicao SET NOT NULL;
DO $$ BEGIN
    ALTER TABLE bens ADD CONSTRAINT bens_estado_conservacao_check
        CHECK (estado_conservacao IN ('novo', 'bom', 'regular', 'ruim', 'inservivel'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE OR REPLACE FUNCTION w03_tombo_digito(base_code TEXT) RETURNS TEXT
LANGUAGE plpgsql IMMUTABLE STRICT AS $$
DECLARE normalized TEXT; total INTEGER := 0; weight INTEGER := 2;
        i INTEGER; char_code INTEGER; value INTEGER; digit INTEGER;
BEGIN
    normalized := upper(regexp_replace(base_code, '[^A-Za-z0-9]', '', 'g'));
    IF normalized = '' THEN RAISE EXCEPTION 'Base de tombo vazia'; END IF;
    FOR i IN REVERSE length(normalized)..1 LOOP
        char_code := ascii(substr(normalized, i, 1));
        IF char_code BETWEEN 48 AND 57 THEN value := char_code - 48;
        ELSE value := char_code - 65 + 10;
        END IF;
        total := total + value * weight;
        weight := CASE WHEN weight = 9 THEN 2 ELSE weight + 1 END;
    END LOOP;
    digit := (11 - (total % 11)) % 11;
    IF digit = 10 THEN digit := 0; END IF;
    RETURN digit::TEXT;
END;
$$;

CREATE OR REPLACE FUNCTION w03_tombo_valido(code TEXT) RETURNS BOOLEAN
LANGUAGE plpgsql IMMUTABLE STRICT AS $$
DECLARE base_code TEXT; supplied TEXT;
BEGIN
    IF code <> upper(code) OR code !~ '^[A-Z0-9]+(-[A-Z0-9]+)*-[0-9]$' THEN RETURN FALSE; END IF;
    base_code := regexp_replace(code, '-[0-9]$', '');
    supplied := right(code, 1);
    RETURN w03_tombo_digito(base_code) = supplied;
END;
$$;

CREATE OR REPLACE FUNCTION w03_tombo_com_digito(code TEXT) RETURNS TEXT
LANGUAGE plpgsql IMMUTABLE STRICT AS $$
BEGIN
    RETURN upper(code) || '-' || w03_tombo_digito(code);
END;
$$;

-- Adiciona DV aos identificadores legados apenas na migração de formato.
UPDATE bens SET codigo_tombamento = w03_tombo_com_digito(codigo_tombamento)
WHERE NOT w03_tombo_valido(codigo_tombamento);
DO $$ BEGIN
    ALTER TABLE bens ADD CONSTRAINT bens_codigo_tombamento_dv_check
        CHECK (w03_tombo_valido(codigo_tombamento));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
CREATE UNIQUE INDEX IF NOT EXISTS bens_codigo_tombamento_casefold_key
    ON bens (upper(codigo_tombamento));

CREATE OR REPLACE FUNCTION impedir_alteracao_tombo() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.codigo_tombamento IS DISTINCT FROM OLD.codigo_tombamento THEN
        RAISE EXCEPTION 'O número de tombo é imutável';
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS bens_codigo_tombamento_imutavel ON bens;
CREATE TRIGGER bens_codigo_tombamento_imutavel
BEFORE UPDATE OF codigo_tombamento ON bens
FOR EACH ROW EXECUTE FUNCTION impedir_alteracao_tombo();

CREATE OR REPLACE FUNCTION impedir_exclusao_bem() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Bem não pode ser excluído fisicamente; inative-o para preservar o tombo';
END;
$$;
DROP TRIGGER IF EXISTS bens_preservar_tombo ON bens;
CREATE TRIGGER bens_preservar_tombo
BEFORE DELETE ON bens
FOR EACH ROW EXECUTE FUNCTION impedir_exclusao_bem();

CREATE OR REPLACE FUNCTION impedir_truncate_bens() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'A tabela de bens não pode ser esvaziada; os tombos devem ser preservados';
END;
$$;
DROP TRIGGER IF EXISTS bens_preservar_tombos_truncate ON bens;
CREATE TRIGGER bens_preservar_tombos_truncate
BEFORE TRUNCATE ON bens
FOR EACH STATEMENT EXECUTE FUNCTION impedir_truncate_bens();

COMMIT;
