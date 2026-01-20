# Push Notification Campaigns Module

## Overview
A beautiful and comprehensive Push Notification Campaign module for the Admin Portal that allows admins to create, schedule, and send push notifications to users and vendors.

## Features

### ✅ Campaign Creation
- **Title & Message**: Create compelling notification content
- **Call-to-Action (CTA)**: Optional CTA button with custom text and URL
- **Image Support**: Add images to notifications for better engagement
- **Target Audience Selection**:
  - All Users
  - All Vendors
  - Specific Users (with searchable user selector)

### ✅ Scheduling
- **Instant Send**: Send notifications immediately
- **Scheduled Send**: Schedule campaigns for future delivery
- **Status Tracking**: Monitor campaign status (draft, scheduled, sending, sent, failed, cancelled)

### ✅ Campaign Management
- **Campaign List**: View all campaigns with filters and search
- **Statistics Dashboard**: Track total, sent, scheduled, and draft campaigns
- **Status Badges**: Visual indicators for campaign status
- **Audience Badges**: Show target audience for each campaign
- **Delivery Stats**: View sent count, failed count, and total recipients

## Database Schema

**Table:** `notification_campaigns`

```sql
- id (UUID, Primary Key)
- title (TEXT, Required)
- message (TEXT, Required)
- cta_text (TEXT, Optional)
- cta_url (TEXT, Optional)
- cta_action (TEXT, Optional)
- target_audience (TEXT, Required: 'all_users' | 'all_vendors' | 'specific_users')
- target_user_ids (UUID[], For specific_users)
- image_url (TEXT, Optional)
- scheduled_at (TIMESTAMPTZ, Optional)
- sent_at (TIMESTAMPTZ, Optional)
- status (TEXT, Required: 'draft' | 'scheduled' | 'sending' | 'sent' | 'failed' | 'cancelled')
- sent_count (INTEGER)
- failed_count (INTEGER)
- total_recipients (INTEGER)
- created_by (UUID, References auth.users)
- created_at (TIMESTAMPTZ)
- updated_at (TIMESTAMPTZ)
```

## Setup Instructions

### 1. Database Setup
Run the SQL migration file to create the campaigns table:

```bash
# Execute in Supabase SQL Editor
apps/company_web/campaigns_schema.sql
```

### 2. Edge Function
Ensure the `send-push-notification` edge function is deployed and configured. This function should:
- Accept `userId`, `title`, `body`, `data`, and `imageUrl` parameters
- Send push notifications via FCM (Firebase Cloud Messaging)
- Return success/failure status

### 3. Access
The Campaigns page is accessible at:
```
/dashboard/campaigns
```

It's automatically added to the sidebar navigation.

## Usage

### Creating a Campaign

1. **Click "New Campaign"** button
2. **Fill in Campaign Details**:
   - Title (required)
   - Message (required)
   - Target Audience (select from: All Users, All Vendors, or Specific Users)
   - If "Specific Users" is selected, search and select users
3. **Optional Fields**:
   - CTA Button Text
   - CTA URL
   - Image URL
4. **Choose Send Option**:
   - **Send Immediately**: Campaign is sent right away
   - **Schedule**: Set a date and time for future delivery
5. **Click "Send Now" or "Schedule Campaign"**

### Viewing Campaigns

- **Search**: Use the search bar to find campaigns by title or message
- **Filter**: Filter by status (draft, scheduled, sending, sent, failed, cancelled)
- **View Details**: Each campaign shows:
  - Title and message
  - Status badge
  - Audience badge
  - Creation and send times
  - Delivery statistics (sent count, failed count)

## Technical Implementation

### Components

**Main Page**: `apps/company_web/src/app/dashboard/campaigns/page.tsx`

**Key Functions**:
- `loadCampaigns()`: Fetches all campaigns from database
- `sendCampaign()`: Creates campaign and sends notifications (if immediate)
- `sendNotifications()`: Sends push notifications via edge function
- `loadUsers()`: Loads users for specific user selection
- `loadVendors()`: Loads vendors for vendor selection

### Edge Function Integration

The module integrates with the existing `send-push-notification` edge function:

```typescript
await supabase.functions.invoke('send-push-notification', {
  body: {
    userId,
    title: campaign.title,
    body: campaign.message,
    data: {
      type: 'campaign',
      campaign_id: campaign.id,
      cta_url: campaign.cta_url,
      cta_action: campaign.cta_action,
    },
    imageUrl: campaign.image_url,
  },
})
```

### User Selection

For "Specific Users" audience:
- Users are loaded from `user_profiles` table
- Searchable by name or email
- Multi-select interface
- Shows selected count

## UI/UX Features

### Beautiful Design
- **Modern Card Layout**: Clean, card-based design
- **Color-Coded Status**: Visual status indicators
- **Responsive Design**: Works on desktop and mobile
- **Smooth Animations**: Transitions and hover effects
- **Modal Interface**: Clean modal for campaign creation

### Statistics Dashboard
- Total Campaigns
- Sent Campaigns (green)
- Scheduled Campaigns (yellow)
- Draft Campaigns (gray)

### Status Badges
- **Draft**: Gray
- **Scheduled**: Yellow
- **Sending**: Blue
- **Sent**: Green
- **Failed**: Red
- **Cancelled**: Gray

## Future Enhancements

1. **Campaign Templates**: Pre-built templates for common notifications
2. **A/B Testing**: Test different messages with different user groups
3. **Analytics**: Detailed analytics on open rates, click rates
4. **Rich Media**: Support for videos and interactive content
5. **Recurring Campaigns**: Schedule recurring notifications
6. **Segmentation**: Advanced user segmentation (by location, behavior, etc.)
7. **Preview**: Preview notification before sending
8. **Bulk Operations**: Edit or delete multiple campaigns

## Security

- **RLS Policies**: Row Level Security ensures only admins can access campaigns
- **Role-Based Access**: Checks for admin role before allowing operations
- **Input Validation**: All inputs are validated before submission
- **Error Handling**: Comprehensive error handling and user feedback

## Testing Checklist

- [ ] Create campaign with "All Users" audience
- [ ] Create campaign with "All Vendors" audience
- [ ] Create campaign with "Specific Users" audience
- [ ] Test instant send functionality
- [ ] Test scheduled send functionality
- [ ] Verify notifications are received on mobile apps
- [ ] Test search and filter functionality
- [ ] Verify campaign statistics update correctly
- [ ] Test error handling (invalid data, network errors)
- [ ] Verify RLS policies work correctly

## Notes

- Campaigns are stored in the database for historical tracking
- Failed notifications are tracked separately
- Scheduled campaigns can be cancelled before they're sent
- The edge function handles actual push notification delivery
- User selection is limited to 500 users for performance (can be increased)
