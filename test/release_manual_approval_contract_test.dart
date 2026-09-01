import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production release cannot start automatically from a tag push', () {
    final workflow = File('.github/workflows/release.yml').readAsStringSync();

    expect(workflow, contains('workflow_dispatch:'));
    expect(workflow, isNot(contains("tags:\n      - 'v[0-9]*.[0-9]*.[0-9]*'")));
    expect(workflow, contains('confirm_tag:'));
    expect(workflow, contains('publish:'));
    expect(workflow, contains('type: boolean'));
    expect(workflow, contains('explicit publish approval is required'));
  });

  test('manual release requires an exact matching tag before build/publish', () {
    final workflow = File('.github/workflows/release.yml').readAsStringSync();

    final approvalIndex = workflow.indexOf('Verify explicit release approval');
    final checkoutIndex = workflow.indexOf('- name: Checkout');
    final publishIndex = workflow.indexOf('- name: Publish Otya APKs');

    expect(approvalIndex, greaterThanOrEqualTo(0));
    expect(approvalIndex, lessThan(checkoutIndex));
    expect(approvalIndex, lessThan(publishIndex));
    expect(workflow, contains('confirmation tag does not match release tag'));
    expect(workflow, contains('RELEASE_APPROVAL: PUBLISH'));
    expect(workflow, contains(r'RELEASE_CONFIRM_TAG: ${{ steps.release.outputs.tag }}'));
  });

  test('R2 publisher fails closed and passes approval to the backend', () {
    final publisher = File('scripts/publish_r2.sh').readAsStringSync();

    final approvalIndex = publisher.indexOf(r'[ "$RELEASE_APPROVAL" = "PUBLISH" ]');
    final firstUploadIndex = publisher.indexOf(r'upload_and_verify "$ARM64_APK"');

    expect(approvalIndex, greaterThanOrEqualTo(0));
    expect(firstUploadIndex, greaterThanOrEqualTo(0));
    expect(approvalIndex, lessThan(firstUploadIndex));
    expect(publisher, contains(r'[ "$RELEASE_CONFIRM_TAG" = "$RAW_TAG" ]'));
    expect(publisher, contains("'approval': os.environ['RELEASE_APPROVAL']"));
    expect(publisher, contains("'confirmTag': os.environ['RELEASE_CONFIRM_TAG']"));
  });
}
