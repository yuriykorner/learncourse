// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

// ✅ ОБНОВЛЕНИЕ ЦВЕТА БАРОВ
void updateThemeColor(String color) {
  try {
    js.context.callMethod('updateThemeColor', [color]);
  } catch (e) {
    print('Update theme error: $e');
  }
}

// ✅ СОХРАНЕНИЕ В LOCALSTORAGE
void saveThemeToLocalStorage(String theme) {
  try {
    js.context['localStorage'].setItem('theme_mode', theme);
  } catch (e) {
    print('Save theme error: $e');
  }
}
