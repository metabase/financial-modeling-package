with revenue as (
  select * from {revenue} rev

), customer_summary as (
  select
    stripe_customer_id
    , min(date_trunc('month', recognized_at))::date as min_month_per_customer
    , max(date_trunc('month', recognized_at))::date as max_month_per_customer
  from revenue
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
    , revenue.customer_name
    , sum(revenue.amount) as total_per_customer
   from revenue
   full outer join months_per_customer
     on months_per_customer.month::date = revenue.month
       and months_per_customer.stripe_customer_id = revenue.stripe_customer_id
  group by 1,2,3

 ), summary_including_previous_values as (
    select
        *
        , lag(total_per_customer) over (partition by stripe_customer_id order by month) as total_per_customer_previous_month
        , lead(total_per_customer) over (partition by stripe_customer_id order by month) as total_per_customer_next_month
    from month_summary

), monthly_revenue as (
  select distinct
    month::date as month
    , stripe_customer_id
    , coalesce(total_per_customer_previous_month, 0) as beginning_rev
    , total_per_customer as ending_rev
    , total_per_customer_next_month as total_next_month
    , case
        when total_per_customer_previous_month is null then total_per_customer
        else 0
      end as new_rev
    , case
        when total_per_customer_previous_month < total_per_customer then (total_per_customer - total_per_customer_previous_month)
        else 0
      end as expansion_rev
    , case
        when total_per_customer_previous_month > total_per_customer then (total_per_customer - total_per_customer_previous_month)
        else 0
      end as contraction_rev
    , case
        when month < date_trunc('month', current_date)::date and total_per_customer_previous_month is not null and total_per_customer is null
          then (-1 * total_per_customer_previous_month)
        else 0
      end as churn_rev
from summary_including_previous_values

), monthly_summary as (
  select
    month
    , sum(new_rev) as new_rev
    , sum(expansion_rev) as expansion_rev
    , sum(contraction_rev) as contraction_rev
    , sum(churn_rev) as churn_rev
    , lag(sum(ending_rev)) over (order by month) as beginning_rev
    , sum(ending_rev) as ending_rev
  from monthly_revenue
  group by 1

), final as (
  select
    month
    , beginning_rev * 12 as beginning_arr
    , new_rev * 12 as new_arr
    , expansion_rev * 12 as expansion_arr
    , contraction_rev * 12 as contraction_arr
    , churn_rev * 12 as churn_arr
    , ending_rev * 12 as ending_arr
  from monthly_summary
  where month <= date_trunc('month', current_date) -- remove next incomplete month
  order by 1

)

select * from final
