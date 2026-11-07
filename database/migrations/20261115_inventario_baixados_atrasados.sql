-- Decisões D5 e D7 do idealizador (07/11/2026).
--
-- D5: bem baixado encontrado na contagem deixa de ser recusado. Ele entra no inventário com a situação
--     "baixado_encontrado" e, no fechamento, vira a pendência "bem_baixado_encontrado".
-- D7: (sem mudança de esquema) empréstimo já atrasado no fechamento gera pendência mesmo sendo ausência
--     justificada.
BEGIN;

ALTER TABLE inventario_itens DROP CONSTRAINT IF EXISTS inventario_itens_situacao_check;
ALTER TABLE inventario_itens ADD CONSTRAINT inventario_itens_situacao_check
    CHECK (situacao IN ('localizado', 'outro_setor', 'nao_localizado', 'nao_cadastrado', 'baixado_encontrado'));

ALTER TABLE pendencias DROP CONSTRAINT IF EXISTS pendencias_tipo_check;
ALTER TABLE pendencias ADD CONSTRAINT pendencias_tipo_check
    CHECK (tipo IN ('bem_nao_localizado', 'bem_nao_cadastrado', 'conflito_sincronizacao', 'operacao_imprevista',
                    'bem_baixado_encontrado'));

COMMIT;
