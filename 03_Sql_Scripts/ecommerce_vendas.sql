select*from fato_vendas_consolidada limit 10
--numero de registro
select
	count(*)as total
from fato_vendas_consolidada;

-- Cria ou substitui a visualização para a dimensão de locais
CREATE OR REPLACE VIEW dim_locais AS
SELECT DISTINCT 
    city,  -- Nome da cidade (Normalizado em minúsculas pelo Python)
    state  -- Nome do estado (Normalizado em minúsculas pelo Python)
FROM fato_vendas_consolidada; -- Origem dos dados brutos já tratados

--Criar a Dimensão Produto (dim_produtos)

CREATE OR REPLACE VIEW dim_produtos AS
SELECT DISTINCT 
    category, 
    sub_category
FROM fato_vendas_consolidada;
select*from dim_produtos


--Criar a Dimensão Produto (dim_produtos)
--Aqui organizamos as categorias e subcategorias.

CREATE OR REPLACE VIEW dim_produtos AS
SELECT DISTINCT 
    category, 
    sub_category
FROM fato_vendas_consolidada;

--Criar a Tabela Fato (fato_vendas)
--Esta é a tabela principal que o Power BI vai usar para calcular os totais. 
--Ela contém as métricas (vendas, lucro, quantidade) 
--e as chaves para ligar às outras tabelas.
CREATE OR REPLACE VIEW fato_vendas AS
SELECT 
    order_id,
    order_date,
    customername,
    total_sales,
    profit,
    quantity,
    paymentmode,
    city, -- Chave para ligar à dim_locais
    category -- Chave para ligar à dim_produtos
FROM fato_vendas_consolidada;
select*from fato_vendas

--perguntas de negocio
--1.Faturamento Total e Lucro por Categoria?
SELECT 
    p.category,
    to_char(SUM(f.total_sales),'FM999G999G999') AS faturamento_total,
    to_char(SUM(f.profit),'FM999G999G999') AS lucro_total
FROM fato_vendas f
INNER JOIN dim_produtos p ON f.category = p.category
GROUP BY p.category
ORDER BY SUM(f.total_sales) DESC;

-- 1. Apaga a view antiga completamente
DROP VIEW fato_vendas;

-- 2. Cria a nova com a coluna 'state' incluída
CREATE VIEW fato_vendas AS
SELECT 
    order_id,
    order_date,
    customername,
    total_sales,
    profit,
    quantity,
    paymentmode,
    city, 
    state,  -- Agora o Postgres aceita, porque a view é "nova"
    category
FROM fato_vendas_consolidada;



--2.Top 5 Cidades com Maior Volume de Vendas?
SELECT 
    l.city,
    l.state,
    SUM(f.total_sales) AS total_vendido
FROM fato_vendas f
INNER JOIN dim_locais l ON f.city = l.city AND f.state = l.state
GROUP BY l.city, l.state
ORDER BY total_vendido DESC
LIMIT 5;

--3. Qual é o Ticket Médio por Modo de Pagamento?
SELECT 
    paymentmode,
    ROUND(AVG(total_sales), 2) AS ticket_medio
FROM fato_vendas
GROUP BY paymentmode
ORDER BY ticket_medio DESC;

--4. Quais Produtos que Geram Prejuízo (Profit Negativo)?
SELECT 
    p.sub_category,
    SUM(f.profit) AS prejuizo_total
FROM fato_vendas f
INNER JOIN dim_produtos p ON f.category = p.category
GROUP BY p.sub_category
HAVING SUM(f.profit) < 0
ORDER BY prejuizo_total ASC;

--5.Qual Quantidade de Pedidos por Mês (Análise Temporal)?
SELECT 
    DATE_TRUNC('month', order_date) AS mes,
    COUNT(order_id) AS total_pedidos
FROM fato_vendas
GROUP BY mes
ORDER BY mes;

--6.Quem são os nossos 10 clientes "VIP" (os que geraram maior volume de vendas)?

SELECT 
    customername,
    SUM(total_sales) AS total_gasto,
    COUNT(order_id) AS num_pedidos
FROM fato_vendas
GROUP BY customername
ORDER BY total_gasto DESC
LIMIT 10;

--7.Qual Percentual de Lucro por Estado (Métrica Avançada)?
SELECT 
    l.state,
    SUM(f.total_sales) AS vendas,
    SUM(f.profit) AS lucro,
    ROUND((SUM(f.profit)::numeric / SUM(f.total_sales)::numeric) * 100, 2) AS margem_percentual
FROM fato_vendas f
INNER JOIN dim_locais l ON f.city = l.city
GROUP BY l.state
ORDER BY margem_percentual DESC;

--8. Cruzamento Complexo: Subcategorias mais vendidas em cidades específicas?
SELECT 
    l.city,
    p.sub_category,
    SUM(f.quantity) AS qtd_itens
FROM fato_vendas f
INNER JOIN dim_locais l ON f.city = l.city
INNER JOIN dim_produtos p ON f.category = p.category
WHERE l.state = 'Maharashtra' -- Exemplo de filtro regional
GROUP BY l.city, p.sub_category
ORDER BY qtd_itens DESC;

--9.Segmentação de Vendas por Faixa de Valor?
SELECT 
    order_id,
    total_sales,
    CASE 
        WHEN total_sales < 500 THEN 'Baixo Valor'
        WHEN total_sales BETWEEN 500 AND 1500 THEN 'Médio Valor'
        ELSE 'Alto Valor'
    END AS categoria_venda
FROM fato_vendas
ORDER BY total_sales DESC;

-- 10.Qual é o faturamento acumulado ao longo do tempo (Running Total)? (Uso de Window Function)
SELECT 
    order_date,
    total_sales,
    SUM(total_sales) OVER (ORDER BY order_date) AS faturamento_acumulado
FROM fato_vendas
ORDER BY order_date;


