import 'dart:collection';

import 'package:fast_i18n/string_extensions.dart';
import 'package:fast_i18n/src/model.dart';

/// decides which class should be generated
class ClassTask {
  final String className;
  final Map<String, Node> members;

  ClassTask(this.className, this.members);
}

/// main generate function
/// returns a string representing the content of the .g.dart file
String generate(
    {required I18nConfig config, required List<I18nData> translations}) {
  StringBuffer buffer = StringBuffer();

  buffer.writeln();
  buffer.writeln('// Generated file. Do not edit.');
  buffer.writeln();
  buffer.writeln('import \'package:flutter/material.dart\';');
  buffer.writeln('import \'package:fast_i18n/fast_i18n.dart\';');

  _generateHeader(buffer, config, translations);

  buffer.writeln();
  buffer.writeln('// translations');

  for (I18nData localeData in translations) {
    _generateLocale(buffer, config, localeData);
  }

  return buffer.toString();
}

/// generates the header of the .g.dart file
/// contains the t function, LocaleSettings class and some global variables
void _generateHeader(
    StringBuffer buffer, I18nConfig config, List<I18nData> allLocales) {
  // identifiers
  const String baseLocaleVar = '_baseLocale';
  const String currLocaleVar = '_currLocale';
  const String translationsClass = 'Translations';
  const String settingsClass = 'LocaleSettings';
  const String translationProviderKey = '_translationProviderKey';
  const String translationProviderClass = 'TranslationProvider';
  const String translationProviderStateClass = '_TranslationProviderState';
  const String inheritedClass = '_InheritedLocaleData';

  // constants
  final String translateVarInternal = '_${config.translateVariable}';
  final String translateVar = config.translateVariable;
  final String enumName = config.enumName;
  final String baseLocale = config.baseLocale;
  final String baseClassName = _getClassNameRoot(
      baseName: config.baseName,
      visibility: config.translationClassVisibility,
      locale: config.baseLocale);

  // current locale variable
  buffer.writeln();
  buffer.writeln(
      'const $enumName $baseLocaleVar = $enumName.${baseLocale.toEnumConstant()};');
  buffer.writeln('$enumName $currLocaleVar = $baseLocaleVar;');

  // enum
  buffer.writeln();
  buffer.writeln('/// Supported locales, see extension methods below.');
  buffer.writeln('///');
  buffer.writeln('/// Usage:');
  buffer.writeln(
      '/// - LocaleSettings.setLocale($enumName.${baseLocale.toEnumConstant()})');
  buffer.writeln(
      '/// - if (LocaleSettings.currentLocale == $enumName.${baseLocale.toEnumConstant()})');
  buffer.writeln('enum $enumName {');
  for (I18nData locale in allLocales) {
    buffer.writeln(
        '\t${locale.locale.toEnumConstant()}, // \'${locale.locale}\'${locale.base ? ' (base locale, fallback)' : ''}');
  }
  buffer.writeln('}');

  // t getter
  buffer.writeln();
  buffer.writeln('/// Method A: Simple');
  buffer.writeln('///');
  buffer.writeln(
      '/// Widgets using this method will not be updated when locale changes during runtime.');
  buffer.writeln(
      '/// Translation happens during initialization of the widget (call of $translateVar).');
  buffer.writeln('///');
  buffer.writeln('/// Usage:');
  buffer.writeln('/// String translated = $translateVar.someKey.anotherKey;');
  buffer.writeln(
      '$baseClassName $translateVarInternal = $currLocaleVar.translations;');
  buffer.writeln('$baseClassName get $translateVar => $translateVarInternal;');

  // t getter (advanced)
  buffer.writeln();
  buffer.writeln('/// Method B: Advanced');
  buffer.writeln('///');
  buffer.writeln(
      '/// All widgets using this method will trigger a rebuild when locale changes.');
  buffer.writeln(
      '/// Use this if you have e.g. a settings page where the user can select the locale during runtime.');
  buffer.writeln('///');
  buffer.writeln('/// Step 1:');
  buffer.writeln('/// wrap your App with');
  buffer.writeln('/// TranslationProvider(');
  buffer.writeln('/// \tchild: MyApp()');
  buffer.writeln('/// );');
  buffer.writeln('///');
  buffer.writeln('/// Step 2:');
  buffer.writeln(
      '/// final $translateVar = $translationsClass.of(context); // get $translateVar variable');
  buffer.writeln(
      '/// String translated = $translateVar.someKey.anotherKey; // use $translateVar variable');
  buffer.writeln('class $translationsClass {');
  buffer.writeln('\t$translationsClass._(); // no constructor');
  buffer.writeln();
  buffer.writeln('\tstatic $baseClassName of(BuildContext context) {');
  buffer.writeln(
      '\t\tfinal inheritedWidget = context.dependOnInheritedWidgetOfExactType<_InheritedLocaleData>();');
  buffer.writeln('\t\tif (inheritedWidget == null) {');
  buffer.writeln(
      '\t\t\tthrow(\'Please wrap your app with "TranslationProvider".\');');
  buffer.writeln('\t\t}');
  buffer.writeln('\t\treturn inheritedWidget.locale.translations;');
  buffer.writeln('\t}');
  buffer.writeln('}');

  // settings
  buffer.writeln();
  buffer.writeln('class $settingsClass {');
  buffer.writeln('\t$settingsClass._(); // no constructor');

  buffer.writeln();
  buffer.writeln('\t/// Uses locale of the device, fallbacks to base locale.');
  buffer.writeln('\t/// Returns the locale which has been set.');
  buffer.writeln(
      '\t/// Hint for pre 4.x.x developers: You can access the raw string via LocaleSettings.useDeviceLocale().languageTag');
  buffer.writeln('\tstatic $enumName useDeviceLocale() {');
  buffer.writeln('\t\tString? deviceLocale = FastI18n.getDeviceLocale();');
  buffer.writeln('\t\tif (deviceLocale != null)');
  buffer.writeln('\t\t\treturn setLocaleRaw(deviceLocale);');
  buffer.writeln('\t\telse');
  buffer.writeln('\t\t\treturn setLocale($baseLocaleVar);');
  buffer.writeln('\t}');

  buffer.writeln();
  buffer.writeln('\t/// Sets locale');
  buffer.writeln('\t/// Returns the locale which has been set.');
  buffer.writeln('\tstatic $enumName setLocale($enumName locale) {');
  buffer.writeln('\t\t$currLocaleVar = locale;');
  buffer.writeln('\t\t$translateVarInternal = $currLocaleVar.translations;');
  buffer.writeln();
  buffer.writeln('\t\tfinal state = $translationProviderKey.currentState;');
  buffer.writeln('\t\tif (state != null) {');
  buffer.writeln('\t\t\t// force rebuild if TranslationProvider is used');
  buffer.writeln('\t\t\tstate.setLocale($currLocaleVar);');
  buffer.writeln('\t\t}');
  buffer.writeln();
  buffer.writeln('\t\treturn $currLocaleVar;');
  buffer.writeln('\t}');

  buffer.writeln();
  buffer.writeln('\t/// Sets locale using string tag (e.g. en_US, de-DE, fr)');
  buffer.writeln('\t/// Fallbacks to base locale.');
  buffer.writeln('\t/// Returns the locale which has been set.');
  buffer.writeln('\tstatic $enumName setLocaleRaw(String locale) {');
  buffer.writeln(
      '\t\tString selectedLocale = FastI18n.selectLocale(locale, supportedLocalesRaw, $baseLocaleVar.languageTag);');
  buffer.writeln('\t\treturn setLocale(selectedLocale.to$enumName()!);');
  buffer.writeln('\t}');

  buffer.writeln();
  buffer.writeln('\t/// Gets current locale.');
  buffer.writeln(
      '\t/// Hint for pre 4.x.x developers: You can access the raw string via LocaleSettings.currentLocale.languageTag');
  buffer.writeln('\tstatic $enumName get currentLocale {');
  buffer.writeln('\t\treturn $currLocaleVar;');
  buffer.writeln('\t}');

  buffer.writeln();
  buffer.writeln('\t/// Gets base locale.');
  buffer.writeln(
      '\t/// Hint for pre 4.x.x developers: You can access the raw string via LocaleSettings.baseLocale.languageTag');
  buffer.writeln('\tstatic $enumName get baseLocale {');
  buffer.writeln('\t\treturn $baseLocaleVar;');
  buffer.writeln('\t}');

  buffer.writeln();
  buffer.writeln('\t/// Gets supported locales in string format.');
  buffer.writeln('\tstatic List<String> get supportedLocalesRaw {');
  buffer.writeln('\t\treturn $enumName.values');
  buffer.writeln('\t\t\t.map((locale) => locale.languageTag)');
  buffer.writeln('\t\t\t.toList();');
  buffer.writeln('\t}');

  buffer.writeln();
  buffer.writeln(
      '\t/// Gets supported locales (as Locale objects) with base locale sorted first.');
  buffer.writeln('\tstatic List<Locale> get supportedLocales {');
  buffer.writeln(
      '\t\treturn FastI18n.convertToLocales(supportedLocalesRaw, $baseLocaleVar.languageTag);');
  buffer.writeln('\t}');

  buffer.writeln('}');

  // enum extension
  buffer.writeln();
  buffer.writeln('// extensions for $enumName');
  buffer.writeln();
  buffer.writeln('extension ${enumName}Extensions on $enumName {');
  buffer.writeln('\t$baseClassName get translations {');
  buffer.writeln('\t\tswitch (this) {');
  for (I18nData locale in allLocales) {
    String className = _getClassNameRoot(
        baseName: config.baseName,
        locale: locale.locale,
        visibility: config.translationClassVisibility);
    buffer.writeln(
        '\t\t\tcase $enumName.${locale.locale.toEnumConstant()}: return $className._instance;');
  }
  buffer.writeln('\t\t}');
  buffer.writeln('\t}');
  buffer.writeln();
  buffer.writeln('\tString get languageTag {');
  buffer.writeln('\t\tswitch (this) {');
  for (I18nData locale in allLocales) {
    buffer.writeln(
        '\t\t\tcase $enumName.${locale.locale.toEnumConstant()}: return \'${locale.locale}\';');
  }
  buffer.writeln('\t\t}');
  buffer.writeln('\t}');
  buffer.writeln('}');
  buffer.writeln();

  // string extension
  buffer.writeln('extension String${enumName}Extensions on String {');
  buffer.writeln('\t$enumName? to$enumName() {');
  buffer.writeln('\t\tswitch (this) {');
  for (I18nData locale in allLocales) {
    buffer.writeln(
        '\t\t\tcase \'${locale.locale}\': return $enumName.${locale.locale.toEnumConstant()};');
  }
  buffer.writeln('\t\t\tdefault: return null;');
  buffer.writeln('\t\t}');
  buffer.writeln('\t}');
  buffer.writeln('}');

  buffer.writeln();
  buffer.writeln('// wrappers');

  // TranslationProvider
  buffer.writeln();
  buffer.writeln(
      'GlobalKey<$translationProviderStateClass> $translationProviderKey = new GlobalKey<$translationProviderStateClass>();');
  buffer.writeln();
  buffer.writeln('class $translationProviderClass extends StatefulWidget {');
  buffer.writeln(
      '\t$translationProviderClass({required this.child}) : super(key: $translationProviderKey);');
  buffer.writeln();
  buffer.writeln('\tfinal Widget child;');
  buffer.writeln();
  buffer.writeln('\t@override');
  buffer.writeln(
      '\t$translationProviderStateClass createState() => $translationProviderStateClass();');
  buffer.writeln('}');

  buffer.writeln();
  buffer.writeln(
      'class $translationProviderStateClass extends State<$translationProviderClass> {');
  buffer.writeln('\t$enumName locale = $currLocaleVar;');
  buffer.writeln();
  buffer.writeln('\tvoid setLocale($enumName newLocale) {');
  buffer.writeln('\t\tsetState(() {');
  buffer.writeln('\t\t\tlocale = newLocale;');
  buffer.writeln('\t\t});');
  buffer.writeln('\t}');
  buffer.writeln();
  buffer.writeln('\t@override');
  buffer.writeln('\tWidget build(BuildContext context) {');
  buffer.writeln('\t\treturn $inheritedClass(');
  buffer.writeln('\t\t\tlocale: locale,');
  buffer.writeln('\t\t\tchild: widget.child,');
  buffer.writeln('\t\t);');
  buffer.writeln('\t}');
  buffer.writeln('}');

  // InheritedLocaleData
  buffer.writeln();
  buffer.writeln('class $inheritedClass extends InheritedWidget {');
  buffer.writeln('\tfinal $enumName locale;');
  buffer.writeln(
      '\t$inheritedClass({required this.locale, required Widget child}) : super(child: child);');
  buffer.writeln();
  buffer.writeln('\t@override');
  buffer.writeln('\tbool updateShouldNotify($inheritedClass oldWidget) {');
  buffer.writeln('\t\treturn oldWidget.locale != locale;');
  buffer.writeln('\t}');
  buffer.writeln('}');
}

