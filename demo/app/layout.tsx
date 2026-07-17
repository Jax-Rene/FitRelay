import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "随练 AI · 静态产品 Demo",
  description: "给训练不规律但有基础的人：每次到了健身房，按今天的真实状态接着练。",
  icons: {
    icon: "/logo.png",
    apple: "/logo.png",
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="zh-CN"><body>{children}</body></html>;
}
