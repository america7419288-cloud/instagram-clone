// server/src/controllers/gif.controller.js

const { successResponse, errorResponse } = require('../utils/response.utils');

// High-fidelity trending mock GIFs with verified working animation URLs
const MOCK_GIFS = [
  {
    id: "gif_cat_highfive",
    url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExM3h0Y3JscXh0bDF6cXBhZHA1YmR5MnlydnV1MG15YjZ4eDk1cGtveSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/VbnUQpnihcIgCTCwXo/giphy.gif",
    preview_url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExM3h0Y3JscXh0bDF6cXBhZHA1YmR5MnlydnV1MG15YjZ4eDk1cGtveSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/VbnUQpnihcIgCTCwXo/giphy.gif",
    title: "Cute Cat High Five",
    width: 480,
    height: 480,
    source: "giphy",
    tags: ["cat", "highfive", "cute", "happy", "yes", "boom"]
  },
  {
    id: "gif_minions_happy",
    url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExbDVqNzRqd2RrbW84ZngyZXphdHJ4NG5pdmM5enVyZzB1N2tzc3E3bSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/3NtY188QaxDdC/giphy.gif",
    preview_url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExbDVqNzRqd2RrbW84ZngyZXphdHJ4NG5pdmM5enVyZzB1N2tzc3E3bSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/3NtY188QaxDdC/giphy.gif",
    title: "Excited Minions Happy",
    width: 480,
    height: 360,
    source: "giphy",
    tags: ["happy", "excited", "minions", "dance", "celebrate", "party"]
  },
  {
    id: "gif_puppy_running",
    url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExM3h2OGJrdWZqMHZ2Mmd2azFjcG03NXRiNXU5eWlkNGE5anQwdTdkOCZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/t372vH3qyepk4/giphy.gif",
    preview_url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExM3h2OGJrdWZqMHZ2Mmd2azFjcG03NXRiNXU5eWlkNGE5anQwdTdkOCZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/t372vH3qyepk4/giphy.gif",
    title: "Happy Running Puppy Dog",
    width: 480,
    height: 480,
    source: "giphy",
    tags: ["dog", "puppy", "running", "happy", "cute", "fun", "animals"]
  },
  {
    id: "gif_drake_dance",
    url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExbTZ2b3BhMDdyMXU1aGFqOXA5MTA5b2xib2lydmpsbmN5ZnB6bThneSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/l3q2zVr6cu95nF6O4/giphy.gif",
    preview_url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExbTZ2b3BhMDdyMXU1aGFqOXA5MTA5b2xib2lydmpsbmN5ZnB6bThneSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/l3q2zVr6cu95nF6O4/giphy.gif",
    title: "Drake Hotline Bling Dance",
    width: 480,
    height: 270,
    source: "giphy",
    tags: ["drake", "dance", "rap", "music", "meme", "happy", "vibe"]
  },
  {
    id: "gif_spongebob_breathing",
    url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExMjdjM251aHY1YTB6NGk1Zms2MXlqaXB2Nzg1bnAwa3oxMHFhcjZwbSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/13CoXDiaCcC2EA/giphy.gif",
    preview_url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExMjdjM251aHY1YTB6NGk1Zms2MXlqaXB2Nzg1bnAwa3oxMHFhcjZwbSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/13CoXDiaCcC2EA/giphy.gif",
    title: "SpongeBob Breathing Hyper",
    width: 480,
    height: 360,
    source: "giphy",
    tags: ["spongebob", "excited", "happy", "pant", "hype", "cartoon"]
  },
  {
    id: "gif_shocked_pikachu",
    url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExOTVpMTVyZHpqNXg4NnJzZnZqYXBrcnQ0MmF3a2MwbXFrczR1anF6ayZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/3kzJvEciJa94SMW3hE/giphy.gif",
    preview_url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExOTVpMTVyZHpqNXg4NnJzZnZqYXBrcnQ0MmF3a2MwbXFrczR1anF6ayZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/3kzJvEciJa94SMW3hE/giphy.gif",
    title: "Shocked Pikachu Face",
    width: 480,
    height: 360,
    source: "giphy",
    tags: ["pikachu", "shocked", "wow", "pokemon", "meme", "what", "surprise"]
  },
  {
    id: "gif_kitty_dance",
    url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExMWNsc2l3bjE5OW9ydDZ1amoxZnR6ZXB4MmF6cjR0ZmVwNXdrdGU0NSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/GeimqsH0TLDt4tScGw/giphy.gif",
    preview_url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExMWNsc2l3bjE5OW9ydDZ1amoxZnR6ZXB4MmF6cjR0ZmVwNXdrdGU0NSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/GeimqsH0TLDt4tScGw/giphy.gif",
    title: "Vibing Cat Headbang",
    width: 480,
    height: 480,
    source: "giphy",
    tags: ["cat", "vibing", "music", "headbang", "cool", "happy", "dance"]
  },
  {
    id: "gif_the_office_no",
    url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExdmN2cnk0bmR2eDhpd3pyNG53ajBhaGplYnJ1cG1lMDMyamwyMWI2eSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/wqbAfFwjU8laXMWZ09/giphy.gif",
    preview_url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExdmN2cnk0bmR2eDhpd3pyNG53ajBhaGplYnJ1cG1lMDMyamwyMWI2eSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/wqbAfFwjU8laXMWZ09/giphy.gif",
    title: "The Office Stanley Eye Roll",
    width: 480,
    height: 270,
    source: "giphy",
    tags: ["no", "eyeroll", "stanley", "office", "bored", "annoyed", "whatever"]
  },
  {
    id: "gif_michael_no",
    url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExMGlvMnk5bTF6dnZldG1ndHAwbnVwdHBiaTRhcm1maG9jNGc1dzgyZSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/12XMGIWtrHBl5e/giphy.gif",
    preview_url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExMGlvMnk5bTF6dnZldG1ndHAwbnVwdHBiaTRhcm1maG9jNGc1dzgyZSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/12XMGIWtrHBl5e/giphy.gif",
    title: "Michael Scott No God Please No",
    width: 480,
    height: 360,
    source: "giphy",
    tags: ["no", "god", "michael", "office", "scream", "hate", "sad"]
  },
  {
    id: "gif_success_kid",
    url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExNWoxNHRzMHQxd28wZHdyYmswbHRibG5iaGgyNWRzM2c1N3o0MTlyYyZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/111ebonMs90YLu/giphy.gif",
    preview_url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExNWoxNHRzMHQxd28wZHdyYmswbHRibG5iaGgyNWRzM2c1N3o0MTlyYyZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/111ebonMs90YLu/giphy.gif",
    title: "Success Kid Win",
    width: 480,
    height: 360,
    source: "giphy",
    tags: ["win", "success", "yes", "happy", "accomplishment", "baby", "meme"]
  },
  {
    id: "gif_shia_clap",
    url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExN3VwdjV3cmw3MHV3MHJqZmx4cjRkc3FsczRxNWdrcm5hbjJjZzd6NSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/l3q2XHFQOP6NoZGUM/giphy.gif",
    preview_url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExN3VwdjV3cmw3MHV3MHJqZmx4cjRkc3FsczRxNWdrcm5hbjJjZzd6NSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/l3q2XHFQOP6NoZGUM/giphy.gif",
    title: "Shia LaBeouf Intense Clapping",
    width: 480,
    height: 270,
    source: "giphy",
    tags: ["clap", "applause", "shia", "intense", "good", "win", "respect"]
  },
  {
    id: "gif_thanks_obama",
    url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExYTN4bmdodjIxbXhjdW1ldGFsZnBhd3cydzRybmR1djc5ODlmdjM4diZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/3o7qDJKG15e1JcT2fe/giphy.gif",
    preview_url: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExYTN4bmdodjIxbXhjdW1ldGFsZnBhd3cydzRybmR1djc5ODlmdjM4diZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/3o7qDJKG15e1JcT2fe/giphy.gif",
    title: "Obama Thanks Smile",
    width: 480,
    height: 360,
    source: "giphy",
    tags: ["thanks", "obama", "thankyou", "smile", "happy", "president"]
  }
];

