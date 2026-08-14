class FaqModel {
  final int? id;
  final String? question;
  final String? answer;

  const FaqModel({
    this.id,
    this.question,
    this.answer,
  });

  factory FaqModel.fromJson(Map<String, dynamic> json) {
    return FaqModel(
      id: json['id'] as int?,
      question: json['question'] as String?,
      answer: json['answer'] as String?,
    );
  }
}
