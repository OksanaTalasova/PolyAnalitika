drop view if exists calendar;
create or replace view calendar as
with min_max_dates as (
	select
		min(sale_date) as _min,
		max(sale_date) as _max
	from sale
)
select
	dd as s_date,
	dd + interval '1 day -1 second' as e_date,
	---
	date_trunc('month', dd) as start_month,
	date_trunc('month', dd) + interval '1 month -1 day' as end_month,
	date_trunc('week', dd) as start_week,
	date_trunc('week', dd) + interval '6 day' as end_week,
	extract('week' from dd) as number_week_of_year,
	extract('isoyear' from dd) as year
from generate_series((select _min from min_max_dates), (select _max from min_max_dates), '1 day'::interval) dd;


with chif as (
	select
		id,
		fio,
		department.department_id
	from seller
	left join department on
		department.dep_chif_id = seller.id
	where
		dep_chif_id is not null
),
products_and_service as (
		select
			'product' as products_and_service_type,
			*
		from product
	union all
		select
			'service' as products_and_service_type,
			*
		from service
),
all_data as (
	select
		c.start_month,
		c.end_month,
		c.start_week,
		c.end_week,
		s.quantity,
		s.final_price,
		p.name as products_and_service_name,
		s.final_price/s.quantity as sale_price,
		(((s.final_price/s.quantity::numeric) - p.price) / p.price * 100)::numeric(18,3) as overcharge_percent,
		seller.fio as salesman_fio,
		chif.fio as chif_fio
	from calendar c
	-- add sale
	inner join sale s on
		s.sale_date between c.s_date and c.e_date
	-- add refs
	left join products_and_service p on
		s.item_id = p.id and c.s_date between p.sdate and p.edate
	left join seller on
		s.salesman_id = seller.id
	left join chif on
		seller.department_id = chif.department_id
)
(
	select
		'month' as period_type,
		start_month as start_date,
		end_month as end_date,
		salesman_fio,
		chif_fio,
		sum(quantity) as sales_count,
		sum(final_price) as sales_sum,
		(array_agg(products_and_service_name order by overcharge_percent desc))[1] as max_overcharge_item,
		max(overcharge_percent) as max_overcharge_percent
	from all_data
	group by 1,2,3,4,5
)
union all
(
	select
		'week' as period_type,
		start_week as start_date,
		end_week as end_date,
		salesman_fio,
		chif_fio,
		sum(quantity) as sales_count,
		sum(final_price) as sales_sum,
		(array_agg(products_and_service_name order by overcharge_percent desc))[1] as max_overcharge_item,
		max(overcharge_percent) as max_overcharge_percent
	from all_data
	group by 1,2,3,4,5
)
order by start_date, salesman_fio
