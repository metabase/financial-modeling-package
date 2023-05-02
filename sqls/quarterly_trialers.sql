with quarterly_stats as (
select
    date_trunc('quarter', month_started_trial)::date as quarter
    , concat(
        case
          when extract('month' from date_trunc('quarter', month_started_trial)) = 1 then 'Q1 '
          when extract('month' from date_trunc('quarter', month_started_trial)) = 4 then 'Q2 '
          when extract('month' from date_trunc('quarter', month_started_trial)) = 7 then 'Q3 '
          when extract('month' from date_trunc('quarter', month_started_trial)) = 10 then 'Q4 '
        end,
        extract('year' from month_started_trial)
    ) as quarter_name
    , sum(num_not_converted_post_trial) as num_not_converted_post_trial
    , sum(num_converted_post_trial) as num_converted_post_trial
from {monthly_trialers} as trial_conversion
group by 1, 2

)
select
    *
    , 1.0 * num_converted_post_trial /
        case
            when num_converted_post_trial + num_not_converted_post_trial = 0 then 1
            else num_converted_post_trial + num_not_converted_post_trial
        end as trial_conversion_rate
from quarterly_stats
where quarter < date_trunc('quarter', current_date) -- remove current incomplete quarter_name
order by 1