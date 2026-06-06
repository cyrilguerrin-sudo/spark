import 'package:flutter_test/flutter_test.dart';
import 'package:spark/app.dart';

void main() {
  testWidgets('Spark app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SparkApp());
  });
}
