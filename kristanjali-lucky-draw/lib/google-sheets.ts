import { google } from 'googleapis';

export async function appendOrUpdateTicketRow(row: { ticket_no:string; category:string; customer_name:string; phone:string; amount:number; payment_mode:string; payment_reference:string; volunteer_email:string; sold_at:string; status:string }) {
  const email = process.env.GOOGLE_SERVICE_ACCOUNT_EMAIL;
  const privateKey = process.env.GOOGLE_PRIVATE_KEY?.replace(/\\n/g, '\n');
  const spreadsheetId = process.env.GOOGLE_SHEET_ID;
  if (!email || !privateKey || !spreadsheetId) throw new Error('Google Sheets is not configured');
  const auth = new google.auth.JWT({ email, key: privateKey, scopes: ['https://www.googleapis.com/auth/spreadsheets'] });
  const sheets = google.sheets({ version:'v4', auth });
  const masterHeaders = ['Ticket No','Category','Customer Name','Mobile','Amount','Payment Mode','Payment Reference','Volunteer','Sold At','Status'];
  const masterValues = [[row.ticket_no,row.category,row.customer_name,row.phone,row.amount,row.payment_mode,row.payment_reference,row.volunteer_email,row.sold_at,row.status]];
  // Update the matching pre-seeded ticket row; append only if the register was not pre-populated.
  const existing = await sheets.spreadsheets.values.get({spreadsheetId,range:'Master Register!A:A'});
  const values = existing.data.values || [];
  let rowNumber = values.findIndex((r:any[]) => r[0] === row.ticket_no) + 1;
  if (rowNumber <= 0) {
    const headersMissing = values.length === 0;
    if (headersMissing) await sheets.spreadsheets.values.update({spreadsheetId,range:'Master Register!A1:J1',valueInputOption:'RAW',requestBody:{values:[masterHeaders]}});
    await sheets.spreadsheets.values.append({spreadsheetId,range:'Master Register!A:J',valueInputOption:'USER_ENTERED',insertDataOption:'INSERT_ROWS',requestBody:{values:masterValues}});
  } else {
    await sheets.spreadsheets.values.update({spreadsheetId,range:`Master Register!A${rowNumber}:J${rowNumber}`,valueInputOption:'USER_ENTERED',requestBody:{values:masterValues}});
  }
  await sheets.spreadsheets.values.append({spreadsheetId,range:'Sales Log!A:J',valueInputOption:'USER_ENTERED',insertDataOption:'INSERT_ROWS',requestBody:{values:masterValues}});
}
