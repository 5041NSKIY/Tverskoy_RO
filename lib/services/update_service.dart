import 'dart:convert';
import 'dart:io';

// ============================================================
// СЕРВИС ОБНОВЛЕНИЙ
// ============================================================

enum UpdateSeverity {
  normal,
  important,
  critical,
}

/// Информация об одном GitHub Release.
class UpdateReleaseInfo {
  final String version;
  final String changelog;
  final UpdateSeverity severity;

  const UpdateReleaseInfo({
    required this.version,
    required this.changelog,
    required this.severity,
  });
}

/// Полный результат проверки обновлений.
class UpdateCheckResult {
  final String? version;
  final String? downloadUrl;

  /// Информация о версии, которая установлена сейчас.
  final UpdateReleaseInfo? currentRelease;

  /// Все опубликованные версии новее текущей.
  /// Список идёт от самой новой к самой старой.
  final List<UpdateReleaseInfo> newerReleases;

  /// Максимальная важность среди пропущенных обновлений.
  final UpdateSeverity severity;

  const UpdateCheckResult({
    this.version,
    this.downloadUrl,
    this.currentRelease,
    this.newerReleases = const [],
    this.severity = UpdateSeverity.normal,
  });

  bool get hasUpdate =>
      version != null && downloadUrl != null;

  int get missedUpdatesCount => newerReleases.length;
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

  /// Чем больше число — тем "новее" канал при одинаковых цифрах.
  static int _releaseStageRank(String value) {
    final lower = value.toLowerCase();

    if (lower.contains('alpha')) return 1;
    if (lower.contains('beta')) return 2;
    if (lower.contains('rc')) return 3;

    return 4;
  }

  static int _compareVersions(
    String a,
    String b,
  ) {
    final aNumbers = _versionNumbers(a);
    final bNumbers = _versionNumbers(b);

    for (int i = 0; i < 3; i++) {
      if (aNumbers[i] > bNumbers[i]) return 1;
      if (aNumbers[i] < bNumbers[i]) return -1;
    }

    final aRank = _releaseStageRank(a);
    final bRank = _releaseStageRank(b);

    if (aRank > bRank) return 1;
    if (aRank < bRank) return -1;

    return 0;
  }

  static bool _isVersionNewer(
    String candidate,
    String current,
  ) {
    return _compareVersions(candidate, current) > 0;
  }

  static bool _isSameVersion(
    String a,
    String b,
  ) {
    return _compareVersions(a, b) == 0;
  }

  // ==========================================================
  // ВАЖНОСТЬ И CHANGELOG
  // ==========================================================

  static UpdateSeverity _severityFromBody(
    String body,
  ) {
    final upper = body.toUpperCase();

    if (upper.contains('[CRITICAL]')) {
      return UpdateSeverity.critical;
    }

    if (upper.contains('[IMPORTANT]')) {
      return UpdateSeverity.important;
    }

    return UpdateSeverity.normal;
  }

  static UpdateSeverity _maxSeverity(
    Iterable<UpdateReleaseInfo> releases,
  ) {
    var result = UpdateSeverity.normal;

    for (final release in releases) {
      if (release.severity == UpdateSeverity.critical) {
        return UpdateSeverity.critical;
      }

      if (release.severity == UpdateSeverity.important) {
        result = UpdateSeverity.important;
      }
    }

    return result;
  }

  /// Маркеры нужны сервису, пользователю их показывать не надо.
  static String _cleanChangelog(
    String body,
  ) {
    final cleaned = body
        .replaceAll(
          RegExp(
            r'\[(NORMAL|IMPORTANT|CRITICAL)\]',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    if (cleaned.isEmpty) {
      return 'Для этой версии описание изменений не указано.';
    }

    return cleaned;
  }

  static UpdateReleaseInfo _releaseInfo(
    Map<String, dynamic> release,
  ) {
    final tag =
        (release['tag_name'] ?? '').toString();

    final body =
        (release['body'] ?? '').toString();

    return UpdateReleaseInfo(
      version: tag,
      changelog: _cleanChangelog(body),
      severity: _severityFromBody(body),
    );
  }

  // ==========================================================
  // УСТАНОВЩИК
  // ==========================================================

  static Map<dynamic, dynamic>? _findInstallerAsset(
    Map<String, dynamic> release,
  ) {
    final assets = release['assets'];

    if (assets is! List) {
      return null;
    }

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
        return asset;
      }
    }

    return null;
  }

