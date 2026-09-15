    DROP TABLE IF EXISTS movimentacoes CASCADE;
    DROP TABLE IF EXISTS bens CASCADE;
    DROP TABLE IF EXISTS setores CASCADE;
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

    CREATE TABLE bens (
        id SERIAL PRIMARY KEY,
        nome VARCHAR(100) NOT NULL,
        tipo VARCHAR(30) NOT NULL,
        codigo_tombamento VARCHAR(50) UNIQUE NOT NULL,
        valor DECIMAL(10, 2) NOT NULL,
        status VARCHAR(50) NOT NULL,
        ativo BOOLEAN NOT NULL DEFAULT TRUE,
        id_categoria INTEGER NOT NULL REFERENCES categorias(id),
        data_cadastro TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE responsaveis(
        id SERIAL PRIMARY KEY,
        nome VARCHAR(100) NOT NULL,
        cargo VARCHAR(100) NOT NULL,
        ativo BOOLEAN NOT NULL DEFAULT TRUE
    );

    CREATE TABLE setores (
        id SERIAL PRIMARY KEY,
        nome VARCHAR(100) NOT NULL,
        responsavel_id INTEGER REFERENCES responsaveis(id),
        flag_almoxarifado BOOLEAN NOT NULL DEFAULT FALSE,
        ativo BOOLEAN NOT NULL DEFAULT TRUE
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
        ativo BOOLEAN DEFAULT TRUE
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


    INSERT INTO setores (nome, responsavel_id, ativo) VALUES
    ('Departamento de Tecnologia', 1, TRUE),
    ('Financeiro', 2, TRUE),
    ('Almoxarifado Central', 3, TRUE),
    ('Recursos Humanos', 4, TRUE);

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
    INSERT INTO bens (nome, tipo, codigo_tombamento, valor, status, ativo, id_categoria, data_cadastro) VALUES
    ('Notebook Dell Latitude', 'Notebook', 'ntb-0001', 4500.00, 'Em Uso', TRUE, 1, '2024-01-15 09:30:00-03'),
    ('Monitor LG 29 Pol', 'Monitor', 'mon-0001', 1200.00, 'Em Uso', TRUE, 1, '2024-02-10 14:00:00-03'),
    ('Cadeira Ergonômica', 'Cadeira', 'cad-0001', 850.50, 'Disponível', TRUE, 2, '2024-03-05 10:15:00-03'),
    ('Teclado Mecânico Logitech', 'Teclado', 'tcl-0001', 350.00, 'Em Uso', TRUE, 1, '2024-05-20 16:45:00-03'),
    ('Mouse Gamer Razer', 'Mouse', 'ms-0001', 280.00, 'Manutenção', TRUE, 1, '2024-06-12 11:00:00-03'),
    ('Projetor Epson 4K', 'Projetor', 'prj-0001', 3200.00, 'Em Uso', TRUE, 4, '2024-08-01 08:00:00-03'),
    ('Servidor HP ProLiant', 'Servidor', 'srv-0001', 15000.00, 'Em Uso', TRUE, 1, '2024-09-15 13:20:00-03'),
    ('Switch Cisco 24 Portas', 'Equipamento de Rede', 'red-0001', 2100.00, 'Disponível', TRUE, 1, '2024-11-30 09:00:00-03'),
    ('Nobreak APC 1500VA', 'Nobreak', 'nbk-0001', 1100.00, 'Em Uso', TRUE, 4, '2025-01-05 15:30:00-03'),
    ('Tablet Samsung S9', 'Tablet', 'tab-0001', 3800.00, 'Em Uso', TRUE, 4, '2025-02-14 10:00:00-03'),
    ('Webcam Logitech C920', 'Periférico', 'prf-0001', 450.00, 'Disponível', TRUE, 1, '2025-03-22 17:10:00-03'),
    ('Impressora HP LaserJet', 'Impressora', 'imp-0001', 1800.00, 'Manutenção', TRUE, 1, '2025-05-10 14:40:00-03'),
    ('Ar Condicionado Split', 'Ar Condicionado', 'ar-0001', 2500.00, 'Em Uso', TRUE, 4, '2025-07-08 09:20:00-03'),
    ('Mesa de Reunião', 'Mesa', 'mes-0001', 1300.00, 'Disponível', TRUE, 2, '2025-09-12 11:50:00-03'),
    ('Roteador Wi-Fi 6', 'Equipamento de Rede', 'red-0002', 750.00, 'Em Uso', TRUE, 1, '2025-11-02 08:30:00-03'),
    ('Headset HyperX Cloud', 'Periférico', 'prf-0002', 500.00, 'Em Uso', TRUE, 1, '2026-01-20 13:00:00-03'),
    ('Estabilizador SMS', 'Estabilizador', 'est-0001', 150.00, 'Disponível', TRUE, 4, '2026-02-15 10:45:00-03'),
    ('MacBook Air M2', 'Notebook', 'ntb-0002', 8500.00, 'Em Uso', TRUE, 1, '2026-03-01 09:00:00-03'),
    ('Smartphone iPhone 15', 'Smartphone', 'cel-0001', 6200.00, 'Em Uso', TRUE, 4, '2026-04-10 15:00:00-03'),
    ('Drone DJI Mini 4', 'Drone', 'drn-0001', 5400.00, 'Disponível', TRUE, 4, '2026-04-20 11:20:00-03');

    INSERT INTO usuarios (username, senha, tipo)
    VALUES ('admin', '123', 'admin'),
    ('joao','123', 'comum');




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