/**
 * @desc    Search for GIFs
 * @route   GET /api/v1/gifs/search
 * @access  Private
 */
const searchGifs = async (req, res) => {
  try {
    const { query } = req.query;
    const apiKey = process.env.GIPHY_API_KEY;

    if (apiKey && apiKey.trim().length > 0 && apiKey !== 'YOUR_GIPHY_API_KEY') {
      console.log(`🌐 Searching Giphy API for: "${query || 'trending'}"`);
      const endpoint = query 
        ? `https://api.giphy.com/v1/gifs/search` 
        : `https://api.giphy.com/v1/gifs/trending`;

      const url = new URL(endpoint);
      url.searchParams.append('api_key', apiKey);
      url.searchParams.append('q', query || '');
      url.searchParams.append('limit', '24');
      url.searchParams.append('rating', 'g');

      const response = await fetch(url.toString());
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      const data = await response.json();

      const formatted = (data.data || []).map(g => ({
        id: g.id,
        url: g.images.original.url,
        preview_url: g.images.fixed_height_small.url || g.images.preview_gif.url,
        title: g.title,
        width: parseInt(g.images.original.width) || 480,
        height: parseInt(g.images.original.height) || 480,
        source: 'giphy'
      }));

      return successResponse(res, 200, 'Gifs fetched from Giphy API', { gifs: formatted });
    }

    // Cooldown/Fallback mode: rich filterable mock GIFs
    console.log(`🔌 Falling back to high-fidelity mock GIFs database for: "${query || 'trending'}"`);
    let results = MOCK_GIFS;

    if (query && query.trim().length > 0) {
      const cleanQuery = query.toLowerCase().trim();
      results = MOCK_GIFS.filter(gif => 
        gif.title.toLowerCase().includes(cleanQuery) || 
        gif.tags.some(tag => tag.includes(cleanQuery))
      );

      // If no matching tags, return all as fallback
      if (results.length === 0) {
        results = MOCK_GIFS;
      }
    }

    // Format output to remove internal 'tags' before returning
    const finalGifs = results.map(({ tags, ...rest }) => rest);

    return successResponse(res, 200, 'Gifs fetched (Mock Local Database)', { gifs: finalGifs });
  } catch (error) {
    console.error('❌ Gif Search Error:', error);
    // Silent failover to mock list so application never crashes
    const safeMock = MOCK_GIFS.map(({ tags, ...rest }) => rest);
    return successResponse(res, 200, 'Gifs loaded (Error Failover to Mock)', { gifs: safeMock });
  }
};

module.exports = {
  searchGifs,
};
