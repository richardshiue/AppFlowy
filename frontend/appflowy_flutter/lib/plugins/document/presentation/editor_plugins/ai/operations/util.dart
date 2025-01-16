import 'package:appflowy/core/helpers/url_launcher.dart';

Future<void> openLearnMorePage() async {
  await afLaunchUrlString(
    "https://docs.appflowy.io/docs/appflowy/product/appflowy-x-openai",
  );
}
