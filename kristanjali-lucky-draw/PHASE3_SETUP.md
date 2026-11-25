# Phase 3 Setup — Payment Verification, Admin Controls and CSV

This phase adds:
- Admin payment verification (sold tickets start as `pending` and admins can verify them).
- Admin release of currently reserved tickets from the ticket grid.
- Admin cancellation of sold tickets with a required reason and audit entry.
- Volunteer sales performance and verified collections on the admin dashboard.
- CSV export of sales.

## 1. Database migration

In Supabase SQL Editor, run `supabase/phase3-admin-controls.sql`.
This migration adds payment verification fields and replaces the admin dashboard RPC, and adds three admin-only RPCs. It does not change ticket prices or ticket rows.

## 2. Update application files

Copy the contents of this project folder into your existing project, replacing source files. Keep your `.env.local` file and do not share it.

## 3. Run locally

```powershell
npm install
npm run dev
```

## 4. Test with test tickets first

- Login as a volunteer, reserve a ticket and confirm a sale.
- Login as admin, refresh the dashboard and verify that it appears as payment pending.
- Verify the payment and check the verified collections value.
- Test release on a reserved ticket.
- Test cancellation on a test sale; enter a reason and verify the ticket becomes available.
- Export the CSV and open it in Excel.

## Notes and limitations

- CSV export currently exports the sales list returned by the admin dashboard (up to 300 rows, the maximum ticket inventory).
- Payment verification is a separate admin action; it does not verify UPI transactions automatically.
- WhatsApp remains a volunteer-triggered prefilled message; it is not a delivery-status integration.
- This is still a pre-production app. Complete security review, permissions review, backups and testing before real sales.
