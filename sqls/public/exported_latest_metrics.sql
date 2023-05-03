with quarterly_arr as (
  select
    *
    , max(quarter) over () as latest_quarter
    , substring(quarter_name from 2 for 1)::int as quarter_number
    , extract(year from quarter) as year
  from {quarterly_arr} arr

), quarterly_customers as (
  select
    *
    , max(quarter) over () as latest_quarter
    , substring(quarter_name from 2 for 1)::int as quarter_number
    , extract(year from quarter) as year
  from {quarterly_customers} customers

), quarterly_trialers as (
  select
    *
    , max(quarter) over () as latest_quarter
    , substring(quarter_name from 2 for 1)::int as quarter_number
    , extract(year from quarter) as year
  from {quarterly_trialers} trialers

), arr as (
  select
      'Latest Ending ARR' as metric
      , ending_arr as value
  from quarterly_arr
  where quarter = latest_quarter

  union all

  select
      'Latest Expansion ARR' as metric
      , expansion_arr as value
  from quarterly_arr
  where quarter = latest_quarter

  union all

  select
      'Latest Expansion Rate' as metric
      , expansion_rate as value
  from quarterly_arr
  where quarter = latest_quarter

  ), customers as (

  select
      'Latest Monthly Average Churn Rate' as metric
      , avg_monthly_churn as value
  from quarterly_customers
  where quarter = latest_quarter

  union all

  select
      'Latest Ending # Customers' as metric
      , ending_customers as value
  from quarterly_customers
  where quarter = latest_quarter

), trialers as (

  select
      'Latest Trial Conversion Rate' as metric
      , trial_conversion_rate as value
  from quarterly_trialers
  where quarter = latest_quarter

  union all

  select
      'Latest New Trialers Rate ' as metric
      , quarterly_trialer_rate as value
  from quarterly_trialers
  where quarter = latest_quarter

  union all

  select
      'Latest # Trialers' as metric
      , num_trialers as value
  from quarterly_trialers
  where quarter = latest_quarter

), acv as (

  select
      'Latest Annual Contract Value' as metric
      , 1.0 * ending_arr / ending_customers as value
  from quarterly_customers
  left join quarterly_arr
      using (quarter, quarter_name, quarter_number, year)
  where quarterly_customers.quarter = quarterly_customers.latest_quarter
      and quarterly_arr.quarter = quarterly_arr.latest_quarter

), final as (
  select 'Latest Year' as metric, year as value from quarterly_arr where quarter = latest_quarter

  union all

  select 'Latest Quarter' as metric, quarter_number as value from quarterly_arr where quarter = latest_quarter

  union all

  select * from arr

  union all

  select * from customers

  union all

  select * from trialers

  union all

  select * from acv

)

select * from final
