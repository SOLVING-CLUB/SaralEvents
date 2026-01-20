/**
 * Web Push Notification Service for Company Web App
 * Uses Web Push API with VAPID keys
 */

export interface PushNotificationPayload {
  title: string;
  body: string;
  data?: Record<string, any>;
  imageUrl?: string;
}

class PushNotificationService {
  private registration: ServiceWorkerRegistration | null = null;
  private subscription: PushSubscription | null = null;
  private vapidPublicKey: string | null = null;

  /**
   * Initialize web push notifications
   */
  async initialize(): Promise<boolean> {
    if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
      console.warn('⚠️ [Company] Push notifications are not supported in this browser');
      return false;
    }

    try {
      // Register service worker
      this.registration = await navigator.serviceWorker.register('/sw.js');
      console.log('✅ [Company] Service worker registered');

      // Request notification permission
      const permission = await Notification.requestPermission();
      if (permission !== 'granted') {
        console.warn('⚠️ [Company] Notification permission denied');
        return false;
      }

      // Get VAPID public key from server/edge function
      // For now, we'll get it from environment or fetch from Supabase
      await this.getVapidKey();

      // Subscribe to push notifications
      await this.subscribe();

      return true;
    } catch (error) {
      console.error('❌ [Company] Error initializing push notifications:', error);
      return false;
    }
  }

  /**
   * Get VAPID public key
   * This should be fetched from your Supabase Edge Function or environment
   */
  private async getVapidKey(): Promise<void> {
    // TODO: Fetch VAPID public key from Supabase Edge Function
    // For now, you'll need to set this in your environment
    // The VAPID key pair should be generated and stored securely
    this.vapidPublicKey = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY || '';
    
    if (!this.vapidPublicKey) {
      throw new Error('VAPID public key not configured');
    }
  }

  /**
   * Subscribe to push notifications
   */
  private async subscribe(): Promise<void> {
    if (!this.registration) {
      throw new Error('Service worker not registered');
    }

    try {
      // Check if already subscribed
      this.subscription = await this.registration.pushManager.getSubscription();

      if (!this.subscription) {
        // Subscribe with VAPID key
        this.subscription = await this.registration.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: this.urlBase64ToUint8Array(this.vapidPublicKey!),
        });
      }

      // Register subscription with Supabase
      await this.registerSubscription();

      console.log('✅ [Company] Subscribed to push notifications');
    } catch (error) {
      console.error('❌ [Company] Error subscribing to push:', error);
      throw error;
    }
  }

  /**
   * Register push subscription with Supabase
   */
  private async registerSubscription(): Promise<void> {
    if (!this.subscription) {
      throw new Error('No subscription available');
    }

    try {
      const { createClient } = await import('./supabase');
      const supabase = createClient();
      const { data: { user } } = await supabase.auth.getUser();

      if (!user) {
        console.warn('⚠️ [Company] No user logged in, skipping subscription registration');
        return;
      }

      // Convert subscription to JSON
      const subscriptionJson = this.subscription.toJSON();

      // Register in fcm_tokens table (reusing the same table)
      const { error } = await supabase
        .from('fcm_tokens')
        .upsert(
          {
            user_id: user.id,
            token: JSON.stringify(subscriptionJson), // Store web push subscription as JSON
            device_type: 'web',
            device_id: this.getBrowserFingerprint(),
            app_version: '1.0.0', // Update with actual version
            is_active: true,
            updated_at: new Date().toISOString(),
          },
          {
            onConflict: 'token',
          }
        );

      if (error) {
        throw error;
      }

      console.log('✅ [Company] Push subscription registered in database');
    } catch (error) {
      console.error('❌ [Company] Error registering subscription:', error);
      throw error;
    }
  }

  /**
   * Unsubscribe from push notifications
   */
  async unsubscribe(): Promise<void> {
    if (this.subscription) {
      await this.subscription.unsubscribe();
      this.subscription = null;
      console.log('✅ [Company] Unsubscribed from push notifications');
    }
  }

  /**
   * Convert VAPID key from base64 URL to Uint8Array
   */
  private urlBase64ToUint8Array(base64String: string): Uint8Array {
    const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
    const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');

    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);

    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  }

  /**
   * Get browser fingerprint for device identification
   */
  private getBrowserFingerprint(): string {
    // Simple fingerprint based on user agent and screen resolution
    const ua = navigator.userAgent;
    const screen = `${screen.width}x${screen.height}`;
    return btoa(`${ua}-${screen}`).substring(0, 32);
  }

  /**
   * Get current subscription
   */
  getSubscription(): PushSubscription | null {
    return this.subscription;
  }
}

// Singleton instance
export const pushNotificationService = new PushNotificationService();
