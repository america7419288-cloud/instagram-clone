// server/src/services/upload.service.js

const multer = require('multer');
const { cloudinary, secondaryConfig } = require('../config/cloudinary');

// ─────────────────────────────────────────────────────
// MULTER CONFIGURATION
// Memory storage → we pass buffer to Cloudinary
// ─────────────────────────────────────────────────────
const storage = multer.memoryStorage();

// ─── File filter ──────────────────────────────────────
const fileFilter = (req, file, cb) => {
  const allowedImageTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'image/gif',
  ];

  const allowedVideoTypes = [
    'video/mp4',
    'video/quicktime', // .mov
    'video/x-msvideo', // .avi
    'video/x-ms-wmv',  // .wmv
    'video/webm',
    'video/3gpp',       // .3gp (mobile)
    'video/mpeg',
  ];

  const allowedAudioTypes = [
    'audio/mpeg',
    'audio/mp3',
    'audio/wav',
    'audio/x-wav',
    'audio/mp4',
    'audio/m4a',
    'audio/aac',
    'audio/ogg',
    'audio/webm',
  ];

  const isImage = allowedImageTypes.includes(file.mimetype);
  const isVideo = allowedVideoTypes.includes(file.mimetype);
  const isAudio = allowedAudioTypes.includes(file.mimetype) || file.mimetype.startsWith('audio/');

  if (isImage || isVideo || isAudio) {
    cb(null, true);
  } else {
    cb(
      new Error(
        `File type ${file.mimetype} is not supported. ` +
        'Please upload an image (JPG, PNG, WebP, GIF), video (MP4, MOV, AVI, WebM), or audio (MP3, WAV, M4A).'
      ),
      false
    );
  }
};

// ─── Multer instances ─────────────────────────────────
// For profile pictures (images only, 5MB limit)
const uploadProfilePicture = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  fileFilter: (req, file, cb) => {
    const allowed = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
    if (allowed.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Only JPG, PNG, and WebP images are allowed for profile pictures.'), false);
    }
  },
});

// For posts (images + videos, 100MB limit)
const uploadPostMedia = multer({
  storage,
  limits: { fileSize: 100 * 1024 * 1024 }, // 100MB
  fileFilter,
});

// For stories (images + videos, 50MB limit)
const uploadStoryMedia = multer({
  storage,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB
  fileFilter,
});

// ─────────────────────────────────────────────────────
// CLOUDINARY UPLOAD HELPERS
// ─────────────────────────────────────────────────────

// ─── Helper: Buffer to base64 data URI ────────────────
const bufferToDataURI = (buffer, mimetype) => {
  const base64 = buffer.toString('base64');
  return `data:${mimetype};base64,${base64}`;
};

// ─── Helper: Upload to Cloudinary via stream with secondary account failover ───
const uploadToCloudinaryStream = (buffer, options) => {
  return new Promise((resolve, reject) => {
    const uploadStream = cloudinary.uploader.upload_stream(options, (error, result) => {
      if (error) {
        if (
          error.message.includes('File size too large') ||
          error.message.includes('Invalid') ||
          error.message.includes('limit exceeded for size')
        ) {
          return reject(error);
        }

        console.warn(`⚠️ Primary Cloudinary stream upload failed (Error: ${error.message}). Trying secondary Cloudinary account...`);

        // Failover to secondary account
        const secondaryOptions = { ...options, ...secondaryConfig };
        const secondaryStream = cloudinary.uploader.upload_stream(secondaryOptions, (secError, secResult) => {
          if (secError) {
            console.error('❌ Secondary Cloudinary stream upload failed too:', secError.message);
            return reject(secError);
          }
          resolve(secResult);
        });
        secondaryStream.end(buffer);
      } else {
        resolve(result);
      }
    });

    uploadStream.end(buffer);
  });
};

// ─── Helper: Upload to Cloudinary directly with secondary account failover ───
const uploadToCloudinaryDirect = async (dataURI, options) => {
  try {
    return await cloudinary.uploader.upload(dataURI, options);
  } catch (error) {
    if (
      error.message.includes('File size too large') ||
      error.message.includes('Invalid') ||
      error.message.includes('limit exceeded for size')
    ) {
      throw error;
    }

    console.warn(`⚠️ Primary Cloudinary direct upload failed (Error: ${error.message}). Trying secondary Cloudinary account...`);

    const secondaryOptions = { ...options, ...secondaryConfig };
    try {
      return await cloudinary.uploader.upload(dataURI, secondaryOptions);
    } catch (secError) {
      console.error('❌ Secondary Cloudinary direct upload failed too:', secError.message);
      throw secError;
    }
  }
};

