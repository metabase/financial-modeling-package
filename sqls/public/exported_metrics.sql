with quarterly_arr as (
  select * from {quarterly_arr} arr

), quarterly_customers as (
  select * from {quarterly_customers} customers

), quarterly_trialers as (
  select * from {quarterly_trialers} trialers

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
    , 'Avg Monthly Customer Churn Rate' as metric
    , avg_monthly_churn as value
  from quarterly_customers customers
  where avg_monthly_churn is not null

), acv as (

select
    quarter
    , quarter_name
    , 'Annual Contract Value' as metric
    , 1.0 * ending_arr / ending_customers as value
from quarterly_customers customers
left join quarterly_arr arr
    using (quarter, quarter_name)

), trialers as (

select
    quarter
    , quarter_name
    , 'Trial Quarterly Conversion Rate' as metric
    , trial_conversion_rate as value
 from quarterly_trialers

 union all

 select
    quarter
    , quarter_name
    , 'Trialer % Quarterly growth ' as metric
    , quarterly_trialer_rate as value
 from quarterly_trialers

), final as (
  select * from arrs

  union all

  select * from customers

  union all

  select * from acv

  union all

  select * from trialers

)

select * from final
order by quarter desc
