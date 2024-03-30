
# Project Title

A brief description of what this project does and who it's for


## Deployment

To deploy this project run

```bash
  SELECT 
       fl.customer_id,
       round((sum(case when fa.in_full = 1 then 1 else 0 end) * 100 / count(fa.order_id)),2) as 'LIFR%',
       sum(fl.delivery_qty) * 100 / sum(fl.order_qty) as 'VOFR%'
FROM fact_order_lines as fl
inner join fact_orders_aggregate as fa
using(customer_id)
group by fl.customer_id
```

