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

select product.category,
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

-- Find the customers based on their total orders and order quantity

select 
       customers.customer_name,
       count(distinct(fl.order_id)) as order_count,
       sum(fl.order_qty) as order_quantity
from fact_order_lines as fl
left join dim_customers as customers
using(customer_id)
group by customers.customer_name
order by order_count desc;

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

with stats as (
select
       customers.customer_name,
       round((sum(case when orders.on_time = 1 then 1 else 0 end) * 100 / count(orders.order_id)),2) as actual_ot,
       round(avg(dt.ontime_target_percentage),2) as target_ot,
       round((sum(case when orders.in_full = 1 then 1 else 0 end) * 100 / count(orders.order_id)),2) as actual_if,
       round(avg(dt.infull_target_percentage),2) as target_if,
       round((sum(case when orders.otif = 1 then 1 else 0 end) * 100 / count(orders.order_id)),2) as actual_otif,
       round(avg(dt.otif_target_percentage),2) as target_otif
from fact_orders_aggregate as orders
left join dim_target_orders as dt
using(customer_id)
left join dim_customers as customers
using(customer_id)
group by customers.customer_name
)

select customer_name,
	   concat((target_ot - actual_ot), '%')  as ot_variance,
       concat((target_if - actual_if), '%') as if_variance,
       concat((target_otif - actual_otif), '%') as otif_variance
from stats
order by otif_variance desc;


-- City wise OT%, IF%, OTIF%

with stats as (
select customers.city,
       (sum(case when orders.on_time = 1 then 1 else 0 end) * 100 / count(orders.order_id)) as OT,
       avg(dt.ontime_target_percentage) as target_OT,
       (sum(case when orders.in_full = 1 then 1 else 0 end) * 100 / count(orders.order_id)) as 'IF',
       avg(dt.infull_target_percentage) as target_IF,
       (sum(case when orders.otif = 1 then 1 else 0 end) * 100 / count(orders.order_id)) as OTIF,
       avg(dt.otif_target_percentage) as target_OTIF
from fact_orders_aggregate as orders
left join dim_customers as customers
using(customer_id)
left join dim_target_orders as dt
using(customer_id)
group by customers.city
)

select city,
       concat((target_OT - OT), '%') as OT_variance,
       concat((target_IF -'IF'), '%') as IF_variance,
       concat((target_OTIF - OTIF), '%') as OTIF_variance
from stats
group by city;

-- customer wise LIFR% and VOFR%

select 
       fl.customer_id,
       round((sum(case when fa.in_full = 1 then 1 else 0 end) * 100 / count(fa.order_id)),2) as 'LIFR%',
       sum(fl.delivery_qty) * 100 / sum(fl.order_qty) as 'VOFR%'
from fact_order_lines as fl
inner join fact_orders_aggregate as fa
using(customer_id)
group by fl.customer_id;

-- Top 3 product in each category by delivered quantity

with stats as (
select p.category,
	   p.product_name,
       sum(fl.delivery_qty) as delivery_qty,
       rank() over(partition by p.category order by sum(fl.delivery_qty) desc ) as rnk
from fact_order_lines as fl
left join dim_products as p
using(product_id)
group by p.category, p.product_name
)

select category,
       product_name,
       delivery_qty,
       rnk
from stats
where rnk <= 3

-- Customer wise most and least ordered products

-- Week over week change of order trend

with week_trend as (
select d.week_no,
       count(distinct(fl.order_id)) as order_count,
       lag(count(distinct(fl.order_id))) over(order by week_no asc) as previous_week_order
from fact_order_lines as fl
left join dim_date as d
on d.date = fl.order_placement_date
group by d.week_no
)

select week_no,
	   ifnull(round((order_count - previous_week_order) * 100 /previous_week_order,2),0) as percentage_change
from week_trend;

-- Customer wise LIFR% and VOFR% --
select 
       fl.customer_id,
       round((sum(case when fa.in_full = 1 then 1 else 0 end) * 100 / count(fa.order_id)),2) as 'LIFR%',
       sum(fl.delivery_qty) * 100 / sum(fl.order_qty) as 'VOFR%'
from fact_order_lines as fl
inner join fact_orders_aggregate as fa
using(customer_id)
group by fl.customer_id;

-- Average LIFR% and VOFR%

with x as (select 
      sum(case when fa.in_full = 1 then 1 else 0 end) * 100 / count(fa.order_id) as LIFR,
      sum(fl.delivery_qty) * 100 / sum(fl.order_qty) as VOFR
from fact_order_lines as fl
inner join fact_orders_aggregate as fa
using(customer_id)
group by fl.customer_id)

