import 'package:flutter/widgets.dart';

class LoadingErrorText extends StatelessWidget {
  const LoadingErrorText({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('حدث خطأ ما. يرجى المحاولة لاحقاََ'));
  }
}
