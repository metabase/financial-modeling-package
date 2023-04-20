with plan_amount as (  -- plan = consolidation of all prices into one
  select
    subscription_id
    , sum(price_amount) as amount
  from {stripe_subscription_item} item
  group by 1

), plan as (
  select
    subscription_id
    , product_name
    , price_description as plan_description
    , price_billing_scheme as plan_billing_scheme
    , price_recurring_interval as plan_recurring_interval
    , price_recurring_interval_count as plan_recurring_interval_count
    , amount as plan_amount
    , price_id
    , product_id
    , row_number() over (partition by subscription_id order by created_at asc)  -- allow selecting oldest on conflict
  from {stripe_subscription_item} item
  left join plan_amount using (subscription_id)  -- add amount that includes other prices
  where is_main_product

), final as (
  select
    subscription.id
    , stripe_customer.name as customer_name
    , subscription.created as created_at
    , billing_cycle_anchor as billing_cycle_anchored_at
    , coalesce(cancel_at, canceled_at) as cancel_at
    , current_period_start as current_period_started_at
    , current_period_end as current_period_end_at
    , trial_start as trial_started_at
    , trial_end as trial_end_at
    , cancel_at_period_end as is_cancel_at_period_end
    , status
    , collection_method
    , product_name
    , plan_billing_scheme
    , plan_recurring_interval
    , plan_recurring_interval_count
    , plan_description
    , plan_amount
    , case
        when plan_recurring_interval = 'year' then 1 / plan_recurring_interval_count * plan_amount
        when plan_recurring_interval = 'month' then 12 / plan_recurring_interval_count * plan_amount
      end as annual_value
    , subscription.customer_id as stripe_customer_id
    , price_id
    , product_id
  from {stripe_schema}.subscription
  left join {stripe_customer} stripe_customer
    on subscription.customer_id = stripe_customer.id
  left join plan
    on subscription.id = plan.subscription_id and row_number = 1
  where livemode and _fivetran_active
)

select * from final
