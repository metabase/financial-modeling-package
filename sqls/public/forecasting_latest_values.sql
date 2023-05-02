with quarterly_arr as (
  select
    *
    , MAX(quarter) over () as latest_quarter
    , SUBSTRING(quarter_name FROM 2 FOR 1) as quarter_label
    , EXTRACT(year from quarter) as year
  from {quarterly_arr} arr

), quarterly_customers as (
  select
    *
    , MAX(quarter) over () as latest_quarter
    , SUBSTRING(quarter_name FROM 2 FOR 1) as quarter_label
    , EXTRACT(year from quarter) as year
  from {quarterly_customers} customers

), quarterly_trialers as (
  select
    *
    , MAX(quarter) over () as latest_quarter
    , SUBSTRING(quarter_name FROM 2 FOR 1) as quarter_label
    , EXTRACT(year from quarter) as year
  from {quarterly_trialers} trialers

), arr as (
select
    quarter_name
    , quarter
    , quarter_label
    , year
    , 'Latest Ending ARR' as metric
    , ending_arr as value
from quarterly_arr
where quarter = latest_quarter

union all

select
    quarter_name
    , quarter
    , quarter_label
    , year
    , 'Latest Expansion ARR' as metric
    , expansion_arr as value
from quarterly_arr
where quarter = latest_quarter

), customers as (

select
    quarter_name
    , quarter
    , quarter_label
    , year
    , 'Latest Monthly Average Churn Rate' as metric
    , avg_monthly_churn as value
from quarterly_customers
where quarter = latest_quarter

union all

select
    quarter_name
    , quarter
    , quarter_label
    , year
    , 'Latest Ending # Customers' as metric
    , ending_customers as value
from quarterly_customers
where quarter = latest_quarter

), trialers as (

select
    quarter_name
    , quarter
    , quarter_label
    , year
    , 'Latest Trial Conversion Rate' as metric
    , trial_conversion_rate as value
from quarterly_trialers
where quarter = latest_quarter

union all

select
    quarter_name
    , quarter
    , quarter_label
    , year
    , 'Latest New Trialers Rate ' as metric
    , quarterly_trialer_rate as value
from quarterly_trialers
where quarter = latest_quarter

union all

select
    quarter_name
    , quarter
    , quarter_label
    , year
    , 'Latest # Trialers' as metric
    , num_trialers as value
from quarterly_trialers
where quarter = latest_quarter

), acv as (

select
    quarter_name
    , quarter
    , quarter_label
    , year
    , 'Latest Annual Contract Value' as metric
    , 1.0 * ending_arr / ending_customers as value
from quarterly_customers
left join quarterly_arr
    using (quarter, quarter_name, quarter_label, year)
where quarterly_customers.quarter = quarterly_customers.latest_quarter
    and quarterly_arr.quarter = quarterly_arr.latest_quarter

)

select * from arr

union all

select * from customers

union all

select * from trialers

union all

select * from acv

order by quarter