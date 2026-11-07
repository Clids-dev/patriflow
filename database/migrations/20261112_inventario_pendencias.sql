-- Inventário: abertura com período e setores, lista esperada congelada, conferência e fechamento.
--
-- Na abertura, a lista de bens esperados de cada setor é copiada (congelada) em inventario_itens:
-- movimentações feitas depois não mudam o que o inventário espera encontrar.
-- Cada item termina com uma situação:
--   localizado      -> encontrado no setor esperado
--   outro_setor     -> encontrado em outro setor (no fechamento, abre uma transferência)
--   nao_localizado  -> não encontrado (no fechamento, vira pendência, salvo ausência justificada)
--   nao_cadastrado  -> bem encontrado que não existe no sistema (no fechamento, vira pendência)
-- O inventário só fecha quando todos os itens têm situação. Fechado, nenhum item muda.
BEGIN;

CREATE TABLE IF NOT EXISTS inventarios (
    id          SERIAL PRIMARY KEY,
    descricao   VARCHAR(160) NOT NULL CHECK (length(btrim(descricao)) >= 3),
    inicio      DATE NOT NULL,
    fim         DATE NOT NULL,
    status      VARCHAR(10) NOT NULL DEFAULT 'aberto' CHECK (status IN ('aberto', 'fechado')),
    aberto_por  INTEGER NOT NULL REFERENCES usuarios(id),
    aberto_em   TIMESTAMP NOT NULL DEFAULT NOW(),
    fechado_por INTEGER REFERENCES usuarios(id),
    fechado_em  TIMESTAMP,
    CONSTRAINT inventarios_periodo_valido CHECK (fim >= inicio),
    CONSTRAINT inventarios_fechamento_completo CHECK (
        (status = 'aberto' AND fechado_em IS NULL AND fechado_por IS NULL)
        OR (status = 'fechado' AND fechado_em IS NOT NULL AND fechado_por IS NOT NULL))
);

