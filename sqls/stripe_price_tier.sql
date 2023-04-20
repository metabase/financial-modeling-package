with final as (
  select
    md5(concat(id, '-', index)) as id
    , flat_amount::float / 100 as flat_amount
    , unit_amount::float / 100 as unit_amount
    , up_to as up_to_quantity
    , index as order_index
    , id as price_id
  from {stripe_schema}.tier
)

select * from final
