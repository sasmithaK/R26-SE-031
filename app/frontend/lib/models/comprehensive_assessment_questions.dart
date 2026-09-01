import '../services/localization_service.dart';

class ComprehensiveQuestion {
  final String textSi;
  final String textEn;

  const ComprehensiveQuestion({required this.textSi, required this.textEn});

  String get id => 'q_${textEn.hashCode.abs()}';

  String get text {
    return LocalizationService.instance.currentLocale == 'si' ? textSi : textEn;
  }
}

class ComprehensiveAssessmentData {
  static const List<ComprehensiveQuestion> basicAssessment = [
    ComprehensiveQuestion(
      textSi: 'ඔබේ දරුවාට කියවීමේදී වමේ සිට දකුණට කියවීමට අපහසුද?',
      textEn: 'Does your child have difficulty reading from left to right?',
    ),
    ComprehensiveQuestion(
      textSi: 'කියවීමට පටන් ගත් පසු ඔබේ දරුවාට ඉක්මනින් මහන්සි දැනෙනවාද?',
      textEn: 'Does your child feel tired quickly after starting to read?',
    ),
    ComprehensiveQuestion(
      textSi: 'කියවීමේදී ඔබේ දරුවාගේ අවධානය නිතර වෙනත් දේවල් වෙත යොමු වෙනවද?',
      textEn:
          'Is your child\'s attention often diverted to other things when reading?',
    ),
    ComprehensiveQuestion(
      textSi: 'කියවීමේදී ඔබේ දරුවා නිතර වැරදි සිදු කරනවාද?',
      textEn: 'Does your child often make mistakes when reading?',
    ),
    ComprehensiveQuestion(
      textSi:
          'එක් කාර්යයක් කෙරෙහි දිගු වේලාවක් අවධානය පවත්වා ගැනීමට ඔබේ දරුවාට අපහසුද?',
      textEn:
          'Is it difficult for your child to maintain focus on one task for a long time?',
    ),
    ComprehensiveQuestion(
      textSi: 'පුද්ගලයන්ගේ නම් මතක තබා ගැනීමට ඔබේ දරුවාට අපහසුද?',
      textEn: "Is it difficult for your child to remember people's names?",
    ),
    ComprehensiveQuestion(
      textSi: 'කතා කරන විට නිවැරදි වචන උච්චාරණය කිරීමට ඔබේ දරුවාට අපහසුද?',
      textEn:
          'Is it difficult for your child to pronounce words correctly when speaking?',
    ),
    ComprehensiveQuestion(
      textSi:
          'දරුවා දන්නා කෙටි වචන ලියන ආකාරය කියාදුන් පසුත් නැවත අමතක වෙනවාද?',
      textEn:
          'Does the child forget how to write familiar short words even after being taught?',
    ),
    ComprehensiveQuestion(
      textSi: 'අලුතින් ඉගෙනගන්නා වචන නිවැරදිව ලිවීමට දරුවාට අපහසුද?',
      textEn:
          'Is it difficult for the child to write newly learned words correctly?',
    ),
    ComprehensiveQuestion(
      textSi: 'කලින් නොකියවූ වචන කියවීමට ඔබේ දරුවාට අපහසුද?',
      textEn: 'Is it difficult for your child to read previously unseen words?',
    ),
    ComprehensiveQuestion(
      textSi:
          'වචනයක තේරුම දැන සිටියත් එය ලිවීමේදී ඔබේ දරුවා අපහසුතාවයකට පත්වෙනවද?',
      textEn:
          'Even if they know the meaning of a word, does your child face difficulty when writing it?',
    ),
    ComprehensiveQuestion(
      textSi:
          'එක දිගට කියවීමේදී සමහර වචන ළඟ නතර වී නැවත වරක් උත්සාහ කිරීමට ඔබේ දරුවාට සිදුවෙනවාද?',
      textEn:
          'When reading continuously, does your child have to stop at some words and try again?',
    ),
    ComprehensiveQuestion(
      textSi: 'කියවීමේදී ඔබේ දරුවාගේ ඇස් එකට ක්‍රියා නොකරන බවක් පෙනෙනවාද?',
      textEn:
          "When reading, does it seem like your child's eyes are not working together?",
    ),
    ComprehensiveQuestion(
      textSi:
          'කියවීමේදී වචන හෙලවෙනවා බොඳව පෙනෙනවා හෝ දරුවාට අවධානය යොමු කිරීමට අපහසු බව ඔබට එක් වරක් හෝ පවසා තිබෙනවාද?',
      textEn:
          'Has the child told you at least once that words move, blur, or it is difficult to focus when reading?',
    ),
  ];

