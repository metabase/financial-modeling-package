with plan_amount as (  -- plan = consolidation of all prices into one
  select
    subscription_id
    , sum(price_amount) as amount
  from {stripe_subscription_item} item
  group by 1

), plan as (
  select
    subscription_id
    , max(price_name) as plan_name
    , max(price_description) as plan_description
    , max(price_billing_scheme) as plan_billing_scheme
    , max(price_recurring_interval) as plan_recurring_interval
    , max(price_recurring_interval_count) as plan_recurring_interval_count
    , max(product_name) as product_name
    , max(amount) as plan_amount
    , max(price_id) as plan_id
    , max(product_id) as product_id
  from {stripe_subscription_item} item
  left join plan_amount using (subscription_id)  -- add amount that includes other prices
  where price_name != 'other'  -- TODO: Fix this to use a flag column. this should produce 1 price per subscription
  group by 1

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
    , plan_name
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
    , plan_id
    , product_id
  from {stripe_schema}.subscription
  left join {stripe_customer} stripe_customer
    on subscription.customer_id = stripe_customer.id
  left join plan
    on subscription.id = plan.subscription_id
  where livemode and _fivetran_active
)

select * from final
