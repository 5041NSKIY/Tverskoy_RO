import 'dart:convert';
import 'dart:io';

// ============================================================
// СЕРВИС ОБНОВЛЕНИЙ
// ============================================================

/// Результат проверки обновлений.
///
/// Если [version] и [downloadUrl] равны null,
/// значит более новой версии нет.
class UpdateCheckResult {
  final String? version;
  final String? downloadUrl;

  const UpdateCheckResult({
    this.version,
    this.downloadUrl,
  });

  bool get hasUpdate =>
      version != null && downloadUrl != null;
}

/// Отвечает за работу с GitHub Releases.
///
/// UI сюда не лезет.
/// Этот сервис только получает данные и возвращает результат.
class UpdateService {
  /// GitHub API со списком релизов.
  ///
  /// Используем /releases, а не /releases/latest,
  /// потому что latest не возвращает prerelease,
  /// а у нас beta-релизы.
  static const String _githubReleasesApi =
      'https://api.github.com/repos/5041NSKIY/Tverskoy_RO/releases?per_page=20';

  // ==========================================================
  // СРАВНЕНИЕ ВЕРСИЙ
  // ==========================================================

  /// Превращает:
  /// v0.1.2-beta
  /// 0.1.2 beta
  ///
  /// в:
  /// [0, 1, 2]
  static List<int> _versionNumbers(String value) {
    final match =
        RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(value);

    if (match == null) {
      return const [0, 0, 0];
    }

    return [
      int.tryParse(match.group(1) ?? '') ?? 0,
      int.tryParse(match.group(2) ?? '') ?? 0,
      int.tryParse(match.group(3) ?? '') ?? 0,
    ];
  }

  /// true, если candidate новее current.
  static bool _isVersionNewer(
    String candidate,
    String current,
  ) {
    final a = _versionNumbers(candidate);
    final b = _versionNumbers(current);

    for (int i = 0; i < 3; i++) {
      if (a[i] > b[i]) return true;
      if (a[i] < b[i]) return false;
    }

    // При одинаковых цифрах стабильный релиз
    // считаем новее beta / alpha / rc.
    final candidateLower = candidate.toLowerCase();
    final currentLower = current.toLowerCase();

    bool isPreRelease(String value) =>
        value.contains('beta') ||
        value.contains('alpha') ||
        value.contains('rc');

    return isPreRelease(currentLower) &&
        !isPreRelease(candidateLower);
  }

  // ==========================================================
  // ПРОВЕРКА GITHUB RELEASES
  // ==========================================================

  /// Ищет самый новый опубликованный релиз,
  /// содержащий установщик Tverskoy RO.
  static Future<UpdateCheckResult> checkForUpdate({
    required String currentVersion,
  }) async {
    final client = HttpClient();

    try {
      final request = await client.getUrl(
        Uri.parse(_githubReleasesApi),
      );

      request.headers.set(
        'Accept',
        'application/vnd.github+json',
      );

      request.headers.set(
        'User-Agent',
        'Tverskoy-RO-Updater',
      );

      request.headers.set(
        'X-GitHub-Api-Version',
        '2026-03-10',
      );

      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'GitHub вернул HTTP ${response.statusCode}',
        );
      }

      final body =
          await response.transform(utf8.decoder).join();

      final List<dynamic> releases =
          json.decode(body);

      Map<String, dynamic>? newestRelease;

      for (final rawRelease in releases) {
        if (rawRelease is! Map<String, dynamic>) {
          continue;
        }

        if (rawRelease['draft'] == true) {
          continue;
        }

        final tag =
            (rawRelease['tag_name'] ?? '').toString();

        if (tag.isEmpty) {
          continue;
        }

        final assets = rawRelease['assets'];

        if (assets is! List) {
          continue;
        }

        final hasInstaller = assets.any((asset) {
          if (asset is! Map) {
            return false;
          }

          final name =
              (asset['name'] ?? '')
                  .toString()
                  .toLowerCase();

          return name.startsWith(
                'tverskoy_ro_setup_',
              ) &&
              name.endsWith('.exe');
        });

        if (!hasInstaller) {
          continue;
        }

        if (newestRelease == null ||
            _isVersionNewer(
              tag,
              (newestRelease['tag_name'] ?? '')
                  .toString(),
            )) {
          newestRelease = rawRelease;
        }
      }

      if (newestRelease == null) {
        return const UpdateCheckResult();
      }

      final newestTag =
          (newestRelease['tag_name'] ?? '')
              .toString();

      if (!_isVersionNewer(
        newestTag,
        currentVersion,
      )) {
        return const UpdateCheckResult();
      }

      final assets =
          newestRelease['assets'] as List<dynamic>;

      Map<dynamic, dynamic>? installerAsset;

      for (final asset in assets) {
        if (asset is! Map) {
          continue;
        }

        final name =
            (asset['name'] ?? '')
                .toString()
                .toLowerCase();

        if (name.startsWith(
              'tverskoy_ro_setup_',
            ) &&
            name.endsWith('.exe')) {
          installerAsset = asset;
          break;
        }
      }

      final downloadUrl =
          (installerAsset?['browser_download_url'] ?? '')
              .toString();

      if (downloadUrl.isEmpty) {
        throw const FormatException(
          'В релизе нет ссылки на Setup EXE.',
        );
      }

      return UpdateCheckResult(
        version: newestTag,
        downloadUrl: downloadUrl,
      );
    } finally {
      client.close(force: true);
    }
  }
}