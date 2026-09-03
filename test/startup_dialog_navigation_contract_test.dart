import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup dialogs use fresh root navigator contexts and do not stack', () {
    final source = File('lib/app/app.dart').readAsStringSync();

    expect(source, contains('AppRouter.navigatorKey.currentContext'));
    expect(
      source,
      contains('await AnnouncementDialog.showIfPending(announcementContext);'),
    );
    expect(
      source,
      contains('await UpdateDialog.checkAndShow(updateContext);'),
    );
    expect(source, contains('!announcementContext.mounted'));
    expect(source, contains('!updateContext.mounted'));
    expect(
      source.indexOf('await UpdateDialog.checkAndShow(updateContext);'),
      greaterThan(
        source.indexOf(
          'await AnnouncementDialog.showIfPending(announcementContext);',
        ),
      ),
    );
    expect(source, isNot(contains('UpdateDialog.checkAndShow(context);')));
    expect(source, isNot(contains('AnnouncementDialog.showIfPending(context);')));
  });
}
