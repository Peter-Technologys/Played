import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup dialogs use root navigator context and do not stack', () {
    final source = File('lib/app/app.dart').readAsStringSync();

    expect(source, contains('AppRouter.navigatorKey.currentContext'));
    expect(source, contains('await AnnouncementDialog.showIfPending(navigatorContext);'));
    expect(source, contains('await UpdateDialog.checkAndShow(navigatorContext);'));
    expect(
      source.indexOf('await UpdateDialog.checkAndShow(navigatorContext);'),
      greaterThan(source.indexOf('await AnnouncementDialog.showIfPending(navigatorContext);')),
    );
    expect(source, isNot(contains('UpdateDialog.checkAndShow(context);')));
    expect(source, isNot(contains('AnnouncementDialog.showIfPending(context);')));
  });
}
