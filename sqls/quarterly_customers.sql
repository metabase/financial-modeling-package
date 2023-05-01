with monthly_customers as (
  select
    *
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
  from {monthly_customers} r

), ending_customers as (
  select
    quarter
    , quarter_at
    , month
    , ending_customers
    , lead(date_trunc('quarter', month)::date) over (order by month) as next_quarter
  from monthly_customers

), beginning_ending_customers as (
  select
      quarter
      , quarter_at
      , lag(ending_customers) over (order by quarter_at) as beginning_customers
      , ending_customers
  from ending_customers
  where quarter_at != next_quarter

), monthly_changing_customers as (
  select
    quarter
    , quarter_at
    , sum(new_customers) as new_customers
    , sum(churn_customers) as churn_customers
  from monthly_customers
  group by 1,2

),  all_customers as (
  select
    quarter
    , quarter_at
    , beginning_customers
    , new_customers
    , churn_customers
    , ending_customers
    , lag(ending_customers, 4) over (order by quarter_at) as last_year_customers
    , lag(ending_customers) over (order by quarter_at) as last_quarter_customers
  from monthly_changing_customers
  full outer join beginning_ending_customers
  using (quarter, quarter_at)
  order by quarter_at asc

), final as (
  select
    quarter
    , quarter_at
    , beginning_customers
    , new_customers
    , churn_customers
    , ending_customers
    , 1.0*(ending_customers - last_year_customers) / last_year_customers as yearly_growth_rate
    , 1.0* ending_customers/last_quarter_customers as quarterly_growth_rate
    , -1.0*churn_customers/ending_customers as churn_rate
  from all_customers
  where quarter_at < date_trunc('quarter', current_date) -- remove current incomplete quarter

)

select * from final
order by quarter_at
