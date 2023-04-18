with final as (
  select
    id
    , number as reference_number
    , created as created_at
    , period_start as period_started_at
    , period_end as period_ended_at
    , due_date as due_at
    , paid as is_paid
    , auto_advance as is_auto_advance
    , attempted as is_attempted
    , status
    , collection_method
    , total::float / 100 as total
    , amount_due::float / 100 as amount_due
    , amount_paid::float / 100 as amount_paid
    , amount_remaining::float / 100 as amount_remaining
    , attempt_count
    , description
    , footer
    , customer_id
    , subscription_id
    , charge_id
  from {{{{ source('{stripe_source}', 'invoice') }}}}
  where livemode and not is_deleted
)

select * from final