  static const List<ComprehensiveQuestion> readingAssessment = [
    ComprehensiveQuestion(
      textSi:
          'දරුවා කුඩා අවධියේ සිට අකුරු ශබ්ද අතර සම්බන්ධතාවය (Phonics) ඉගෙන ගැනීමට ඔබේ දරුවාට අපහසුතාවයක් තිබුණාද?',
      textEn:
          'Has your child had difficulty learning the relationship between letters and sounds (Phonics) since childhood?',
    ),
    ComprehensiveQuestion(
      textSi: 'ශබ්ද නඟා කියවීමේදී දරුවා නිතර වැරදි සිදුකරනවාද?',
      textEn: 'Does your child frequently make mistakes when reading aloud?',
    ),
    ComprehensiveQuestion(
      textSi:
          'ලියා ඇති දේ නැවත නැවත කියවීමකින් තොරව තේරුම් ගැනීමට ඔබේ දරුවාට අපහසුද?',
      textEn:
          'Does your child have difficulty understanding written text without rereading it repeatedly?',
    ),
    ComprehensiveQuestion(
      textSi:
          'දරුවාගේ කියවීමේ වේගය එම වයසේම අනිත් දරුවන්ට වඩා මන්දගාමී යැයි ඔබට හැඟී තිබෙනවාද?',
      textEn:
          "Do you feel that your child's reading speed is slower than other children of the same age?",
    ),
    ComprehensiveQuestion(
      textSi: 'කියවීමේදී වචන අතහැර යෑම හෝ වැරදි ලෙස කියවීම සිදුවෙනවාද?',
      textEn:
          'Does your child skip words or read them incorrectly when reading?',
    ),
    ComprehensiveQuestion(
      textSi: 'මේ මොහොතේ කියවමින් සිටි ස්ථානය ක්ෂණික අමතක වීමකට ලක්වෙනවාද?',
      textEn:
          'Does your child instantly forget the place they were currently reading?',
    ),
    ComprehensiveQuestion(
      textSi:
          'යම් ලේඛනයක් පිරික්සා අවශ්‍ය තොරතුරු ඉක්මනින් සොයා ගැනීමට ඔබේ දරුවාට අපහසුද?',
      textEn:
          'Does your child have difficulty scanning a document to quickly find necessary information?',
    ),
    ComprehensiveQuestion(
      textSi:
          'කියවීමේදී දරුවාගේ අවධානය ඉක්මනින් වෙනත් අතකට යොමු වන බව ඔබට හැඟී තිබෙනවාද?',
      textEn:
          "Have you felt that your child's attention is quickly drawn elsewhere when reading?",
    ),
    ComprehensiveQuestion(
      textSi:
          'කියවීමේදී වචන හෙලවෙනවා එකට මිශ්‍ර වෙනවා හෝ වෙනස් ලෙස පෙනෙනවා කියා ඔබේ දරුවා ඔබට පවසා තිබෙනවාද?',
      textEn:
          'Has your child told you that words move, mix together, or look different when reading?',
    ),
    ComprehensiveQuestion(
      textSi:
          'සුදු කඩදාසියක් හෝ සුදු පුවරුවක් දෙස බලන විට ඔහු හෝ ඇයගේ ඇස් වලට අපහසුතාවයක් දැනෙන බව ඔබේ දරුවා ඔබට පවසා තිබෙනවාද / නැතිනම් ඔබ හඳුනාගෙන තිබෙනවාද?',
      textEn:
          'Has your child told you, or have you noticed, that their eyes feel discomfort when looking at a white paper or whiteboard?',
    ),
  ];

  static const List<ComprehensiveQuestion> writingAssessment = [
    ComprehensiveQuestion(
      textSi:
          'ලිවීමේදී වචන නිවැරදි අක්ෂර වින්‍යාස භාවිතා කිරීමෙන් ලිවීමට දරුවා අපහසුතාවයක් පෙන්වනවාද?',
      textEn:
          'Does the child show difficulty in spelling words correctly when writing?',
    ),
    ComprehensiveQuestion(
      textSi: 'සමාන වචන එකිනෙක පටලවා ගැනීමක් හෝ පටලවා ලිවීමක් සිදුවෙනවාද?',
      textEn: 'Does the child mix up similar words or write them confusingly?',
    ),
    ComprehensiveQuestion(
      textSi:
          'ලියන විට විශේෂ අනවශ්‍ය පීඩනයක් පෙන්වීම හෝ වචන අත්හැර ලිවීමක් සිදුවෙනවාද?',
      textEn:
          'Does the child show unnecessary pressure when writing or skip words?',
    ),
    ComprehensiveQuestion(
      textSi:
          'දරුවාගේ අත් අකුරු පැහැදිලි නැති බව හෝ ලිවීමේ වේගය මන්දගාමී බව ඔබට පෙනෙනවාද?',
      textEn:
          "Do you notice that the child's handwriting is unclear or their writing speed is slow?",
    ),
    ComprehensiveQuestion(
      textSi:
          'කතා කිරීමේ හැකියාවට සාපේක්ෂව ලිවීමේ හැකියාව අඩු බව දැනී තිබෙනවාද?',
      textEn:
          'Have you felt that their writing ability is lower compared to their speaking ability?',
    ),
    ComprehensiveQuestion(
      textSi:
          'කතා කිරීමේදී තම අදහස් හොඳින් ප්‍රකාශ කළද එම අදහසම ලිවීමේදී දරුවා අපහසුතාවයකට පත්වෙන බව පෙනෙනවාද?',
      textEn:
          'Even if they express their thoughts well while speaking, does it seem they face difficulty expressing the same thoughts when writing?',
    ),
  ];

