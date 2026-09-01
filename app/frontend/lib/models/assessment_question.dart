class AssessmentQuestion {
  final String questionText;
  final int yesWeight;

  const AssessmentQuestion({
    required this.questionText,
    required this.yesWeight,
  });

  String get id => 'q_${questionText.hashCode.abs()}';

  static const List<AssessmentQuestion> allQuestions = [
    AssessmentQuestion(
      questionText: 'Do you find it difficult telling your left from right?',
      yesWeight: 10,
    ),
    AssessmentQuestion(
      questionText: 'Do you get tired quickly when you read?',
      yesWeight: 10,
    ),
    AssessmentQuestion(
      questionText: 'Do you frequently find yourself thinking about something else when you are reading?',
      yesWeight: 10,
    ),
    AssessmentQuestion(
      questionText: 'Do you often make many errors when reading?',
      yesWeight: 20,
    ),
    AssessmentQuestion(
      questionText: 'Do you find it difficult stay focused?',
      yesWeight: 20,
    ),
    AssessmentQuestion(
      questionText: 'Do you find it hard to remember names?',
      yesWeight: 20,
    ),
    AssessmentQuestion(
      questionText: 'Do you find it hard to pronounce words correctly when talking?',
      yesWeight: 10,
    ),
    AssessmentQuestion(
      questionText: 'Do you forget how to spell short words you know sometimes?',
      yesWeight: 20,
    ),
    AssessmentQuestion(
      questionText: 'Do you find it difficult spelling words that you have not seen written down before?',
      yesWeight: 30,
    ),
    AssessmentQuestion(
      questionText: 'Do you find it difficult to read words you are unfamiliar with?',
      yesWeight: 30,
    ),
    AssessmentQuestion(
      questionText: 'Do you understand and use big words that you cannot spell?',
      yesWeight: 20,
    ),
    AssessmentQuestion(
      questionText: 'Do you get stuck with words you cannot read?',
      yesWeight: 10,
    ),
    AssessmentQuestion(
      questionText: 'Do your eyes feel a little out of coordination when reading text?',
      yesWeight: 10,
    ),
    AssessmentQuestion(
      questionText: 'Do words appear to move, appear blurred or hard to focus on when reading?',
      yesWeight: 30,
    ),
  ];
}
