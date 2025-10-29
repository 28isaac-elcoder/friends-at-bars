# User Check-ins Feature

## Overview

The app now differentiates between **all check-ins** (shown on the map) and **user's own check-ins** (shown in the list).

## How It Works

### localStorage Tracking

- When a user creates a check-in, the Supabase ID is stored in `localStorage` under the key `"userCheckInIds"`
- This persists across browser sessions for that specific user/device
- No authentication required - it's device-based tracking

### Data Flow

1. **Creating a Check-in:**
   - User fills out the form and submits
   - Check-in is saved to Supabase
   - The returned Supabase ID is stored in localStorage
   - Data is reloaded to show the new check-in

2. **Loading Check-ins:**
   - All check-ins are fetched from Supabase (for the map)
   - User's check-in IDs are retrieved from localStorage
   - Check-ins are filtered: only those matching localStorage IDs are shown in "My Check-ins"

3. **Display:**
   - **Map**: Shows ALL check-ins from all users (markers highlight venues with activity)
   - **My Check-ins List**: Shows ONLY check-ins created by this user on this device

## Files Modified

### New Files

- `src/lib/userCheckIns.ts` - Utility functions for localStorage management

### Updated Files

- `src/components/CheckInForm.tsx` - Tracks Supabase ID after successful submission
- `src/pages/Home.tsx` - Manages two separate states (all vs user check-ins)
- `src/components/CheckInList.tsx` - Updated title to "My Check-ins"

## Limitations

- **Device-specific**: Check-ins are tracked per browser/device, not per user account
- **localStorage**: Clearing browser data will lose the tracking (but check-ins remain in Supabase)
- **No cross-device sync**: A user's check-ins won't show on a different device

## Future Enhancements

To make this more robust, consider:

1. **User Authentication**: Use Supabase Auth to tie check-ins to actual user accounts
2. **User ID Column**: Add a `user_id` column to the `checkins` table
3. **Cross-device Sync**: Check-ins would then show across all devices for a logged-in user
4. **Privacy Controls**: Users could choose to make check-ins public or private

## Testing

1. **Create a check-in** - It should appear in "My Check-ins"
2. **Refresh the page** - Your check-in should still be in "My Check-ins"
3. **Open in incognito/another browser** - You won't see your check-ins in the list (but will see them on the map)
4. **Have a friend create a check-in** - You'll see it on the map, but not in your "My Check-ins" list
