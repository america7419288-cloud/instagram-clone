// server/src/services/upload.service.js
// Handles all image/video uploads to Cloudinary

const { cloudinary } = require('../config/cloudinary');
const multer = require('multer');
const path = require('path');

// ─── MULTER SETUP ──────────────────────────────────────────
// Multer handles the file from the request
// We use memory storage (don't save to disk)
// Send directly to Cloudinary

const storage = multer.memoryStorage();

// Filter: only allow images
const imageFilter = (req, file, cb) => {
  const allowedMimeTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'image/gif',
  ];

  if (allowedMimeTypes.includes(file.mimetype)) {
    cb(null, true); // Accept file
  } else {
    cb(
      new Error('Invalid file type. Only JPEG, PNG, WebP and GIF allowed.'),
      false // Reject file
    );
  }
};

// Filter: allow images AND videos
const mediaFilter = (req, file, cb) => {
  const allowedMimeTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'video/mp4',
    'video/quicktime',
    'video/x-msvideo',
  ];

  if (allowedMimeTypes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(
      new Error('Invalid file type. Only images and videos allowed.'),
      false
    );
  }
};

// Single image upload (for profile picture)
const uploadSingleImage = multer({
  storage,
  fileFilter: imageFilter,
  limits: {
    fileSize: 40 * 1024 * 1024, // 40MB max for high-resolution stories
  },
}).single('image'); // 'image' = field name in form

// Multiple images upload (for posts - up to 10)
const uploadMultipleMedia = multer({
  storage,
  fileFilter: mediaFilter,
  limits: {
    fileSize: 100 * 1024 * 1024, // 100MB per file for 4K uploads
    files: 10,                   // Max 10 files
  },
}).array('media', 10); // 'media' = field name, 10 = max count

// ─── CLOUDINARY UPLOAD FUNCTIONS ───────────────────────────

// Upload image buffer to Cloudinary
const uploadImageToCloudinary = (
  fileBuffer,
  folder,
  options = {}
) => {
  return new Promise((resolve, reject) => {
    const uploadOptions = {
      folder: `instagram-clone/${folder}`,
      resource_type: 'image',
      // Preserve detail for high-resolution uploads.
      quality: '100',
      // Auto-choose best format (WebP when possible)
      fetch_format: 'auto',
      ...options,
    };

    // Upload using stream (works with buffer)
    const uploadStream = cloudinary.uploader.upload_stream(
      uploadOptions,
      (error, result) => {
        if (error) {
          reject(error);
        } else {
          resolve(result);
        }
      }
    );

    uploadStream.end(fileBuffer);
  });
};

// Upload and create multiple sizes for profile picture
const uploadProfilePicture = async (fileBuffer, userId) => {
  try {
    const result = await uploadImageToCloudinary(
      fileBuffer,
      'profile-pictures',
      {
        public_id: `profile_${userId}`, // Consistent name (overwrite old)
        overwrite: true,
        // Create multiple sizes automatically
        eager: [
          // Small: for stories circle, comments
          { width: 150, height: 150, crop: 'fill', gravity: 'face' },
          // Medium: for profile page
          { width: 320, height: 320, crop: 'fill', gravity: 'face' },
        ],
        eager_async: false,
      }
    );

    return {
      url: result.secure_url,           // Original URL
      small_url: result.eager[0]?.secure_url,  // 150x150
      medium_url: result.eager[1]?.secure_url, // 320x320
      public_id: result.public_id,
    };
  } catch (error) {
    throw new Error(`Profile picture upload failed: ${error.message}`);
  }
};

// Delete image from Cloudinary
const deleteFromCloudinary = async (publicId) => {
  try {
    const result = await cloudinary.uploader.destroy(publicId);
    return result.result === 'ok';
  } catch (error) {
    console.error('Cloudinary delete error:', error);
    return false;
  }
};

// Upload post media (image or video)
const uploadPostMedia = async (fileBuffer, mimeType, userId, index) => {
  const isVideo = mimeType.startsWith('video/');
  const folder = isVideo ? 'post-videos' : 'post-images';

  try {
    const result = await uploadImageToCloudinary(
      fileBuffer,
      folder,
      {
        resource_type: isVideo ? 'video' : 'image',
        public_id: `post_${userId}_${Date.now()}_${index}`,
        // For images: create thumbnail and medium sizes
        ...(!isVideo && {
          eager: [
            // Thumbnail: for grid view
            { width: 600, height: 600, crop: 'fill', quality: 'auto:best' },
            // 4K: for feed/detail display
            { width: 4096, height: 4096, crop: 'limit', quality: '100' },
          ],
          eager_async: false,
        }),
        ...(isVideo && {
          eager: [
            { format: 'jpg', transformation: [{ start_offset: '0' }] },
          ],
          eager_async: false,
        }),
      }
    );

    return {
      url: result.secure_url,
      thumbnail_url: isVideo
        ? result.eager?.[0]?.secure_url
        : result.eager?.[0]?.secure_url,
      medium_url: !isVideo ? result.eager?.[1]?.secure_url : null,
      public_id: result.public_id,
      media_type: isVideo ? 'video' : 'image',
      width: result.width,
      height: result.height,
      duration: result.duration || null,
    };
  } catch (error) {
    throw new Error(`Media upload failed: ${error.message}`);
  }
};

module.exports = {
  uploadSingleImage,
  uploadMultipleMedia,
  uploadImageToCloudinary,
  uploadProfilePicture,
  deleteFromCloudinary,
  uploadPostMedia,
};
