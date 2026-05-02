// server/src/services/upload.service.js

const multer = require('multer');
const cloudinary = require('../config/cloudinary');

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

  const isImage = allowedImageTypes.includes(file.mimetype);
  const isVideo = allowedVideoTypes.includes(file.mimetype);

  if (isImage || isVideo) {
    cb(null, true);
  } else {
    cb(
      new Error(
        `File type ${file.mimetype} is not supported. ` +
        'Please upload an image (JPG, PNG, WebP, GIF) or video (MP4, MOV, AVI, WebM).'
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

// ─── Upload single image to Cloudinary ────────────────
const uploadImageToCloudinary = async (
  buffer,
  mimetype,
  folder = 'instagram-clone/posts'
) => {
  try {
    const dataURI = bufferToDataURI(buffer, mimetype);

    const result = await cloudinary.uploader.upload(dataURI, {
      folder,
      resource_type: 'image',
      // Auto-format to WebP if browser supports
      fetch_format: 'auto',
      // Auto-quality optimization
      quality: 'auto',
      // Transformation: normalize image
      transformation: [
        {
          width: 1080,
          height: 1080,
          crop: 'limit', // Don't enlarge small images
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
    const dataURI = bufferToDataURI(buffer, mimetype);

    console.log('☁️ Uploading video to Cloudinary...');

    const result = await cloudinary.uploader.upload(dataURI, {
      folder,
      resource_type: 'video',
      // Cloudinary auto-generates thumbnail
      eager: [
        {
          // Generate thumbnail at 1 second mark
          width: 1080,
          height: 1080,
          crop: 'fill',
          gravity: 'center',
          start_offset: '1',
          format: 'jpg',
          quality: 'auto',
        },
      ],
      eager_async: false, // Wait for thumbnail generation
      // Optimize video
      transformation: [
        {
          quality: 'auto',
          fetch_format: 'mp4',
        },
      ],
    });

    // ─── Extract thumbnail URL ─────────────────────────
    // Cloudinary returns eager transformations as array
    let thumbnailUrl = null;

    if (result.eager && result.eager.length > 0) {
      thumbnailUrl = result.eager[0].secure_url;
    } else {
      // Fallback: construct thumbnail URL manually
      // Replace video extension with jpg and add transformations
      thumbnailUrl = result.secure_url
        .replace('/video/upload/', '/video/upload/w_1080,h_1080,c_fill,so_1,f_jpg/')
        .replace(/\.(mp4|mov|avi|webm|3gp|mpeg)$/i, '.jpg');
    }

    // ─── Get video duration ────────────────────────────
    const duration = result.duration
      ? Math.round(result.duration)
      : null;

    console.log(`✅ Video uploaded: ${result.public_id}`);
    console.log(`   Duration: ${duration}s`);
    console.log(`   Thumbnail: ${thumbnailUrl}`);

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

    // Better error messages
    if (error.message.includes('File size too large')) {
      throw new Error('Video file is too large. Maximum size is 100MB.');
    }
    if (error.message.includes('Invalid video')) {
      throw new Error('Invalid video format. Please use MP4, MOV, or WebM.');
    }

    throw new Error('Failed to upload video. Please try again.');
  }
};

// ─── Upload profile picture ────────────────────────────
const uploadProfilePictureToCloudinary = async (buffer, mimetype) => {
  try {
    const dataURI = bufferToDataURI(buffer, mimetype);

    const result = await cloudinary.uploader.upload(dataURI, {
      folder: 'instagram-clone/profiles',
      resource_type: 'image',
      transformation: [
        {
          width: 300,
          height: 300,
          crop: 'fill',
          gravity: 'face', // Smart face detection for profile pics
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

  try {
    const dataURI = bufferToDataURI(buffer, mimetype);

    if (isVideo) {
      const result = await cloudinary.uploader.upload(dataURI, {
        folder: 'instagram-clone/stories/videos',
        resource_type: 'video',
        eager: [
          {
            width: 1080,
            height: 1920,
            crop: 'fill',
            start_offset: '0',
            format: 'jpg',
          },
        ],
        eager_async: false,
      });

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
      const result = await cloudinary.uploader.upload(dataURI, {
        folder: 'instagram-clone/stories',
        resource_type: 'image',
        transformation: [
          {
            width: 1080,
            height: 1920,
            crop: 'limit',
            quality: 'auto',
            fetch_format: 'auto',
          },
        ],
      });

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

// ─── Delete from Cloudinary ────────────────────────────
const deleteFromCloudinary = async (publicId, resourceType = 'image') => {
  try {
    if (!publicId) return;
    await cloudinary.uploader.destroy(publicId, {
      resource_type: resourceType,
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
  return 'image';
};

// ─── Validate video duration ──────────────────────────
// We can't easily check duration from buffer alone.
// Cloudinary returns it after upload, so we validate
// AFTER upload and delete if too long.
const MAX_POST_VIDEO_DURATION = 60;   // 60 seconds for posts
const MAX_STORY_VIDEO_DURATION = 15;  // 15 seconds for stories

module.exports = {
  // Multer middleware
  uploadProfilePicture,
  uploadPostMedia,
  uploadStoryMedia,

  // Cloudinary helpers
  uploadImageToCloudinary,
  uploadVideoToCloudinary,
  uploadProfilePictureToCloudinary,
  uploadStoryToCloudinary,
  deleteFromCloudinary,

  // Utils
  getMediaType,
  MAX_POST_VIDEO_DURATION,
  MAX_STORY_VIDEO_DURATION,
};
