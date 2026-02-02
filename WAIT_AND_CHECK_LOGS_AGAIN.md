# Wait and Check Edge Function Logs

## ⏰ **WAIT 20-30 SECONDS**

pg_net is async, so wait a bit, then:

1. Go to Supabase Dashboard > **Edge Functions** > **send-push-notification** > **Logs**
2. **Refresh the logs**
3. Look for logs around the current time
4. **Share what you see**

---

## 🔍 **IF STILL NO LOGS**

If after 30 seconds there are still no logs, this suggests Supabase might be blocking pg_net requests to edge functions, or there's a configuration issue.

---

## 💡 **ALTERNATIVE SOLUTION: Call Edge Function from App Code**

Since direct tests work perfectly, we can call the edge function directly from your app code instead of using database triggers with pg_net.

**This would mean:**
- Database triggers call app code/webhook
- App code calls edge function directly
- Edge function sends notification

**But first, let's wait and check the logs!**

---

**Wait 30 seconds, refresh logs, and share what you see!**