select concat(round(avg(LIFR),2), "%") as avg_LIFR,
       concat(round(avg(VOFR),2), "%") as avg_VOFR
from x;

-- categories the orders by Product category for each city in descending order 

select c.city,
       p.category,
       count(distinct(fl.order_id)) as total_order
from fact_order_lines as fl
left join dim_customers as c
on c.customer_id = fl.customer_id
left join dim_products as p
on p.product_id = fl.product_id
group by c.city, p.category
order by total_order desc;

-- Find the top 3 Customers from each city based on thier total orders and what is their OTIF% 
       
with top_3 as (
select c.customer_name,
       c.city,
       count(distinct(fa.order_id)) as total_order,
       concat(round(sum(case when fa.otif = 1 then 1 else 0 end) * 100 / count(fa.order_id),2), "%") as OTIF,
       rank() over(partition by c.city order by count(distinct(fa.order_id)) desc) as rnk
from fact_orders_aggregate as fa
left join dim_customers as c
using(customer_id)
group by c.customer_name, c.city
)

select city,
       customer_name,
       total_order, 
       OTIF,
       rnk
from top_3
where rnk <=3;

-- What's the OT%, IF% and OTIF% for the business

with stats as (
select distinct(customer_id),
       sum(case when fa.on_time= 1 then 1 else 0 end) * 100 / count(fa.order_id) as OT,
       sum(case when fa.in_full = 1 then 1 else 0 end) * 100 / count(fa.order_id) as In_full,
       sum(case when fa.otif = 1 then 1 else 0 end) * 100 / count(fa.order_id) as OTIF
from fact_orders_aggregate as fa
group by customer_id
)

select concat(round(avg(OT),2), "%") as Avg_OT,
       concat(round(avg(In_full),2),"%") as Avg_IF,
	   concat(round(avg(OTIF),2),"%") as Avg_OTIF
from stats;

-- Number of orders getting delayed delivery

select count(distinct(order_id)) as delay_order_count
from fact_order_lines
where agreed_delivery_date < actual_delivery_date;

-- How many days orders getting delayed on an average ?

with delivery as (
select datediff(actual_delivery_date, agreed_delivery_date) as delay_delivery
from fact_order_lines
where datediff(actual_delivery_date, agreed_delivery_date) > 0
)

select round(avg(delay_delivery),2) as avg_delay_days
from delivery;

-- Average lead time by each city
select c.city,
       round(avg(datediff(fl.actual_delivery_date, fl.order_placement_date)),2) as avg_delivery_days
from fact_order_lines as fl
left join dim_customers as c
using(customer_id)
group by c.city;

select round(avg(delay_delivery),2) as avg_delay_days
from delivery;


-- Analyze the monthly trend of on time delivery

select 
	month(order_placement_date) as month,
    count(order_id) AS Total_orders,
    sum(case when fact_order_lines.On_Time = 1 then 1 else 0 end) as on_time_orders,
    round((SUM(case when fact_order_lines.On_Time = 1 then 1 else 0 end) / count(fact_order_lines.order_id) *100 ),2) as on_time_pct 
from 
		fact_order_lines 
group by
			month(order_placement_date)
order by 
				month(order_placement_date);
                
-- What is business overall LIFR% and OTIF%?

select concat(round(sum(case when fa.otif = 1 then 1 else 0 end) * 100 / count(fa.order_id),2),"%") as OTIF,
       concat(round(avg(t.otif_target_percentage),2),"%") as target_OTIF,
       concat(round(sum(case when fl.in_full = 1 then 1 else 0 end) * 100 / count(fl.order_id),2),"%") as LIFR
from fact_orders_aggregate as fa
left join fact_order_lines as fl
using(customer_id)
left join dim_target_orders as t
using(customer_id)

-- LIFR and VOFR by customer wise

select c.customer_name,
	   concat(round(sum(case when fl.in_full = 1 then 1 else 0 end) * 100 / count(fl.order_id),2),"%") as LIFR,
       concat(round(sum(fl.delivery_qty) * 100 / sum(fl.order_qty),2), "%") as VOFR
from fact_order_lines as fl
left join dim_customers as c
using(customer_id)
group by c.customer_name
order by LIFR desc;

-- What is the average lead time and delay delivery days for each cusotmer?

select c.customer_name,
       round(avg(datediff(fl.agreed_delivery_date,fl.order_placement_date)),2) as lead_time,
       avg(datediff(fl.actual_delivery_date,fl.agreed_delivery_date)) as delay_days
