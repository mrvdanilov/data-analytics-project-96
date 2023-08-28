-- сюда можно вставить запрос с любой атрибуции с attribution.sql.

with visitors_with_leads as (
    select
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        row_number() over (
            partition by s.visitor_id
            order by
                case when s.medium = 'organic' then 0 else 1 end desc,
                s.visit_date desc
        ) as rn
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
)

select
    utm_source,
    utm_medium,
    percentile_disc(0.90) within group (
        order by date_part('day', created_at - visit_date)
    ) as days_to_lead
from visitors_with_leads
where rn = 1
group by 1, 2