-- Setores do inventário. "aberto" acompanha o inventário e permite garantir, por índice,
-- que um setor não esteja em dois inventários abertos ao mesmo tempo.
CREATE TABLE IF NOT EXISTS inventario_setores (
    inventario_id INTEGER NOT NULL REFERENCES inventarios(id),
    setor_id      INTEGER NOT NULL REFERENCES setores(id),
    aberto        BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (inventario_id, setor_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS inventario_setores_um_aberto ON inventario_setores (setor_id) WHERE aberto;

CREATE TABLE IF NOT EXISTS inventario_itens (
    id                   SERIAL PRIMARY KEY,
    inventario_id        INTEGER NOT NULL REFERENCES inventarios(id),
    -- Setor onde o bem era esperado (lista congelada). Nulo para itens achados fora da lista.
    setor_esperado_id    INTEGER REFERENCES setores(id),
    bem_id               INTEGER REFERENCES bens(id),
    -- Cópia do bem na abertura: o relatório continua fiel mesmo se o cadastro mudar depois.
    codigo_tombamento    VARCHAR(30),
    nome                 VARCHAR(200) NOT NULL,
    estado_esperado      VARCHAR(20),
    -- Bem emprestado ou em manutenção na abertura: ausência justificada.
    ausencia_justificada VARCHAR(20) CHECK (ausencia_justificada IN ('emprestado', 'manutencao')),
    situacao             VARCHAR(20) CHECK (situacao IN ('localizado', 'outro_setor', 'nao_localizado', 'nao_cadastrado')),
    setor_encontrado_id  INTEGER REFERENCES setores(id),
    estado_encontrado    VARCHAR(20) CHECK (estado_encontrado IN ('novo', 'bom', 'regular', 'ruim', 'inservivel')),
    observacao           VARCHAR(500),
    conferido_por        INTEGER REFERENCES usuarios(id),
    conferido_em         TIMESTAMP,
    CONSTRAINT inventario_itens_conferencia_completa CHECK ((situacao IS NULL) = (conferido_em IS NULL)),
    CONSTRAINT inventario_itens_encontrado_tem_setor CHECK (
        situacao IS NULL OR situacao = 'nao_localizado' OR setor_encontrado_id IS NOT NULL),
    CONSTRAINT inventario_itens_nao_cadastrado_sem_bem CHECK ((situacao = 'nao_cadastrado') = (bem_id IS NULL))
);
-- Um bem aparece uma vez por inventário (itens não cadastrados não têm bem_id e podem ser vários).
CREATE UNIQUE INDEX IF NOT EXISTS inventario_itens_bem_unico ON inventario_itens (inventario_id, bem_id)
    WHERE bem_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS inventario_itens_setor_idx ON inventario_itens (inventario_id, setor_esperado_id, situacao);
CREATE INDEX IF NOT EXISTS inventario_itens_encontrado_idx ON inventario_itens (inventario_id, setor_encontrado_id);
CREATE INDEX IF NOT EXISTS inventario_itens_bem_idx ON inventario_itens (bem_id, conferido_em DESC);

-- Pendências: o que precisa de decisão do patrimônio (bem não localizado, bem não cadastrado).
CREATE TABLE IF NOT EXISTS pendencias (
    id                 SERIAL PRIMARY KEY,
    tipo               VARCHAR(30) NOT NULL CHECK (tipo IN ('bem_nao_localizado', 'bem_nao_cadastrado')),
    inventario_item_id INTEGER REFERENCES inventario_itens(id),
    bem_id             INTEGER REFERENCES bens(id),
    setor_id           INTEGER REFERENCES setores(id),
    descricao          VARCHAR(500) NOT NULL,
    criada_por         INTEGER NOT NULL REFERENCES usuarios(id),
    criada_em          TIMESTAMP NOT NULL DEFAULT NOW(),
    resolvida_por      INTEGER REFERENCES usuarios(id),
    resolvida_em       TIMESTAMP,
    resolucao          VARCHAR(500),
    CONSTRAINT pendencias_resolucao_completa CHECK (
        (resolvida_em IS NULL AND resolvida_por IS NULL AND resolucao IS NULL)
        OR (resolvida_em IS NOT NULL AND resolvida_por IS NOT NULL AND length(btrim(resolucao)) >= 3))
);
CREATE UNIQUE INDEX IF NOT EXISTS pendencias_uma_por_item ON pendencias (inventario_item_id) WHERE inventario_item_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS pendencias_abertas_idx ON pendencias (criada_em) WHERE resolvida_em IS NULL;

-- ---------------------------------------------------------------------------------------------
-- Imutabilidade
-- ---------------------------------------------------------------------------------------------
-- Itens de inventário fechado não mudam; a lista congelada (bem, setor esperado, cópia) nunca muda.
CREATE OR REPLACE FUNCTION proteger_item_inventario() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF (SELECT status FROM inventarios WHERE id = OLD.inventario_id) = 'fechado' THEN
        RAISE EXCEPTION 'O inventário já foi fechado; seus itens não podem mudar.' USING ERRCODE = 'restrict_violation';
    END IF;
    IF (NEW.inventario_id, NEW.setor_esperado_id, NEW.bem_id, NEW.codigo_tombamento, NEW.nome,
        NEW.estado_esperado, NEW.ausencia_justificada)
       IS DISTINCT FROM
       (OLD.inventario_id, OLD.setor_esperado_id, OLD.bem_id, OLD.codigo_tombamento, OLD.nome,
        OLD.estado_esperado, OLD.ausencia_justificada) THEN
        RAISE EXCEPTION 'A lista congelada do inventário não pode ser alterada.' USING ERRCODE = 'restrict_violation';
    END IF;
    RETURN NEW;
END;
$$;

-- Pendência só pode ser resolvida uma vez, sem mudar o que foi registrado.
CREATE OR REPLACE FUNCTION resolver_pendencia_uma_vez() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.resolvida_em IS NOT NULL THEN
        RAISE EXCEPTION 'Esta pendência já foi resolvida.' USING ERRCODE = 'restrict_violation';
    END IF;
    IF (NEW.tipo, NEW.inventario_item_id, NEW.bem_id, NEW.setor_id, NEW.descricao, NEW.criada_por, NEW.criada_em)
       IS DISTINCT FROM
       (OLD.tipo, OLD.inventario_item_id, OLD.bem_id, OLD.setor_id, OLD.descricao, OLD.criada_por, OLD.criada_em) THEN
        RAISE EXCEPTION 'O registro da pendência não pode ser alterado.' USING ERRCODE = 'restrict_violation';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS inventario_itens_protegidos ON inventario_itens;
CREATE TRIGGER inventario_itens_protegidos BEFORE UPDATE ON inventario_itens
    FOR EACH ROW EXECUTE FUNCTION proteger_item_inventario();
DROP TRIGGER IF EXISTS inventario_itens_sem_exclusao ON inventario_itens;
CREATE TRIGGER inventario_itens_sem_exclusao BEFORE DELETE ON inventario_itens
    FOR EACH ROW EXECUTE FUNCTION impedir_exclusao_evento();
DROP TRIGGER IF EXISTS inventarios_sem_exclusao ON inventarios;
CREATE TRIGGER inventarios_sem_exclusao BEFORE DELETE ON inventarios
    FOR EACH ROW EXECUTE FUNCTION impedir_exclusao_evento();
DROP TRIGGER IF EXISTS pendencias_resolve_uma_vez ON pendencias;
CREATE TRIGGER pendencias_resolve_uma_vez BEFORE UPDATE ON pendencias
    FOR EACH ROW EXECUTE FUNCTION resolver_pendencia_uma_vez();
DROP TRIGGER IF EXISTS pendencias_sem_exclusao ON pendencias;
CREATE TRIGGER pendencias_sem_exclusao BEFORE DELETE ON pendencias
    FOR EACH ROW EXECUTE FUNCTION impedir_exclusao_evento();

COMMIT;
