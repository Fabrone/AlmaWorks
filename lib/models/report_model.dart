import 'package:cloud_firestore/cloud_firestore.dart';
class ReportModel {
final String id;
final String name;
final String? url;
final String projectId;
final String projectName;
final DateTime uploadedAt;
final String type;
final Map<String, dynamic>? safetyFormData;
final String? fileType;
ReportModel({
required this.id,
required this.name,
this.url,
required this.projectId,
required this.projectName,
required this.uploadedAt,
required this.type,
this.safetyFormData,
this.fileType,
});
factory ReportModel.fromMap(String id, Map<String, dynamic> data) {
return ReportModel(
id: id,
name: data['name'] ?? '',
url: data['url'],
projectId: data['projectId'] ?? '',
projectName: data['projectName'] ?? '',
uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
type: data['type'] ?? '',
safetyFormData: data['safetyFormData'],
fileType: data['fileType'],
);
}
Map<String, dynamic> toMap() {
return {
'name': name,
'url': url,
'projectId': projectId,
'projectName': projectName,
'uploadedAt': Timestamp.fromDate(uploadedAt),
'type': type,
'safetyFormData': safetyFormData,
'fileType': fileType,
};
}
}