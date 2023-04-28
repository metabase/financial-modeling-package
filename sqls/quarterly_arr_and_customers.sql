with customer_summary as (
  select
    stripe_customer_id
    , min(date_trunc('month', recognized_at))::date as min_month_per_customer
    , max(date_trunc('month', recognized_at))::date as max_month_per_customer
  from {revenue} invoice
  group by 1

), months_per_customer as (
  select
    *
  from customer_summary 
  join generate_series(min_month_per_customer, max_month_per_customer + interval '1 month', '1 month'::interval) month on true

),

month_summary as (
  select
    months_per_customer.month
    , months_per_customer.stripe_customer_id
    , rev.customer_name
    , sum(rev.amount) as total_per_customer
   from {revenue} rev
   full outer join months_per_customer
     on months_per_customer.month::date = rev.month
       and months_per_customer.stripe_customer_id = rev.stripe_customer_id
  group by 1,2,3

), summary_including_previous_values as (
    select
        *
        , lag(total_per_customer) over (partition by stripe_customer_id order by month) as total_per_customer_previous_month
        , lead(total_per_customer) over (partition by stripe_customer_id order by month) as total_per_customer_next_month
    from month_summary

), status as (
  select
    *
    , case when total_per_customer_previous_month is null then 1 else 0 end as is_new
    , case when total_per_customer_next_month is null then 1 else 0 end as is_churned
    , case when total_per_customer_previous_month is not null and total_per_customer is not null then 1 else 0 end as is_retained
  from summary_including_previous_values as rev

), quarter as (
  select
    concat(case when extract('month' from date_trunc('quarter', month)) = 1 then 'Q1 '
             when extract('month' from date_trunc('quarter', month)) = 4 then 'Q2 '
             when extract('month' from date_trunc('quarter', month)) = 7 then 'Q3 '
             when extract('month' from date_trunc('quarter', month)) = 10 then 'Q4 '
           end, extract('year' from month)) as quarter
    , date_trunc('quarter', month)::date as quarter_at
    , stripe_customer_id
    , customer_name
    , sum(total_per_customer) as total_per_customer
    , max(is_new) as is_new
    , max(is_churned) as is_churned
    , max(is_retained) as is_retained
  from status
  group by 1,2,3,4

), quarters_new_customers as (
  select
    quarter
    , quarter_at
    , 'New' as status
    , count(distinct stripe_customer_id) as customers
  from quarter
  where is_new = 1
  group by 1,2,3

), quarters_churned_customers as (
  select
    quarter
    , quarter_at
    , 'Churn' as status
    , count(distinct stripe_customer_id) * -1 as customers
  from quarter
  where is_churned = 1
  group by 1,2,3

),  quarters_retained_customers as (
  select
    quarter
    , quarter_at
    , 'Beginning' as status
    , count(distinct stripe_customer_id) as customers
  from quarter
  where is_retained = 1 and is_new = 0
  group by 1,2,3

), unioned as (
  select
    *
    , sum(customers) over (partition by quarter order by quarter_at) as ending_customers
  from (
    select * from quarters_new_customers
    UNION
    select * from quarters_churned_customers
    UNION
    select * from quarters_retained_customers) u
  order by quarter_at desc

), quarterly_customers as (
  select
    quarter
    , quarter_at
    , status
    , customers
    , ending_customers
from unioned
where quarter_at < date_trunc('quarter', current_date) -- remove current, incomplete quarter

) , quarterly_arrs as (
  select
    quarter
    , quarter_at
    , 'New' as status
    , new_rev * 4 as arr
    , ending_rev * 4 as ending_arr
  from {quarterly_revenue} rev
  where quarter_at < date_trunc('quarter', current_date) -- remove current, incomplete quarter
  
  union all
  
  select
    quarter
    , quarter_at
    , 'Churn' as status
    , churn_rev * 4 as arr
    , ending_rev * 4 as ending_arr
  from {quarterly_revenue} rev
  where quarter_at < date_trunc('quarter', current_date) -- remove current, incomplete quarter
  
  union all
  
  select
    quarter
    , quarter_at
    , 'Beginning' as status
    , beginning_rev_lag * 4 as arr
    , ending_rev * 4 as ending_arr
  from {quarterly_revenue} rev
  where quarter_at < date_trunc('quarter', current_date) -- remove current, incomplete quarter
  
  union all
  
  select
    quarter
    , quarter_at
    , 'Expansion' as status
    , expansion_rev * 4 as arr
    , ending_rev * 4 as ending_arr
  from {quarterly_revenue} rev
  where quarter_at < date_trunc('quarter', current_date) -- remove current, incomplete quarter
  
  union all
  
  select
    quarter
    , quarter_at
    , 'Contraction' as status
    , contraction_rev * 4 as arr
    , ending_rev * 4 as ending_arr
  from {quarterly_revenue} rev
  where quarter_at < date_trunc('quarter', current_date) -- remove current, incomplete quarter

), quarterly_arrs_and_customers as (
    select
      coalesce(a.quarter, c.quarter) as quarter
      , coalesce(a.quarter_at, c.quarter_at) as quarter_at
      , coalesce(a.status, c.status) as status
      , customers
      , ending_customers
      , arr
      , ending_arr
    from quarterly_customers c
    full join quarterly_arrs a
        on c.quarter = a.quarter and c.status = a.status
), final as (
  select
    *
    , lag(ending_arr, 4) over (partition by status order by quarter_at) as last_year_arr_value
    , lag(ending_customers, 4) over (partition by status order by quarter_at) as last_year_customer_value
from quarterly_arrs_and_customers
)

select * from final order by quarter_at desc
