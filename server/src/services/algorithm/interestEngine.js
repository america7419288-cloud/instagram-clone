// server/src/services/algorithm/interestEngine.js

const { UserInterestProfile, ContentInteraction } = require('../../models');

// Action weights for interest score calculation
const ACTION_WEIGHTS = {
  like: 1.0,
  comment: 2.0,
  share: 3.0,
  save: 3.0,
  profile_visit: 1.5,
  hashtag_click: 1.0,
  follow: 5.0,
  video_watch_25: 0.5,
  video_watch_50: 1.0,
  video_watch_75: 1.5,
  video_watch_100: 2.0,
  carousel_swipe: 1.0,
  link_click: 2.0,
  story_reply: 2.0,
  story_react: 1.0,
  not_interested: -3.0,
  hide: -2.0,
  report: -5.0,
  unfollow: -3.0,
  scroll_past: -0.5,
};

// Category mapping from hashtags
const HASHTAG_CATEGORIES = {
  fashion: ['fashion', 'style', 'outfit', 'ootd', 'clothing', 'designer', 'streetwear', 'luxury'],
  food: ['food', 'foodie', 'recipe', 'cooking', 'restaurant', 'chef', 'baking', 'cuisine'],
  travel: ['travel', 'wanderlust', 'explore', 'adventure', 'vacation', 'trip', 'tourism', 'backpacking'],
  fitness: ['fitness', 'workout', 'gym', 'exercise', 'health', 'bodybuilding', 'yoga', 'running'],
  tech: ['tech', 'technology', 'coding', 'programming', 'software', 'ai', 'startup', 'developer'],
  music: ['music', 'song', 'artist', 'hiphop', 'pop', 'rock', 'edm', 'musician'],
  art: ['art', 'artwork', 'painting', 'drawing', 'illustration', 'design', 'creative', 'artist'],
  gaming: ['gaming', 'gamer', 'game', 'esports', 'twitch', 'playstation', 'xbox', 'nintendo'],
  beauty: ['beauty', 'makeup', 'skincare', 'cosmetics', 'glam', 'haircare', 'nails'],
  sports: ['sports', 'football', 'basketball', 'soccer', 'cricket', 'tennis', 'athletics'],
  education: ['education', 'learning', 'science', 'history', 'books', 'school', 'university', 'study'],
  entertainment: ['movie', 'series', 'netflix', 'actors', 'hollywood', 'anime', 'drama', 'celebrity'],
  news: ['news', 'politics', 'world', 'currentevents', 'journalism', 'breakingnews'],
  lifestyle: ['lifestyle', 'motivation', 'mindset', 'success', 'productivity', 'selfcare', 'positivity'],
  photography: ['photography', 'photoshoot', 'camera', 'lens', 'portrait', 'landscape', 'streetphotography'],
  humor: ['funny', 'meme', 'humor', 'comedy', 'lol', 'jokes', 'hilarious', 'viral'],
  science: ['science', 'space', 'astronomy', 'biology', 'physics', 'chemistry', 'nature'],
  health: ['health', 'wellness', 'mentalhealth', 'nutrition', 'diet', 'meditation'],
  business: ['business', 'finance', 'investing', 'money', 'marketing', 'entrepreneur'],
  pets: ['pets', 'dog', 'cat', 'animal', 'puppy', 'kitten', 'cuteanimals'],
};

/**
 * Record a user interaction and update interest profile
 */
const recordInteraction = async ({
  userId,
  contentId,
  contentType,
  authorId,
  action,
  dwellTime = 0,
  source = 'feed',
  contentCategories = [],
  contentHashtags = [],
  sessionId,
}) => {
  try {
    // Save raw interaction log in PostgreSQL
    await ContentInteraction.create({
      userId,
      contentId,
      contentType,
      authorId,
      action,
      dwellTime,
      source,
      sessionId,
      contentCategories: contentCategories || [],
      contentHashtags: contentHashtags || [],
    });

    // Update interest profile asynchronously
    setImmediate(() => {
      _updateInterestProfile({
        userId,
        authorId,
        action,
        contentCategories,
        contentHashtags,
        dwellTime,
      }).catch(err => console.error('updateInterestProfile error:', err));
    });

  } catch (error) {
    console.error('recordInteraction error:', error.message);
  }
};

/**
 * Update user's interest profile based on interaction
 */
