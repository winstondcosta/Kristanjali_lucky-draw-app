import { NextResponse } from 'next/server';
import { appendOrUpdateTicketRow } from '@/lib/google-sheets';
import { createClient } from '@supabase/supabase-js';
export async function POST(req:Request){
 const auth=req.headers.get('authorization');
 if(!process.env.SUPABASE_SERVICE_ROLE_KEY||!auth?.startsWith('Bearer '))return NextResponse.json({error:'Unauthorised'},{status:401});
 const token=auth.slice(7);const admin=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.SUPABASE_SERVICE_ROLE_KEY);
 const {data:{user},error:authError}=await admin.auth.getUser(token);if(authError||!user)return NextResponse.json({error:'Unauthorised'},{status:401});
 const {ticket_no}=await req.json();const {data:profile}=await admin.from('profiles').select('active').eq('user_id',user.id).single();if(!profile?.active)return NextResponse.json({error:'Inactive volunteer'},{status:403});
 const {data,error}=await admin.from('tickets').select('*').eq('ticket_no',ticket_no).eq('status','sold').single();if(error||!data||data.sold_by!==user.id)return NextResponse.json({error:'Sold ticket not found for this volunteer'},{status:404});
 try{await appendOrUpdateTicketRow({ticket_no:data.ticket_no,category:data.category,customer_name:data.customer_name,phone:data.phone,amount:data.amount,payment_mode:data.payment_mode,payment_reference:data.payment_reference||'',volunteer_email:data.sold_by_email,sold_at:data.sold_at,status:data.status});await admin.from('tickets').update({sheet_synced_at:new Date().toISOString(),sheet_sync_error:null}).eq('ticket_no',ticket_no);return NextResponse.json({ok:true})}catch(e:any){await admin.from('tickets').update({sheet_sync_error:String(e.message||e)}).eq('ticket_no',ticket_no);return NextResponse.json({error:'Saved in database; Sheets sync failed and needs retry.'},{status:502})}
}