// ─── Upload single image to Cloudinary ────────────────
const uploadImageToCloudinary = async (
  buffer,
  mimetype,
  folder = 'instagram-clone/posts'
) => {
  try {
    const result = await uploadToCloudinaryStream(buffer, {
      folder,
      resource_type: 'image',
      fetch_format: 'auto',
      quality: 'auto',
      transformation: [
        {
          width: 1080,
          height: 1080,
          crop: 'limit',
          quality: 'auto',
          fetch_format: 'auto',
        },
      ],
    });
    return {
      url: result.secure_url,
      publicId: result.public_id,
      width: result.width,
      height: result.height,
      mediaType: 'image',
      thumbnailUrl: null,
      duration: null,
    };
  } catch (error) {
    console.error('❌ Cloudinary image upload error:', error.message);
    throw new Error('Failed to upload image. Please try again.');
  }
};

// ─── Upload video to Cloudinary ───────────────────────
const uploadVideoToCloudinary = async (
  buffer,
  mimetype,
  folder = 'instagram-clone/posts/videos'
) => {
  try {
    console.log('☁️ Uploading video to Cloudinary via stream...');
    const result = await uploadToCloudinaryStream(buffer, {
      folder,
      resource_type: 'video',
      eager: [
        {
          width: 1080,
          height: 1080,
          crop: 'fill',
          gravity: 'center',
          start_offset: '1',
          format: 'jpg',
          quality: 'auto',
        },
      ],
      eager_async: false,
      transformation: [
        {
          quality: 'auto',
          fetch_format: 'mp4',
        },
      ],
    });

    // ─── Extract thumbnail URL ─────────────────────────
    let thumbnailUrl = null;
    if (result.eager && result.eager.length > 0) {
      thumbnailUrl = result.eager[0].secure_url;
    } else {
      thumbnailUrl = result.secure_url
        .replace('/video/upload/', '/video/upload/w_1080,h_1080,c_fill,so_1,f_jpg/')
        .replace(/\.(mp4|mov|avi|webm|3gp|mpeg)$/i, '.jpg');
    }

    const duration = result.duration ? Math.round(result.duration) : null;

    console.log(`✅ Video uploaded: ${result.public_id}`);
    return {
      url: result.secure_url,
      publicId: result.public_id,
      width: result.width,
      height: result.height,
      mediaType: 'video',
      thumbnailUrl,
      duration,
    };
  } catch (error) {
    console.error('❌ Cloudinary video upload error:', error.message);

    if (error.message.includes('File size too large')) {
      throw new Error('Video file is too large. Maximum size is 100MB.');
    }
    if (error.message.includes('Invalid video')) {
      throw new Error('Invalid video format. Please use MP4, MOV, or WebM.');
    }

    throw new Error('Failed to upload video. Please try again.');
  }
};

// ─── Upload audio to Cloudinary ───────────────────────
const uploadAudioToCloudinary = async (
  buffer,
  mimetype,
  folder = 'instagram-clone/messages/audio'
) => {
  try {
    console.log('☁️ Uploading audio to Cloudinary via stream...');
    const result = await uploadToCloudinaryStream(buffer, {
      folder,
      resource_type: 'video', // Cloudinary treats audio as 'video'
    });
    return {
      url: result.secure_url,
      publicId: result.public_id,
      mediaType: 'audio',
      duration: result.duration ? Math.round(result.duration) : null,
    };
  } catch (error) {
    console.error('❌ Cloudinary audio upload error:', error.message);
    throw new Error('Failed to upload audio. Please try again.');
  }
};

// ─── Upload profile picture ────────────────────────────
const uploadProfilePictureToCloudinary = async (buffer, mimetype) => {
  try {
    const result = await uploadToCloudinaryStream(buffer, {
      folder: 'instagram-clone/profiles',
      resource_type: 'image',
      transformation: [
        {
          width: 300,
          height: 300,
          crop: 'fill',
          gravity: 'face',
          quality: 'auto',
          fetch_format: 'auto',
        },
      ],
    });
    return {
      url: result.secure_url,
      publicId: result.public_id,
    };
  } catch (error) {
    console.error('❌ Profile picture upload error:', error.message);
    throw new Error('Failed to upload profile picture. Please try again.');
  }
};

