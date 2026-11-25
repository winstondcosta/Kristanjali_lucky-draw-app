import type { Metadata } from 'next';
import './style.css';
export const metadata: Metadata = { title:'Kristanjali Lucky Draw Manager', description:'Private volunteer ticket management' };
export default function RootLayout({children}:{children:React.ReactNode}) { return <html lang="en"><body>{children}</body></html>; }