/// generates all classes of one locale
/// all non-default locales has a postfix of their locale code
/// e.g. Strings, StringsDe, StringsFr
void _generateLocale(
    StringBuffer buffer, I18nConfig config, I18nData localeData) {
  Queue<ClassTask> queue = Queue();

  queue.add(ClassTask(
    _getClassNameRoot(
        baseName: config.baseName,
        visibility: config.translationClassVisibility),
    localeData.root.entries,
  ));

  do {
    ClassTask task = queue.removeFirst();

    _generateClass(
      config,
      localeData.base,
      localeData.locale,
      buffer,
      queue,
      task.className,
      task.members,
    );
  } while (queue.isNotEmpty);
}

/// generates a class and all of its members of ONE locale
/// adds subclasses to the queue
void _generateClass(
  I18nConfig config,
  bool base,
  String locale,
  StringBuffer buffer,
  Queue<ClassTask> queue,
  String className,
  Map<String, Node> currMembers,
) {
  final finalClassName = _getClassName(parentName: className, locale: locale);

  buffer.writeln();

  if (base) {
    buffer.writeln('class $finalClassName {');
  } else {
    final baseClassName =
        _getClassName(parentName: className, locale: config.baseLocale);
    buffer.writeln('class $finalClassName implements $baseClassName {');
  }

  buffer.writeln('\t$finalClassName._(); // no constructor');
  buffer.writeln();
  buffer.writeln('\tstatic $finalClassName _instance = $finalClassName._();');
  if (config.translationClassVisibility == TranslationClassVisibility.public)
    buffer.writeln('\tstatic $finalClassName get instance => _instance;');
  buffer.writeln();

  currMembers.forEach((key, value) {
    key = key.toCase(config.keyCase);

    buffer.write('\t');
    if (!base) buffer.write('@override ');

    if (value is TextNode) {
      if (value.params.isEmpty) {
        buffer.writeln('String get $key => \'${value.content}\';');
      } else {
        buffer.writeln(
            'String $key${_toParameterList(value.params)} => \'${value.content}\';');
      }
    } else if (value is ListNode) {
      String type = value.plainStrings ? 'String' : 'dynamic';
      buffer.write('List<$type> get $key => ');
      _generateList(base, locale, buffer, queue, className, value.entries, 0);
    } else if (value is ObjectNode) {
      String childClassNoLocale =
          _getClassName(parentName: className, childName: key);
      if (value.mapMode) {
        // inline map
        String type = value.plainStrings ? 'String' : 'dynamic';
        buffer.write('Map<String, $type> get $key => ');
        _generateMap(
            base, locale, buffer, queue, childClassNoLocale, value.entries, 0);
      } else {
        // generate a class later on
        queue.add(ClassTask(childClassNoLocale, value.entries));
        String childClassWithLocale = _getClassName(
            parentName: className, childName: key, locale: locale);
        buffer.writeln(
            '$childClassWithLocale get $key => $childClassWithLocale._instance;');
      }
    }
  });

  buffer.writeln('}');
}

