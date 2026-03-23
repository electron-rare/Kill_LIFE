"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const LINKS = [
  { href: "/", label: "Dashboard" },
  { href: "/diagram", label: "Diagram editor" },
  { href: "/pcb", label: "PCB viewer" },
  { href: "/review", label: "PR review" }
];

export function ProductNav() {
  const pathname = usePathname();

  return (
    <nav style={styles.root}>
      {LINKS.map((link) => {
        const active = pathname === link.href;

        return (
          <Link
            href={link.href}
            key={link.href}
            style={{
              ...styles.link,
              ...(active ? styles.linkActive : null)
            }}
          >
            {link.label}
          </Link>
        );
      })}
    </nav>
  );
}

const styles: Record<string, React.CSSProperties> = {
  root: {
    display: "flex",
    gap: "10px",
    flexWrap: "wrap"
  },
  link: {
    padding: "10px 14px",
    borderRadius: "999px",
    textDecoration: "none",
    background: "rgba(8, 16, 29, 0.96)",
    border: "1px solid rgba(149, 188, 255, 0.16)",
    color: "#d9ebff"
  },
  linkActive: {
    background:
      "linear-gradient(135deg, rgba(119, 242, 201, 0.22), rgba(126, 168, 255, 0.24))",
    border: "1px solid rgba(119, 242, 201, 0.32)"
  }
};
