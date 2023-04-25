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

), yearly_arr as (
select
        quarter
        , date(quarter_at) as quarter_at
        , concat(status, ' Customers Y/Y%') as metric
        , (arr - last_year_arr_value)/coalesce(last_year_arr_value,1)  as value
    from {quarterly_arr_and_customers} customers

), yearly_customers as (
select
        quarter
        , date(quarter_at) as quarter_at
        , concat(status, ' ARR Y/Y%') as metric
        , (customers - last_year_customer_value)/coalesce(last_year_customer_value,1)  as value
    from {quarterly_arr_and_customers} customers

), final as (
    select * from arr
    union all
    select * from customers
    union all
    select * from yearly_arr
    union all
    select * from yearly_customers


)

select * from final
order by 2 desc