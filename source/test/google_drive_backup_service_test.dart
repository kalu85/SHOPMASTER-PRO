import 'package:flutter_test/flutter_test.dart';
import 'package:shopmaster_pro/core/services/google_drive_backup_service.dart';

void main() {
  group('Google Drive download metadata verification', () {
    const checksum = 'd41d8cd98f00b204e9800998ecf8427e';

    test('accepts matching downloaded file metadata', () {
      expect(
        GoogleDriveBackupService.downloadMetadataMatches(
          expectedId: 'drive-file-id',
          expectedName: 'shopmaster_drive_backup.db',
          downloadedSize: 2048,
          downloadedMd5: checksum,
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

    test('rejects size and checksum mismatches', () {
      final metadata = {
        'id': 'drive-file-id',
        'name': 'shopmaster_drive_backup.db',
        'size': '2048',
        'md5Checksum': checksum,
      };
      expect(
        GoogleDriveBackupService.downloadMetadataMatches(
          expectedId: 'drive-file-id',
          expectedName: 'shopmaster_drive_backup.db',
          downloadedSize: 1024,
          downloadedMd5: checksum,
          metadata: metadata,
        ),
        isFalse,
      );
      expect(
        GoogleDriveBackupService.downloadMetadataMatches(
          expectedId: 'drive-file-id',
          expectedName: 'shopmaster_drive_backup.db',
          downloadedSize: 2048,
          downloadedMd5: '00000000000000000000000000000000',
          metadata: metadata,
        ),
        isFalse,
      );
    });

    test('rejects a different file identity or incomplete metadata', () {
      expect(
        GoogleDriveBackupService.downloadMetadataMatches(
          expectedId: 'requested-id',
          expectedName: 'shopmaster_drive_backup.db',
          downloadedSize: 2048,
          downloadedMd5: checksum,
          metadata: {
            'id': 'other-id',
            'name': 'shopmaster_drive_backup.db',
            'size': '2048',
            'md5Checksum': checksum,
          },
        ),
        isFalse,
      );
      expect(
        GoogleDriveBackupService.downloadMetadataMatches(
          expectedId: 'drive-file-id',
          expectedName: 'shopmaster_drive_backup.db',
          downloadedSize: 2048,
          downloadedMd5: checksum,
          metadata: {'id': 'drive-file-id'},
        ),
        isFalse,
      );
    });
  });

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