const _updateInterestProfile = async ({
  userId,
  authorId,
  action,
  contentCategories = [],
  contentHashtags = [],
  dwellTime,
}) => {
  const weight = ACTION_WEIGHTS[action] || 0;
  if (weight === 0) return;

  // Find or create profile
  let profile = await UserInterestProfile.findOne({ where: { userId } });
  if (!profile) {
    profile = await UserInterestProfile.create({ userId });
  }

  // Find categories from hashtags
  const detectedCategories = new Set([...(contentCategories || [])]);
  (contentHashtags || []).forEach(tag => {
    const lowerTag = tag.toLowerCase().replace('#', '');
    Object.entries(HASHTAG_CATEGORIES).forEach(([category, keywords]) => {
      if (keywords.some(kw => lowerTag.includes(kw))) {
        detectedCategories.add(category);
      }
    });
  });

  // 1. Update category interest scores (with decay & cap)
  const interests = { ...(profile.interests || {}) };
  // Apply a small decay factor (0.98) to other scores so interests stay fresh
  Object.keys(interests).forEach(cat => {
    interests[cat] = interests[cat] * 0.98;
  });

  detectedCategories.forEach(category => {
    if (category in interests) {
      const increment = weight * 0.5;
      interests[category] = Math.max(0, interests[category] + increment);
    }
  });
  profile.interests = interests;
  profile.changed('interests', true);

  // 2. Update format preferences
  if (action === 'video_watch_100' || action === 'video_watch_50') {
    const prefs = { ...(profile.formatPreferences || {}) };
    prefs.reel = Math.min(100, (prefs.reel || 50) + 1);
    profile.formatPreferences = prefs;
    profile.changed('formatPreferences', true);
  }

  // 3. Update author relationship score
  if (authorId && weight > 0) {
    const recentAuthors = [...(profile.recentAuthors || [])];
    const authorIdx = recentAuthors.findIndex(a => a.authorId === authorId);
    if (authorIdx > -1) {
      recentAuthors[authorIdx].score += weight;
      recentAuthors[authorIdx].lastInteraction = new Date();
    } else {
      recentAuthors.push({
        authorId,
        score: weight,
        lastInteraction: new Date(),
      });
    }
    // Sort and keep top 100
    recentAuthors.sort((a, b) => b.score - a.score);
    profile.recentAuthors = recentAuthors.slice(0, 100);
    profile.changed('recentAuthors', true);
  }

  // 4. Update hashtag affinity
  if (contentHashtags && contentHashtags.length > 0 && weight > 0) {
    const recentHashtags = [...(profile.recentHashtags || [])];
    contentHashtags.slice(0, 5).forEach(tag => {
      const cleanTag = tag.toLowerCase().replace('#', '');
      const tagIdx = recentHashtags.findIndex(h => h.tag === cleanTag);
      if (tagIdx > -1) {
        recentHashtags[tagIdx].score += weight;
        recentHashtags[tagIdx].lastSeen = new Date();
      } else {
        recentHashtags.push({
          tag: cleanTag,
          score: weight,
          lastSeen: new Date(),
        });
      }
    });
    recentHashtags.sort((a, b) => b.score - a.score);
    profile.recentHashtags = recentHashtags.slice(0, 200);
    profile.changed('recentHashtags', true);
  }

  // 5. Update interaction counts & active time hashes
  if (action === 'like') profile.totalLikes += 1;
  if (action === 'comment') profile.totalComments += 1;
  if (action === 'share') profile.totalShares += 1;
  if (action === 'save') profile.totalSaves += 1;
  if (action === 'profile_visit') profile.totalProfileVisits += 1;

  const now = new Date();
  const hour = now.getHours();
  const day = now.getDay();

  const activeHours = { ...(profile.activeHours || {}) };
  activeHours[hour] = (activeHours[hour] || 0) + 1;
  profile.activeHours = activeHours;
  profile.changed('activeHours', true);

  const activeDays = { ...(profile.activeDays || {}) };
  activeDays[day] = (activeDays[day] || 0) + 1;
  profile.activeDays = activeDays;
  profile.changed('activeDays', true);

  profile.lastActiveAt = now;
  
  await profile.save();

  // Normalize scores (cap at 100)
  await _normalizeInterestScores(profile);
};

/**
 * Normalize interest scores to 0-100 range
 */
const _normalizeInterestScores = async (profile) => {
  if (!profile) return;
  const interests = { ...(profile.interests || {}) };
  const maxScore = Math.max(...Object.values(interests), 1);

  if (maxScore > 100) {
    const updates = {};
    Object.keys(interests).forEach(key => {
      updates[key] = Math.round(Math.min(100, (interests[key] / maxScore) * 100) * 100) / 100;
    });
    profile.interests = updates;
    profile.changed('interests', true);
    await profile.save();
  }
};

/**
 * Get user's top interests (sorted by score)
 */
const getUserTopInterests = async (userId, limit = 10) => {
  const profile = await UserInterestProfile.findOne({ where: { userId } });
  if (!profile) return [];

  const interests = profile.interests || {};
  return Object.entries(interests)
    .sort(([, a], [, b]) => b - a)
    .slice(0, limit)
    .map(([category, score]) => ({ category, score }));
};

module.exports = {
  recordInteraction,
  getUserTopInterests,
  ACTION_WEIGHTS,
  HASHTAG_CATEGORIES,
};
