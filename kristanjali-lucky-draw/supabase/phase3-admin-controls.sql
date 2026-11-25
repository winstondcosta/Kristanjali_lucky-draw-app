-- Phase 3: Payment verification, admin ticket controls, volunteer performance.
-- Run this in Supabase SQL Editor. Review policies and test with non-production data first.
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS payment_status text NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending','verified'));
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS payment_verified_by uuid REFERENCES auth.users(id);
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS payment_verified_at timestamptz;

CREATE OR REPLACE FUNCTION public.get_admin_dashboard()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE result jsonb;
BEGIN
 IF NOT public.is_admin() THEN RAISE EXCEPTION 'Administrator access required'; END IF;
 SELECT jsonb_build_object(
  'sold_count',(SELECT count(*) FROM public.tickets t WHERE t.status='sold'),
  'sold_value',(SELECT coalesce(sum(t.amount),0) FROM public.tickets t WHERE t.status='sold'),
  'available_count',(SELECT count(*) FROM public.tickets t WHERE t.status='available'),
  'reserved_count',(SELECT count(*) FROM public.tickets t WHERE t.status='reserved' AND t.reserved_until>now()),
  'pending_payment_count',(SELECT count(*) FROM public.tickets t WHERE t.status='sold' AND t.payment_status='pending'),
  'verified_payment_value',(SELECT coalesce(sum(t.amount),0) FROM public.tickets t WHERE t.status='sold' AND t.payment_status='verified'),
  'by_category',(SELECT coalesce(jsonb_agg(jsonb_build_object('category',x.category,'sold_count',x.sold_count,'sold_value',x.sold_value) ORDER BY x.category),'[]'::jsonb) FROM (SELECT t.category,count(*) sold_count,coalesce(sum(t.amount),0) sold_value FROM public.tickets t WHERE t.status='sold' GROUP BY t.category) x),
  'volunteers',(SELECT coalesce(jsonb_agg(jsonb_build_object('volunteer',x.volunteer,'sold_count',x.sold_count,'sold_value',x.sold_value,'verified_value',x.verified_value) ORDER BY x.sold_count DESC),'[]'::jsonb) FROM (SELECT coalesce(t.sold_by_email,'Unknown') volunteer,count(*) sold_count,coalesce(sum(t.amount),0) sold_value,coalesce(sum(t.amount) FILTER (WHERE t.payment_status='verified'),0) verified_value FROM public.tickets t WHERE t.status='sold' GROUP BY t.sold_by_email) x),
  'recent_sales',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.sold_at DESC),'[]'::jsonb) FROM (SELECT t.ticket_no,t.category,t.customer_name,t.phone,t.amount,t.payment_mode,t.payment_reference,t.sold_by_email,t.sold_at,t.payment_status FROM public.tickets t WHERE t.status='sold' ORDER BY t.sold_at DESC LIMIT 300) x)
 ) INTO result;
 RETURN result;
END;$function$;
REVOKE ALL ON FUNCTION public.get_admin_dashboard() FROM public;
GRANT EXECUTE ON FUNCTION public.get_admin_dashboard() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_verify_payment(p_ticket_no text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE t public.tickets;
BEGIN
 IF NOT public.is_admin() THEN RAISE EXCEPTION 'Administrator access required'; END IF;
 UPDATE public.tickets SET payment_status='verified',payment_verified_by=auth.uid(),payment_verified_at=now()
 WHERE ticket_no=p_ticket_no AND status='sold' AND payment_status='pending' RETURNING * INTO t;
 IF NOT FOUND THEN RAISE EXCEPTION 'Ticket not found, not sold, or already verified'; END IF;
 INSERT INTO public.ticket_audit(ticket_no,action,actor,details) VALUES(p_ticket_no,'payment_verified',auth.uid(),jsonb_build_object('amount',t.amount,'payment_mode',t.payment_mode));
 RETURN jsonb_build_object('ticket_no',t.ticket_no,'payment_status',t.payment_status);
END;$function$;
REVOKE ALL ON FUNCTION public.admin_verify_payment(text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_verify_payment(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_release_ticket(p_ticket_no text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE t public.tickets;
BEGIN
 IF NOT public.is_admin() THEN RAISE EXCEPTION 'Administrator access required'; END IF;
 UPDATE public.tickets SET status='available',reserved_by=NULL,reserved_until=NULL
 WHERE ticket_no=p_ticket_no AND status='reserved' RETURNING * INTO t;
 IF NOT FOUND THEN RAISE EXCEPTION 'Ticket is not currently reserved'; END IF;
 INSERT INTO public.ticket_audit(ticket_no,action,actor,details) VALUES(p_ticket_no,'reservation_released',auth.uid(),jsonb_build_object('previous_reserved_by',t.reserved_by));
 RETURN jsonb_build_object('ticket_no',t.ticket_no,'status','available');
END;$function$;
REVOKE ALL ON FUNCTION public.admin_release_ticket(text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_release_ticket(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_cancel_ticket(p_ticket_no text,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE t public.tickets; old_customer text; old_amount integer;
BEGIN
 IF NOT public.is_admin() THEN RAISE EXCEPTION 'Administrator access required'; END IF;
 IF length(trim(coalesce(p_reason,'')))<5 THEN RAISE EXCEPTION 'Please provide a cancellation reason (at least 5 characters)'; END IF;
 SELECT customer_name,amount INTO old_customer,old_amount FROM public.tickets WHERE ticket_no=p_ticket_no AND status='sold' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Ticket is not currently sold'; END IF;
 UPDATE public.tickets SET status='available',reserved_by=NULL,reserved_until=NULL,customer_name=NULL,phone=NULL,payment_mode=NULL,payment_reference=NULL,sold_by=NULL,sold_by_email=NULL,sold_at=NULL,payment_status='pending',payment_verified_by=NULL,payment_verified_at=NULL,sheet_synced_at=NULL,sheet_sync_error=NULL
 WHERE ticket_no=p_ticket_no AND status='sold' RETURNING * INTO t;
 IF NOT FOUND THEN RAISE EXCEPTION 'Ticket is not currently sold'; END IF;
 INSERT INTO public.ticket_audit(ticket_no,action,actor,details) VALUES(p_ticket_no,'sale_cancelled',auth.uid(),jsonb_build_object('reason',trim(p_reason),'amount',old_amount,'previous_customer',old_customer));
 RETURN jsonb_build_object('ticket_no',t.ticket_no,'status','available');
END;$function$;
REVOKE ALL ON FUNCTION public.admin_cancel_ticket(text,text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_cancel_ticket(text,text) TO authenticated;