/// generates a map of ONE locale
/// similar to _generateClass but anonymous and accessible via key
void _generateMap(
  bool base,
  String locale,
  StringBuffer buffer,
  Queue<ClassTask> queue,
  String className, // without locale
  Map<String, Node> currMembers,
  int depth,
) {
  buffer.writeln('{');

  currMembers.forEach((key, value) {
    _addTabs(buffer, depth + 2);
    if (value is TextNode) {
      if (value.params.isEmpty) {
        buffer.writeln('\'$key\': \'${value.content}\',');
      } else {
        buffer.writeln(
            '\'$key\': ${_toParameterList(value.params)} => \'${value.content}\',');
      }
    } else if (value is ListNode) {
      buffer.write('\'$key\': ');
      _generateList(
          base, locale, buffer, queue, className, value.entries, depth + 1);
    } else if (value is ObjectNode) {
      String childClassNoLocale =
          _getClassName(parentName: className, childName: key);
      if (value.mapMode) {
        // inline map
        buffer.write('\'$key\': ');
        _generateMap(base, locale, buffer, queue, childClassNoLocale,
            value.entries, depth + 1);
      } else {
        // generate a class later on
        queue.add(ClassTask(childClassNoLocale, value.entries));
        String childClassWithLocale = _getClassName(
            parentName: className, childName: key, locale: locale);
        buffer.writeln('\'$key\': $childClassWithLocale._instance,');
      }
    }
  });

  _addTabs(buffer, depth + 1);

  buffer.write('}');

  if (depth == 0) {
    buffer.writeln(';');
  } else {
    buffer.writeln(',');
  }
}

