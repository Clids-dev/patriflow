-- As funções de tombo chamavam umas às outras sem o schema. O backup do pg_dump
-- restaura com search_path vazio, então a carga dos dados (que dispara a
-- restrição de DV) não encontrava a função. Chamadas passam a ser qualificadas
-- com public.; o comportamento não muda.
BEGIN;

CREATE OR REPLACE FUNCTION public.w03_tombo_digito(base_code TEXT) RETURNS TEXT
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

CREATE OR REPLACE FUNCTION public.w03_tombo_valido(code TEXT) RETURNS BOOLEAN
LANGUAGE plpgsql IMMUTABLE STRICT AS $$
DECLARE base_code TEXT; supplied TEXT;
BEGIN
    IF code <> upper(code) OR code !~ '^[A-Z0-9]+(-[A-Z0-9]+)*-[0-9]$' THEN RETURN FALSE; END IF;
    base_code := regexp_replace(code, '-[0-9]$', '');
    supplied := right(code, 1);
    RETURN public.w03_tombo_digito(base_code) = supplied;
END;
$$;

CREATE OR REPLACE FUNCTION public.w03_tombo_com_digito(code TEXT) RETURNS TEXT
LANGUAGE plpgsql IMMUTABLE STRICT AS $$
BEGIN
    RETURN upper(code) || '-' || public.w03_tombo_digito(code);
END;
$$;

COMMIT;
