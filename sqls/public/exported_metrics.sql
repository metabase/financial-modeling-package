with quarterly_arr as (
  select * from {quarterly_arr} arr

), quarterly_customers as (
  select * from {quarterly_customers} customers

), arrs as (
  select
    quarter
    , quarter_name
    , 'Beginning ARR' as metric
    , beginning_arr as value
  from quarterly_arr arr

  union all

  select
    quarter
    , quarter_name
    , 'New ARR' as metric
    , new_arr as value
  from quarterly_arr arr

  union all

  select
    quarter
    , quarter_name
    , 'Expansion ARR' as metric
    , expansion_arr as value
  from quarterly_arr arr

  union all

  select
    quarter
    , quarter_name
    , 'Contraction ARR' as metric
    , contraction_arr as value
  from quarterly_arr arr

  union all

  select
    quarter
    , quarter_name
    , 'Churn ARR' as metric
    , churn_arr as value
  from quarterly_arr arr

  union all

  select
    quarter
    , quarter_name
    , 'Ending ARR' as metric
    , ending_arr as value
  from quarterly_arr arr

  union all

  select
    quarter
    , quarter_name
    , 'ARR % YoY growth' as metric
    , yearly_growth_rate as value
  from quarterly_arr arr
  where yearly_growth_rate is not null

  union all

  select
    quarter
    , quarter_name
    , 'ARR % Quarterly growth' as metric
    , quarterly_growth_rate as value
  from quarterly_arr arr
  where quarterly_growth_rate is not null

  union all

  select
    quarter
    , quarter_name
    , 'ARR Quarterly Expansion Rate' as metric
    , expansion_rate as value
  from quarterly_arr arr
  where expansion_rate is not null

), customers as (
  select
    quarter
    , quarter_name
    , 'Beginning customers' as metric
    , beginning_customers as value
  from quarterly_customers customers

  union all

  select
    quarter
    , quarter_name
    , 'New customers' as metric
    , new_customers as value
  from quarterly_customers customers

  union all

  select
    quarter
    , quarter_name
    , 'Churn customers' as metric
    , churn_customers as value
  from quarterly_customers customers

  union all

  select
    quarter
    , quarter_name
    , 'Ending customers' as metric
    , ending_customers as value
  from quarterly_customers customers

  union all

  select
    quarter
    , quarter_name
    , 'Customers % YoY growth' as metric
    , yearly_growth_rate as value
  from quarterly_customers customers
  where yearly_growth_rate is not null

  union all

  select
    quarter
    , quarter_name
    , 'Customers % Quarterly growth' as metric
    , quarterly_growth_rate as value
  from quarterly_customers customers
  where quarterly_growth_rate is not null

  union all

  select
    quarter
    , quarter_name
    , 'Customer Quarterly Churn Rate' as metric
    , churn_rate as value
  from quarterly_customers customers
  where churn_rate is not null

), acv as (

select
    quarter
    , quarter_name
    , 'Annual Contract Value'
    , 1.0 * ending_arr / ending_customers as acv
from quarterly_customers customers
left join quarterly_arr arr
    using (quarter, quarter_name)

), final as (
  select * from arrs

  union all

  select * from customers

  union all

  select * from acv

)

select * from final
order by quarter desc
