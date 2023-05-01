with monthly_arr as (
  select
    *
    , concat(
        case
          when extract('month' from date_trunc('quarter_name', month)) = 1 then 'Q1 '
          when extract('month' from date_trunc('quarter_name', month)) = 4 then 'Q2 '
          when extract('month' from date_trunc('quarter_name', month)) = 7 then 'Q3 '
          when extract('month' from date_trunc('quarter_name', month)) = 10 then 'Q4 '
        end,
        extract('year' from month)
    ) as quarter_name
    , date_trunc('quarter', month)::date as quarter
  from {monthly_arr} r

), ending_arrs as (
  select
    quarter_name
    , quarter_name
    , month
    , ending_arr
    , lead(date_trunc('quarter', month)::date) over (order by month) as next_quarter
  from monthly_arr

), beginning_ending_arrs as (
  select
      quarter_name
      , quarter_name
      , lag(ending_arr) over (order by quarter_name) as beginning_arr
      , ending_arr
  from ending_arrs
  where quarter != next_quarter

), changing_arrs as (
  select
    quarter_name
    , quarter
    , sum(new_arr) as new_arr
    , sum(expansion_arr) as expansion_arr
    , sum(contraction_arr) as contraction_arr
    , sum(churn_arr) as churn_arr
  from monthly_arr
  group by 1,2

),  all_arrs as (
  select
    quarter_name
    , quarter
    , beginning_arr
    , new_arr
    , expansion_arr
    , contraction_arr
    , churn_arr
    , ending_arr
    , lag(ending_arr, 4) over (order by quarter) as last_year_arr
  from changing_arrs
  full outer join beginning_ending_arrs
  using (quarter_name, quarter)
  order by quarter asc

), final as (
  select
    quarter_name
    , quarter
    , beginning_arr
    , new_arr
    , expansion_arr
    , contraction_arr
    , churn_arr
    , ending_arr
    , (ending_arr - last_year_arr) / last_year_arr as yearly_growth
  from all_arrs
  where quarter < date_trunc('quarter', current_date) -- remove current incomplete quarter_name

)

select * from final
