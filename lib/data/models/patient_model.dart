class PatientModel {
  PatientModel({
    required this.patientId,
    required this.name,
    required this.age,
    required this.sex,
    this.dob = '',
    this.height = '',
    this.weight = '',
    this.bloodPressure = '',
    this.medications = '',
    this.comments = '',
    this.photoPath = '',
    this.signaturePath = '',
  });

  final String patientId;
  final String name;
  final String age;
  final String sex;
  final String dob;
  final String height;
  final String weight;
  final String bloodPressure;
  final String medications;
  final String comments;

  /// Local file path to the patient's photo, copied into this app's own
  /// storage at capture time (see `PatientMediaService`) rather than kept
  /// as a raw OS gallery/camera path — empty when none was captured, in
  /// which case the PDF report reserves no space for it at all.
  final String photoPath;

  /// Local file path to the patient's signature (drawn or uploaded), same
  /// storage/empty-means-omitted convention as [photoPath].
  final String signaturePath;

  Map<String, dynamic> toJson() => {
        'patient_id': patientId,
        'name': name,
        'age': age,
        'sex': sex,
        'dob': dob,
        'height': height,
        'weight': weight,
        'blood_pressure': bloodPressure,
        'medications': medications,
        'comments': comments,
        'photo_path': photoPath,
        'signature_path': signaturePath,
      };

  factory PatientModel.fromJson(Map<String, dynamic> json) => PatientModel(
        patientId: json['patient_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        age: json['age'] as String? ?? '',
        sex: json['sex'] as String? ?? '',
        dob: json['dob'] as String? ?? '',
        height: json['height'] as String? ?? '',
        weight: json['weight'] as String? ?? '',
        bloodPressure: json['blood_pressure'] as String? ?? '',
        medications: json['medications'] as String? ?? '',
        comments: json['comments'] as String? ?? '',
        photoPath: json['photo_path'] as String? ?? '',
        signaturePath: json['signature_path'] as String? ?? '',
      );
}
