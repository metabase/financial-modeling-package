with ending_arr as (
  select distinct
    quarter
    , quarter_at
    , 'Ending ARR' as metric
    , ending_arr as value
  from {quarterly_arr_and_customers} ending_arr

), ending_customers as (
  select distinct
    quarter
    , quarter_at
    , 'Ending customers' as metric
    , ending_customers as value
  from {quarterly_arr_and_customers} ending_customers

), arr as (
  select
    quarter
    , quarter_at
    , concat(status, ' ARR') as metric
    , arr as value
  from {quarterly_arr_and_customers} arr

), customers as (
  select
    quarter
    , quarter_at
    , concat(status, ' customers') as metric
    , customers as value
  from {quarterly_arr_and_customers} customers
  where status not in ('Expansion', 'Contraction')

), yearly_arr as (
  select distinct
    quarter
    , quarter_at
    , 'ARR % YoY growth' as metric
    , (ending_arr - last_year_arr_value)/coalesce(last_year_arr_value, 1) value
  from {quarterly_arr_and_customers} customers
  where last_year_arr_value is not null

), yearly_customers as (
  select distinct
    quarter
    , date(quarter_at) as quarter_at
    , 'Customers % YoY growth' as metric
    , (ending_customers - last_year_customer_value)/coalesce(last_year_customer_value, 1) as value
  from {quarterly_arr_and_customers} customers
  where last_year_customer_value is not null

), final as (
  select * from ending_arr
  union all
  select * from ending_customers
  union all
  select * from arr
  union all
  select * from customers
  union all
  select * from yearly_arr
  union all
  select * from yearly_customers
)

select * from final
order by 2 desc
