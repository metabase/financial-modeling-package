with final as (
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
    , sum(new_rev) as new_rev
    , sum(expansion_rev) as expansion_rev
    , sum(contraction_rev) as contraction_rev
    , sum(churn_rev) as churn_rev
    , sum(beginning_rev) as beginning_rev
    , sum(ending_rev) as ending_rev
  from {monthly_revenue} r
  group by 1,2
  order by 2
)

select
  *
  , lag(ending_rev) over (order by quarter_at) as beginning_rev_lag
from final
