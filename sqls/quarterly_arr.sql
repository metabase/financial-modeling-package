with monthly_arr as (
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
  from {monthly_arr} r

), ending_arrs as (
  select
    quarter
    , quarter_at
    , month
    , ending_arr
    , lead(date_trunc('quarter', month)::date) over (order by month) as next_quarter
  from monthly_arr

), beginning_ending_arrs as (
  select
      quarter
      , quarter_at
      , lag(ending_arr) over (order by quarter_at) as beginning_arr
      , ending_arr
  from ending_arrs
  where quarter_at != next_quarter

), changing_arrs as (
  select
    quarter
    , quarter_at
    , sum(new_arr) as new_arr
    , sum(expansion_arr) as expansion_arr
    , sum(contraction_arr) as contraction_arr
    , sum(churn_arr) as churn_arr
  from monthly_arr
  group by 1,2

),  all_arrs as (
  select
    quarter
    , quarter_at
    , beginning_arr
    , new_arr
    , expansion_arr
    , contraction_arr
    , churn_arr
    , ending_arr
    , lag(ending_arr, 4) over (order by quarter_at) as last_year_arr
    , lag(ending_arr) over (order by quarter_at) as last_quarter_arr
  from changing_arrs
  full outer join beginning_ending_arrs
  using (quarter, quarter_at)
  order by quarter_at asc

), final as (
  select
    quarter
    , quarter_at
    , beginning_arr
    , new_arr
    , expansion_arr
    , contraction_arr
    , churn_arr
    , ending_arr
    , (ending_arr - last_year_arr) / last_year_arr as yearly_growth_rate
    , 1.0 * ending_arr / last_quarter_arr as quarterly_growth_rate
    , 1.0 * expansion_arr / ending_arr as expansion_rate
  from all_arrs
  where quarter_at < date_trunc('quarter', current_date) -- remove current incomplete quarter

)

select * from final
