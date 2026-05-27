require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

// Map DB_PASSWORD to DB_PASS since database.js uses DB_PASS
if (process.env.DB_PASSWORD && !process.env.DB_PASS) {
  process.env.DB_PASS = process.env.DB_PASSWORD;
}

const { sequelize } = require('../src/config/database');
const { v4: uuidv4 } = require('uuid');
const User = require('../src/models/User.model');
const Post = require('../src/models/Post.model');
const PostMedia = require('../src/models/PostMedia.model');
const Advertiser = require('../src/models/Advertiser.model');
const Campaign = require('../src/models/Campaign.model');
const AdCreative = require('../src/models/AdCreative.model');

// Load index.js to configure associations
require('../src/models/index.js');

const DUMMY_HASH = '$2b$10$abcdefghijklmnopqrstuvwxyz1234567890abcdefghijklm'; // complies with len validation

const SEED_USERS = [
  {
    username: 'global_news',
    email: 'news@global.com',
    fullName: 'Global News Network',
    profile_pic_url: 'https://images.unsplash.com/photo-1493612276216-ee3925520721?q=80&w=200',
    bio: 'Your trusted source for global breaking news, live event coverage, and deep investigative journalism.',
    is_verified: true
  },
  {
    username: 'global_ent',
    email: 'entertainment@global.com',
    fullName: 'Global Entertainment',
    profile_pic_url: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?q=80&w=200',
    bio: 'Lights, camera, action! 🎬 Delivering the latest movie updates, music festival news, and pop culture highlights directly to your screen.',
    is_verified: true
  },
  {
    username: 'global_funny',
    email: 'funny@global.com',
    fullName: 'Global Funny & Memes',
    profile_pic_url: 'https://images.unsplash.com/photo-1533738363-b7f9aef128ce?q=80&w=200',
    bio: 'Your daily dose of comedy, hilarious memes, and viral videos. Smiling is free, so do it often! 😂',
    is_verified: true
  }
];

