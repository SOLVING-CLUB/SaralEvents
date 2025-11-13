"use client";
import { useEffect } from "react";
import { useParams } from "next/navigation";

export default function ServicePage() {
  const params = useParams();
  const serviceId = params.id as string;

  useEffect(() => {
    if (!serviceId) return;

    const isAndroid = /Android/i.test(navigator.userAgent);
    const isIOS = /iPhone|iPad|iPod/i.test(navigator.userAgent);

    // Try to open in app
    if (isAndroid) {
      // Android: Try custom scheme first
      const customScheme = `saralevents://service/${serviceId}`;
      window.location.href = customScheme;

      // Fallback: Try intent URL
      setTimeout(() => {
        const intent = `intent://service/${serviceId}#Intent;scheme=saralevents;package=com.mycompany.saralevents;end`;
        window.location.href = intent;
      }, 500);
    } else if (isIOS) {
      // iOS: Try custom scheme
      const customScheme = `saralevents://service/${serviceId}`;
      window.location.href = customScheme;
    }

    // If still on page after 2 seconds, show message
    setTimeout(() => {
      const appLink = `saralevents://service/${serviceId}`;
      alert(`Please install Saral Events app and open this link:\n${appLink}`);
    }, 2000);
  }, [serviceId]);

  return (
    <div className="max-w-2xl mx-auto p-6">
      <div className="rounded-xl overflow-hidden border p-5">
        <h1 className="text-2xl font-bold mb-4">View Service</h1>
        {serviceId ? (
          <>
            <p className="text-gray-600 mb-4">
              Opening service in app... If the app doesn't open, please install Saral Events app.
            </p>
            <a
              href={`saralevents://service/${serviceId}`}
              className="inline-flex items-center px-4 py-2 rounded-md bg-black text-white"
            >
              Open in App
            </a>
          </>
        ) : (
          <p className="text-gray-600">No service ID provided.</p>
        )}
      </div>
    </div>
  );
}

