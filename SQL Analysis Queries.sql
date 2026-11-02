/*
QUICK-COMMERCE OPERATIONS ANALYSIS — STEP 1
Business question:
Investigate the cancellation spike.

Dataset window: 2026-09-01 through 2026-10-31
SQL dialect: MySQL 8+

RUN ORDER
1. Create/use the database and create the 13 tables using the schema script supplied.
2. Import CSV data with MySQL Workbench's Table Data Import Wizard.
3. Run these investigation queries in order.

Note:
This file contains the 22 investigation queries in the sequence of the investigation.
*/

USE quick_commerce_project;


/* ==================== QUERY 01: Overall order performance ==================== */
select count(*) as total_orders,
sum(case when order_status = 'DELIVERED' then 1 else 0 end) as delivered_orders,
sum(case when order_status = 'CANCELLED' then 1 else 0 end) as cancelled_orders,
sum(case when order_status = 'IN_PROGRESS' then 1 else 0 end) as in_progress_orders,
round((sum(case when order_status = 'CANCELLED' then 1 else 0 end)/nullif(count(*),0))*100.0,2) as cancellation_rate_pct,
round((sum(case when order_status = 'DELIVERED' then 1 else 0 end)/nullif(count(*),0))*100.0,2) as delivery_rate_pct
from orders;


/* ==================== QUERY 02: Cancellation performance by store ==================== */
select store_id, count(*) as total_orders,
sum(case when order_status = 'DELIVERED' then 1 else 0 end) as delivered_orders,
sum(case when order_status = 'CANCELLED' then 1 else 0 end) as cancelled_orders,
round((sum(case when order_status = 'CANCELLED' then 1 else 0 end)/nullif(count(*),0))*100.0,2) as cancellation_rate_pct,
round((sum(case when order_status = 'CANCELLED' then 1 else 0 end)/nullif((select count(*) from orders where order_status = 'CANCELLED'),0))*100.0,2) as contribution_to_total_cancellations_pct
from orders
group by store_id
order by cancellation_rate_pct desc;


/* ==================== QUERY 03: Daily cancellation trend by store ==================== */
select date(order_placed_at) as order_date, store_id,
count(*) as total_orders,
sum(case when order_status = 'CANCELLED' then 1 else 0 end) as cancelled_orders,
round((sum(case when order_status = 'CANCELLED' then 1 else 0 end)/nullif(count(*),0))*100.0,2) as cancellation_rate_pct
from orders
group by date(order_placed_at), store_id
order by store_id, order_date;


/* ==================== QUERY 04: Before/after October 15 cancellation rates ==================== */
select store_id,
case when date(order_placed_at) < '2026-10-15' then 'Before Oct 15' else 'Oct 15 Onwards' end as analysis_period,
count(*) as total_orders,
sum(case when order_status = 'CANCELLED' then 1 else 0 end) as cancelled_orders,
round((sum(case when order_status = 'CANCELLED' then 1 else 0 end)/nullif(count(*),0))*100.0,2) as cancellation_rate_pct
from orders
group by store_id, case when date(order_placed_at) < '2026-10-15' then 'Before Oct 15' else 'Oct 15 Onwards' end
order by store_id, analysis_period;


/* ==================== QUERY 05: Cancellation reason mix ==================== */
select store_id, case when date(cancellation_timestamp) < '2026-10-15' then 'Before Oct 15' else 'Oct 15 Onwards' end as analysis_period,
cancellation_reason, count(*) as cancelled_orders, 
round((count(*)/nullif(sum(count(*)) over (partition by store_id,case when date(cancellation_timestamp) < '2026-10-15' then 'Before Oct 15' else 'Oct 15 Onwards' end),0))*100,2) as reason_share_pct
from cancellation_events
group by store_id, case when date(cancellation_timestamp) < '2026-10-15' then 'Before Oct 15' else 'Oct 15 Onwards' end,cancellation_reason
ORDER BY store_id, analysis_period, cancelled_orders DESC;