const SEED_POSTS = [
  // GLOBAL NEWS GIANTS (3 Posts)
  {
    username: 'global_news',
    caption: `🌍 BREAKING NEWS: Humanity is on the verge of returning to the Moon! The next-generation lunar exploration mission has officially cleared its final systems check and is scheduled for launch early next month.\n\nScientists from international space coalitions have verified that all deep-space communications and solar shielding arrays are functioning at 100% capacity. This historic expedition aims to pave the way for sustainable deep-space bases and eventual human journeys to Mars.\n\n#GlobalNews #Space #SpaceExploration #NASA #MoonMission #ScienceNews`,
    imageUrl: 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=80&w=1080'
  },
  {
    username: 'global_news',
    caption: `📰 GLOBAL ECONOMY REPORT: The transition toward clean and renewable energy systems has created over 10 million new technology and infrastructure jobs worldwide in the last fiscal year, according to a comprehensive joint economic study released today.\n\nSubstantial green investment programs in modern solar farms, offshore wind grids, and large-scale grid storage technologies have led to an unprecedented manufacturing boom. Leading economists project this sustainable trend will continue to accelerate over the next decade.\n\n#CleanEnergy #Economy #Sustainability #GreenJobs #Future`,
    imageUrl: 'https://images.unsplash.com/photo-1504711434969-e33886168f5c?q=80&w=1080'
  },
  {
    username: 'global_news',
    caption: `🏢 METROPOLIS REVOLUTION: Prominent urban architects have unveiled plans for a groundbreaking zero-emission vertical city forest in the heart of the metropolis, aiming to redefine sustainable urban living for generations to come.\n\nSpanning over 45 levels, the complex will integrate thousands of native plant species and sophisticated high-efficiency solar captures, providing naturally filtered clean air and completely self-sustainable water systems for over five thousand active residents.\n\n#Architecture #GreenCity #SmartLiving #FutureDesign #SustainableUrbanism`,
    imageUrl: 'https://images.unsplash.com/photo-1526470608268-f674ce90ebd4?q=80&w=1080'
  },

  // ENTERTAINMENT SENSATIONS (4 Posts)
  {
    username: 'global_ent',
    caption: `🎸 ROCK THE COLISEUM: The legendary annual Summer Solstice Rock Festival returned last night with a spectacular record-breaking crowd of over eighty-five thousand ecstatic fans witnessing music history!\n\nThe state-of-the-art stage setup featured brilliant multi-colored laser displays and incredible surround sound projection systems that vibrated the entire arena. Outstanding headlining performances delivered an emotional set that will be talked about for decades.\n\n#LiveMusic #MusicFestival #Concert #RockMusic #Vibes #SummerVibes`,
    imageUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?q=80&w=1080'
  },
  {
    username: 'global_ent',
    caption: `🎬 CINEMATIC SHOWCASE: The highly anticipated modern cinematic masterpiece from the award-winning director has officially broken global box office records on its opening weekend, securing critical acclaim worldwide.\n\nFilm critics are praising the movie's stellar casting, revolutionary high-fidelity camera work, and an emotionally moving orchestral soundtrack. Fans are already calling it a strong contender for next year's major Academy Awards.\n\n#Hollywood #Cinema #MovieReview #FilmRelease #BoxOffice`,
    imageUrl: 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?q=80&w=1080'
  },
  {
    username: 'global_ent',
    caption: `🎧 ELECTRONIC SUNSET: A mesmerizing rooftop DJ set overlooking the city's neon-lit skyline captured the essence of summer music culture last night, creating an unforgettable atmosphere for attendees.\n\nCombining deep house basslines with progressive synth progressions, the performance kept the crowd dancing late into the night. Look out for the full recorded high-definition set dropping online this Friday!\n\n#ElectronicMusic #DJ #RooftopParty #SunsetVibes #DanceMusic #ClubCulture`,
    imageUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?q=80&w=1080'
  },
  {
    username: 'global_ent',
    caption: `🎭 BROADWAY EXTRAVAGANZA: The spectacular performing arts theater group marked their 500th continuous live show last night with an ultra-exclusive production that captivated all attendees.\n\nFeaturing intricate custom costumes and gorgeous hand-painted scenic backgrounds, the actors delivered a dramatic theatrical experience that received a well-deserved five-minute standing ovation at the final curtain drop.\n\n#Theater #Broadway #Drama #PerformingArts #LiveShow #ArtsCulture`,
    imageUrl: 'https://images.unsplash.com/photo-1603190287605-e6ade32fa852?q=80&w=1080'
  },

  // FUNNY & MEMES GIANTS (3 Posts)
  {
    username: 'global_funny',
    caption: `🕶️ When you finally put on your expensive sunglasses and instantly feel like you own 51% of the company, but then you remember you're just here to get free coffee and look busy. \n\nDrop a comment if you've ever masterfully perfected the art of walking fast with a paper folder to avoid being assigned extra projects at work! 😂🙌\n\n#Memes #FunnyQuotes #WorkLife #OfficeHumor #CatMemes #CoolCats`,
    imageUrl: 'https://images.unsplash.com/photo-1533738363-b7f9aef128ce?q=80&w=1080'
  },
  {
    username: 'global_funny',
    caption: `🦙 Presenting the supreme ruler of local mountains, absolute master of photobombs, and official model for perfect side-eye expressions. This majestic alpaca has officially seen your browser history and is highly unimpressed by your lifestyle choices.\n\nTag that one friend who always pulls this exact face when they hear a ridiculous rumor! 👇\n\n#FunnyAnimals #Alpaca #SideEye #MemeGenerator #Humor #DailyLaughs`,
    imageUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?q=80&w=1080'
  },
  {
    username: 'global_funny',
    caption: `🎨 An exclusive look inside the prestigious national museum's private collection, featuring a timeless renaissance portrait of a refined feline contemplation. Art historians agree this masterpiece represents the pure philosophy of "if I fits, I sits."\n\nIs it a painting? Is it a cat? It's pure, elegant comedy gold. 🐱🖼️\n\n#ArtHumor #RenaissanceCat #FunnyMuseum #CatLife #ClassicMeme #WholesomeHumor`,
    imageUrl: 'https://images.unsplash.com/photo-1513364776144-60967b0f800f?q=80&w=1080'
  }
];

const SEED_ADS = [
  {
    advertiserName: 'Spotify',
    headline: 'Get 3 Months Free',
    primaryText: 'Uninterrupted music. Just premium sound. Listen offline, play on-demand, and skip as much as you like. Ad-free music.',
    description: 'Listen offline. No ads.',
    imageUrl: 'https://images.unsplash.com/photo-1610438235354-a6fa524e6276?q=80&w=1080',
    ctaUrl: 'https://spotify.com/premium',
    ctaType: 'learn_more',
    logoUrl: 'https://images.unsplash.com/photo-1610438235354-a6fa524e6276?q=80&w=200'
  },
  {
    advertiserName: 'Google',
    headline: 'Google Pixel 8 Pro',
    primaryText: 'Designed by Google, with AI at the center. Experience the best camera yet, incredibly smart assistant, and all-day battery.',
    description: 'The smart phone by Google.',
    imageUrl: 'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?q=80&w=1080',
    ctaUrl: 'https://store.google.com/pixel',
    ctaType: 'shop_now',
    logoUrl: 'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?q=80&w=200'
  },
  {
    advertiserName: 'Apple',
    headline: 'iPhone 15 Pro',
    primaryText: 'Forged in titanium. Featuring the A17 Pro chip, customizable Action button, and a powerful camera system.',
    description: 'Titanium. A17 Pro.',
    imageUrl: 'https://images.unsplash.com/photo-1510557880182-3d4d3cba35a5?q=80&w=1080',
    ctaUrl: 'https://apple.com/iphone',
    ctaType: 'learn_more',
    logoUrl: 'https://images.unsplash.com/photo-1510557880182-3d4d3cba35a5?q=80&w=200'
  },
  {
    advertiserName: 'Nike',
    headline: 'Just Do It. Air Max.',
    primaryText: 'Push the limits of performance. The new Air Max combines responsive cushioning with lightweight breathability.',
    description: 'Run on air. Shop new arrivals.',
    imageUrl: 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?q=80&w=1080',
    ctaUrl: 'https://nike.com',
    ctaType: 'shop_now',
    logoUrl: 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?q=80&w=200'
  }
];

