import 'package:flutter/material.dart';

import '../services/analytics_service.dart';

Future<AppReview?> showRateStudyMateDialog({
  required BuildContext context,
  required String studentName,
  AppReview? initialReview,
  bool barrierDismissible = true,
}) {
  return showDialog<AppReview>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) {
      return _RateStudyMateDialog(
        studentName: studentName,
        initialReview: initialReview,
      );
    },
  );
}

class _RateStudyMateDialog extends StatefulWidget {
  const _RateStudyMateDialog({required this.studentName, this.initialReview});

  final String studentName;
  final AppReview? initialReview;

  @override
  State<_RateStudyMateDialog> createState() => _RateStudyMateDialogState();
}

class _RateStudyMateDialogState extends State<_RateStudyMateDialog> {
  late final TextEditingController _commentController;
  late int _selectedRating;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedRating = widget.initialReview?.rating ?? 5;
    _commentController = TextEditingController(
      text: widget.initialReview?.comment ?? '',
    );
    _commentController.addListener(_onCommentChanged);
  }

  @override
  void dispose() {
    _commentController.removeListener(_onCommentChanged);
    _commentController.dispose();
    super.dispose();
  }

  void _onCommentChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submit() async {
    final String comment = _commentController.text.trim();
    if (comment.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a short comment before submitting.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await AnalyticsService.instance.submitReview(
        rating: _selectedRating,
        comment: comment,
        displayName: widget.studentName,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        AppReview(
          displayName: widget.studentName,
          rating: _selectedRating,
          comment: comment,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not submit your review. Please check your internet connection and try again.',
          ),
        ),
      );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final EdgeInsets viewInsets = MediaQuery.of(context).viewInsets;
    final bool keyboardVisible = viewInsets.bottom > 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double dialogWidth = constraints.maxWidth > 420
                ? 420
                : constraints.maxWidth;
            final double dialogMaxHeight = constraints.maxHeight * 0.9;

            return Align(
              alignment: keyboardVisible
                  ? Alignment.bottomCenter
                  : Alignment.center,
              child: SizedBox(
                width: dialogWidth,
                child: Material(
                  color: theme.colorScheme.surface,
                  elevation: 24,
                  borderRadius: BorderRadius.circular(28),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: dialogMaxHeight),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rate StudyMate',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Your feedback helps other students decide if StudyMate fits their workflow.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.65,
                              ),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: Wrap(
                              spacing: 6,
                              children: List.generate(5, (index) {
                                final int rating = index + 1;
                                final bool selected = _selectedRating >= rating;
                                return IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 40,
                                    height: 40,
                                  ),
                                  onPressed: _isSubmitting
                                      ? null
                                      : () {
                                          setState(() {
                                            _selectedRating = rating;
                                          });
                                        },
                                  icon: Icon(
                                    selected
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: selected
                                        ? const Color(0xFFF59E0B)
                                        : theme.colorScheme.outline,
                                    size: 32,
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _commentController,
                            minLines: 3,
                            maxLines: 4,
                            maxLength: 280,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Comment',
                              hintText: 'What helped you most?',
                              alignLabelWithHint: true,
                              counterText: '',
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${_commentController.text.length}/280',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 12),
                              FilledButton(
                                onPressed: _isSubmitting ? null : _submit,
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Submit'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
