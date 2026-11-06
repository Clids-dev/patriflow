    DROP TABLE IF EXISTS movimentacoes CASCADE;
    DROP TABLE IF EXISTS bens CASCADE;
    DROP TABLE IF EXISTS setores CASCADE;
    DROP TABLE IF EXISTS salas CASCADE;
    DROP TABLE IF EXISTS andares CASCADE;
    DROP TABLE IF EXISTS predios CASCADE;
    DROP TABLE IF EXISTS responsaveis CASCADE;
    DROP TABLE IF EXISTS categorias CASCADE;
    DROP TABLE IF EXISTS usuarios CASCADE;
    DROP TABLE IF EXISTS tipos CASCADE;



    CREATE TABLE tipos (
        id SERIAL PRIMARY KEY,
        nome VARCHAR(100) UNIQUE NOT NULL,
        prefixo VARCHAR(10) UNIQUE NOT NULL,
        contador INT DEFAULT 0
    );

    CREATE TABLE categorias (
        id SERIAL PRIMARY KEY,
        nome VARCHAR(100) NOT NULL,
        sigla VARCHAR(10) UNIQUE NOT NULL,
        ativo BOOLEAN NOT NULL DEFAULT TRUE
    );

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
    DECLARE base_code TEXT;
    BEGIN
        IF code <> upper(code) OR code !~ '^[A-Z0-9]+(-[A-Z0-9]+)*-[0-9]$' THEN RETURN FALSE; END IF;
        base_code := regexp_replace(code, '-[0-9]$', '');
        RETURN w03_tombo_digito(base_code) = right(code, 1);
    END;
    $$;

    CREATE OR REPLACE FUNCTION impedir_alteracao_tombo() RETURNS TRIGGER
    LANGUAGE plpgsql AS $$
    BEGIN
        IF NEW.codigo_tombamento IS DISTINCT FROM OLD.codigo_tombamento THEN
            RAISE EXCEPTION 'O número de tombo é imutável';
        END IF;
        RETURN NEW;
    END;
    $$;

    CREATE OR REPLACE FUNCTION impedir_exclusao_bem() RETURNS TRIGGER
    LANGUAGE plpgsql AS $$
    BEGIN
        RAISE EXCEPTION 'Bem não pode ser excluído fisicamente; inative-o para preservar o tombo';
    END;
    $$;

    CREATE OR REPLACE FUNCTION impedir_truncate_bens() RETURNS TRIGGER
    LANGUAGE plpgsql AS $$
    BEGIN
        RAISE EXCEPTION 'A tabela de bens não pode ser esvaziada; os tombos devem ser preservados';
    END;
    $$;

    CREATE TABLE bens (
        id SERIAL PRIMARY KEY,
        nome VARCHAR(100) NOT NULL,
        tipo VARCHAR(30) NOT NULL,
        codigo_tombamento VARCHAR(60) UNIQUE NOT NULL,
        valor DECIMAL(10, 2) NOT NULL,
        status VARCHAR(50) NOT NULL,
        ativo BOOLEAN NOT NULL DEFAULT TRUE,
        id_categoria INTEGER NOT NULL REFERENCES categorias(id),
        data_cadastro TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        marca VARCHAR(120),
        modelo VARCHAR(120),
        numero_serie VARCHAR(120),
        valor_aquisicao NUMERIC(12, 2) NOT NULL,
        nota_fiscal VARCHAR(120),
        data_entrada DATE,
        estado_conservacao VARCHAR(20) NOT NULL DEFAULT 'novo'
            CHECK (estado_conservacao IN ('novo', 'bom', 'regular', 'ruim', 'inservivel'))
        ,CONSTRAINT bens_codigo_tombamento_dv_check CHECK (w03_tombo_valido(codigo_tombamento))
    );

    CREATE UNIQUE INDEX bens_codigo_tombamento_casefold_key ON bens (upper(codigo_tombamento));

    CREATE TABLE responsaveis(
        id SERIAL PRIMARY KEY,
        nome VARCHAR(100) NOT NULL,
        cargo VARCHAR(100) NOT NULL,
        ativo BOOLEAN NOT NULL DEFAULT TRUE
    );

    CREATE TRIGGER bens_codigo_tombamento_imutavel
    BEFORE UPDATE OF codigo_tombamento ON bens
    FOR EACH ROW EXECUTE FUNCTION impedir_alteracao_tombo();

    CREATE TRIGGER bens_preservar_tombo
    BEFORE DELETE ON bens
    FOR EACH ROW EXECUTE FUNCTION impedir_exclusao_bem();

    CREATE TRIGGER bens_preservar_tombos_truncate
    BEFORE TRUNCATE ON bens
    FOR EACH STATEMENT EXECUTE FUNCTION impedir_truncate_bens();

    CREATE TABLE predios (
        id SERIAL PRIMARY KEY,
        nome VARCHAR(120) NOT NULL UNIQUE,
        endereco VARCHAR(250)
    );

    CREATE TABLE andares (
        id SERIAL PRIMARY KEY,
        predio_id INTEGER NOT NULL REFERENCES predios(id),
        identificacao VARCHAR(80) NOT NULL,
        UNIQUE (predio_id, identificacao)
    );

    CREATE TABLE salas (
        id SERIAL PRIMARY KEY,
        andar_id INTEGER NOT NULL REFERENCES andares(id),
        identificacao VARCHAR(80) NOT NULL,
        UNIQUE (andar_id, identificacao)
    );

    CREATE TABLE setores (
        id SERIAL PRIMARY KEY,
        nome VARCHAR(100) NOT NULL,
        responsavel_id INTEGER REFERENCES responsaveis(id),
        flag_almoxarifado BOOLEAN NOT NULL DEFAULT FALSE,
        ativo BOOLEAN NOT NULL DEFAULT TRUE,
        sala_id INTEGER NOT NULL REFERENCES salas(id)
    );

    CREATE TABLE movimentacoes (
        id SERIAL PRIMARY KEY,
        bem_id INTEGER REFERENCES bens(id),
        setor_origem_id INTEGER REFERENCES setores(id),
        setor_destino_id INTEGER REFERENCES setores(id),
        data_movimentacao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        justificativa VARCHAR(500),
        ativo BOOLEAN NOT NULL DEFAULT TRUE
    );

    CREATE TABLE usuarios (
        id SERIAL PRIMARY KEY,
        username VARCHAR(50) UNIQUE NOT NULL,
        senha VARCHAR(255) NOT NULL,
        tipo VARCHAR(20) NOT NULL,
        ativo BOOLEAN NOT NULL DEFAULT TRUE,
        nome VARCHAR(120),
        setor_id INTEGER REFERENCES setores(id),
        CONSTRAINT usuarios_tipo_check CHECK (tipo IN ('setor_patrimonio', 'agente_campo', 'responsavel_setor'))
    );

    BEGIN;


    INSERT INTO categorias (nome, sigla, ativo) VALUES
    ('Informática', 'INF', TRUE),
    ('Mobiliário', 'MOB', TRUE),
    ('Veículos', 'VEI', TRUE),
    ('Eletrônicos', 'ELE', TRUE);


    INSERT INTO responsaveis (nome, cargo, ativo) VALUES
    ('Carlos Mendes', 'Gerente de TI', TRUE),
    ('Fernanda Costa', 'Diretora Financeira', TRUE),
    ('João Batista', 'Chefe de Almoxarifado', TRUE),
    ('Mariana Alves', 'Supervisora de RH', TRUE);


    INSERT INTO predios (nome, endereco) VALUES ('Prédio Principal', 'Endereço institucional');
    INSERT INTO andares (predio_id, identificacao) VALUES
    (1, 'Térreo'), (1, '1º andar'), (1, '2º andar');
    INSERT INTO salas (andar_id, identificacao) VALUES
    (1, 'Almoxarifado'), (2, 'TI'), (2, 'Financeiro'), (3, 'Recursos Humanos');

    INSERT INTO setores (nome, responsavel_id, ativo, sala_id) VALUES
    ('Departamento de Tecnologia', 1, TRUE, 2),
    ('Financeiro', 2, TRUE, 3),
    ('Almoxarifado Central', 3, TRUE, 1),
    ('Recursos Humanos', 4, TRUE, 4);

    INSERT INTO tipos (nome, prefixo, contador) VALUES
    ('Notebook', 'ntb', 2),
    ('Monitor', 'mon', 1),
    ('Cadeira', 'cad', 1),
    ('Teclado', 'tcl', 1),
    ('Mouse', 'ms', 1),
    ('Projetor', 'prj', 1),
    ('Servidor', 'srv', 1),
    ('Equipamento de Rede', 'red', 2),
    ('Nobreak', 'nbk', 1),
    ('Tablet', 'tab', 1),
    ('Periférico', 'prf', 2),
    ('Impressora', 'imp', 1),
    ('Ar Condicionado', 'ar', 1),
    ('Mesa', 'mes', 1),
    ('Estabilizador', 'est', 1),
    ('Smartphone', 'cel', 1),
    ('Drone', 'drn', 1);

