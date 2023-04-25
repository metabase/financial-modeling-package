with month_summary as (
select distinct
  date_trunc('month', recognized_at)::date as month
  , stripe_subscription_id
  , stripe_customer_id
  , customer_name
  , sum(amount) over (partition by date_trunc('month', recognized_at)::date, stripe_subscription_id) as total_per_subscription
  , sum(amount) over (partition by date_trunc('month', recognized_at)::date, stripe_customer_id) as total_per_customer
from {monthly_revenue} as rev
)

, month_summary_w_previous as (
select
  *
  , lag(total_per_customer) over (partition by stripe_subscription_id order by month) as total_per_customer_previous_month
  , lead(total_per_customer) over (partition by stripe_subscription_id order by month) as total_per_customer_next_month
from month_summary
)

, status as (
select
  *
  , case when total_per_customer_previous_month is null then 1 else 0 end as is_new
  , case when total_per_customer_next_month is null then 1 else 0 end as is_churned
  , case when total_per_customer_previous_month is not null and total_per_customer is not null then 1 else 0 end as is_retained
from month_summary_w_previous
)

, quarter as (
select
  concat(case when extract('month' from date_trunc('quarter', month)) = 1 then 'Q1 '
           when extract('month' from date_trunc('quarter', month)) = 4 then 'Q2 '
           when extract('month' from date_trunc('quarter', month)) = 7 then 'Q3 '
           when extract('month' from date_trunc('quarter', month)) = 10 then 'Q4 '
         end, extract('year' from month)) as quarter
  , stripe_subscription_id
  , stripe_customer_id
  , customer_name
  , date_trunc('quarter', month) as quarter_at
  , sum(total_per_subscription) as total_per_subscription
  , sum(total_per_customer) as total_per_customer
  , max(is_new) as is_new
  , max(is_churned) as is_churned
  , max(is_retained) as is_retained
from status
group by 1,2,3,4,5

), quarters_arr_new_customers as (

select
    quarter,
    quarter_at,
    'New' as status,
    4*sum(total_per_customer) as arr, -- since we are doing per quarter and not per month, we multiply by 4
    count(distinct stripe_customer_id) as customers
    from quarter
    where
        is_new = 1
    group by 1,2,3

), quarters_arr_churned_customers as (

select
    quarter,
    quarter_at,
    'Churned' as status,
    4*sum(total_per_customer) as arr,
    count(distinct stripe_customer_id) as customers
    from quarter
    where
        is_churned = 1
    group by 1,2,3

),  quarters_arr_retained_customers as (

select
    quarter,
    quarter_at,
    'Retained' as status,
    4*sum(total_per_customer) as arr,
    count(distinct stripe_customer_id) as customers
    from quarter
    where
        is_retained = 1
    group by 1,2,3
)

select
    *
from quarters_arr_new_customers
UNION select * from quarters_arr_churned_customers
UNION select * from quarters_arr_retained_customers
order by quarter_at desc
