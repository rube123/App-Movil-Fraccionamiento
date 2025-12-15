class Residente {
  final int idResidente;           
  final String nombre;
  final String primerApellido;
  final String? segundoApellido;
  final String? correo;            
  final String? telefono;
  final int? numeroResidencia;     

  Residente({
    required this.idResidente,
    required this.nombre,
    required this.primerApellido,
    this.segundoApellido,
    this.correo,
    this.telefono,
    this.numeroResidencia,
  });

  factory Residente.fromJson(Map<String, dynamic> json) {
    return Residente(
      idResidente: json['id_persona'] as int,
      nombre: json['nombre'] as String,
      primerApellido: json['primer_apellido'] as String,
      segundoApellido: json['segundo_apellido'] as String?,
      correo: json['correo'] as String?,
      telefono: json['telefono'] as String?,
      numeroResidencia: json['no_residencia'] as int?,
    );
  }
}
