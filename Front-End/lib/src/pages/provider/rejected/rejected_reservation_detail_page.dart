import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seyoni/src/config/url.dart';
import 'package:seyoni/src/constants/constants_color.dart';
import 'package:seyoni/src/constants/constants_font.dart';
import 'package:seyoni/src/widgets/background_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'dart:convert';

class RejectedReservationDetailPage extends StatefulWidget {
  final String reservationId;

  const RejectedReservationDetailPage({required this.reservationId, super.key});

  @override
  RejectedReservationDetailPageState createState() =>
      RejectedReservationDetailPageState();
}

class RejectedReservationDetailPageState
    extends State<RejectedReservationDetailPage> {
  Map<String, dynamic>? reservation;
  String readableAddress = '';
  bool isLoading = true;
  bool isAccepted = false;

  @override
  void initState() {
    super.initState();
    _fetchReservationDetails();
  }

  Future<void> _fetchReservationDetails() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? providerId = prefs.getString('providerId');
      if (providerId == null || providerId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not logged in'),
            backgroundColor: kErrorColor,
          ),
        );
        return;
      }

      final response = await http.get(
        Uri.parse('$getReservationsUrl/${widget.reservationId}'),
        headers: {
          'Content-Type': 'application/json',
          'provider-id': providerId,
        },
      );

      if (response.statusCode == 200) {
        final reservationData = json.decode(response.body);
        setState(() {
          reservation = reservationData;
          isAccepted = reservationData['status'] == 'accepted';
          isLoading = false;
        });
        _getReadableAddress();
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load reservation: ${response.body}'),
            backgroundColor: kErrorColor,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load reservation: $e'),
          backgroundColor: kErrorColor,
        ),
      );
    }
  }

  Future<void> _getReadableAddress() async {
    try {
      final locationString = reservation?['location'] ?? '';
      final latLng = locationString
          .substring(
            locationString.indexOf('(') + 1,
            locationString.indexOf(')'),
          )
          .split(', ');
      final latitude = double.parse(latLng[0]);
      final longitude = double.parse(latLng[1]);

      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);
      Placemark place = placemarks[0];
      setState(() {
        readableAddress =
            '${place.street}, ${place.locality}, ${place.country}';
      });
    } catch (e) {
      setState(() {
        readableAddress = 'Unknown location';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(
        color: kPrimaryColor,
      ));
    }

    if (reservation == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Reservation Details',
              style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: Text('Failed to load reservation details')),
      );
    }

    final seeker = reservation?['seeker'] ?? {};
    final profileImage = seeker['profileImage'] ?? '';
    final name = '${seeker['firstName']} ${seeker['lastName']}';
    final date = reservation?['date'] ?? 'Unknown';
    final formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.parse(date));
    final time = reservation?['time'] ?? 'Unknown';
    final description = reservation?['description'] ?? 'No description';
    final images = reservation?['images'] ?? [];

    return BackgroundWidget(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Reservation Details',
              style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Display seeker's profile picture
                CircleAvatar(
                  radius: 40,
                  backgroundImage: profileImage.isNotEmpty
                      ? NetworkImage(profileImage)
                      : null,
                  child: profileImage.isEmpty
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
                const SizedBox(height: 16),
                // Display reservation details with icons
                Row(
                  children: [
                    const Icon(Icons.person, color: kPrimaryColor),
                    const SizedBox(width: 8),
                    Text(name, style: kSubtitleTextStyle2),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: kPrimaryColor),
                    const SizedBox(width: 8),
                    Text(readableAddress, style: kSubtitleTextStyle2),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: kPrimaryColor),
                    const SizedBox(width: 8),
                    Text(formattedDate, style: kSubtitleTextStyle2),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: kPrimaryColor),
                    const SizedBox(width: 8),
                    Text(time, style: kSubtitleTextStyle2),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Description', style: kSubtitleTextStyle2),
                const SizedBox(height: 8),
                Text(description, style: kBodyTextStyle),
                const SizedBox(height: 16),
                // Display images with curves if they exist
                if (images.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        final imageUrl = images[index] ?? '';
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FullScreenImage(
                                  imageUrl: imageUrl,
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16.0),
                            child: Image.network(imageUrl),
                          ),
                        );
                      },
                    ),
                  ),
                if (images.isNotEmpty) const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImage({required this.imageUrl, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Image.network(imageUrl),
      ),
    );
  }
}