from fact_order_lines as fl
left join dim_customers as c
using(customer_id)
group by c.customer_name
order by delay_days desc;

-- Product wise LIFR and OTIF 

select p.product_name,
       concat(round(sum(case when fl.in_full = 1 then 1 else 0 end) * 100 / count(fl.order_id),2),"%") as LIFR,
       concat(round(sum(case when fa.otif = 1 then 1 else 0 end) * 100 / count(fa.order_id),2),"%") as OTIF
from fact_order_lines as fl
left join fact_orders_aggregate as fa
using(customer_id)
left join dim_products as p
on p.product_id = fl.product_id
group by p.product_name
order by OTIF asc;

-- Week over week LIFR

select d.week_no,
       concat(round(sum(case when fl.in_full = 1 then 1 else 0 end) * 100
       / count(fl.order_id),2),"%") as LIFR
from fact_order_lines as fl
left join dim_date as d
on d.date = fl.order_placement_date
group by d.week_no

-- Which product was most and least ordered bt each customer?

with product as (
select c.customer_name,
       p.product_name,
       count(fl.product_id) as product_count
from fact_order_lines as fl
left join dim_products as p
using(product_id)
left join dim_customers as c
using(customer_id)
group by c.customer_name, p.product_name
order by product_count desc), 
with product_rank as (
select customer_name,
       product_name,
       rank() over(partition by customer_name order by product_count desc) as max_rank,
       rank() over(partition by customer_name order by product_count asc) as min_rank
from product
)

select customer_name,
       max(case when max_rank = 1 then product_name end) as most_order_product,
       min(case when min_rank = 1 then product_name end) as min_order_product
from x
group by customer_name;

-- Which product category has the highest delivery delay?

select p.category,
       avg(datediff(fl.actual_delivery_date, fl.agreed_delivery_date)) as delay
from fact_order_lines as fl
left join dim_products as p
using(product_id)
group by p.category;

select p.product_name,
       avg(datediff(fl.actual_delivery_date, fl.agreed_delivery_date)) as delay
from fact_order_lines as fl
left join dim_products as p
using(product_id)
group by p.product_name
order by delay desc;

-- Week over week business performance

select d.week_no,
       sum(fl.order_qty) as order_quantity,
       sum(case when fa.on_time= 1 then 1 else 0 end) * 100 / count(fa.order_id) as OT,
       sum(case when fa.in_full = 1 then 1 else 0 end) * 100 / count(fa.order_id) as In_full,
       sum(case when fa.otif = 1 then 1 else 0 end) * 100 / count(fa.order_id) as OTIF
from fact_order_lines as fl
left join fact_orders_aggregate as fa
using(customer_id)
left join dim_date as d
on d.date = fl.order_placement_date
group by d.week_no

-- Each product delay count

select avg(datediff(actual_delivery_date,agreed_delivery_date


-- 
WITH x AS (
SELECT week_no, COUNT (DISTINCT (order_id)) AS orders
FROM dim_date as d
LEFT JOIN fact_order_lines as f
ON d.date = f.order_placement_date
GROUP BY week_no
ORDER BY week_no),
y AS (
SELECT week_no, orders, LAG(orders, 1,0) OVER(ORDER BY week_no ASC) AS previous _week_orders
FROM x)
SELECT week_no, orders, previous_week_orders,
IFNULL (ROUND(((orders/previous_week_orders)-1)*100,2),0) AS percentage_change
FROM y;

-- 
SELECT 
    WEEKDAY(order_placement_date) AS Day_no,
    CASE WEEKDAY(order_placement_date)
		WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednwsday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
     END AS Day_Name,  
	COUNT(order_id) AS Total_orders
 FROM 
	fact_order_lines
 GROUP BY 
	Day_no, Day_Name
 ORDER BY 
    Total_orders DESC;
    
--
select 
     case when datediff(fl.actual_delivery_date,fl.agreed_delivery_date) = 1 then 1
          when datediff(fl.actual_delivery_date,fl.agreed_delivery_date) = 2 then 2
          when datediff(fl.actual_delivery_date,fl.agreed_delivery_date) = 3 then 3
          else 0 end as delivery_days,
	 count(distinct(case when p.category = 'Dairy' then fa.order_id else 0 end)) as dairy,
     count(distinct(case when p.category = 'Food' then fa.order_id else 0 end)) as Food,
     count(distinct(case when p.category = 'beverages' then fa.order_id else 0 end)) as Beverage
from fact_order_lines as fl
left join dim_products as p
using(product_id)
left join fact_orders_aggregate as fa
on fl.customer_id = fa.customer_id
group by delivery_days
order by delivery_days asc