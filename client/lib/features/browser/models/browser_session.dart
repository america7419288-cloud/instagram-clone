class BrowserSession {
  final String url;
  final String title;
  final String? favicon;
  final bool isAd;
  final String? adSource;      // 'instagram', 'sponsored'
  final String? adCampaignId;

  const BrowserSession({
    required this.url,
    required this.title,
    this.favicon,
    this.isAd = false,
    this.adSource,
    this.adCampaignId,
  });
}

class BrowserHistoryItem {
  final String url;
  final String title;
  final String? favicon;
  final DateTime visitedAt;

  const BrowserHistoryItem({
    required this.url,
    required this.title,
    this.favicon,
    required this.visitedAt,
  });
}

class DownloadItem {
  final String url;
  final String filename;
  final String? mimeType;
  final int? fileSize;
  DownloadStatus status;
  double progress;

  DownloadItem({
    required this.url,
    required this.filename,
    this.mimeType,
    this.fileSize,
    this.status = DownloadStatus.pending,
    this.progress = 0,
  });
}

enum DownloadStatus { pending, downloading, completed, failed }
