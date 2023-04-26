with month_summary as (
  select distinct
    date_trunc('month', recognized_at)::date as month
    , stripe_subscription_id
    , stripe_customer_id
    , customer_name
    , sum(amount) over (partition by date_trunc('month', recognized_at)::date, stripe_subscription_id) as total_per_subscription
    , sum(amount) over (partition by date_trunc('month', recognized_at)::date, stripe_customer_id) as total_per_customer
  from {monthly_revenue} as rev

), month_summary_w_previous as (
  select
    *
    , lag(total_per_customer) over (partition by stripe_subscription_id order by month) as total_per_customer_previous_month
    , lead(total_per_customer) over (partition by stripe_subscription_id order by month) as total_per_customer_next_month
  from month_summary

), status as (
  select
    *
    , case when total_per_customer_previous_month is null then 1 else 0 end as is_new
    , case when total_per_customer_next_month is null then 1 else 0 end as is_churned
    , case when total_per_customer_previous_month is not null and total_per_customer is not null then 1 else 0 end as is_retained
  from month_summary_w_previous

), quarter as (
  select
    concat(case when extract('month' from date_trunc('quarter', month)) = 1 then 'Q1 '
             when extract('month' from date_trunc('quarter', month)) = 4 then 'Q2 '
             when extract('month' from date_trunc('quarter', month)) = 7 then 'Q3 '
             when extract('month' from date_trunc('quarter', month)) = 10 then 'Q4 '
           end, extract('year' from month)) as quarter
    , date_trunc('quarter', month)::date as quarter_at
    , stripe_subscription_id
    , stripe_customer_id
    , customer_name
    , sum(total_per_subscription) as total_per_subscription
    , sum(total_per_customer) as total_per_customer
    , max(is_new) as is_new
    , max(is_churned) as is_churned
    , max(is_retained) as is_retained
  from status
  group by 1,2,3,4,5

), quarters_arr_new_customers as (
  select
    quarter
    , quarter_at
    , 'New' as status
    , 4 * sum(total_per_customer) as arr -- since we are doing per quarter and not per month, we multiply by 4
    , count(distinct stripe_customer_id) as customers
  from quarter
  where is_new = 1
  group by 1,2,3

), quarters_arr_churned_customers as (
  select
    quarter
    , quarter_at
    , 'Churn' as status
    , -4 * sum(total_per_customer) as arr
    , count(distinct stripe_customer_id) * -1 as customers
  from quarter
  where is_churned = 1
  group by 1,2,3

),  quarters_arr_retained_customers as (
  select
    quarter
    , quarter_at
    , 'Beginning' as status
    , 4 * sum(total_per_customer) as arr
    , count(distinct stripe_customer_id) as customers
  from quarter
  where is_retained = 1 and is_new = 0
  group by 1,2,3

), unioned as (
  select
    *
    , sum(customers) over (partition by quarter order by quarter_at) as ending_customers
    , sum(arr) over (partition by quarter order by quarter_at) as ending_arr
  from (
    select * from quarters_arr_new_customers
    UNION
    select * from quarters_arr_churned_customers
    UNION
    select * from quarters_arr_retained_customers) u
  order by quarter_at desc

), quarterly_arr_and_customers as (
  select
    quarter
    , quarter_at
    , status
    , arr
    , customers
--    , case when status = 'Beginning' then coalesce(lag(ending_customers) over (partition by status order by quarter_at), customers)
--        when status != 'Beginning' then customers
--      end as customers
    , ending_customers
    , ending_arr
from unioned
where quarter_at < date_trunc('quarter', current_date) -- remove current, incomplete quarter

), final as (
  select
    *
    , lag(ending_arr, 4) over (partition by status order by quarter_at) as last_year_arr_value
    , lag(ending_customers, 4) over (partition by status order by quarter_at) as last_year_customer_value
from quarterly_arr_and_customers
)

select * from final order by quarter_at desc