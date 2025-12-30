"use client";
import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase";
import Link from "next/link";

type Invitation = {
  id: string;
  title: string;
  description: string | null;
  event_date: string | null;
  event_time: string | null;
  venue_name: string | null;
  address: string | null;
  cover_image_url: string | null;
  slug: string;
};

export default function InvitePage({ params }: { params: { slug: string } }) {
  const [loading, setLoading] = useState(true);
  const [inv, setInv] = useState<Invitation | null>(null);

  useEffect(() => {
    const supabase = createClient();
    supabase
      .from("invitations")
      .select("*")
      .eq("slug", params.slug)
      .maybeSingle()
      .then(({ data }) => {
        setInv((data as Invitation) ?? null);
        setLoading(false);
      });
  }, [params.slug]);

  if (loading) return <div className="p-6">Loading…</div>;
  if (!inv) return <div className="p-6">Invitation not found</div>;

  const openInApp = () => {
    const appLink = `${window.location.origin}/invite/${inv.slug}`;
    const isAndroid = /Android/i.test(navigator.userAgent);

    if (isAndroid) {
      // Try multiple approaches for Android
      const packageName = 'com.saralevents.userapp';
      const scheme = 'saralevents';

      // Method 1: Direct intent with fallback
      const intent = `intent://invite/${inv.slug}#Intent;scheme=${scheme};package=${packageName};S.browser_fallback_url=${encodeURIComponent(
        appLink,
      )};end`;

      // Try intent first
      const iframe = document.createElement('iframe');
      iframe.style.display = 'none';
      iframe.src = intent;
      document.body.appendChild(iframe);

      // Fallback to custom scheme after a delay (for browsers that ignore intent)
      setTimeout(() => {
        window.location.href = `${scheme}://invite/${inv.slug}`;
      }, 800);

      // Final fallback to web page (if app is not installed)
      setTimeout(() => {
        window.location.href = appLink;
      }, 1600);
    } else {
      // For non-Android, just use the web link
      window.location.href = appLink;
    }
  };

  return (
    <div className="max-w-2xl mx-auto p-6">
      <div className="rounded-xl overflow-hidden border">
        {inv.cover_image_url && (
          <img src={inv.cover_image_url} alt={inv.title} className="w-full h-64 object-cover" />
        )}
        <div className="p-5">
          <h1 className="text-2xl font-bold mb-2">{inv.title}</h1>
          {inv.description && <p className="text-gray-700 mb-3">{inv.description}</p>}
          <div className="text-sm text-gray-600 space-y-1">
            <div>
              <span className="font-medium">When:</span> {[inv.event_date, inv.event_time].filter(Boolean).join(" • ")}
            </div>
            {(inv.venue_name || inv.address) && (
              <div>
                <span className="font-medium">Where:</span> {[inv.venue_name, inv.address].filter(Boolean).join(", ")}
              </div>
            )}
          </div>
          <div className="mt-5">
            <button
              className="inline-flex items-center px-4 py-2 rounded-md bg-black text-white"
              onClick={openInApp}
            >
              Open in app
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}


