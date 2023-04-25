with revenue as (
  select
    date_trunc('month', recognized_at)::date as month
    , product_name
    , 12 * sum(amount) as arr
    , count(distinct stripe_customer_id) as customers
  from {monthly_revenue} as revenue
  group by 1, 2
  order by 1 desc, 2

), financial_month_series as (
    select
        month::date
    from generate_series(date('2018-01-01'), CURRENT_DATE, '1 month') as month
),
 final as (
  select
    coalesce(revenue.month, fms.month) as month
    , product_name
    , arr
    , customers
    , LAG(arr) OVER (PARTITION by product_name order by coalesce(revenue.month, fms.month)) as previous_month_arr
    , LAG(customers) OVER (PARTITION by product_name order by coalesce(revenue.month, fms.month)) as previous_month_customers
  from revenue
  full join financial_month_series fms
    on revenue.month = fms.month

)

select * from final
