import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../data/models/location_model.dart';

class LocationSearchPage extends StatefulWidget {
  const LocationSearchPage({super.key});

  @override
  State<LocationSearchPage> createState() => _LocationSearchPageState();
}

class _LocationSearchPageState extends State<LocationSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<LocationModel> _searchResults = [];
  bool _isSearching = false;

  final List<LocationModel> _nearbyPlaces = [
    LocationModel(id: '1', name: 'Milan, Italy', address: 'Lombardy, Italy'),
    LocationModel(id: '2', name: 'Duomo di Milano', address: 'Piazza del Duomo, 20122 Milano MI'),
    LocationModel(id: '3', name: 'Galleria Vittorio Emanuele II', address: 'Piazza del Duomo, 20121 Milano MI'),
    LocationModel(id: '4', name: 'Teatro alla Scala', address: 'Via Filodrammatici, 2, 20121 Milano MI'),
    LocationModel(id: '5', name: 'Parco Sempione', address: 'Piazza Sempione, 20154 Milano MI'),
    LocationModel(id: '6', name: 'San Siro Stadium', address: 'Piazzale Angelo Moratti, 20151 Milano MI'),
  ];

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      // Mock search logic
      _searchResults = _nearbyPlaces
          .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: bgColor,
        border: Border(bottom: BorderSide(color: isDark ? Colors.grey[900]! : Colors.grey[200]!, width: 0.5)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Text('Cancel', style: TextStyle(color: textColor, fontSize: 16)),
          onPressed: () => Navigator.pop(context),
        ),
        middle: Text(
          'Location',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CupertinoSearchTextField(
              controller: _searchController,
              placeholder: 'Search location',
              onChanged: _onSearchChanged,
              style: TextStyle(color: textColor),
              backgroundColor: isDark ? const Color(0xFF262626) : const Color(0xFFF2F2F2),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (!_isSearching) ...[
                  _buildSectionHeader('Nearby Places', isDark),
                  ..._nearbyPlaces.map((p) => _buildLocationTile(p, isDark)),
                ] else ...[
                  if (_searchResults.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text('No locations found', style: TextStyle(color: Colors.grey[600])),
                      ),
                    )
                  else
                    ..._searchResults.map((p) => _buildLocationTile(p, isDark)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildLocationTile(LocationModel location, bool isDark) {
    return ListTile(
      onTap: () => Navigator.pop(context, location),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF262626) : const Color(0xFFF2F2F2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.location_on_outlined,
          color: isDark ? Colors.white : Colors.black,
          size: 20,
        ),
      ),
      title: Text(
        location.name,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        location.address,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 13,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
