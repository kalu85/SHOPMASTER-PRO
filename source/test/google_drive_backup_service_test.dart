import 'package:flutter_test/flutter_test.dart';
import 'package:shopmaster_pro/core/services/google_drive_backup_service.dart';

void main() {
  group('Google Drive upload metadata verification', () {
    const checksum = 'd41d8cd98f00b204e9800998ecf8427e';

    test('accepts matching uploaded file metadata', () {
      expect(
        GoogleDriveBackupService.uploadMetadataMatches(
          expectedName: 'shopmaster_drive_backup.db',
          expectedSize: 2048,
          expectedMd5: checksum,
          metadata: {
            'id': 'drive-file-id',
            'name': 'shopmaster_drive_backup.db',
            'size': '2048',
            'md5Checksum': checksum,
          },
        ),
        isTrue,
      );
    });

    test('rejects a size mismatch', () {
      expect(
        GoogleDriveBackupService.uploadMetadataMatches(
          expectedName: 'shopmaster_drive_backup.db',
          expectedSize: 2048,
          expectedMd5: checksum,
          metadata: {
            'id': 'drive-file-id',
            'name': 'shopmaster_drive_backup.db',
            'size': '1024',
            'md5Checksum': checksum,
          },
        ),
        isFalse,
      );
    });

    test('rejects a checksum mismatch', () {
      expect(
        GoogleDriveBackupService.uploadMetadataMatches(
          expectedName: 'shopmaster_drive_backup.db',
          expectedSize: 2048,
          expectedMd5: checksum,
          metadata: {
            'id': 'drive-file-id',
            'name': 'shopmaster_drive_backup.db',
            'size': '2048',
            'md5Checksum': '00000000000000000000000000000000',
          },
        ),
        isFalse,
      );
    });

    test('rejects incomplete Drive metadata', () {
      expect(
        GoogleDriveBackupService.uploadMetadataMatches(
          expectedName: 'shopmaster_drive_backup.db',
          expectedSize: 2048,
          expectedMd5: checksum,
          metadata: {'name': 'shopmaster_drive_backup.db'},
        ),
        isFalse,
      );
    });
  });
}
