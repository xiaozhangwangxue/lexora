import type { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: { userAgent: "*", allow: "/" },
    sitemap: "https://lexora.12323456.xyz/sitemap.xml",
    host: "https://lexora.12323456.xyz",
  };
}
