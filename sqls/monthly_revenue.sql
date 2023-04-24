with monthly_self_service_invoices as (
  select
    i.total as amount
    , i.period_ended_at::date as date
    , s.id as subscription_id
    , s.cancel_at is null and not s.is_cancel_at_period_end as is_auto_renewal
    , coalesce(sh.stripe_price_id, u.old_record_stripe_price_id, s.plan_id) as plan_id
    , coalesce(sh.plan_name, u.old_record_plan_name, s.plan_name) as plan_name
    , case
      when s.plan_id = 'price_1Ke4UtK2yjOku12MKG9h4YJ4' and i.period_ended_at < '2022-10-01' then 'monthly' -- Yearly prototype (for Isaac) but billed monthly
      else p.billing_cycle
    end as billing_cycle
    , i.stripe_customer_id
    , u.updated_at as updated_to_yearly_plan_at
  from {{ ref('stripe_invoice') }} i
  join {{ ref('stripe_subscription') }} s
   on s.id = i.subscription_id
  left join {{ ref('ms_subscription_history') }} sh
    on i.subscription_id = sh.stripe_subscription_id
    and i.period_ended_at >= sh.valid_from
    and i.period_ended_at < sh.valid_to
  left join {{ ref('stripe_customer') }} c
   on c.id = s.stripe_customer_id
  left join {{ ref('ms_yearly_subscription_audit') }} u
    on u.stripe_subscription_id = s.id
  left join {{ ref('stripe_price') }} p
    on p.id = coalesce(u.old_record_stripe_price_id, s.plan_id)
  where (coalesce(u.old_record_stripe_price_id, s.plan_id) in
                      (select id
                        from {{ ref('stripe_price') }}
                        where name in ('starter', 'pro', 'premium-embedding-deprecated')
                          and recurring_interval = 'month'
                      )
          -- Yearly prototype (for Isaac) but billed monthly
          -- we're using the same plan_id for pro-cloud-yearly but Isaac was billed montly before they switched to a new plan
          or s.plan_id = 'price_1Ke4UtK2yjOku12MKG9h4YJ4' and i.period_ended_at < '2022-10-01')
  and (date_trunc('day', i.period_ended_at) < date_trunc('day', u.updated_at) or u.updated_at is null) -- only take monthly invoice before upgrade to yearly
  and i.total > 0 -- there's one refund a bunch of zero dollar orders
  and i.status not in ('uncollectible', 'void', 'deleted')
  and s.id not in ('sub_IuPZ9LDrHv304I') -- testing
  and date_trunc('month', i.period_ended_at) <= date_trunc('month', CURRENT_DATE)
  and c.email not like '%@metabase.com' -- exclude internal test accounts

), expected_self_service_invoices_this_month as (
  select
    last_month.amount
    , (last_month.date + interval '1 month')::date as date
    , last_month.plan_id, last_month.plan_name
    , last_month.billing_cycle
    , last_month.stripe_customer_id
    , last_month.subscription_id
    , last_month.is_auto_renewal
    , last_month.updated_to_yearly_plan_at
  from monthly_self_service_invoices last_month
  left join monthly_self_service_invoices this_month
    on last_month.subscription_id = this_month.subscription_id
    and date_trunc('month', last_month.date) + interval '1 month' = date_trunc('month', this_month.date)
  where last_month.is_auto_renewal
    and date_trunc('month', last_month.date) + interval '1 month' = date_trunc('month', CURRENT_DATE)
    and this_month.date is null

), annual_self_service_invoices as (
  select i.total as amount,
        i.period_ended_at::date as date
        , s.current_period_end_at as subscription_period_end
        , s.id as subscription_id
        , s.cancel_at is null and not s.is_cancel_at_period_end as is_auto_renewal
        , s.plan_id as plan_id
        , s.plan_name
        , p.billing_cycle
        , i.stripe_customer_id
        , u.updated_at
  from {{ ref('stripe_invoice') }} i
  join {{ ref('stripe_subscription') }} s
   on s.id = i.subscription_id
  left join {{ ref('stripe_customer') }} c
   on c.id = s.stripe_customer_id
  left join {{ ref('ms_yearly_subscription_audit') }} u
    on u.stripe_subscription_id = s.id
  left join {{ ref('stripe_price') }} p
    on s.plan_id = p.id
  where s.plan_name in ('starter', 'pro', 'premium-embedding-deprecated')
    and s.plan_recurring_interval = 'year'
    and (s.plan_id ~ 'embedding' or i.period_ended_at > '2022-10-01') -- to exclude invoices from Isaac's yearly prototype that are using the same plan_id but billed monthly
    and i.total > 0 -- there's one refund a bunch of zero dollar orders
    and i.status not in ('uncollectible', 'deleted', 'void')
    and date_trunc('month', i.period_ended_at) <= date_trunc('month', CURRENT_DATE)
    and (date_trunc('day', i.period_ended_at) >= date_trunc('day', u.updated_at) or u.updated_at is null) -- to filter out monthly invoice billed during the same month as the yearly upgrade
    and c.email not like '%@metabase.com' -- exclude internal test accounts

), annual_self_service_invoices_to_monthly as (
  select
    (date + month_offset * interval '1 month')::date as date
    , billing_cycle
    , plan_name
    , amount::float/12 as amount
    , true as is_actual
    , is_auto_renewal
    , stripe_customer_id
    , subscription_id
    , plan_id
  from annual_self_service_invoices
  join generate_series(0, 11) as month_offset
    on date + month_offset * interval '1 month' < coalesce(subscription_period_end, date_trunc('month', now()) + interval '1 month')

), sold_subscriptions as (
  select
    organization_name
    , account.created_at as period_start
    , billing_cycle
    , plan as plan_name
    , true as is_actual
    , auto_renewal as is_auto_renewal
    , canceled_at as period_end
    , account.annual_value / 12 as monthly_price
    , account.stripe_customer_id
    , stripe_subscription_id
    , sub.plan_id as stripe_plan_id
    , account.id as account_id
  from {{ ref('unified_accounts') }} account
  left join {{ ref('stripe_subscription') }} sub
    on account.stripe_subscription_id = sub.id
  where purchase_type = 'sold'

), monthly_sold_revenue as (
  select
    (period_start::date + month_offset * interval '1 month')::date as recognized_at
    , billing_cycle
    , plan_name
    , is_auto_renewal
    , monthly_price as amount
    , stripe_customer_id
    , stripe_subscription_id
    , stripe_plan_id
    , account_id
  from sold_subscriptions s
  join generate_series(0, 1000) as month_offset
  on period_start + month_offset * interval '1 month' < coalesce(period_end, date_trunc('month', now()) + interval '1 month')

), monthly_revenue as (
  select
    date as recognized_at
    , billing_cycle
    , plan_name
    , true as is_actual
    , is_auto_renewal
    , amount
    , stripe_customer_id
    , subscription_id as stripe_subscription_id
    , plan_id as stripe_plan_id
    , null as account_id
  from monthly_self_service_invoices
  union all
  select
    date as recognized_at
    , billing_cycle
    , plan_name
    , false as is_actual
    , is_auto_renewal
    , amount
    , stripe_customer_id
    , subscription_id as stripe_subscription_id
    , plan_id as stripe_plan_id
    , null as account_id
  from expected_self_service_invoices_this_month
  where updated_to_yearly_plan_at is null -- don't forecast next monthly revenue if a stripe_customer_id upgraded to yearly plan
  union all
  select
    date as recognized_at
    , billing_cycle
    , plan_name
    , is_actual
    , is_auto_renewal
    , amount
    , stripe_customer_id
    , subscription_id as stripe_subscription_id
    , plan_id as stripe_plan_id
    , null as account_id
  from annual_self_service_invoices_to_monthly
  union all
  select
    recognized_at
    , billing_cycle
    , plan_name
    , recognized_at < current_date as is_actual
    , is_auto_renewal
    , amount
    , stripe_customer_id
    , stripe_subscription_id
    , stripe_plan_id
    , account_id
  from monthly_sold_revenue

), consolidated_monthly_revenue as (
  select
    max(recognized_at) as recognized_at
    , max(billing_cycle) as billing_cycle
    , max(plan_name) as plan_name
    , max(is_actual::integer)::boolean as is_actual
    , max(is_auto_renewal::integer)::boolean as is_auto_renewal
    , sum(amount) as amount
    , max(stripe_customer_id) as stripe_customer_id
    , stripe_subscription_id
    , max(stripe_plan_id) as stripe_plan_id
    , max(account_id) as account_id
  from monthly_revenue
  group by date_trunc('month', recognized_at), stripe_subscription_id

), stripe_subscription as (
  select
    stripe_subscription_id as id
    , max(organization_name) as organization_name
    , max(is_activated::integer)::boolean as is_activated
    , max(purchase_type) as purchase_type
    , max(use_case) as use_case
    , max(deployment) as deployment
    , max(feature_set) as feature_set
    , max(country) as country
    , max(id) as account_id  -- randomly pick one as we don't know which one is the correct one for the subscription
    , max(customer_id) as customer_id
    , max(organization_id) as ms_organization_id
  from {{ ref('unified_accounts') }}
  group by 1

), final as (
  select
    {{ dbt_utils.surrogate_key(['recognized_at', 'revenue.stripe_subscription_id']) }} as id
    , coalesce(account.organization_name, stripe_subscription.organization_name) as customer_name
    , recognized_at
    , amount
    , is_actual
    , coalesce(account.is_activated, stripe_subscription.is_activated) as is_activated
    , is_auto_renewal
    , revenue.plan_name
    , coalesce(price.purchase_type, account.purchase_type, stripe_subscription.purchase_type) as purchase_type
    , coalesce(account.use_case, stripe_subscription.use_case) as use_case
    , coalesce(price.deployment, account.deployment, stripe_subscription.deployment) as deployment
    , coalesce(price.feature_set, account.feature_set, stripe_subscription.feature_set) as feature_set
    , revenue.billing_cycle
    , coalesce(account.country, stripe_subscription.country) as country
    , price.product_name
    , coalesce(account.id, stripe_subscription.account_id) as account_id
    , coalesce(account.customer_id, stripe_subscription.customer_id) as customer_id
    , coalesce(account.organization_id, stripe_subscription.ms_organization_id) as ms_organization_id
    , revenue.stripe_customer_id
    , revenue.stripe_subscription_id
    , stripe_plan_id
  from consolidated_monthly_revenue revenue
  left join {{ ref('unified_accounts') }} account
    on revenue.account_id = account.id
  left join stripe_subscription
    on revenue.stripe_subscription_id = stripe_subscription.id
  left join {{ ref('stripe_price') }} price
    on revenue.stripe_plan_id = price.id
  where recognized_at < date_trunc('month', current_date) + interval '1 month'
    and (account.id is not null or stripe_subscription.account_id is not null)  -- bad subscriptions / fix upstream and not here
  order by recognized_at desc

)

select * from final