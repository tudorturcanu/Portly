import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Portly Screenshot Builder",
  description: "Design and export App Store + Google Play screenshots for Portly.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="antialiased font-sans">{children}</body>
    </html>
  );
}