-- 5. Inserir Bens usando o formato gerador de códigos (prefixo-0000)
    INSERT INTO bens (nome, tipo, codigo_tombamento, valor, status, ativo, id_categoria, data_cadastro, valor_aquisicao) VALUES
    ('Notebook Dell Latitude', 'Notebook', 'NTB-0001-7', 4500.00, 'Em Uso', TRUE, 1, '2024-01-15 09:30:00-03', 4500.00),
    ('Monitor LG 29 Pol', 'Monitor', 'MON-0001-0', 1200.00, 'Em Uso', TRUE, 1, '2024-02-10 14:00:00-03', 1200.00),
    ('Cadeira Ergonômica', 'Cadeira', 'CAD-0001-7', 850.50, 'Disponível', TRUE, 2, '2024-03-05 10:15:00-03', 850.50),
    ('Teclado Mecânico Logitech', 'Teclado', 'TCL-0001-7', 350.00, 'Em Uso', TRUE, 1, '2024-05-20 16:45:00-03', 350.00),
    ('Mouse Gamer Razer', 'Mouse', 'MS-0001-6', 280.00, 'Manutenção', TRUE, 1, '2024-06-12 11:00:00-03', 280.00),
    ('Projetor Epson 4K', 'Projetor', 'PRJ-0001-1', 3200.00, 'Em Uso', TRUE, 4, '2024-08-01 08:00:00-03', 3200.00),
    ('Servidor HP ProLiant', 'Servidor', 'SRV-0001-4', 15000.00, 'Em Uso', TRUE, 1, '2024-09-15 13:20:00-03', 15000.00),
    ('Switch Cisco 24 Portas', 'Equipamento de Rede', 'RED-0001-2', 2100.00, 'Disponível', TRUE, 1, '2024-11-30 09:00:00-03', 2100.00),
    ('Nobreak APC 1500VA', 'Nobreak', 'NBK-0001-2', 1100.00, 'Em Uso', TRUE, 4, '2025-01-05 15:30:00-03', 1100.00),
    ('Tablet Samsung S9', 'Tablet', 'TAB-0001-4', 3800.00, 'Em Uso', TRUE, 4, '2025-02-14 10:00:00-03', 3800.00),
    ('Webcam Logitech C920', 'Periférico', 'PRF-0001-3', 450.00, 'Disponível', TRUE, 1, '2025-03-22 17:10:00-03', 450.00),
    ('Impressora HP LaserJet', 'Impressora', 'IMP-0001-1', 1800.00, 'Manutenção', TRUE, 1, '2025-05-10 14:40:00-03', 1800.00),
    ('Ar Condicionado Split', 'Ar Condicionado', 'AR-0001-8', 2500.00, 'Em Uso', TRUE, 4, '2025-07-08 09:20:00-03', 2500.00),
    ('Mesa de Reunião', 'Mesa', 'MES-0001-7', 1300.00, 'Disponível', TRUE, 2, '2025-09-12 11:50:00-03', 1300.00),
    ('Roteador Wi-Fi 6', 'Equipamento de Rede', 'RED-0002-0', 750.00, 'Em Uso', TRUE, 1, '2025-11-02 08:30:00-03', 750.00),
    ('Headset HyperX Cloud', 'Periférico', 'PRF-0002-1', 500.00, 'Em Uso', TRUE, 1, '2026-01-20 13:00:00-03', 500.00),
    ('Estabilizador SMS', 'Estabilizador', 'EST-0001-0', 150.00, 'Disponível', TRUE, 4, '2026-02-15 10:45:00-03', 150.00),
    ('MacBook Air M2', 'Notebook', 'NTB-0002-5', 8500.00, 'Em Uso', TRUE, 1, '2026-03-01 09:00:00-03', 8500.00),
    ('Smartphone iPhone 15', 'Smartphone', 'CEL-0001-8', 6200.00, 'Em Uso', TRUE, 4, '2026-04-10 15:00:00-03', 6200.00),
    ('Drone DJI Mini 4', 'Drone', 'DRN-0001-7', 5400.00, 'Disponível', TRUE, 4, '2026-04-20 11:20:00-03', 5400.00);

    -- Contas iniciais: admin / Admin@PatriFlow2026 e agente / Agente@PatriFlow2026.
    -- As senhas abaixo são hashes PBKDF2, nunca texto limpo.
    INSERT INTO usuarios (username, senha, tipo, ativo, nome)
    VALUES
    ('admin', 'pbkdf2_sha256$310000$OalE7FohEaJD2Y94BKgSYA$nBmLl5eem4QqqiiK1XKr9tlN9nvW_AvpuKv956Ne8dk', 'setor_patrimonio', TRUE, 'Administrador PatriFlow'),
    ('agente', 'pbkdf2_sha256$310000$F68oo5MT37gxYPNPa7Z41A$8UwH5xW1LtLNjXBr7Qgn4FN92bX7mcRCWVpeBPCtwU4', 'agente_campo', TRUE, 'Agente Padrão');




    -- 5. Inserir Movimentações
    -- IDs de Setores esperados: 1=TI, 2=Financeiro, 3=Almoxarifado, 4=RH
    -- IDs de Bens esperados: 1=Notebook, 2=Monitor, 3=Cadeira...

    INSERT INTO movimentacoes (bem_id, setor_origem_id, setor_destino_id, data_movimentacao, ativo) VALUES
    -- Notebook saiu do Almoxarifado (3) para TI (1)
    (1, 3, 1, '2024-01-10 09:00:00', TRUE),

    -- Monitor saiu do Almoxarifado (3) para TI (1)
    (2, 3, 1, '2024-01-10 09:05:00', TRUE),

    -- Cadeira chegou direto no Almoxarifado (Origem NULL = Compra nova)
    (3, NULL, 3, '2024-01-15 14:00:00', TRUE),

    -- Mesa saiu do Almoxarifado (3) para o RH (4)
    (4, 3, 4, '2024-01-20 10:30:00', TRUE),

    -- Servidor saiu da TI (1) para Manutenção externa (destino pode ser NULL ou um setor específico de manutenção, aqui simulando volta para Almoxarifado)
    (5, 1, 3, NOW(), TRUE);

    COMMIT; -- Confirma a gravação
