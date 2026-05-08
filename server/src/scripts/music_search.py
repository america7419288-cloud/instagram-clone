import sys
import json
from ytmusicapi import YTMusic

def search_music(query):
    try:
        yt = YTMusic()
        # Search for songs
        search_results = yt.search(query, filter="songs", limit=20)
        
        songs = []
        for result in search_results:
            # Basic validation
            if not result.get("videoId"):
                continue
                
            # Extract relevant fields
            song = {
                "id": result.get("videoId"),
                "title": result.get("title"),
                "artist": ", ".join([a.get("name") for a in result.get("artists", [])]),
                "album": result.get("album", {}).get("name") if result.get("album") else "Unknown Album",
                "duration": result.get("duration"),
                "thumbnail": result.get("thumbnails", [{}])[-1].get("url") if result.get("thumbnails") else None,
            }
            songs.append(song)
        
        return songs
    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    # Get query from command line argument or use default
    query = sys.argv[1] if len(sys.argv) > 1 else "trending"
    
    results = search_music(query)
    # Output only the JSON result to stdout
    print(json.dumps(results))
