with arr as (
    select
        quarter
        , date(quarter_at) as quarter_at
        , concat(status, ' ARR') as metric
        , arr as value
    from {quarterly_arr_and_customers} arr

), customers as (
    select
        quarter
        , date(quarter_at) as quarter_at
        , concat(status, ' Customers') as metric
        , customers as value
    from {quarterly_arr_and_customers} customers

), final as (
    select * from arr
    union all
    select * from customers

)

select * from final
order by 2 desc