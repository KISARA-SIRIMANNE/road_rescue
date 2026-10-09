import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:road_rescue/theme/road_rescue_theme.dart';

import 'vehicle_owner_home_page.dart';

class ReviewRatingPage extends StatefulWidget {
  final String requestId;
  final String providerName;
  final String? providerPhotoUrl;

  const ReviewRatingPage({
    super.key,
    required this.requestId,
    required this.providerName,
    this.providerPhotoUrl,
  });

  @override
  State<ReviewRatingPage> createState() => _ReviewRatingPageState();
}

class _ReviewRatingPageState extends State<ReviewRatingPage> {
  final Color _backgroundColor = RoadRescueColors.background;

  final Color _cardColor = RoadRescueColors.surface;

  final Color _yellowColor = RoadRescueColors.accent;

  final TextEditingController _reviewController = TextEditingController();

  int _selectedRating = 0;

  final List<String> _availableTags = [
    'Professional',
    'Fast Service',
    'Friendly',
    'Good Communication',
    'Reliable',
  ];

  final Set<String> _selectedTags = {};

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  void _selectRating(int rating) {
    setState(() {
      _selectedRating = rating;
    });
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  Future<void> _submitReview() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a rating.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User session not found. Please log in again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!mounted) {
        return;
      }

      if (!userSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User profile could not be found.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final Map<String, dynamic> userData =
          userSnapshot.data() as Map<String, dynamic>;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => VehicleOwnerHomePage(userData: userData),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to return to dashboard: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  } // <-- this closing brace was missing

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Review Provider',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              _buildProviderCard(),
              const SizedBox(height: 28),
              const Text(
                'How was your service?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your feedback helps us improve RoadRescue.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),
              const SizedBox(height: 24),
              _buildRatingSection(),
              const SizedBox(height: 30),
              _buildTagsSection(),
              const SizedBox(height: 28),
              _buildReviewField(),
              const SizedBox(height: 28),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProviderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _yellowColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _yellowColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child:
                widget.providerPhotoUrl != null &&
                    widget.providerPhotoUrl!.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      widget.providerPhotoUrl!,
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.person_rounded,
                          color: _yellowColor,
                          size: 30,
                        );
                      },
                    ),
                  )
                : Icon(Icons.person_rounded, color: _yellowColor, size: 30),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Roadside Assistance Provider',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.providerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final int rating = index + 1;

            return GestureDetector(
              onTap: () {
                _selectRating(rating);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: AnimatedScale(
                  scale: _selectedRating == rating ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    rating <= _selectedRating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: _yellowColor,
                    size: 48,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Text(
          _ratingText(),
          style: TextStyle(
            color: _selectedRating == 0 ? Colors.grey.shade500 : _yellowColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _ratingText() {
    switch (_selectedRating) {
      case 1:
        return 'Very Poor';
      case 2:
        return 'Poor';
      case 3:
        return 'Average';
      case 4:
        return 'Good';
      case 5:
        return 'Excellent';
      default:
        return 'Tap a star to rate';
    }
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What did you like?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: _availableTags.map((tag) {
            final bool selected = _selectedTags.contains(tag);

            return GestureDetector(
              onTap: () {
                _toggleTag(tag);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected ? _yellowColor : _cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? _yellowColor : Colors.white12,
                  ),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    color: selected ? Colors.black : Colors.grey.shade300,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildReviewField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Write a review',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _reviewController,
          maxLines: 5,
          maxLength: 500,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Tell us about your experience...',
            hintStyle: TextStyle(color: Colors.grey.shade600),
            filled: true,
            fillColor: _cardColor,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _yellowColor, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _submitReview,
        style: ElevatedButton.styleFrom(
          backgroundColor: _yellowColor,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Submit Review',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
