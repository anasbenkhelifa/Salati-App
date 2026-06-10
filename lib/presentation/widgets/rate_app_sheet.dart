import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_locale_provider.dart';
import '../../data/services/rating_service.dart';

class RateAppSheet extends StatefulWidget {
  const RateAppSheet({super.key});

  @override
  State<RateAppSheet> createState() => _RateAppSheetState();
}

class _RateAppSheetState extends State<RateAppSheet> with SingleTickerProviderStateMixin {
  int _selectedStars = 0;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusScope = FocusNode();
  
  bool _isSubmitting = false;
  bool _isSuccess = false;

  late AnimationController _starAnimController;
  late Animation<double> _starScaleAnim;

  @override
  void initState() {
    super.initState();
    _starAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _starScaleAnim = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40.0,
      ),
      TweenSequenceItem<double>(
        tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 60.0,
      ),
    ]).animate(_starAnimController);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusScope.dispose();
    _starAnimController.dispose();
    super.dispose();
  }

  void _onStarTapped(int index) {
    if (_isSubmitting || _isSuccess) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedStars = index;
    });
    // Replay animation slightly differently by resetting and forwarding
    _starAnimController.forward(from: 0.0);
  }

  Future<void> _onMaybeLater() async {
    final prefs = await SharedPreferences.getInstance();
    // Save current timestamp to prevent asking again for 7 days
    await prefs.setInt('last_dismissed_rate_app', DateTime.now().millisecondsSinceEpoch);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _onSubmit() async {
    if (_selectedStars == 0 || _isSubmitting || _isSuccess) return;

    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.mediumImpact();

    // Show success IMMEDIATELY — no waiting for network
    setState(() {
      _isSuccess = true;
    });
    
    // Save to SharedPreferences so we don't prompt them again
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_rated_app', true);

    // Fire-and-forget: save to Firestore in the background
    RatingService.instance.submitRating(
      stars: _selectedStars,
      comment: _commentController.text,
    ).catchError((e) {
      debugPrint('[RateAppSheet] Background save failed: $e');
    });

    // Wait 2 seconds before auto-closing
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocaleProvider.of(context).isArabic;
    // Glassmorphism constraints adapted from other components
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutQuint,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.currentSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag handle indicator
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.currentTextSecondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Title
                Text(
                  isArabic ? 'تقييم التطبيق' : 'Rate Salati',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  isArabic
                      ? 'أخبرنا برأيك في التطبيق لتساعدنا على تحسينه'
                      : 'Let us know how you feel about the app to help us improve.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.currentTextSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),

                // Stars Row
                AnimatedBuilder(
                  animation: _starAnimController,
                  builder: (context, child) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starValue = index + 1;
                        final isSelected = starValue <= _selectedStars;
                        final scale = isSelected && starValue == _selectedStars
                            ? _starScaleAnim.value
                            : (isSelected ? 1.05 : 1.0);

                        return GestureDetector(
                          onTap: () => _onStarTapped(starValue),
                          behavior: HitTestBehavior.opaque,
                          child: Transform.scale(
                            scale: _isSuccess ? 1.0 : scale, // Reset scale if success
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                                  size: 40,
                                  color: isSelected
                                      ? AppTheme.currentActiveGlow
                                      : AppTheme.currentTextSecondary.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Comment Field (Optional)
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _selectedStars > 0 && !_isSuccess
                      ? Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.currentActiveGlow.withValues(alpha: _commentFocusScope.hasFocus ? 0.05 : 0.02),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.currentActiveGlow.withValues(alpha: _commentFocusScope.hasFocus ? 0.3 : 0.1),
                                ),
                              ),
                              child: TextField(
                                controller: _commentController,
                                focusNode: _commentFocusScope,
                                maxLength: 300,
                                maxLines: 3,
                                minLines: 2,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  hintText: isArabic
                                      ? 'أضف تعليقاً (اختياري)'
                                      : 'Leave an optional comment (max 300 characters)',
                                  hintStyle: TextStyle(
                                    color: AppTheme.currentTextSecondary.withValues(alpha: 0.5),
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(16),
                                  counterText: "", // Hide default counter to make it cleaner
                                ),
                                style: const TextStyle(fontSize: 14),
                                onChanged: (_) {
                                  // Call setState to trigger maxLength rebuild if needed (optional if custom counter)
                                  setState((){});
                                },
                              ),
                            ),
                            // Custom Counter Text
                            Align(
                              alignment: isArabic ? Alignment.centerLeft : Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8.0, right: 4.0, left: 4.0),
                                child: Text(
                                  '${_commentController.text.length} / 300',
                                  style: TextStyle(
                                    color: _commentController.text.length >= 300
                                        ? Colors.redAccent
                                        : AppTheme.currentTextSecondary.withValues(alpha: 0.5),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),

                SizedBox(height: _selectedStars > 0 ? 24 : 8),

                // Action Buttons
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isSuccess
                      ? _buildSuccessState(isArabic)
                      : _buildSubmitState(isArabic),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitState(bool isArabic) {
    return Column(
      key: const ValueKey('submit_state'),
      children: [
        // Submit Button
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: _selectedStars > 0
                  ? [
                      AppTheme.currentActiveGlow,
                      AppTheme.currentActiveGlow.withValues(alpha: 0.8),
                    ]
                  : [
                      AppTheme.currentTextSecondary.withValues(alpha: 0.2),
                      AppTheme.currentTextSecondary.withValues(alpha: 0.1),
                    ],
            ),
            boxShadow: _selectedStars > 0 && !_isSubmitting
                ? [
                    BoxShadow(
                      color: AppTheme.currentActiveGlow.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _selectedStars > 0 && !_isSubmitting ? _onSubmit : null,
              borderRadius: BorderRadius.circular(16),
              child: Center(
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        isArabic ? 'إرسال التقييم' : 'Submit Rating',
                        style: TextStyle(
                          color: _selectedStars > 0 ? Colors.white : AppTheme.currentTextSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Maybe Later Button
        TextButton(
          onPressed: _isSubmitting ? null : _onMaybeLater,
          style: TextButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            isArabic ? 'ربما لاحقاً' : 'Maybe Later',
            style: TextStyle(
              color: AppTheme.currentTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState(bool isArabic) {
    return Container(
      key: const ValueKey('success_state'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Colors.green,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            isArabic ? 'شكراً لتقييمك!' : 'Thank you for your feedback!',
            style: const TextStyle(
              color: Colors.green,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
