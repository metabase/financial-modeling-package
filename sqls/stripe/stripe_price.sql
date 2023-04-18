with final as (
  select
    price.id
    , case price.id
        when '{stripe_price_id}' then '{stripe_price_name}'
        else 'other'
      end as name
    , price.created as created_at
    , price.active as is_active
    , nickname as description
    , product.name as product_name
    , price.type
    , billing_scheme
    , case
        when recurring_interval = 'month' and recurring_interval_count = 1 then 'monthly'
        when recurring_interval = 'month' and recurring_interval_count = 3 then 'quarterly'
        when recurring_interval = 'month' and recurring_interval_count = 6 then 'biannually'
        when recurring_interval = 'month' and recurring_interval_count = 6 then 'biannually'
        when recurring_interval = 'year' and recurring_interval_count = 1 then 'annually'
      end as billing_cycle
    , tiers_mode
    , recurring_interval
    , recurring_interval_count
    , unit_amount::float / 100 as unit_amount
    , product_id
  from {{{{ source('{stripe_source}', 'price') }}}}
  left join {{{{ source('{stripe_source}', 'product') }}}}
    on price.product_id = product.id
  where price.livemode and not price.is_deleted

)

select * from final