// ─── Upload story media ────────────────────────────────
const uploadStoryToCloudinary = async (buffer, mimetype) => {
  const isVideo = mimetype.startsWith('video/');

  const options = {
    folder: isVideo ? 'instagram-clone/stories/videos' : 'instagram-clone/stories',
    resource_type: isVideo ? 'video' : 'image',
  };

  if (isVideo) {
    options.eager = [
      {
        width: 1080,
        height: 1920,
        crop: 'fill',
        start_offset: '0',
        format: 'jpg',
      },
    ];
    options.eager_async = false;
  } else {
    options.transformation = [
      {
        width: 1080,
        height: 1920,
        crop: 'limit',
        quality: 'auto',
        fetch_format: 'auto',
      },
    ];
  }

  try {
    const result = await uploadToCloudinaryStream(buffer, options);

    if (isVideo) {
      const thumbnailUrl =
        result.eager?.[0]?.secure_url ||
        result.secure_url
          .replace('/video/upload/', '/video/upload/f_jpg/')
          .replace(/\.(mp4|mov|webm)$/i, '.jpg');

      return {
        url: result.secure_url,
        publicId: result.public_id,
        mediaType: 'video',
        thumbnailUrl,
        duration: result.duration ? Math.round(result.duration) : null,
      };
    } else {
      return {
        url: result.secure_url,
        publicId: result.public_id,
        mediaType: 'image',
        thumbnailUrl: null,
        duration: null,
      };
    }
  } catch (error) {
    console.error('❌ Story upload error:', error.message);
    throw new Error('Failed to upload story media. Please try again.');
  }
};

// ─── Upload Reel video to Cloudinary ──────────────────
const uploadReelToCloudinary = async (buffer, mimetype) => {
  try {
    const dataURI = bufferToDataURI(buffer, mimetype);

    console.log('☁️  Uploading reel to Cloudinary...');

    const result = await uploadToCloudinaryDirect(dataURI, {
      folder: 'instagram-clone/reels',
      resource_type: 'video',
      // ─── Generate thumbnail at 0.5 second mark ──────
      eager: [
        {
          width: 1080,
          height: 1920,
          crop: 'fill',
          gravity: 'center',
          start_offset: '0.5',
          format: 'jpg',
          quality: 'auto',
        },
      ],
      eager_async: false,
      // ─── Optimize video for mobile streaming ────────
      transformation: [
        {
          quality: 'auto',
          fetch_format: 'mp4',
          // Normalize to vertical if possible
          width: 1080,
          height: 1920,
          crop: 'limit',
        },
      ],
    });

    // ─── Extract thumbnail ───────────────────────────
    let thumbnailUrl = null;
    if (result.eager && result.eager.length > 0) {
      thumbnailUrl = result.eager[0].secure_url;
    } else {
      thumbnailUrl = result.secure_url
        .replace('/video/upload/', '/video/upload/w_1080,h_1920,c_fill,so_0.5,f_jpg/')
        .replace(/\.(mp4|mov|avi|webm|3gp|mpeg)$/i, '.jpg');
    }

    const duration = result.duration
      ? Math.round(result.duration)
      : null;

    console.log(`✅ Reel uploaded: ${result.public_id}`);
    console.log(`   Duration: ${duration}s`);

    return {
      videoUrl: result.secure_url,
      thumbnailUrl,
      publicId: result.public_id,
      duration,
      width: result.width,
      height: result.height,
    };
  } catch (error) {
    console.error('❌ Reel upload error:', error.message);

    if (error.message.includes('File size too large')) {
      throw new Error(
        'Reel video is too large. Maximum size is 100MB.'
      );
    }

    throw new Error('Failed to upload reel. Please try again.');
  }
};

// ─── Delete from Cloudinary ────────────────────────────
const deleteFromCloudinary = async (publicId, resourceType = 'image') => {
  try {
    if (!publicId) return;
    await cloudinary.uploader.destroy(publicId, {
      resource_type: resourceType,
    });
    // Attempt delete on secondary account in case it was uploaded there
    await cloudinary.uploader.destroy(publicId, {
      resource_type: resourceType,
      ...secondaryConfig,
    });
    console.log(`🗑️ Deleted from Cloudinary: ${publicId}`);
  } catch (error) {
    // Non-fatal: log but don't throw
    console.error('❌ Cloudinary delete error:', error.message);
  }
};

// ─── Detect media type from mimetype ──────────────────
const getMediaType = (mimetype) => {
  if (mimetype.startsWith('video/')) return 'video';
  if (mimetype.startsWith('audio/')) return 'audio';
  return 'image';
};

// ─── Constants ────────────────────────────────────────
const MAX_POST_VIDEO_DURATION = 60;   // 60 seconds for posts
const MAX_STORY_VIDEO_DURATION = 15;  // 15 seconds for stories
const MAX_REEL_VIDEO_DURATION = 60;   // 60 seconds for reels

// ─────────────────────────────────────────────────────
// EXPORTS
// ─────────────────────────────────────────────────────
module.exports = {
  // Multer middleware
  uploadProfilePicture,
  uploadPostMedia,
  uploadStoryMedia,

  // Cloudinary helpers
  uploadImageToCloudinary,
  uploadVideoToCloudinary,
  uploadAudioToCloudinary,
  uploadProfilePictureToCloudinary,
  uploadStoryToCloudinary,
  uploadReelToCloudinary,
  deleteFromCloudinary,

  // Utils
  getMediaType,
  MAX_POST_VIDEO_DURATION,
  MAX_STORY_VIDEO_DURATION,
  MAX_REEL_VIDEO_DURATION,
};
