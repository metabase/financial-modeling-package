
-- arr logic
-- We need to break up beginning ARR, Expansion ARR, New ARR and Churn ARR
-- New ARR is sum of amount for when you are a new user and you did not upgrade or downgrade
-- chrun arr is for when you qualify as churned and you did not upgrade or downgrade
-- expansion is the sum of the amount for when you upgrade and downgrade
--Beginning ARR = everyone who is not new or churned who also did not upgrade or downgrade

with monthly_customer_summary as (
  select distinct
    month
    , concat(
            case
                when extract('month' from date_trunc('quarter', month)) = 1 then 'Q1 '
                when extract('month' from date_trunc('quarter', month)) = 4 then 'Q2 '
                when extract('month' from date_trunc('quarter', month)) = 7 then 'Q3 '
                when extract('month' from date_trunc('quarter', month)) = 10 then 'Q4 '
             end,
            extract('year' from month)
        ) as quarter
    , date_trunc('quarter', month)::date as quarter_at
    , stripe_customer_id
    , total_per_customer_previous_month
    , total_per_customer_next_month
    , total_per_customer
    , case when total_per_customer_previous_month is null then 1 else 0 end as is_new
    , case when total_per_customer_next_month is null then 1 else 0 end as is_churned
    , case when total_per_customer_previous_month is not null and total_per_customer is not null then 1 else 0 end as is_retained
    , case when total_per_customer_previous_month > total_per_customer then 1 else 0 end as is_downgrade
    , case when total_per_customer_previous_month < total_per_customer then 1 else 0 end as is_upgrade
  from {monthly_revenue} as rev

), mini_expansion as (
    select
        quarter
        , quarter_at
        , sum(total_per_customer) as total_expansion
    from monthly_customer_summary
    where is_downgrade + is_upgrade > 0
    group by 1,2

), mini_new as (
    select
        quarter
        , quarter_at
        , sum(total_per_customer) as total_new
    from monthly_customer_summary
    where is_new = 1 and is_downgrade + is_upgrade =0
    group by 1,2

), mini_churned as (
    select
        quarter
        , quarter_at
        , sum(total_per_customer) * -1 as total_churned
    from monthly_customer_summary
    where is_churned = 1 and is_downgrade + is_upgrade =0
    group by 1,2

), mini_beginning as (
    select
        quarter
        , quarter_at
        , sum(total_per_customer) as total_beginning
    from monthly_customer_summary
    where is_newgit  = 0 is_downgrade + is_upgrade =0
    group by 1,2

), non_collapsed as (
select
    *
from mini_expansion
full outer join mini_new using (quarter, quarter_at)
full outer join mini_churned using (quarter, quarter_at)
full outer join mini_beginning using (quarter, quarter_at)

), revenue_summary as (
    select
        quarter
        , quarter_at
        , coalesce(total_expansion,0) as total_expansion
        , coalesce(total_new,0) as total_new
        , coalesce(total_churned,0) as total_churned
        , coalesce(total_beginning,0) as total_beginning
from non_collapsed
order by quarter_at desc

)

select distinct
    *
    , total_expansion + total_new + total_churned + total_beginning as total_ending
    , 4 * total_expansion as expansion_arr
    , 4 * total_new as new_arr
    , 4 * total_churned as churned_arr
    , 4 * total_beginning as beginning_arr
    , 4 * (total_expansion + total_new + total_churned + total_beginning) as ending_arr
from revenue_summary
order by quarter_at desc