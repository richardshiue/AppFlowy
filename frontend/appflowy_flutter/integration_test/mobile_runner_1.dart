import 'package:appflowy_backend/log.dart';
import 'package:integration_test/integration_test.dart';

import 'mobile/document/page_style_test.dart' as page_style_test;
import 'mobile/home_page/create_new_page_test.dart' as create_new_page_test;
import 'mobile/sign_in/anonymous_sign_in_test.dart' as anonymous_sign_in_test;

Future<void> main() async {
  Log.shared.disableLog = true;

  await runIntegration1OnMobile();
}

Future<void> runIntegration1OnMobile() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  anonymous_sign_in_test.main();
  create_new_page_test.main();
  page_style_test.main();
}