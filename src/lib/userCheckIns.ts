// Utility functions for managing user's own check-ins in localStorage

const USER_CHECKINS_KEY = "userCheckInIds";

// Get all check-in IDs created by this user
export const getUserCheckInIds = (): string[] => {
  try {
    const stored = localStorage.getItem(USER_CHECKINS_KEY);
    return stored ? JSON.parse(stored) : [];
  } catch (error) {
    console.error("Error reading user check-ins from localStorage:", error);
    return [];
  }
};

// Add a check-in ID to the user's list
export const addUserCheckInId = (checkInId: string): void => {
  try {
    const currentIds = getUserCheckInIds();
    if (!currentIds.includes(checkInId)) {
      const updatedIds = [...currentIds, checkInId];
      localStorage.setItem(USER_CHECKINS_KEY, JSON.stringify(updatedIds));
    }
  } catch (error) {
    console.error("Error saving user check-in to localStorage:", error);
  }
};

// Check if a check-in was created by this user
export const isUserCheckIn = (checkInId: string): boolean => {
  const userIds = getUserCheckInIds();
  return userIds.includes(checkInId);
};

// Remove a check-in ID from the user's list (optional, for future use)
export const removeUserCheckInId = (checkInId: string): void => {
  try {
    const currentIds = getUserCheckInIds();
    const updatedIds = currentIds.filter((id) => id !== checkInId);
    localStorage.setItem(USER_CHECKINS_KEY, JSON.stringify(updatedIds));
  } catch (error) {
    console.error("Error removing user check-in from localStorage:", error);
  }
};

// Clear all user check-ins (optional, for future use)
export const clearUserCheckIns = (): void => {
  try {
    localStorage.removeItem(USER_CHECKINS_KEY);
  } catch (error) {
    console.error("Error clearing user check-ins from localStorage:", error);
  }
};