/* ==================== QUERY 06: Stockout rates by store and period ==================== */
select store_id, case when snapshot_date < '2026-10-15' then 'Before Oct 15' else 'Oct 15 Onwards' end as analysis_period, count(*) as total_snapshots,
sum(stockout_flag) as stockout_snapshots, round((sum(stockout_flag)/nullif(count(*),0))*100.0,2) as stockout_rate_pct from inventory_snapshots
Where  snapshot_date >= '2026-09-01' and snapshot_date < '2026-11-01'
group by store_id, case when snapshot_date < '2026-10-15' then 'Before Oct 15' else 'Oct 15 Onwards' end
order by store_id, analysis_period;


/* ==================== QUERY 07: Shelf vs backroom stockout ==================== */
with inventory_analysis as (select store_id, case when snapshot_date < '2026-10-15' then 'Before Oct 15' else 'Oct 15 Onwards' end as analysis_period, 
count(*) as total_snapshots, sum(stockout_flag) as stockout_snapshots, 
sum(case when shelf_stock_units=0 and backroom_stock_units>0 then 1 else 0 end) as Shelf_empty_backroom_available, 
sum(case when shelf_stock_units=0 and backroom_stock_units=0 then 1 else 0 end) as Shelf_empty_backroom_empty from inventory_snapshots
Where  snapshot_date >= '2026-09-01' and snapshot_date < '2026-11-01'
group by store_id, case when snapshot_date < '2026-10-15' then 'Before Oct 15' else 'Oct 15 Onwards' end)

select store_id, analysis_period, total_snapshots, round((stockout_snapshots/total_snapshots)*100.0,2) as stockout_rate_pct, 
round((Shelf_empty_backroom_available/total_snapshots)*100.0,2) as Shelf_empty_backroom_available_rate, 
round((Shelf_empty_backroom_empty/total_snapshots)*100.0,2) as Both_empty_rate from inventory_analysis;


/* ==================== QUERY 08: Receipts, sales, discrepancy and complete stockouts ==================== */
select store_id, case when snapshot_date < '2026-10-15' then 'Before Oct 15' else 'Oct 15 Onwards' end as analysis_period, 
sum(received_units) as total_units_recieved, sum(units_sold) as total_units_sold, sum(received_units)/nullif(count(distinct(snapshot_date)),0) as avg_daily_units_recieved, 
sum(Units_sold)/nullif(count(distinct(snapshot_date)),0) as avg_daily_units_sold, round((sum(case when system_on_hand_units > physical_on_hand_units then 1 else 0 end)/nullif(count(*),0))*100.0,2) as system_stock_higher_rate_pct,
round((sum(case when shelf_stock_units=0 and backroom_stock_units=0 then 1 else 0 end)/nullif(count(*),0))*100.0,2) as Complete_Stockout_Rate from inventory_snapshots
Where  snapshot_date >= '2026-09-01' and snapshot_date < '2026-11-01'
group by store_id, case when snapshot_date < '2026-10-15' then 'Before Oct 15' else 'Oct 15 Onwards' end
order by store_id, analysis_period;


/* ==================== QUERY 09: Product-level inventory performance ==================== */
select product_id, case when snapshot_date < '2026-10-15' then 'Before Oct 15' else 'Oct 15 Onwards' end as analysis_period, 
sum(received_units) as total_units_recieved, sum(units_sold) as total_units_sold, sum(received_units)/nullif(count(distinct(snapshot_date)),0) as avg_daily_units_recieved, 
sum(Units_sold)/nullif(count(distinct(snapshot_date)),0) as avg_daily_units_sold, round((sum(case when system_on_hand_units > physical_on_hand_units then 1 else 0 end)/nullif(count(*),0))*100.0,2) as system_stock_higher_rate_pct,
round((sum(case when shelf_stock_units=0 and backroom_stock_units=0 then 1 else 0 end)/nullif(count(*),0))*100.0,2) as Complete_Stockout_Rate from inventory_snapshots
Where store_id='GGN_04' and (snapshot_date >= '2026-09-01' and snapshot_date < '2026-11-01')
group by product_id, case when snapshot_date < '2026-10-15' then 'Before Oct 15' else 'Oct 15 Onwards' end
order by product_id, analysis_period;


/* ==================== QUERY 10: Daily inventory history for selected SKUs ==================== */
select snapshot_date, product_id, opening_stock_units, received_units, units_sold, system_on_hand_units, physical_on_hand_units, shelf_stock_units, backroom_stock_units, inventory_adjustment_units, stockout_flag
from inventory_snapshots
where store_id = 'GGN_04'
and product_id in ('SKU0038', 'SKU0021', 'SKU0040', 'SKU0049', 'SKU0013')
and snapshot_date >= '2026-10-15'
and snapshot_date < '2026-11-01'
order by product_id, snapshot_date;