  // ==========================================================
  // ПРОВЕРКА GITHUB RELEASES
  // ==========================================================

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

      final decoded = json.decode(body);

      if (decoded is! List) {
        throw const FormatException(
          'GitHub вернул неожиданный формат списка релизов.',
        );
      }

      final publishedReleases =
          <Map<String, dynamic>>[];

      for (final rawRelease in decoded) {
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

        publishedReleases.add(rawRelease);
      }

      // --------------------------------------------------------
      // CHANGELOG ТЕКУЩЕЙ ВЕРСИИ
      // --------------------------------------------------------

      UpdateReleaseInfo? currentRelease;

      for (final release in publishedReleases) {
        final tag =
            (release['tag_name'] ?? '').toString();

        if (_isSameVersion(tag, currentVersion)) {
          currentRelease = _releaseInfo(release);
          break;
        }
      }

      // --------------------------------------------------------
      // ВСЕ ПРОПУЩЕННЫЕ ОБНОВЛЕНИЯ
      // --------------------------------------------------------

      final newerReleaseMaps =
          <Map<String, dynamic>>[];

      for (final release in publishedReleases) {
        final tag =
            (release['tag_name'] ?? '').toString();

        if (!_isVersionNewer(
          tag,
          currentVersion,
        )) {
          continue;
        }

        // Если для релиза нет Setup EXE,
        // он не считается устанавливаемым обновлением.
        if (_findInstallerAsset(release) == null) {
          continue;
        }

        newerReleaseMaps.add(release);
      }

      newerReleaseMaps.sort(
        (a, b) {
          final aTag =
              (a['tag_name'] ?? '').toString();
          final bTag =
              (b['tag_name'] ?? '').toString();

          // Новые версии сверху.
          return -_compareVersions(aTag, bTag);
        },
      );

      final newerReleases = newerReleaseMaps
          .map(_releaseInfo)
          .toList(growable: false);

      if (newerReleaseMaps.isEmpty) {
        return UpdateCheckResult(
          currentRelease: currentRelease,
        );
      }

      // Самый новый релиз всегда первый после сортировки.
      final newestRelease =
          newerReleaseMaps.first;

      final newestTag =
          (newestRelease['tag_name'] ?? '')
              .toString();

      final installerAsset =
          _findInstallerAsset(newestRelease);

      final downloadUrl =
          (installerAsset?['browser_download_url'] ?? '')
              .toString();

      if (downloadUrl.isEmpty) {
        throw const FormatException(
          'В новом релизе нет ссылки на Setup EXE.',
        );
      }

      return UpdateCheckResult(
        version: newestTag,
        downloadUrl: downloadUrl,
        currentRelease: currentRelease,
        newerReleases: newerReleases,
        severity: _maxSeverity(newerReleases),
      );
    } finally {
      client.close(force: true);
    }
  }

  // ==========================================================
  // СКАЧИВАНИЕ И ЗАПУСК ОБНОВЛЕНИЯ
  // ==========================================================

  /// Скачивает Setup EXE во временную папку Windows
  /// и запускает установщик.
  ///
  /// Закрытием самого приложения этот сервис НЕ занимается.
  /// Это остаётся ответственностью main.dart.
  static Future<void> downloadAndLaunchInstaller({
    required String downloadUrl,
    required String version,
    void Function(double progress)? onProgress,
  }) async {
    final client = HttpClient();
    IOSink? sink;

    try {
      final request = await client.getUrl(
        Uri.parse(downloadUrl),
      );

      request.headers.set(
        'User-Agent',
        'Tverskoy-RO-Updater',
      );

      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Не удалось скачать обновление: '
          'HTTP ${response.statusCode}',
        );
      }

      final safeVersion = version.replaceAll(
        RegExp(r'[^0-9A-Za-z._-]'),
        '_',
      );

      final installerFile = File(
        '${Directory.systemTemp.path}'
        '\\Tverskoy_RO_Setup_$safeVersion.exe',
      );

      sink = installerFile.openWrite();

      final totalBytes = response.contentLength;
      int receivedBytes = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        if (totalBytes > 0) {
          onProgress?.call(
            receivedBytes / totalBytes,
          );
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      onProgress?.call(1);

      await Process.start(
        installerFile.path,
        const [
          '/SP-',
          '/CLOSEAPPLICATIONS',
          '/RESTARTAPPLICATIONS',
        ],
        mode: ProcessStartMode.detached,
      );
    } finally {
      try {
        await sink?.close();
      } catch (_) {}

      client.close(force: true);
    }
  }
}
