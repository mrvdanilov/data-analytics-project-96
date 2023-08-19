-- агрегированная таблица
-- last_paid_click_attribution
with attribution as (
    with sessions_with_paid_mark as (
        select
            *,
            case
                -- необходимо выделить все платные метки из данных
                -- и здесь дополнить / убрать ненужное
                when
                    medium in (
                        'cpc',
                        'cpm',
                        'cpa',
                        'youtube',
                        'cpp',
                        'tg',
                        'referal',
                        'social'
                    )
                    then 1
                else 0
            end as is_paid
        from sessions
    ),

    visitors_with_leads as (
        select
            s.visitor_id,
            s.visit_date,
            s.source as utm_source,
            s.medium as utm_medium,
            s.campaign as utm_campaign,
            l.lead_id,
            l.created_at,
            l.amount,
            l.closing_reason,
            l.status_id,
            row_number() over (
                partition by s.visitor_id
                order by s.is_paid desc, s.visit_date desc
            ) as rn
        from sessions_with_paid_mark as s
        left join leads as l
            on
                l.visitor_id = s.visitor_id
                and l.created_at >= s.visit_date
    )

    select *
    from visitors_with_leads
    where rn = 1
),

aggregated_data as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        date(visit_date) as visit_date,
        count(visitor_id) as visitors_count,
        count(
            case
                when created_at is not null then visitor_id
            end

        ) as leads_count,
        count(case when status_id = 142 then visitor_id end) as purchases_count,
        sum(case when status_id = 142 then amount end) as revenue
    from attribution
    group by 1, 2, 3, 4
),

marketing_data as (
    select
        date(campaign_date) as visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from ya_ads
    group by 1, 2, 3, 4
    union all
    select
        date(campaign_date) as visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from vk_ads
    group by 1, 2, 3, 4
)

select
    a.visit_date,
    a.utm_source,
    a.utm_medium,
    a.utm_campaign,
    m.total_cost,
    a.visitors_count,
    a.leads_count,
    a.purchases_count,
    a.revenue
from aggregated_data as a
left join marketing_data as m
    on
        a.visit_date = m.visit_date
        and lower(a.utm_source) = m.utm_source
        and lower(a.utm_medium) = m.utm_medium
        and lower(a.utm_campaign) = m.utm_campaign
