with trial_information as (
  select
      id as subscription_id
      , date(created_at) as created_at
      , date(cancel_at) as cancel_at
      , date(trial_started_at) as trial_started_at
      , date(trial_end_at) as trial_end_at
      , is_cancel_at_period_end
      , trial_end_at < cancel_at or cancel_at is NULL as is_converted
      , status
  from {stripe_subscription} as subscriptions
  where status != 'trialing'

), max_min_dates as (
  select
      max(cancel_at) as max_cancel_at
      , min(created_at) as min_created_at
  from trial_information

), calendar_dates AS (
  select
    date(date_trunc('month', month)) as dt
  from max_min_dates
  join generate_series(min_created_at, max_cancel_at + interval '1 month', '1 month'::interval) month on true

), monthly_stats as (
  select
      coalesce(dt , date(date_trunc('month', trial_started_at))) as month_started_trial
      , coalesce(count(distinct case when not is_converted then subscription_id end), 0) as num_not_converted_post_trial
      , coalesce(count(distinct case when is_converted then subscription_id end), 0) as num_converted_post_trial
  from trial_information
  full outer join calendar_dates
      on dt = date(date_trunc('month', trial_started_at))
  group by 1

), final as (
  select
      *
      , 1.0 * num_converted_post_trial /
          case
              when num_converted_post_trial + num_not_converted_post_trial = 0 then 1
              else num_converted_post_trial + num_not_converted_post_trial
          end as trial_conversion_rate
  from monthly_stats
      where month_started_trial <= date_trunc('month', current_date)
  order by 1 asc

)

select * from final
