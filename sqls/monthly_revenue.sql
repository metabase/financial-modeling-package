with monthly_self_service_invoices as (
   select
     invoice.total as amount
     , invoice.period_ended_at::date as date
     , subscription.id as subscription_id
     , subscription.customer_name
     , subscription.cancel_at is null and not subscription.is_cancel_at_period_end as is_auto_renewal
     , subscription.product_id
     , subscription.product_name as product_name
     , 'monthly' as billing_cycle
     , invoice.customer_id as stripe_customer_id
   from {stripe_invoice} invoice
   join {stripe_subscription} subscription
    on subscription.id = invoice.subscription_id
   left join {stripe_customer} customer
    on customer.id = subscription.stripe_customer_id
   left join {stripe_price} price
     on price.product_id = subscription.product_id
   where invoice.total > 0 -- there's one refund a bunch of zero dollar orders
   and invoice.status not in ('uncollectible', 'void', 'deleted')
   and date_trunc('month', invoice.period_ended_at) <= date_trunc('month', CURRENT_DATE)

 ), expected_self_service_invoices_this_month as (
   select
     last_month.amount
     , (last_month.date + interval '1 month')::date as date
     , last_month.product_id
     , last_month.product_name
     , last_month.billing_cycle
     , last_month.stripe_customer_id
     , last_month.subscription_id
     , last_month.customer_name
     , last_month.is_auto_renewal
   from monthly_self_service_invoices last_month
   left join monthly_self_service_invoices this_month
     on last_month.subscription_id = this_month.subscription_id
     and date_trunc('month', last_month.date) + interval '1 month' = date_trunc('month', this_month.date)
   where last_month.is_auto_renewal
     and date_trunc('month', last_month.date) + interval '1 month' = date_trunc('month', CURRENT_DATE)
     and this_month.date is null

 ), annual_self_service_invoices as (
   select invoice.total as amount,
         invoice.period_ended_at::date as date
         , subscription.current_period_end_at as subscription_period_end
         , subscription.id as subscription_id
         , subscription.customer_name
         , subscription.cancel_at is null and not subscription.is_cancel_at_period_end as is_auto_renewal
         , subscription.product_id as product_id
         , subscription.product_name
         , price.billing_cycle
         , invoice.customer_id as stripe_customer_id
   from {stripe_invoice} invoice
   join {stripe_subscription} subscription
    on subscription.id = invoice.subscription_id
   left join {stripe_customer} customer
    on customer.id = subscription.stripe_customer_id
   left join {stripe_price} price
     on subscription.product_id = price.product_id
   where subscription.plan_recurring_interval = 'year'
     and invoice.total > 0 -- there's one refund a bunch of zero dollar orders
     and invoice.status not in ('uncollectible', 'deleted', 'void')
     and date_trunc('month', invoice.period_ended_at) <= date_trunc('month', CURRENT_DATE)

 ), annual_self_service_invoices_to_monthly as (
   select
     (date + month_offset * interval '1 month')::date as date
     , 'yearly' as billing_cycle
     , product_name
     , amount::float/12 as amount
     , true as is_actual
     , is_auto_renewal
     , stripe_customer_id
     , subscription_id
     , customer_name
     , product_id
   from annual_self_service_invoices
   join generate_series(0, 11) as month_offset
     on date + month_offset * interval '1 month' < coalesce(subscription_period_end, date_trunc('month', now()) + interval '1 month')

 ), monthly_revenue as (
   select
     date as recognized_at
     , billing_cycle
     , product_name
     , true as is_actual
     , is_auto_renewal
     , amount
     , stripe_customer_id
     , subscription_id as stripe_subscription_id
     , customer_name
     , product_id as stripe_product_id
     , null as account_id
   from monthly_self_service_invoices
   union all
   select
     date as recognized_at
     , billing_cycle
     , product_name
     , false as is_actual
     , is_auto_renewal
     , amount
     , stripe_customer_id
     , subscription_id as stripe_subscription_id
     , customer_name
     , product_id as stripe_product_id
     , null as account_id
   from expected_self_service_invoices_this_month
   union all
   select
     date as recognized_at
     , billing_cycle
     , product_name
     , is_actual
     , is_auto_renewal
     , amount
     , stripe_customer_id
     , subscription_id as stripe_subscription_id
     , customer_name
     , product_id as stripe_product_id
     , null as account_id
   from annual_self_service_invoices_to_monthly

 ), consolidated_monthly_revenue as (
   select
     max(recognized_at) as recognized_at
     , max(billing_cycle) as billing_cycle
     , max(product_name) as product_name
     , max(is_actual::integer)::boolean as is_actual
     , max(is_auto_renewal::integer)::boolean as is_auto_renewal
     , sum(amount) as amount
     , max(stripe_customer_id) as stripe_customer_id
     , max(stripe_subscription_id) as stripe_subscription_id
     , max(customer_name) as customer_name
     , max(stripe_product_id) as stripe_product_id
     , max(account_id) as account_id
   from monthly_revenue
   group by date_trunc('month', recognized_at), stripe_subscription_id

 ),

 final as (
   select
     revenue.stripe_subscription_id
     , revenue.customer_name
     , revenue.recognized_at
     , revenue.amount
     , revenue.is_actual
     , revenue.is_auto_renewal
     , revenue.product_name
     , revenue.billing_cycle
     , revenue.stripe_customer_id
     , revenue.stripe_product_id
   from consolidated_monthly_revenue revenue
   where recognized_at < date_trunc('month', current_date) + interval '1 month'
   order by recognized_at desc

 )

 select * from final