/* ==================== QUERY 11: Putaway events by status/reason ==================== */
select store_id, case when date(receipt_timestamp)< '2026-10-15' then 'Before Oct 15' else 'Oct 15 Onwards' end as  analysis_period,putaway_status, 
coalesce(exception_reason,'NO Exception') as exception_reason, count(*) as total_putaway_events from putaway_events
Where receipt_timestamp >= '2026-09-01' and receipt_timestamp < '2026-11-01'
group by store_id, case when date(receipt_timestamp)< '2026-10-15' then 'Before Oct 15' else 'Oct 15 Onwards' end, putaway_status,coalesce(exception_reason,'NO Exception')
order by store_id, analysis_period, total_putaway_events DESC;


/* ==================== QUERY 12: Putaway delay rates across stores ==================== */
with putaway_analysis as (select store_id, case when date(receipt_timestamp)< '2026-10-15' then 'Before Oct 15' else 'Oct 15 Onwards' end as analysis_period, count(*) as total_putaway_events, 
sum(case when putaway_status='completed' then 1 else 0 end) as completed_events, sum(case when putaway_status='Putaway_delayed' then 1 else 0 end) as delayed_events,
sum(case when exception_reason='Backroom_processing_delay' then 1 else 0 end) as Backroom_processing_delays, sum(case when exception_reason='shelf_replenishment_pending' then 1 else 0 end) as shelf_replenishment_pending_delays,
sum(case when exception_reason = 'staffing_delay' then 1 else 0 end) as staffing_delay_events from putaway_events
Where receipt_timestamp >= '2026-09-01' and receipt_timestamp < '2026-11-01'
group by store_id, case when date(receipt_timestamp)< '2026-10-15' then 'Before Oct 15' else 'Oct 15 Onwards' end)

select store_id, analysis_period, total_putaway_events, completed_events, round((completed_events/nullif(total_putaway_events,0))*100.0,2) as completed_event_rate,
delayed_events, round((delayed_events/nullif(total_putaway_events,0))*100.0,2) as delayed_events_rate, Backroom_processing_delays, round((Backroom_processing_delays/nullif(total_putaway_events,0))*100.0,2) as Backroom_processing_delay_rate,
round((Backroom_processing_delays/nullif(delayed_events,0))*100.0,2) as Pct_Backroom_processing_to_delay_events,
shelf_replenishment_pending_delays, round((shelf_replenishment_pending_delays/nullif(total_putaway_events,0))*100.0,2) as shelf_replenishment_pending_delay_rate, 
round((shelf_replenishment_pending_delays/nullif(delayed_events,0))*100.0,2) as Pct_shelf_replenishment_pending_to_delay_events from putaway_analysis
order by store_id, analysis_period;


/* ==================== QUERY 13: Putaway delay rates at GGN_04 ==================== */
with putaway_analysis as (select store_id, case when date(receipt_timestamp)< '2026-10-15' then 'Before Oct 15' else 'Oct 15 Onwards' end as analysis_period, count(*) as total_putaway_events, 
sum(case when putaway_status='completed' then 1 else 0 end) as completed_events, sum(case when putaway_status='Putaway_delayed' then 1 else 0 end) as delayed_events,
sum(case when exception_reason='Backroom_processing_delay' then 1 else 0 end) as Backroom_processing_delays, sum(case when exception_reason='shelf_replenishment_pending' then 1 else 0 end) as shelf_replenishment_pending_delays,
sum(case when exception_reason = 'staffing_delay' then 1 else 0 end) as staffing_delay_events from putaway_events
Where store_id='GGN_04' and  (receipt_timestamp >= '2026-09-01' and receipt_timestamp < '2026-11-01')
group by store_id, case when date(receipt_timestamp)< '2026-10-15' then 'Before Oct 15' else 'Oct 15 Onwards' end)

