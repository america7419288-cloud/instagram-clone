// server/src/utils/hashtag.utils.js

const { Hashtag, PostHashtag } = require('../models');

// ─── EXTRACT HASHTAGS FROM TEXT ────────────────────────────
// Input:  "Beautiful sunset #sunset #travel #photography"
// Output: ['sunset', 'travel', 'photography']
const extractHashtags = (text) => {
  if (!text) return [];

  // Match #word patterns
  // Allows letters, numbers, underscores
  const regex = /#([a-zA-Z0-9_]+)/g;
  const matches = text.match(regex) || [];

  // Remove # symbol and lowercase
  const hashtags = matches
    .map((tag) => tag.slice(1).toLowerCase())
    .filter((tag) => tag.length > 0 && tag.length <= 100);

  // Remove duplicates
  return [...new Set(hashtags)];
};

// ─── SAVE HASHTAGS FOR A POST ──────────────────────────────
// Creates hashtag if not exists
// Links post to hashtag
const saveHashtagsForPost = async (postId, caption, transaction = null) => {
  try {
    const hashtagNames = extractHashtags(caption);

    if (hashtagNames.length === 0) return [];

    const savedHashtags = [];

    for (const name of hashtagNames) {
      // Find or create the hashtag
      const [hashtag] = await Hashtag.findOrCreate({
        where: { name },
        defaults: { name, post_count: 0 },
        transaction,
      });

      // Increment post count
      await hashtag.increment('post_count', { transaction });

      // Link post to hashtag
      await PostHashtag.findOrCreate({
        where: { post_id: postId, hashtag_id: hashtag.id },
        transaction,
      });

      savedHashtags.push(hashtag);
    }

    return savedHashtags;

  } catch (error) {
    console.error('❌ Save hashtags error:', error);
    return [];
  }
};

// ─── REMOVE HASHTAGS FOR A POST ────────────────────────────
// When post is deleted, decrement hashtag counts
const removeHashtagsForPost = async (postId) => {
  try {
    // Get all hashtags for this post
    const postHashtags = await PostHashtag.findAll({
      where: { post_id: postId },
    });

    for (const ph of postHashtags) {
      const hashtag = await Hashtag.findByPk(ph.hashtag_id);
      if (hashtag && hashtag.post_count > 0) {
        await hashtag.decrement('post_count');
      }
    }

    // Delete the links
    await PostHashtag.destroy({ where: { post_id: postId } });

  } catch (error) {
    console.error('❌ Remove hashtags error:', error);
  }
};

module.exports = {
  extractHashtags,
  saveHashtagsForPost,
  removeHashtagsForPost,
};