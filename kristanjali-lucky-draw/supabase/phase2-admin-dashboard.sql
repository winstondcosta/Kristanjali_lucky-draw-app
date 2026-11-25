-- Phase 2: Admin dashboard RPC. Run this in Supabase SQL Editor.
-- Admin role is checked in the database; customer data is only returned to admins.
CREATE OR REPLACE FUNCTION public.get_admin_dashboard()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  result jsonb;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Administrator access required';
  END IF;

  SELECT jsonb_build_object(
    'sold_count', (SELECT count(*) FROM public.tickets AS t WHERE t.status = 'sold'),
    'sold_value', (SELECT coalesce(sum(t.amount), 0) FROM public.tickets AS t WHERE t.status = 'sold'),
    'available_count', (SELECT count(*) FROM public.tickets AS t WHERE t.status = 'available'),
    'reserved_count', (SELECT count(*) FROM public.tickets AS t WHERE t.status = 'reserved' AND t.reserved_until > now()),
    'by_category', (
      SELECT coalesce(jsonb_agg(jsonb_build_object('category', x.category, 'sold_count', x.sold_count, 'sold_value', x.sold_value) ORDER BY x.category), '[]'::jsonb)
      FROM (SELECT t.category, count(*) AS sold_count, coalesce(sum(t.amount),0) AS sold_value FROM public.tickets AS t WHERE t.status='sold' GROUP BY t.category) AS x
    ),
    'recent_sales', (
      SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.sold_at DESC), '[]'::jsonb)
      FROM (SELECT t.ticket_no, t.customer_name, t.phone, t.amount, t.payment_mode, t.payment_reference, t.sold_by_email, t.sold_at FROM public.tickets AS t WHERE t.status='sold' ORDER BY t.sold_at DESC LIMIT 50) AS x
    )
  ) INTO result;
  RETURN result;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_admin_dashboard() FROM public;
GRANT EXECUTE ON FUNCTION public.get_admin_dashboard() TO authenticated;