async function seed() {
  try {
    console.log('Connecting to database...');
    await sequelize.authenticate();
    console.log('Connected.');

    // ─── 1. SEED USERS & POSTS ───────────────────────────────
    const userMap = {};

    for (const u of SEED_USERS) {
      let user = await User.findOne({ where: { username: u.username } });
      if (!user) {
        user = await User.create({
          id: uuidv4(),
          username: u.username,
          email: u.email,
          password_hash: DUMMY_HASH,
          fullName: u.fullName,
          profile_pic_url: u.profile_pic_url,
          bio: u.bio,
          is_verified: u.is_verified,
          is_active: true
        });
        console.log(`Created test user: ${u.username}`);
      } else {
        console.log(`Test user already exists: ${u.username}`);
      }
      userMap[u.username] = user;
    }

    // Clear previous posts for these test accounts to avoid duplicates on multiple runs
    const testUserIds = Object.values(userMap).map(u => u.id);
    await Post.destroy({ where: { userId: testUserIds } });
    console.log('Cleaned up previous posts from test users.');

    // Create new posts
    for (const p of SEED_POSTS) {
      const user = userMap[p.username];
      const postId = uuidv4();
      await Post.create({
        id: postId,
        userId: user.id,
        caption: p.caption,
        likesCount: 0,
        commentsCount: 0,
        isArchived: false
      });

      await PostMedia.create({
        id: uuidv4(),
        postId: postId,
        url: p.imageUrl,
        thumbnailUrl: p.imageUrl,
        mediaType: 'image',
        order: 0,
        width: 1080,
        height: 1080
      });
      console.log(`Published HD post for ${p.username}`);
    }

    // ─── 2. SEED ADVERTISER, CAMPAIGNS & CREATIVES ───────────
    // Get/create an advertiser linked to a test user
    const hostUser = userMap['global_news'];
    let advertiser = await Advertiser.findOne({ where: { userId: hostUser.id } });
    if (!advertiser) {
      advertiser = await Advertiser.create({
        id: uuidv4(),
        userId: hostUser.id,
        businessName: 'App Premium Brands LLC',
        businessEmail: 'ads@premiumbrands.com',
        businessCategory: 'tech',
        logoUrl: hostUser.profile_pic_url,
        isVerified: true,
        balance: 1000000 // $10,000.00
      });
      console.log('Created Advertiser account');
    }

    // Clean up previous campaigns of this advertiser
    await Campaign.destroy({ where: { advertiserId: advertiser.id } });
    console.log('Cleaned up previous test campaigns.');

    // Create campaigns and ad creatives
    for (const ad of SEED_ADS) {
      const campaignId = uuidv4();
      await Campaign.create({
        id: campaignId,
        advertiserId: advertiser.id,
        name: `${ad.advertiserName} Campaign`,
        objective: 'awareness',
        status: 'active',
        budgetType: 'daily',
        budgetAmount: 500000, // $5,000.00 daily budget
        budgetSpent: 0,
        bidStrategy: 'lowest_cost',
        bidAmount: 200, // $2.00 bid
        startDate: new Date(Date.now() - 24 * 60 * 60 * 1000), // Active since yesterday
        endDate: null,
        placementFeed: true,
        placementReels: true,
        placementStories: true
      });

      await AdCreative.create({
        id: uuidv4(),
        campaignId: campaignId,
        advertiserId: advertiser.id,
        type: 'image',
        imageUrl: ad.imageUrl,
        advertiserName: ad.advertiserName,
        advertiserAvatarUrl: ad.logoUrl,
        headline: ad.headline,
        primaryText: ad.primaryText,
        description: ad.description,
        ctaType: ad.ctaType,
        ctaUrl: ad.ctaUrl,
        status: 'active'
      });
      console.log(`Created Ad Creative for brand: ${ad.advertiserName}`);
    }

    console.log('🎉 Database Seeding successfully completed!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Seeding failed:', error);
    process.exit(1);
  }
}

seed();
