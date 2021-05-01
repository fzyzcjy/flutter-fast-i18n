import 'dart:io';

import 'package:fast_i18n/src/generator/generate.dart';
import 'package:fast_i18n/src/model/build_config.dart';
import 'package:fast_i18n/src/model/i18n_config.dart';
import 'package:fast_i18n/src/model/i18n_data.dart';
import 'package:fast_i18n/src/model/i18n_locale.dart';
import 'package:fast_i18n/src/model/pluralization_resolvers.dart';
import 'package:fast_i18n/src/parser_json.dart';
import 'package:fast_i18n/src/parser_yaml.dart';
import 'package:fast_i18n/src/utils.dart';

void main() async {
  final stopwatch = Stopwatch()..start();
  print('Generating translations...\n');

  Iterable<FileSystemEntity> files =
      (await Directory.current.list(recursive: true).toList())
          .where((item) => FileSystemEntity.isFileSync(item.path));

  // build config
  BuildConfig? buildConfig;
  for (final file in files) {
    final fileName = file.path.getFileName();

    if (fileName == 'build.yaml') {
      print('Found build.yaml in ${file.path}');
      final content = await File(file.path).readAsString();
      buildConfig = parseBuildYaml(content);
      break;
    }
  }

  if (buildConfig == null) {
    buildConfig = parseBuildYaml(null);
    print('No build.yaml, use default settings.');
  }

  print('');
  print(' -> baseLocale: ${buildConfig.baseLocale.toLanguageTag()}');
  print(
      ' -> inputDirectory: ${buildConfig.inputDirectory != null ? buildConfig.inputDirectory : 'null (everywhere)'}');
  print(' -> inputFilePattern: ${buildConfig.inputFilePattern}');
  print(
      ' -> outputDirectory: ${buildConfig.outputDirectory != null ? buildConfig.outputDirectory : 'null (directory of input)'}');
  print(' -> outputFilePattern: ${buildConfig.outputFilePattern}');
  print(' -> translateVar: ${buildConfig.translateVar}');
  print(' -> enumName: ${buildConfig.enumName}');
  print(
      ' -> translationClassVisibility: ${(buildConfig.translationClassVisibility.toString().split('.').last)}');
  print(
      ' -> keyCase: ${buildConfig.keyCase != null ? buildConfig.keyCase.toString().split('.').last : 'null (no change)'}');
  print(' -> maps: ${buildConfig.maps}');
  print(' -> pluralization/cardinal: ${buildConfig.pluralCardinal}');
  print(' -> pluralization/ordinal: ${buildConfig.pluralOrdinal}');
  print('');

  // filter files according to build config
  files = files.where((file) {
    if (!file.path.endsWith(buildConfig!.inputFilePattern)) return false;

    if (buildConfig.inputDirectory != null &&
        !file.path.contains(buildConfig.inputDirectory!)) return false;

    return true;
  });

  // find base name
  String? baseName;
  for (final file in files) {
    final fileName = file.path.getFileName();

    final fileNameNoExtension =
        fileName.replaceAll(buildConfig.inputFilePattern, '');
    final baseFile = Utils.baseFileRegex.firstMatch(fileNameNoExtension);
    if (baseFile != null) {
      baseName = fileNameNoExtension;
      print(
          'Found base name: "$baseName" (used for output file name and class names)');
      break;
    }
  }

  if (baseName == null) {
    print('Error: No base translation file.');
    return;
  }

  // scan translations
  print('Scanning translations...');
  print('');
  final translationList = <I18nData>[];
  String? resultPath;
  for (final file in files) {
    final fileName = file.path.getFileName();

    final fileNameNoExtension =
        fileName.replaceAll(buildConfig.inputFilePattern, '');
    final baseFile = Utils.baseFileRegex.firstMatch(fileNameNoExtension);
    if (baseFile != null) {
      // base file
      final content = await File(file.path).readAsString();
      final currTranslations =
          parseJSON(buildConfig, buildConfig.baseLocale, content);
      translationList.add(currTranslations);
      resultPath =
          file.path.replaceAll("${Platform.pathSeparator}$fileName", '') +
              Platform.pathSeparator +
              baseName +
              buildConfig.outputFilePattern;
      print(
          '${('(base) ' + buildConfig.baseLocale.toLanguageTag()).padLeft(12)} -> ${file.path}');
    } else {
      // secondary files (strings_x)
      final match = Utils.fileWithLocaleRegex.firstMatch(fileNameNoExtension);
      if (match != null) {
        final language = match.group(3);
        final script = match.group(5);
        final country = match.group(7);
        final locale = I18nLocale(
            language: language ?? '', script: script, country: country);
        final content = await File(file.path).readAsString();
        final currTranslations = parseJSON(buildConfig, locale, content);
        translationList.add(currTranslations);
        print('${locale.toLanguageTag().padLeft(12)} -> ${file.path}');
      }
    }
  }

  if (buildConfig.outputDirectory != null) {
    resultPath = buildConfig.outputDirectory! +
        Platform.pathSeparator +
        baseName +
        buildConfig.outputFilePattern;
  }

  if (resultPath == null) {
    print('No base file found.');
    return;
  }

  // generate
  final String output = generate(
      config: I18nConfig(
          baseName: baseName,
          baseLocale: buildConfig.baseLocale,
          renderedPluralizationResolvers: buildConfig
                      .pluralCardinal.isNotEmpty ||
                  buildConfig.pluralOrdinal.isNotEmpty
              ? PLURALIZATION_RESOLVERS
                  .where((resolver) => translationList.any(
                      (locale) => locale.locale.language == resolver.language))
                  .toList()
              : [],
          keyCase: buildConfig.keyCase,
          translateVariable: buildConfig.translateVar,
          enumName: buildConfig.enumName,
          translationClassVisibility: buildConfig.translationClassVisibility),
      translations: translationList
        ..sort((a, b) => a.base
            ? -1
            : a.localeTag.compareTo(
                b.localeTag))); // base locale, then all other locales

  await File(resultPath).writeAsString(output);

  if (buildConfig.pluralCardinal.isNotEmpty ||
      buildConfig.pluralOrdinal.isNotEmpty) {
    final languages =
        translationList.map((locale) => locale.locale.language).toSet();
    final rendered = PLURALIZATION_RESOLVERS
        .map((resolver) => resolver.language)
        .toSet()
        .intersection(languages);
    final missing = languages.difference(rendered);
    print('');
    print('Pluralization:');
    print(' -> rendered resolvers: ${rendered.toList()}');
    print(' -> you must implement these resolvers: ${missing.toList()}');
  }

  print('');
  print('Output: $resultPath');
  print('Translations generated successfully. (${stopwatch.elapsed})');
}

extension on String {
  /// converts /some/path/file.json to file.json
  String getFileName() {
    return this.split(Platform.pathSeparator).last;
  }
}