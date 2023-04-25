with arr as (
    select
        month
        , concat(product_name, ' ARR') as metric
        , arr as value
    from {monthly_arr_and_customers} arr

), customers as (
    select
        month
        , concat(product_name, ' Customers') as metric
        , customers as value
    from {monthly_arr_and_customers} customers

), final as (
    select * from arr
    union all
    select * from customers

)

select * from final
order by 1, 2