select store_id, analysis_period, total_putaway_events, completed_events, round((completed_events/nullif(total_putaway_events,0))*100.0,2) as completed_event_rate,
delayed_events, round((delayed_events/nullif(total_putaway_events,0))*100.0,2) as delayed_events_rate, Backroom_processing_delays, round((Backroom_processing_delays/nullif(total_putaway_events,0))*100.0,2) as Backroom_processing_delay_rate,
round((Backroom_processing_delays/nullif(delayed_events,0))*100.0,2) as Pct_Backroom_processing_to_delay_events,
shelf_replenishment_pending_delays, round((shelf_replenishment_pending_delays/nullif(total_putaway_events,0))*100.0,2) as shelf_replenishment_pending_delay_rate, 
round((shelf_replenishment_pending_delays/nullif(delayed_events,0))*100.0,2) as Pct_shelf_replenishment_pending_to_delay_events from putaway_analysis
order by store_id, analysis_period;


/* ==================== QUERY 14: Putaway turnaround duration and missing timestamps ==================== */
select store_id, case when date(receipt_timestamp)< '2026-10-15' then 'Before Oct 15' else 'Oct 15 Onwards' end as analysis_period, count(*) as total_putaway_events,
avg(putaway_turnaround_minutes) as avg_putaway_turnaround_minutes,
round(avg(case when putaway_status='putaway_delayed' then putaway_turnaround_minutes end),2) as avg_delayed_turnaround_minutes,
round(avg(case when putaway_status='completed' then putaway_turnaround_minutes end),2) as avg_completed_turnaround_minutes,
round(avg (case when putaway_started_at is not null then timestampdiff(minute,receipt_timestamp, putaway_started_at)end),2) as avg_receipt_to_start_minutes,
sum(case when putaway_started_at is null then 1 else 0 end) as missing_start_timestamp_events,
sum(case when putaway_completed_at is null then 1 else 0 end) as missing_completion_timestamp_events
from putaway_events
where receipt_timestamp >= '2026-09-01' and receipt_timestamp < '2026-11-01'
group by store_id, case when date(receipt_timestamp) < '2026-10-15' then 'before oct 15' else 'oct 15 onwards' end
order by store_id, analysis_period;


/* ==================== QUERY 15: Putaway turnaround by status and reason ==================== */
select store_id, case when receipt_timestamp < '2026-10-15' then 'before oct 15' else 'oct 15 onwards' end as analysis_period,
putaway_status, coalesce(exception_reason,'no exception') as exception_reason, count(*) as total_events, 
round(avg(putaway_turnaround_minutes),2) as avg_turnaround_minutes, max(putaway_turnaround_minutes) as max_turnaround_minutes from putaway_events
where receipt_timestamp >= '2026-09-01' and receipt_timestamp < '2026-11-01'
group by store_id, case when receipt_timestamp < '2026-10-15' then 'before oct 15' else 'oct 15 onwards' end, putaway_status, coalesce(exception_reason,'no exception')
order by store_id, analysis_period, total_events desc;


/* ==================== QUERY 16: Putaway exceptions and stockout snapshots ==================== */
select case when pe.receipt_timestamp < '2026-10-15' then 'before oct 15' else 'oct 15 onwards' end as analysis_period,
pe.putaway_status,
coalesce(pe.exception_reason,'no exception') as exception_reason,
count(*) as total_events,
sum(case when inv.shelf_stock_units = 0 and inv.backroom_stock_units = 0 then 1 else 0 end) as complete_stockout_events,
round((100.0*sum(case when inv.shelf_stock_units = 0 and inv.backroom_stock_units = 0 then 1 else 0 end)/count(*)),2) as complete_stockout_rate_pct,
sum(case when inv.shelf_stock_units = 0 and inv.backroom_stock_units > 0 then 1 else 0 end) as shelf_empty_backroom_available_events
from putaway_events pe
join inventory_snapshots inv
on pe.inventory_snapshot_id = inv.inventory_snapshot_id
where pe.store_id = 'GGN_04'
and pe.receipt_timestamp >= '2026-09-01'
and pe.receipt_timestamp < '2026-11-01'
group by case when pe.receipt_timestamp < '2026-10-15' then 'before oct 15' else 'oct 15 onwards' end, pe.putaway_status, coalesce(pe.exception_reason,'no exception')
order by analysis_period, total_events desc;


