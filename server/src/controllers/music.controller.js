const { exec, spawn } = require('child_process');
const path = require('path');
const https = require('https');
const fs = require('fs');
const agent = new https.Agent({ keepAlive: true });
const PYTHON_CMD = process.platform === 'win32' ? 'py' : 'python';
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
 * Fixed: Use spawn with array arguments to prevent command injection
 */
const searchMusic = async (req, res) => {
    try {
        const { query } = req.query;
        if (!query || query.trim() === '') {
            return errorResponse(res, 400, 'Search query is required');
        }

        // Validate query - only allow safe characters
        const sanitizedQuery = query.trim().replace(/[^\w\s\-'(),]/gi, '');
        if (!sanitizedQuery || sanitizedQuery.length === 0) {
            return errorResponse(res, 400, 'Invalid search query');
        }

        const scriptPath = path.join(__dirname, '..', 'scripts', 'music_search.py');

        console.log(`🎵 Searching music for: ${sanitizedQuery}`);

        // Use spawn with array arguments instead of shell exec to prevent command injection
        const pythonProcess = spawn(PYTHON_CMD, [scriptPath, sanitizedQuery], {
            shell: false,
            env: { ...process.env, PYTHONIOENCODING: 'utf-8' }
        });

        let stdout = '';
        let stderr = '';

        pythonProcess.stdout.on('data', (data) => {
            stdout += data.toString();
        });

        pythonProcess.stderr.on('data', (data) => {
            stderr += data.toString();
        });

        pythonProcess.on('close', (code) => {
            if (code !== 0) {
                console.error(`❌ Python script error (code ${code}): ${stderr}`);
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

        pythonProcess.on('error', (error) => {
            console.error(`❌ Failed to start Python process: ${error}`);
            return errorResponse(res, 500, 'Failed to execute music search script');
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
 * Public Invidious instances to resolve YouTube audio streams without bot blocks
 */
const INVIDIOUS_INSTANCES = [
    'https://yewtu.be',
    'https://invidious.nerdvpn.de',
    'https://invidious.flokinet.to',
    'https://vid.puffyan.us',
    'https://invidious.projectsegfau.lt'
];

const fetchInvidiousStreamUrl = async (videoId) => {
    for (const instance of INVIDIOUS_INSTANCES) {
        try {
            console.log(`🌐 Trying Invidious instance: ${instance} for video: ${videoId}`);
            const url = `${instance}/api/v1/videos/${videoId}`;
            
            const data = await new Promise((resolve, reject) => {
                const req = https.get(url, { timeout: 3500 }, (res) => {
                    let body = '';
                    res.on('data', chunk => body += chunk);
                    res.on('end', () => {
                        try {
                            resolve(JSON.parse(body));
                        } catch (e) {
                            reject(e);
                        }
                    });
                });
                req.on('error', reject);
                req.on('timeout', () => {
                    req.destroy();
                    reject(new Error('Timeout'));
                });
            });

            if (data && data.adaptiveFormats) {
                // Find an audio stream (mimeType starts with audio/)
                const audioFormat = data.adaptiveFormats.find(f => 
                    f.mimeType && f.mimeType.startsWith('audio/')
                );
                
                if (audioFormat && audioFormat.url) {
                    console.log(`✅ Successfully extracted stream via Invidious (${instance})`);
                    return audioFormat.url;
                }
            }
        } catch (e) {
            console.warn(`⚠️ Failed to fetch stream from Invidious instance ${instance}: ${e.message}`);
        }
    }
    return null;
};

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

        // Validate videoId - YouTube IDs are 11 characters alphanumeric
        if (!/^[a-zA-Z0-9_-]{11}$/.test(videoId)) {
            return errorResponse(res, 400, 'Invalid video ID format');
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

        // Try Invidious API first (super fast & bot-bypass)
        const invidiousUrl = await fetchInvidiousStreamUrl(videoId);
        if (invidiousUrl) {
            _handleExtractedUrl(videoId, invidiousUrl, filePath, range, res, req.headers);
            return;
        }

        console.log(`⚠️ Invidious API bypassed. Falling back to local yt-dlp...`);

        // 3. Extract using yt-dlp
        const command = `${PYTHON_CMD} -m yt_dlp -g -f "ba/best" ${YT_DLP_FLAGS} "${videoId}"`;
        
        exec(command, (error, stdout, stderr) => {
            if (error) {
                console.error(`❌ yt-dlp error: ${error}`);
                if (stderr) console.error(`⚠️ stderr: ${stderr}`);
                
                // Fallback attempt with different client if first fails
                const fallbackCommand = `${PYTHON_CMD} -m yt_dlp -g -f "ba/best" --quiet "${videoId}"`;
                
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

    const command = `${PYTHON_CMD} -m yt_dlp -f "ba/best" ${YT_DLP_FLAGS} -o "${filePath}" "${videoId}"`;
    
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