/// generates a list
void _generateList(
  bool base,
  String locale,
  StringBuffer buffer,
  Queue<ClassTask> queue,
  String className,
  List<Node> currList,
  int depth,
) {
  buffer.writeln('[');

  for (int i = 0; i < currList.length; i++) {
    Node value = currList[i];
    _addTabs(buffer, depth + 2);
    if (value is TextNode) {
      if (value.params.isEmpty) {
        buffer.writeln('\'${value.content}\',');
      } else {
        buffer.writeln(
            '${_toParameterList(value.params)} => \'${value.content}\',');
      }
    } else if (value is ListNode) {
      _generateList(
          base, locale, buffer, queue, className, value.entries, depth + 1);
    } else if (value is ObjectNode) {
      String child = depth.toString() + 'i' + i.toString();
      String childClassNoLocale =
          _getClassName(parentName: className, childName: child);
      queue.add(ClassTask(childClassNoLocale, value.entries));

      String childClassWithLocale = _getClassName(
          parentName: className, childName: child, locale: locale);
      buffer.writeln('$childClassWithLocale._instance,');
    }
  }

  _addTabs(buffer, depth + 1);

  buffer.write(']');

  if (depth == 0) {
    buffer.writeln(';');
  } else {
    buffer.writeln(',');
  }
}

