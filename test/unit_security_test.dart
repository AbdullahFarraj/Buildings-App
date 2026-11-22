import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:building_app/models/user_model.dart';
import 'package:building_app/services/storage_service.dart';
import 'package:building_app/utils/phone_helper.dart';

void main() {
  group('PhoneHelper', () {
    test('normalizes UAE mobile formats', () {
      expect(PhoneHelper.normalizeUaeMobile('0501234567'), '971501234567');
      expect(PhoneHelper.normalizeUaeMobile('+971 50-123-4567'), '971501234567');
      expect(PhoneHelper.normalizeUaeMobile('00971501234567'), '971501234567');
      expect(PhoneHelper.normalizeUaeMobile('9710501234567'), '971501234567');
      expect(PhoneHelper.normalizeUaeMobile('501234567'), '971501234567');
      expect(PhoneHelper.normalizeUaeMobile('12345'), isNull);
    });

    test('converts to local UAE format safely', () {
      expect(PhoneHelper.toLocalUaeFormat('971501234567'), '0501234567');
      expect(PhoneHelper.toLocalUaeFormat('invalid'), isNull);
    });
  });

  group('StorageService.sanitizeFileName', () {
    test('strips path traversal and unsafe characters', () {
      expect(
        StorageService.sanitizeFileName('../../etc/passwd'),
        'passwd',
      );
      expect(
        StorageService.sanitizeFileName(r'C:\Users\test\my file (1).pdf'),
        'my_file__1_.pdf',
      );
      expect(StorageService.sanitizeFileName('..'), 'attachment');
    });
  });

  group('UserModel.fromMap', () {
    test('parses Timestamp, DateTime, ISO String, and null safely', () {
      final ts = Timestamp.fromDate(DateTime.utc(2026, 1, 15));
      final user = UserModel.fromMap({
        'name': 'Test Tenant',
        'phone': '0501234567',
        'role': 'tenant',
        'contractStartDate': ts,
        'contractEndDate': '2027-01-15T00:00:00Z',
        'properties': [
          {
            'buildingName': 'Tower A',
            'unitNumber': '101',
            'startDate': DateTime(2026, 2, 1),
            'endDate': null,
          }
        ],
      }, 'uid_1');

      expect(user.contractStartDate, ts.toDate().toLocal());
      expect(user.contractEndDate, DateTime.parse('2027-01-15T00:00:00Z').toLocal());
      expect(user.properties, hasLength(1));
      expect(user.properties!.first.startDate, DateTime(2026, 2, 1));
      expect(user.properties!.first.endDate, isNull);
    });
  });
}