/* ==================== QUERY 17: Inventory-related cancellations by product ==================== */
with scoped_orders as ( select o.order_id, o.store_id, 
case when o.order_placed_at < '2026-10-15' then 'before oct 15' else 'oct 15 onwards' end as analysis_period from orders o
where o.store_id = 'GGN_04' and (o.order_placed_at >= '2026-09-01' and o.order_placed_at < '2026-11-01')),

product_orders as ( select distinct so.order_id, so.analysis_period, 
oi.product_id from scoped_orders so join order_items oi on so.order_id = oi.order_id),

inventory_cancellations as ( select ce.order_id, max(case when ce.cancellation_reason in ('item_unavailable','shelf_replenishment_pending') then 1 else 0 end) as inventory_related_cancel
from cancellation_events ce
where ce.store_id = 'GGN_04'
group by ce.order_id)

select po.product_id, po.analysis_period, count(distinct po.order_id) as orders_containing_product,
count(distinct case when ic.inventory_related_cancel = 1 then po.order_id end) as inventory_related_cancelled_orders,
round((count(distinct case when ic.inventory_related_cancel = 1 then po.order_id end)/nullif(count(distinct po.order_id),0))*100.0,2) as inventory_related_cancellation_rate_pct
from product_orders po left join inventory_cancellations ic on po.order_id = ic.order_id
group by po.product_id, po.analysis_period
order by po.analysis_period, inventory_related_cancelled_orders desc;


/* ==================== QUERY 18: Compare product cancellations with stockout metrics ==================== */
with product_orders as ( select distinct o.order_id, oi.product_id, case when o.order_placed_at < '2026-10-15' then 'before oct 15' else 'oct 15 onwards' end as analysis_period 
from orders o join order_items oi on o.order_id = oi.order_id
where o.store_id = 'GGN_04' and (o.order_placed_at >= '2026-09-01' and o.order_placed_at < '2026-11-01')),

inventory_cancellations as (select ce.order_id, max(case when ce.cancellation_reason in ('item_unavailable','shelf_replenishment_pending') then 1 else 0 end) as inventory_related_cancel
from cancellation_events ce
where ce.store_id = 'GGN_04'
group by ce.order_id),

product_cancellation_metrics as (select po.product_id, po.analysis_period, count(distinct po.order_id) as orders_containing_product,
count(distinct case when ic.inventory_related_cancel = 1 then po.order_id end) as inventory_related_cancelled_orders,
round((count(distinct case when ic.inventory_related_cancel = 1 then po.order_id end)/nullif(count(distinct po.order_id),0))*100.0,2) as inventory_cancellation_rate_pct
from product_orders po left join inventory_cancellations ic on po.order_id = ic.order_id
group by po.product_id, po.analysis_period),

product_inventory_metrics as (
select inv.product_id,
case when inv.snapshot_date < '2026-10-15' then 'before oct 15' else 'oct 15 onwards' end as analysis_period,
count(*) as inventory_snapshots,
round((sum(case when inv.stockout_flag = 1 then 1 else 0 end)/nullif(count(*),0))*100.0,2) as shelf_stockout_rate_pct,
round((sum(case when inv.shelf_stock_units = 0 and inv.backroom_stock_units = 0 then 1 else 0 end)/nullif(count(*),0))*100.0,2) as complete_stockout_rate_pct
from inventory_snapshots inv
where inv.store_id = 'GGN_04' and inv.snapshot_date >= '2026-09-01' and inv.snapshot_date < '2026-11-01'
group by inv.product_id, case when inv.snapshot_date < '2026-10-15' then 'before oct 15' else 'oct 15 onwards' end)

select c.product_id, c.analysis_period, c.orders_containing_product, c.inventory_related_cancelled_orders, c.inventory_cancellation_rate_pct,
i.inventory_snapshots, i.shelf_stockout_rate_pct, i.complete_stockout_rate_pct from product_cancellation_metrics c left join product_inventory_metrics i
on c.product_id = i.product_id and c.analysis_period = i.analysis_period
order by c.analysis_period, c.inventory_cancellation_rate_pct desc;


