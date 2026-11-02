# Quick-Commerce Operations Analysis | SQL Case Study

## Project Overview

This project analyses a simulated quick-commerce operation to understand order cancellations, identify store-level operational issues, and investigate the factors associated with a sharp increase in cancellations at one store.

The analysis uses SQL (MySQL) to examine order performance, cancellation reasons, inventory availability, putaway operations, picking performance, and delivery partner availability.

## Business Problem

The objective is to investigate why order cancellations increased at a particular store, identify the operational areas associated with the increase, and recommend actions to reduce similar incidents in the future.

## Repository Structure

| File / Folder | Description |
|---|---|
| [SQL Analysis Queries.sql](./SQL%20Analysis%20Queries.sql) | SQL queries used for the operational analysis |
| [Case Study PDF](./quick_commerce_operations_case_study.pdf) | Detailed case study covering findings, interpretation, recommendations, and limitations |
| [data/](./data/) | Folder reserved for source datasets and selected analysis outputs |

## Scope of Analysis

- Overall order performance and cancellation rate
- Store-wise cancellation comparison
- Daily cancellation trends and before/after comparison
- Cancellation reason distribution
- Inventory stockout and shelf replenishment indicators
- Product-level stockout and cancellation signals
- Putaway delays and completion rates
- Picking failures and delays
- Delivery partner availability

## Key Findings

- The dataset contains 81,333 orders, including 75,714 delivered orders and 5,618 cancelled orders. The overall cancellation rate is 6.91%.
- GGN_04 recorded a 12.01% cancellation rate, compared with approximately 5.85%–6.42% across the other stores.
- At GGN_04, the cancellation rate increased from 6.74% on October 14, 2026, to 23.27% on October 15, 2026.
- After October 15, inventory-related reasons (item unavailable and shelf replenishment pending) accounted for 66.66% of GGN_04 cancellations.
- GGN_04 also showed a marked increase in stockout indicators, putaway delays, and pick failures after October 15.
- Delivery partner unavailability did not increase over the same comparison periods, making it a less convincing explanation for the cancellation spike.

## Conclusion

The analysis indicates that GGN_04 experienced a sharp increase in cancellations from October 15, 2026. This increase coincided with higher stockouts, shelf replenishment delays, and pick failures. Inventory availability and replenishment processes are therefore the key areas requiring further investigation and improvement.

The analysis identifies operational associations rather than proving a single cause. The findings should be validated against store-level process records and item-level order data.

## Recommendations

1. Improve the movement of products from receiving and backroom storage to shelves.
2. Prioritise products showing recurring stockouts and replenishment issues.
3. Reduce picking failures by ensuring products are available on shelves and distinguishing genuine stock shortages from products waiting in the backroom.
4. Conduct preventive shelf and backroom stock checks, especially before peak hours.
5. Monitor cancellations, stockouts, and putaway delays through daily operational metrics.
6. Assign clear ownership for pending replenishment and delayed putaway activities.

## Tools Used

- MySQL
- SQL (Joins, Aggregations, Subqueries, CTEs, Window Functions, and Date/Time Analysis)

## Dataset Note

This is a simulated quick-commerce operations case study created for SQL analysis and portfolio demonstration. The results should not be interpreted as actual performance data from Blinkit or any other company.

## Project Files

- [View SQL Analysis Queries](./SQL%20Analysis%20Queries.sql)
- [View Case Study PDF](./quick_commerce_operations_case_study.pdf)
- [Explore Data Folder](./data/)
