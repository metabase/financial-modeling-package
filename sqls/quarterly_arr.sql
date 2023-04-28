with values as (

    select
        concat(case
              when extract('month' from date_trunc('quarter', month)) = 1 then 'Q1 '
              when extract('month' from date_trunc('quarter', month)) = 4 then 'Q2 '
              when extract('month' from date_trunc('quarter', month)) = 7 then 'Q3 '
              when extract('month' from date_trunc('quarter', month)) = 10 then 'Q4 '
             end,
            extract('year' from month)
            ) as quarter
        , date_trunc('quarter', month)::date as quarter_at
        , month
        , ending_arr
        , lead(month) over (order by month) as next_month
        , lead(date_trunc('quarter', month)::date) over (order by month) as next_quarter

    from {monthly_arr} r

), beginning_ending_arrs as (
select
    quarter
    , quarter_at
    , lag(ending_arr) over (order by quarter_at) as beginning_arr
    , ending_arr
from values
where quarter_at != next_quarter

), changing_values as (select
    concat(case
              when extract('month' from date_trunc('quarter', month)) = 1 then 'Q1 '
              when extract('month' from date_trunc('quarter', month)) = 4 then 'Q2 '
              when extract('month' from date_trunc('quarter', month)) = 7 then 'Q3 '
              when extract('month' from date_trunc('quarter', month)) = 10 then 'Q4 '
             end,
            extract('year' from month)
            ) as quarter
    , date_trunc('quarter', month)::date as quarter_at
    , sum(new_arr) as new_arr
    , sum(expansion_arr) as expansion_arr
    , sum(contraction_arr) as contraction_arr
    , sum(churn_arr) as churn_arr
from {monthly_arr} r
group by 1,2

)
select
    quarter
    , quarter_at
    , ending_arr
    , beginning_arr
    , new_arr
    , expansion_arr
    , contraction_arr
    , churn_arr
    --, 12*(new_rev + churn_rev + expansion_rev + contraction_rev + beginning_rev) as sum_col
from changing_values
full outer join beginning_ending_arrs
using (quarter, quarter_at)
order by quarter_at asc

















