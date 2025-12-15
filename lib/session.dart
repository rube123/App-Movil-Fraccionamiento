import 'package:shared_preferences/shared_preferences.dart';

class Session {
  static const _kIdPersona = "id_persona";
  static const _kIdUsuario = "id_usuario";
  static const _kLastActivity = "last_activity"; 

  /// Minutos de inactividad antes de cerrar sesión
  static const int inactivityMinutes = 5;

  /// Guardar sesión + marcar última actividad como ahora
  static Future<void> save({
    required int idPersona,
    required int idUsuario,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kIdPersona, idPersona);
    await sp.setInt(_kIdUsuario, idUsuario);
    await _setNowAsLastActivity(sp);
  }

  /// Actualizar solo la marca de última actividad
  static Future<void> touch() async {
    final sp = await SharedPreferences.getInstance();
    await _setNowAsLastActivity(sp);
  }

  static Future<int> idPersona() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kIdPersona) ?? 0;
  }

  static Future<int> idUsuario() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kIdUsuario) ?? 0;
  }

  /// Devuelve true si la sesión ya expiró por inactividad
  static Future<bool> isExpired() async {
    final sp = await SharedPreferences.getInstance();
    final last = sp.getInt(_kLastActivity);

    if (last == null) return true; // no hay marca -> considerar expirada

    final lastDt = DateTime.fromMillisecondsSinceEpoch(last);
    final diff = DateTime.now().difference(lastDt);

    return diff > const Duration(minutes: inactivityMinutes);
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kIdPersona);
    await sp.remove(_kIdUsuario);
    await sp.remove(_kLastActivity);
  }

  static Future<void> _setNowAsLastActivity(SharedPreferences sp) async {
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    await sp.setInt(_kLastActivity, nowMillis);
  }
}
