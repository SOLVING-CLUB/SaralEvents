"use client";
import { useEffect } from "react";
import { useSearchParams } from "next/navigation";

export default function ReferPage() {
  const searchParams = useSearchParams();
  const code = searchParams.get("code");

  useEffect(() => {
    if (!code) return;

    const isAndroid = /Android/i.test(navigator.userAgent);
    const isIOS = /iPhone|iPad|iPod/i.test(navigator.userAgent);

    // Try to open in app
    if (isAndroid) {
      // Android: Try custom scheme first
      const customScheme = `saralevents://refer/${code}`;
      window.location.href = customScheme;

      // Fallback: Try intent URL
      setTimeout(() => {
        const intent = `intent://refer/${code}#Intent;scheme=saralevents;package=com.mycompany.saralevents;end`;
        window.location.href = intent;
      }, 500);
    } else if (isIOS) {
      // iOS: Try custom scheme
      const customScheme = `saralevents://refer/${code}`;
      window.location.href = customScheme;
    }

    // If still on page after 2 seconds, show message
    setTimeout(() => {
      const appLink = `saralevents://refer/${code}`;
      alert(`Please install Saral Events app and open this link:\n${appLink}`);
    }, 2000);
  }, [code]);

  return (
    <div className="max-w-2xl mx-auto p-6">
      <div className="rounded-xl overflow-hidden border p-5">
        <h1 className="text-2xl font-bold mb-4">Join Saral Events</h1>
        {code ? (
          <>
            <p className="mb-4">Use referral code: <strong>{code}</strong></p>
            <p className="text-gray-600 mb-4">
              Opening in app... If the app doesn't open, please install Saral Events app.
            </p>
            <a
              href={`saralevents://refer/${code}`}
              className="inline-flex items-center px-4 py-2 rounded-md bg-black text-white"
            >
              Open in App
            </a>
          </>
        ) : (
          <p className="text-gray-600">No referral code provided.</p>
        )}
      </div>
    </div>
  );
}

