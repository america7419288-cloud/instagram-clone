const { exec, spawn } = require('child_process');
const path = require('path');
const https = require('https');
const fs = require('fs');
const agent = new https.Agent({ keepAlive: true });
const {
    successResponse,
    errorResponse,
} = require('../utils/response.utils');

/**
 * Simple in-memory cache for stream URLs to speed up subsequent loads
 * Key: videoId, Value: { url, expiry }
 */
const urlCache = new Map();
const CACHE_EXPIRY = 5 * 60 * 60 * 1000; // 5 hours (YouTube URLs usually last 6h)

/**
 * Search for music using ytmusicapi Python script
 */
const searchMusic = async (req, res) => {
    try {
        const { query } = req.query;
        if (!query || query.trim() === '') {
            return errorResponse(res, 400, 'Search query is required');
        }

        const scriptPath = path.join(__dirname, '..', 'scripts', 'music_search.py');
        // Use double quotes for the query to handle spaces and special characters
        const command = `python "${scriptPath}" "${query.replace(/"/g, '\\"')}"`;

        console.log(`🎵 Searching music for: ${query}`);

        exec(command, (error, stdout, stderr) => {
            if (error) {
                console.error(`❌ Python exec error: ${error}`);
                return errorResponse(res, 500, 'Failed to execute music search script');
            }
            if (stderr) {
                console.warn(`⚠️ Python stderr: ${stderr}`);
            }

            try {
                const results = JSON.parse(stdout);
                
                if (results.error) {
                    console.error(`❌ YTMusic API error: ${results.error}`);
                    return errorResponse(res, 500, results.error);
                }

                return successResponse(res, 200, 'Music search results loaded', results);
            } catch (parseError) {
                console.error(`❌ JSON Parse error: ${parseError}`);
                console.log('Raw output:', stdout);
                return errorResponse(res, 500, 'Failed to parse music search results');
            }
        });
    } catch (error) {
        console.error('❌ searchMusic error:', error);
        return errorResponse(res, 500, error.message || 'Internal server error');
    }
};

/**
 * Common yt-dlp flags to bypass bot detection
 */
const YT_DLP_FLAGS = [
    '--no-playlist',
    '--quiet',
    '--no-warnings',
    '--no-check-certificate',
    '--prefer-free-formats',
    '--user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"',
].join(' ');

/**
 * Proxy YouTube audio stream to bypass client-side DNS/403 issues
 * GET /api/music/stream/:videoId
 */
const streamMusic = async (req, res) => {
    try {
        const { videoId } = req.params;
        if (!videoId) {
            return errorResponse(res, 400, 'Video ID is required');
        }

        const cacheDir = path.join(__dirname, '..', '..', 'cache', 'audio');
        // Ensure cache dir exists
        if (!fs.existsSync(cacheDir)) {
            fs.mkdirSync(cacheDir, { recursive: true });
        }

        const filePath = path.join(cacheDir, `${videoId}.mp3`);
        const range = req.headers.range;

        // 1. Check if file exists on disk
        if (fs.existsSync(filePath)) {
            console.log(`🚀 Serving from Disk Cache: ${videoId}`);
            return res.sendFile(filePath);
        }

        // 2. Check Memory Cache for URL
        const cached = urlCache.get(videoId);
        if (cached && cached.expiry > Date.now()) {
            console.log(`⚡ Using cached stream URL for: ${videoId}`);
            
            // Trigger background download to disk for future use
            _downloadToDisk(videoId, filePath);
            
            return _pipeStream(cached.url, range, res, req.headers);
        }

        console.log(`🎵 Extracting fresh stream for video: ${videoId}`);

        // 3. Extract using yt-dlp
        const command = `python -m yt_dlp -g -f "ba/best" ${YT_DLP_FLAGS} "${videoId}"`;
        
        exec(command, (error, stdout, stderr) => {
            if (error) {
                console.error(`❌ yt-dlp error: ${error}`);
                if (stderr) console.error(`⚠️ stderr: ${stderr}`);
                
                // Fallback attempt with different client if first fails
                const fallbackCommand = `python -m yt_dlp -g -f "ba/best" --quiet "${videoId}"`;
                
                exec(fallbackCommand, (fError, fStdout) => {
                    if (fError) {
                        return errorResponse(res, 500, 'Failed to get stream URL after multiple attempts');
                    }
                    const streamUrl = fStdout.trim();
                    _handleExtractedUrl(videoId, streamUrl, filePath, range, res, req.headers);
                });
                return;
            }

            const streamUrl = stdout.trim();
            _handleExtractedUrl(videoId, streamUrl, filePath, range, res, req.headers);
        });
    } catch (error) {
        console.error('❌ streamMusic error:', error);
        return errorResponse(res, 500, error.message || 'Internal server error');
    }
};

/**
 * Helper to handle extracted URL
 */
const _handleExtractedUrl = (videoId, streamUrl, filePath, range, res, reqHeaders) => {
    if (!streamUrl) {
        return errorResponse(res, 404, 'Stream URL not found');
    }

    // Save URL to memory cache
    urlCache.set(videoId, {
        url: streamUrl,
        expiry: Date.now() + CACHE_EXPIRY
    });

    // Trigger background download to disk
    _downloadToDisk(videoId, filePath);

    // Pipe stream
    _pipeStream(streamUrl, range, res, reqHeaders);
};

/**
 * Download audio to disk in the background
 */
const _downloadToDisk = (videoId, filePath) => {
    // Only download if not already exists/downloading
    if (fs.existsSync(filePath) || urlCache.get(`downloading_${videoId}`)) return;

    console.log(`📥 Starting background download: ${videoId}`);
    urlCache.set(`downloading_${videoId}`, true);

    const command = `python -m yt_dlp -f "ba/best" ${YT_DLP_FLAGS} -o "${filePath}" "${videoId}"`;
    
    exec(command, (error) => {
        urlCache.delete(`downloading_${videoId}`);
        if (error) {
            console.error(`❌ Background download failed: ${videoId}`, error);
        } else {
            console.log(`✅ Cached to disk: ${videoId}`);
        }
    });
};

/**
 * Helper to pipe the https stream to the response
 */
const _pipeStream = (url, range, res, reqHeaders) => {
    const options = {
        agent,
        headers: {
            'User-Agent': reqHeaders['user-agent'] || 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
        }
    };
    
    if (range) {
        options.headers['range'] = range;
    }

    https.get(url, options, (proxyRes) => {
        // Forward status code
        res.status(proxyRes.statusCode);

        // Forward headers
        Object.keys(proxyRes.headers).forEach(key => {
            res.setHeader(key, proxyRes.headers[key]);
        });

        proxyRes.pipe(res);
    }).on('error', (e) => {
        console.error(`❌ Proxy pipe error: ${e}`);
        if (!res.headersSent) {
            errorResponse(res, 500, 'Failed to proxy audio stream');
        }
    });
};

module.exports = {
    searchMusic,
    streamMusic,
};
