with final as (
  select
    quarter
    , quarter_at 
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