/// returns the parameter list
/// e.g. ({required Object name, required Object age}) for definition = true
/// or (name, age) for definition = false
String _toParameterList(List<String> params, {bool definition = true}) {
  StringBuffer buffer = StringBuffer();
  buffer.write('(');
  if (definition) buffer.write('{');
  for (int i = 0; i < params.length; i++) {
    if (i != 0) buffer.write(', ');
    if (definition) buffer.write('required Object ');
    buffer.write(params[i]);
  }
  if (definition) buffer.write('}');
  buffer.write(')');
  return buffer.toString();
}

/// writes count times \t to the buffer
void _addTabs(StringBuffer buffer, int count) {
  for (int i = 0; i < count; i++) {
    buffer.write('\t');
  }
}

String _getClassNameRoot(
    {required String baseName,
    String locale = '',
    required TranslationClassVisibility visibility}) {
  String result = baseName.toCase(KeyCase.pascal) +
      locale.toLowerCase().toCase(KeyCase.pascal);
  if (visibility == TranslationClassVisibility.private) result = '_' + result;
  return result;
}

String _getClassName(
    {required String parentName, String childName = '', String locale = ''}) {
  return parentName +
      childName.toCase(KeyCase.pascal) +
      locale.toLowerCase().toCase(KeyCase.pascal);
}