/* ==================== QUERY 19: Order-level pick exceptions ==================== */
select case when o.order_placed_at < '2026-10-15' then 'before oct 15' else 'oct 15 onwards' end as period,
count(distinct o.order_id) as total_orders,
count(distinct case when p.order_id is not null then o.order_id end) as orders_with_pick_events,
count(distinct case when p.pick_status is not null and p.pick_status <> 'PICKED' then p.order_id end) as orders_with_noncompleted_pick_status,
count(distinct case when p.exception_reason is not null and p.exception_reason <> '' then p.order_id end) as orders_with_pick_exceptions,
round((100.0*count(distinct case when p.exception_reason is not null and p.exception_reason <> '' then p.order_id end)/nullif(count(distinct o.order_id),0)),2) as pick_exception_order_rate_pct
from orders o
left join pick_events p
on o.order_id = p.order_id
where o.store_id = 'GGN_04'
and o.order_placed_at >= '2026-09-01'
and o.order_placed_at < '2026-11-01'
group by period
order by period;


/* ==================== QUERY 20: Pick event status rates ==================== */
select case when pick_timestamp < '2026-10-15' then 'before oct 15' else 'oct 15 onwards' end as period,
count(*) as total_pick_events,
sum(case when pick_status = 'picked' then 1 else 0 end) as picked_events,
sum(case when pick_status = 'pick_failed' then 1 else 0 end) as failed_events,
sum(case when pick_status = 'pick_delayed' then 1 else 0 end) as delayed_events,
round((100.0*sum(case when pick_status = 'picked' then 1 else 0 end)/nullif(count(*),0)),2) as picked_rate_pct,
round((100.0*sum(case when pick_status = 'pick_failed' then 1 else 0 end)/nullif(count(*),0)),2) as pick_failure_rate_pct,
round((100.0*sum(case when pick_status = 'pick_delayed' then 1 else 0 end)/nullif(count(*),0)),2) as pick_delay_rate_pct from pick_events
where store_id = 'GGN_04' and pick_timestamp >= '2026-09-01' and pick_timestamp < '2026-11-01'
group by period
order by period;


/* ==================== QUERY 21: Pick exception reasons ==================== */
select case when pick_timestamp < '2026-10-15' then 'before oct 15' else 'oct 15 onwards' end as period, pick_status,
coalesce(exception_reason,'not specified') as exception_reason, count(*) as event_count,
round((count(*)/nullif(sum(count(*)) over(partition by case when pick_timestamp < '2026-10-15' then 'before oct 15' else 'oct 15 onwards' end, pick_status),0))*100.0,2) as reason_rate_within_status_pct,
round((count(*)/nullif(sum(count(*)) over(partition by case when pick_timestamp < '2026-10-15' then 'before oct 15' else 'oct 15 onwards' end),0))*100.0,2) as pct_of_failed_and_delayed_events
from pick_events
where store_id = 'GGN_04' and pick_timestamp >= '2026-09-01' and pick_timestamp < '2026-11-01' and pick_status in ('pick_failed','pick_delayed')
group by period, pick_status, coalesce(exception_reason,'not specified')
order by period, pick_status, event_count desc;


/* ==================== QUERY 22: Delivery partner availability ==================== */
select case when dispatch_event_timestamp < '2026-10-15' then 'before oct 15' else 'oct 15 onwards' end as period,
count(*) as total_delivery_events,
sum(case when partner_assignment_status = 'assigned' then 1 else 0 end) as assigned_events,
sum(case when partner_availability_status = 'unavailable' then 1 else 0 end) as partner_unavailable_events,
round((sum(case when partner_availability_status = 'unavailable' then 1 else 0 end)/nullif(count(*),0))*100.0,2) as partner_unavailable_rate_pct
from delivery_events
where store_id = 'GGN_04' and dispatch_event_timestamp >= '2026-09-01' and dispatch_event_timestamp < '2026-11-01'
group by period
order by period;

/* ============================================================
   INTERPRETATION REMINDERS
   ============================================================
   - Treat findings as associations, not proof of causality.
   - The before/after windows differ in length (44 days vs 17 days);
     compare rates rather than raw counts.
   - Different tables use different event timestamps. They are useful
     complementary signals but do not form a perfectly aligned timeline.
   - Product-level cancellation association does not prove that a specific
     SKU caused the cancellation, because an order can contain multiple items.
   - Inventory snapshots are daily.
   - Check the actual status/reason values in your imported data if a query
     returns zero for completed/delayed statuses.
*/