  static const List<ComprehensiveQuestion> otherAssessment = [
    ComprehensiveQuestion(
      textSi: 'කුඩා කාලයේදී කථන හෝ භාෂා සංවර්ධනයේ ප්‍රමාදයක් තිබුණාද?',
      textEn:
          'Was there a delay in speech or language development during childhood?',
    ),
    ComprehensiveQuestion(
      textSi:
          'කුඩා කාලයේ මැද කනේ ආසාදනය (Glue Ear / Otitis Media) ඇති වී තිබුණාද?',
      textEn:
          'Did they have middle ear infections (Glue Ear / Otitis Media) during childhood?',
    ),
    ComprehensiveQuestion(
      textSi: 'ඇදුම, එක්සීමා වැනි ප්‍රතිශක්තිකරණ පද්ධතියට සම්බන්ධ රෝග තිබුණාද?',
      textEn:
          'Did they have immune system-related conditions like asthma or eczema?',
    ),
    ComprehensiveQuestion(
      textSi:
          'හොඳින් කතා කළද සමහර අදහස් පිළිවෙලකට ප්‍රකාශ කිරීමට ඔබේ දරුවාට අපහසුද?',
      textEn:
          'Even though they speak well, is it difficult for your child to express some ideas in an organized manner?',
    ),
    ComprehensiveQuestion(
      textSi:
          'කතා කිරීමට අවශ්‍ය වචනය මතකයට ගන්නට ප්‍රමාදයක් හෝ වචන වැරදි ලෙස උච්චාරණය කිරීම සිදුවෙනවාද?',
      textEn:
          'Is there a delay in recalling the right word to speak, or do they pronounce words incorrectly?',
    ),
    ComprehensiveQuestion(
      textSi:
          'ප්‍රශ්නයක් ඇසූ විට, එය තේරුම්ගෙන පිළිතුරු දීමට සාමාන්‍යයට වඩා වැඩි කාලයක් ගන්නවද?',
      textEn:
          'When asked a question, do they take more time than usual to understand and answer?',
    ),
    ComprehensiveQuestion(
      textSi: 'දරුවාගේ මතක ශක්තියේ මදි බවක් දැක තිබෙනවාද? (ඉක්මනින් අමතක වීම)',
      textEn:
          'Have you noticed a lack of memory in the child? (Forgetting quickly)',
    ),
    ComprehensiveQuestion(
      textSi:
          'ගණිත ගණනය කිරීම්, සංඛ්‍යා පිටපත් කිරීම හෝ ගුණන වගු මතක තබා ගැනීමේ අපහසුතා තිබෙනවාද?',
      textEn:
          'Are there difficulties with mathematical calculations, copying numbers, or remembering multiplication tables?',
    ),
    ComprehensiveQuestion(
      textSi:
          'ADHD හෝ ඩිස්ලෙක්සියා වැනි තත්වයන් සමඟ සම්බන්ධතාවයක් (මුල් ලක්ෂණ) දරුවාගේ හැසිරීම් මත හඳුනාගෙන තිබෙනවාද?',
      textEn:
          "Have you recognized any connection (early signs) with conditions like ADHD or Dyslexia in the child's behavior?",
    ),
    ComprehensiveQuestion(
      textSi:
          'දරුවාට අපහසු තත්ත්වයකට මුහුණ දීමට සිදුවුවහොත් අධික කනස්සල්ලක් හෝ භීතියක් දරුවා තුළින් පෙන්වනවද?',
      textEn:
          'Does the child show excessive anxiety or fear if they have to face a difficult situation?',
    ),
    ComprehensiveQuestion(
      textSi:
          'කාලය කළමනාකරණය, පිළිවෙළට වැඩ කිරීම පිළිබඳ අපහසුතා ඔබ දැක තිබෙනවාද?',
      textEn:
          'Have you noticed difficulties regarding time management and working systematically?',
    ),
    ComprehensiveQuestion(
      textSi:
          'සාමාන්‍ය බුද්ධිමය හැකියාව තිබුණද විශේෂයෙන් කියවීම හා ලිවීම සම්බන්ධ බලාපොරොත්තු වූ මට්ටමට (පාසැල් කටයුතු හැසිරවීම) නොපැමිණෙන බව පෙනෙනවාද?',
      textEn:
          'Despite having normal intellectual ability, does it seem that they do not reach the expected level (handling school work) especially regarding reading and writing?',
    ),
  ];

  static List<ComprehensiveQuestion> getQuestionsByCategory(String category) {
    switch (category) {
      case 'basic':
        return basicAssessment;
      case 'reading':
        return readingAssessment;
      case 'writing':
        return writingAssessment;
      case 'other':
        return otherAssessment;
      default:
        return [];
    }
  }

  static String getCategoryTitle(String category) {
    switch (category) {
      case 'basic':
        return LocalizationService.instance.t('cat_basic');
      case 'reading':
        return LocalizationService.instance.t('cat_reading');
      case 'writing':
        return LocalizationService.instance.t('cat_writing');
      case 'other':
        return LocalizationService.instance.t('cat_other');
      default:
        return '';
    }
  }
}
