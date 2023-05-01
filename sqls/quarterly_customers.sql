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
    ) as quarter_name
    , date_trunc('quarter', month)::date as quarter
  from {monthly_customers} r

), ending_customers as (
  select
    quarter_name
    , quarter
    , month
    , ending_customers
    , lead(date_trunc('quarter', month)::date) over (order by month) as next_quarter
  from monthly_customers

), beginning_ending_customers as (
  select
      quarter_name
      , quarter
      , lag(ending_customers) over (order by quarter) as beginning_customers
      , ending_customers
  from ending_customers
  where quarter != next_quarter

), monthly_changing_customers as (
  select
    quarter_name
    , quarter
    , sum(new_customers) as new_customers
    , sum(churn_customers) as churn_customers
  from monthly_customers
  group by 1,2

),  all_customers as (
  select
    quarter_name
    , quarter
    , beginning_customers
    , new_customers
    , churn_customers
    , ending_customers
    , lag(ending_customers, 4) over (order by quarter) as last_year_customers
    , lag(ending_customers) over (order by quarter) as last_quarter_customers

  from monthly_changing_customers
  full outer join beginning_ending_customers
  using (quarter_name, quarter)
  order by quarter asc

), final as (
  select
    quarter_name
    , quarter
    , beginning_customers
    , new_customers
    , churn_customers
    , ending_customers
    , 1.0*(ending_customers - last_year_customers) / last_year_customers as yearly_growth_rate
    , 1.0* ending_customers/last_quarter_customers as quarterly_growth_rate
    , -1.0*churn_customers/ending_customers as churn_rate
  from all_customers
  where quarter < date_trunc('quarter', current_date) -- remove current incomplete quarter_name

)

select * from final
order by quarter
