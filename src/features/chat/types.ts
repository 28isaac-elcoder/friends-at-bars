export type ChatFeedSort = "recent" | "popular";

export type ChatVoteDirection = "up" | "down";

/** Current user's vote on a post: +1, -1, or null if none. */
export type ChatMyVote = 1 | -1 | null;

export interface ChatPost {
  id: string;
  author_id: string;
  body: string;
  venue_name: string;
  score: number;
  is_hidden: boolean;
  created_at: string;
  expires_at: string;
}

export interface ChatVote {
  post_id: string;
  voter_id: string;
  vote: 1 | -1;
  created_at: string;
  updated_at: string;
}

export interface ChatPostWithVote extends ChatPost {
  myVote: ChatMyVote;
}
