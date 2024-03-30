use supply_chain;

SELECT orders.customer_id,
       orders.in_full,
       orders.on_time,
       orders.on_time_in_full,
       case when orders.agreed_delivery_date <= orders.actual_delivery_date then 'On Time' else 'Delay' end as delivery_status,
       target.ontime_target_percentage,
       target.infull_target_percentage,
       target.otif_target_percentage
FROM fact_order_lines as orders
left join dim_target_orders as target
on orders.customer_id = target.customer_id;

-- What is total number of customers
select count(customer_id) as customer_count
from dim_customers

-- Total Number of Orders

SELECT COUNT(DISTINCT(order_id))
FROM fact_order_lines;

-- Number of customer by city

select city,
       count(distinct(customer_id)) as customer_count
from dim_customers
group by city

-- Category wise Avg. days between order date and agreed delivery date

SELECT product.category,
       AVG(datediff(orders.actual_delivery_date,orders.order_placement_date)) AS avg_delivery_days
FROM fact_order_lines AS orders
INNER JOIN dim_products AS product
ON orders.product_id = product.product_id
GROUP BY product.category;

-- City wise number of customers and orders placed

SELECT customers.city as city,
	   COUNT(DISTINCT(orders.customer_id)) as customer_count, 
	   COUNT(DISTINCT(orders.order_id)) as order_count
FROM fact_order_lines AS orders
LEFT JOIN dim_customers AS customers
USING(customer_id)
GROUP BY customers.city
order by order_count desc;

-- customer wise order and quantity count

select 
       ROW_NUMBER() over (order by count(distinct(orders.order_id)) desc) as sl_no,
       customers.customer_name as customer_name,
       count(distinct(orders.order_id)) as order_count,
       sum(orders.order_qty) as total_quantity
from fact_order_lines as orders
left join dim_customers as customers
on orders.customer_id = customers.customer_id
group by customers.customer_name
limit 5;

-- What is the product wise order count

select products.product_name,
       count(distinct(orders.order_id)) as order_count,
       sum(orders.order_qty) as total_qty
from fact_order_lines as orders
left join dim_products as products
using(product_id)
group by products.product_name
order by order_count desc;

-- Avg order quantity by each customer

SELECT DISTINCT(customer_id),
       AVG(order_qty) as avg_order_qty
FROM fact_order_lines
group BY customer_id
order by avg_order_qty desc;

-- What is the average delivery time by city

select customers.city,
       avg(datediff(orders.actual_delivery_date, orders.order_placement_date)) as avg_delivery_time
from fact_order_lines as orders
left join dim_customers as customers
using(customer_id)
group by customers.city;

-- Citywise OT%, IF%, OTIF%

select customers.city,
       (sum(case when orders.on_time = 1 then 1 else 0 end) * 100 / count(distinct(orders.order_id))) as 'OT%',
       (sum(case when orders.in_full = 1 then 1 else 0 end) * 100 / count(distinct(orders.order_id))) as 'IF%',
       (sum(case when orders.otif = 1 then 1 else 0 end) * 100 / count(distinct(orders.order_id))) as 'OTIF%'
from fact_orders_aggregate as orders
left join dim_customers as customers
using(customer_id)
group by customers.city;

-- Customer wise OT%, IF%, OTIF%

select distinct(orders.customer_id) as customer_id,
       (sum(case when orders.on_time = 1 then 1 else 0 end) * 100 / count(orders.order_id)) as 'OT%',
       round(avg(dt.ontime_target_percentage),2) as 'Target_OT%',
       (sum(case when orders.in_full = 1 then 1 else 0 end) * 100 / count(orders.order_id)) as 'IF%',
       round(avg(dt.infull_target_percentage),2) as 'target_IF%',
       (sum(case when orders.otif = 1 then 1 else 0 end) * 100 / count(orders.order_id)) as 'OTIF%',
       round(avg(dt.otif_target_percentage),2) as 'target_OTIF%'
from fact_orders_aggregate as orders
left join dim_target_orders as dt
USING(customer_id)
group by customer_id;

-- City wise OT%, IF%, OTIF%

select customers.city,
       (sum(case when orders.on_time = 1 then 1 else 0 end) * 100 / count(orders.order_id)) as 'OT%',
       avg(dt.ontime_target_percentage) as 'target_OT%',
       (sum(case when orders.in_full = 1 then 1 else 0 end) * 100 / count(orders.order_id)) as 'IF%',
       avg(dt.infull_target_percentage) as 'target_IF%',
       (sum(case when orders.otif = 1 then 1 else 0 end) * 100 / count(orders.order_id)) as 'OTIF%',
       avg(dt.otif_target_percentage) as 'target_OTIF%'
from fact_orders_aggregate as orders
left join dim_customers as customers
using(customer_id)
left join dim_target_orders as dt
using(customer_id)
group by customers.city;

-- customer wise LIFR% and VOFR%

select fl.customer_id,
       (sum(case when fa.in_full = 1 then 1 else 0 end) * 100 / count(fa.order_id)) as 'LIFR%',
       sum(fl.delivery_qty) * 100 / sum(fl.order_qty) as 'VOFR%'
from fact_order_lines as fl
inner join fact_orders_aggregate as fa
using(customer_id)
group by fl.customer_id
order by 'LIFR%' desc