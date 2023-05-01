with arrs as (
  select
    quarter_name
    , quarter
    , 'Beginning ARR' as metric
    , beginning_arr as value
  from {quarterly_arr} arr

  union all

  select
    quarter_name
    , quarter
    , 'New ARR' as metric
    , new_arr as value
  from {quarterly_arr} arr

  union all

  select
    quarter_name
    , quarter
    , 'Expansion ARR' as metric
    , expansion_arr as value
  from {quarterly_arr} arr

  union all

  select
    quarter_name
    , quarter
    , 'Contraction ARR' as metric
    , contraction_arr as value
  from {quarterly_arr} arr

  union all

  select
    quarter_name
    , quarter
    , 'Churn ARR' as metric
    , churn_arr as value
  from {quarterly_arr} arr

  union all

  select
    quarter_name
    , quarter
    , 'Ending ARR' as metric
    , ending_arr as value
  from {quarterly_arr} arr

  union all

  select
    quarter_name
    , quarter
    , 'ARR % YoY growth' as metric
    , yearly_growth as value
  from {quarterly_arr} arr
  where yearly_growth is not null

), customers as (
  select
    quarter_name
    , quarter
    , 'Beginning customers' as metric
    , beginning_customers as value
  from {quarterly_customers} customers

  union all

  select
    quarter_name
    , quarter
    , 'New customers' as metric
    , new_customers as value
  from {quarterly_customers} arr

  union all

  select
    quarter_name
    , quarter
    , 'Churn customers' as metric
    , churn_customers as value
  from {quarterly_customers} arr

  union all

  select
    quarter_name
    , quarter
    , 'Ending customers' as metric
    , ending_customers as value
  from {quarterly_customers} arr

  union all

  select
    quarter_name
    , quarter
    , 'Customers % YoY growth' as metric
    , yearly_growth as value
  from {quarterly_customers} arr
  where yearly_growth is not null

), final as (
  select * from arrs

  union all

  select * from customers

)

select * from final
order by quarter desc
