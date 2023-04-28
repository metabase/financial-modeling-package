with arrs as (
  select
    quarter
    , quarter_at
    , 'Beginning ARR' as metric
    , beginning_arr as value
  from {quarterly_arr} arr

  union all

  select
    quarter
    , quarter_at
    , 'New ARR' as metric
    , new_arr as value
  from {quarterly_arr} arr

  union all

  select
    quarter
    , quarter_at
    , 'Expansion ARR' as metric
    , expansion_arr as value
  from {quarterly_arr} arr

  union all

  select
    quarter
    , quarter_at
    , 'Contraction ARR' as metric
    , contraction_arr as value
  from {quarterly_arr} arr

  union all

  select
    quarter
    , quarter_at
    , 'Churn ARR' as metric
    , churn_arr as value
  from {quarterly_arr} arr

  union all

  select
    quarter
    , quarter_at
    , 'Ending ARR' as metric
    , ending_arr as value
  from {quarterly_arr} arr

  union all

  select
    quarter
    , quarter_at
    , 'ARR % YoY growth' as metric
    , yearly_growth as value
  from {quarterly_arr} arr
  where yearly_growth is not null

), customers as (
  select
    quarter
    , quarter_at
    , concat(status, ' customers') as metric
    , customers as value
  from {quarterly_arr_and_customers} customers
  where status not in ('Expansion', 'Contraction')

  union all

  select distinct
    quarter
    , quarter_at
    , 'Ending customers' as metric
    , ending_customers as value
  from {quarterly_arr_and_customers} ending_customers

  union all

  select distinct
    quarter
    , date(quarter_at) as quarter_at
    , 'Customers % YoY growth' as metric
    , (ending_customers - last_year_customer_value)/coalesce(last_year_customer_value, 1) as value
  from {quarterly_arr_and_customers} customers
  where last_year_customer_value is not null

), final as (
  select * from arrs

  union all

  select * from customers

)

select * from final
order by 2 desc
