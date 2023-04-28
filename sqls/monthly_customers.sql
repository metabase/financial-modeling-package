with customer_summary as (
  select
    stripe_customer_id
    , min(date_trunc('month', recognized_at))::date as min_month_per_customer
    , max(date_trunc('month', recognized_at))::date as max_month_per_customer
  from {revenue} rev
  group by 1

), months_per_customer as (
  select
    *
  from customer_summary
  join generate_series(min_month_per_customer, max_month_per_customer + interval '1 month', '1 month'::interval) month on true

), month_summary as (
  select
    months_per_customer.month
    , months_per_customer.stripe_customer_id
    , sum(rev.amount) as total_per_customer
   from {revenue} rev
   full outer join months_per_customer
     on months_per_customer.month::date = rev.month
       and months_per_customer.stripe_customer_id = rev.stripe_customer_id
  group by 1,2

 ), summary_including_previous_values as (
  select
    *
    , lag(total_per_customer) over (partition by stripe_customer_id order by month) as total_per_customer_previous_month
    , lead(total_per_customer) over (partition by stripe_customer_id order by month) as total_per_customer_next_month
  from month_summary

), monthly_status as (
  select distinct
    month::date as month
    , stripe_customer_id
    , total_per_customer_previous_month is null and total_per_customer > 0 as is_new
    , month < date_trunc('month', current_date)::date and total_per_customer_previous_month is not null and total_per_customer is null
      as is_churn
    , total_per_customer is not null and total_per_customer > 0 as is_paid
    , total_per_customer_previous_month is not null and total_per_customer is not null as is_retained
from summary_including_previous_values

), monthly_summary as (
    select
        month
        , count(distinct case when is_new then stripe_customer_id end) as new_customers
        , count(distinct case when is_churn then stripe_customer_id end) as churn_customers
        , count(distinct case when is_paid then stripe_customer_id end) as ending_customers
        , count(distinct case when is_retained then stripe_customer_id end) as retained_customers
    from monthly_status
    group by 1
)

select
    month
    , coalesce(lag(ending_customers) over (order by month),0) as beginning_customers
    , new_customers
    , -1 * coalesce(churn_customers,0) as churn_customers
    , ending_customers
from monthly_summary
where month <= date_trunc('month', current_date) -- remove next incomplete month
order by month
