with final as (
  select
    customer.id
    , coalesce(customer.name, customer.description, lower(customer.email)) as name
    , customer.created as created_at
    , lower(customer.email) as email
    , coalesce(customer.address_country, customer.shipping_address_country, card.country) as country
    , coalesce(customer.address_state, customer.shipping_address_state) as state
    , coalesce(customer.address_city, customer.shipping_address_city) as city
    , coalesce(customer.address_postal_code, customer.shipping_address_postal_code) as zip
    , customer.delinquent as is_delinquent
    , customer.invoice_prefix
    , customer.balance::float / 100 as balance
  from {stripe_schema}.customer
  left join {stripe_schema}.card
    on customer.default_card_id = card.id
  where customer.livemode and not customer.is_deleted

)

select * from final
