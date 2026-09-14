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
      );
}
