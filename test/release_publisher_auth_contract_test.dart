import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release CI uses the Cloudflare Workflows API', () {
    final workflow = File('.github/workflows/release.yml').readAsStringSync();
    final publisher = File('scripts/publish_r2.sh').readAsStringSync();

    expect(workflow, contains('CF_ACCOUNT_ID: \${{ vars.CF_ACCOUNT_ID }}'));
    expect(workflow, contains('CF_API_TOKEN: \${{ secrets.CF_API_TOKEN }}'));
    expect(publisher, contains('/workflows/otya-release/instances'));
    expect(publisher, contains("'params': json.dumps(payload"));
    expect(publisher, contains('?simple=false&order=asc'));
    expect(publisher, contains("WORKFLOW_TIMEOUT_SECONDS', '900'"));
    expect(publisher, contains("failed_step.get('attempts')"));
    expect(
      publisher,
      contains("'Authorization': 'Bearer ' + os.environ['CF_API_TOKEN']"),
    );

    expect(workflow, isNot(contains('OTYA_STORE_ADMIN_TOKEN')));
    expect(publisher, isNot(contains('OTYA_STORE_ADMIN_TOKEN')));
    expect(publisher, isNot(contains('/api/admin/release-workflow')));
  });
}
