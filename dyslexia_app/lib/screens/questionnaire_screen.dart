import 'package:flutter/material.dart';

import '../utils/questionnaire_db.dart';

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _respondentNameController = TextEditingController();
  final TextEditingController _studentNameController = TextEditingController();
  final TextEditingController _studentAgeController = TextEditingController();
  final TextEditingController _studentGradeController = TextEditingController();

  String _respondentRole = 'දෙමාපිය';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['studentName'] != null) {
        _studentNameController.text = args['studentName'] as String;
        if (args['studentAge'] != null) {
          _studentAgeController.text = args['studentAge'] as String;
        }
        if (args['studentGrade'] != null) {
          _studentGradeController.text = args['studentGrade'] as String;
        }
      }
    });
  }

  // Part One Scores
  final Map<int, int> _partOneScores = {};
  
  final List<Map<String, dynamic>> _partOneQuestions = [
    {'q': 'වම සහ දකුණ වෙන්කර හඳුනා ගැනීමට අපහසු ද?', 'weight': 10},
    {'q': 'කියවීමේදී ඉක්මනින් තෙහෙට්ටුව දැනෙනවා ද?', 'weight': 10},
    {'q': 'කියවද්දී සිත වෙනත් දෙයක් වෙත යාම නිතර සිදුවේද?', 'weight': 10},
    {'q': 'කියවීමේදී වැරදි බොහෝවිට සිදුවේද?', 'weight': 20},
    {'q': 'අවධානය රඳවා ගැනීමට අපහසු ද?', 'weight': 20},
    {'q': 'නම් මතක තබා ගැනීමට අපහසු ද?', 'weight': 20},
    {'q': 'කතා කරන විට වචන නිවැරදිව උච්චාරණයට අපහසු ද?', 'weight': 10},
    {'q': 'ඔබ දන්නා කෙටි වචනවල අක්ෂර වින්යාසය අමතක වනවා ද?', 'weight': 20},
    {'q': 'පෙර ලියවී නොදුටු වචනවල අක්ෂර වින්යාසය අපහසු ද?', 'weight': 30},
    {'q': 'හුරු නැති වචන කියවීමට අපහසු ද?', 'weight': 30},
    {'q': 'ලියන්න බැරි නමුත් භාවිතා කරන විශාල වචන තේරුම් ගන්නවා ද?', 'weight': 20},
    {'q': 'කියවිය නොහැකි වචනවලදී නවතිනවා ද?', 'weight': 10},
    {'q': 'කියවීමේදී ඇස් සම්බන්ධීකරණය අඩු වගේ දැනෙනවා ද?', 'weight': 10},
    {'q': 'කියවීමේදී වචන හලනවා/අඳුරු/අවධානයට ගන්න අපහසු වගේ පෙනේද?', 'weight': 30},
  ];

  // Part Two answers (boolean) - Reading Behaviors
  final Map<int, bool?> _partTwoAnswers = {};
  
  final List<String> _partTwoQuestions = [
'දරුවා කියවීම සම්බන්ධ ක්‍රියාකාරකම්වලින් වැළකී සිටීමට උත්සාහ කරනවාද?',
'දරුවා තම පන්තියේ අනෙකුත් දරුවන්ට වඩා මන්දගාමීව කියවනවාද?',
'දරුවා කියවීමේදී වචන මඟහැර යනවාද?',
'දරුවා කියවීමේදී තමන් කියවමින් සිටින ස්ථානය අහිමි කරගන්නවාද?',
'දරුවා වචනය සම්පූර්ණයෙන් කියවීම වෙනුවට අනුමාන කරමින් කියවීමට උත්සාහ කරනවාද?',
'දරුවා නව හෝ නොහුරු වචන කියවීමට අපහසුතාවයක් දක්වනවාද?',
'දරුවා වාක්‍යයක් තේරුම් ගැනීම සඳහා නැවත නැවත කියවීමට අවශ්‍ය වනවාද?',
'දරුවා ටික වේලාවක් කියවීමෙන් පසු ඉක්මනින් වෙහෙසට පත්වනවාද?'
  ];

  // Part Three answers (boolean) - Academic Classroom Observation
  final Map<int, bool?> _partThreeAnswers = {};
  
  final List<String> _partThreeQuestions = [
    'ලිඛිතව ලබාදෙන තොරතුරු වලට වඩා කථනය මඟින් ලබාදෙන තොරතුරු දරුවාට වඩා හොඳින් අවබෝධ කරගත හැකිද?',
'දරුවා කථන ක්‍රියාකාරකම්වල හොඳින් සහභාගී වන නමුත් ලිඛිත කාර්යයන්හි අපහසුතා පෙන්වනවාද?',
'කියවීම සම්බන්ධ කාර්යයන් සම්පූර්ණ කිරීමට දරුවා අනෙකුත් දරුවන්ට වඩා වැඩි කාලයක් ගන්නවාද?',
'දරුවා ශබ්ද නගා කියවීමෙන් වැළකී සිටීමට උත්සාහ කරනවාද?',
'කියවීම හෝ ලිවීම සම්බන්ධ අධ්‍යයන ක්‍රියාකාරකම්වලදී දරුවා කලකිරීම, ආතතිය හෝ අසහනය පෙන්වනවාද?',
  ];

  int get totalScore {
    int score = 0;
    _partOneScores.forEach((key, value) {
      if (value == 1) { // 1 means Yes
        score += _partOneQuestions[key]['weight'] as int;
      }
    });
    return score;
  }

  String get riskLevel {
    int score = totalScore;
    if (score == 0) return 'ඩිස්ලෙක්සියා අවදානම අඩුය';
    if (score <= 75) return 'ඩිස්ලෙක්සියා මධ්යම අවදානමක් ඇත';
    if (score <= 150) return 'ඩිස්ලෙක්සියා ඉහළ අවදානමක් ඇත (වෘත්තීය පරීක්ෂණය නිර්දේශිතයි)';
    return 'ඩිස්ලෙක්සියා ඉතා ඉහළ අවදානමක් ඇත (වෛද්ය/මනෝවෛද්ය තක්සේරුව අවශ්යයි)';
  }

  int get selectedPartTwoCount {
    int count = 0;
    _partTwoAnswers.forEach((_, value) {
      if (value ?? false) {
        count++;
      }
    });
    return count;
  }

  int get selectedPartThreeCount {
    int count = 0;
    _partThreeAnswers.forEach((_, value) {
      if (value ?? false) {
        count++;
      }
    });
    return count;
  }

  @override
  void dispose() {
    _respondentNameController.dispose();
    _studentNameController.dispose();
    _studentAgeController.dispose();
    _studentGradeController.dispose();
    super.dispose();
  }

  Future<void> _saveSubmission() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_partOneScores.length != _partOneQuestions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('පළමු කොටසේ සියලු ප්රශ්න සඳහා පිළිතුරු දෙන්න.')),
      );
      return;
    }

    if (_partTwoAnswers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('දෙවන කොටසේ සියලු ප්රශ්න සඳහා පිළිතුරු දෙන්න.')),
      );
      return;
    }

    if (_partThreeAnswers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('තෙවන කොටසේ සියලු ප්රශ්න සඳහා පිළිතුරු දෙන්න.')),
      );
      return;
    }

    final studentAge = int.tryParse(_studentAgeController.text.trim());
    if (studentAge == null || studentAge <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('වලංගු වයසක් ඇතුළත් කරන්න.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await QuestionnaireDb.instance.insertSubmission(
        respondentRole: _respondentRole,
        respondentName: _respondentNameController.text.trim(),
        studentName: _studentNameController.text.trim(),
        studentAge: studentAge,
        studentGrade: _studentGradeController.text.trim(),
        partOneScore: totalScore,
        riskLevel: riskLevel,
        partTwoCount: selectedPartTwoCount,
        partThreeCount: selectedPartThreeCount,
        partOneAnswers: _partOneScores,
        partTwoAnswers: _partTwoAnswers,
        partThreeAnswers: _partThreeAnswers,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ප්රශ්නාවලි දත්ත සාර්ථකව සුරකිණි.')),
      );

      // Compute tier from score: Tier 1 = low, Tier 2 = medium, Tier 3 = high
      String tier;
      if (totalScore == 0) {
        tier = 'Tier 1';
      } else if (totalScore <= 75) {
        tier = 'Tier 2';
      } else {
        tier = 'Tier 3';
      }

      Navigator.pushNamed(context, '/student_preferences', arguments: {
        'studentName': _studentNameController.text.trim(),
        'studentAge': _studentAgeController.text.trim(),
        'studentGrade': _studentGradeController.text.trim(),
        'totalScore': totalScore,
        'tier': tier,
        'isNewStudent': true,
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('දත්ත සුරැකීමේ දෝෂයක් ඇතිවිය: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ඩිස්ලෙක්සියා මුල් පරීක්ෂාව'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'ප්රගති වාර්තා',
            onPressed: () => Navigator.pushNamed(context, '/questionnaire_reports'),
            icon: const Icon(Icons.analytics_outlined),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionHeader('ගුරු/දෙමාපිය තොරතුරු'),
            DropdownButtonFormField<String>(
              value: _respondentRole,
              decoration: const InputDecoration(
                labelText: 'පුරවන්නාගේ භූමිකාව',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'දෙමාපිය', child: Text('දෙමාපිය')),
                DropdownMenuItem(value: 'ගුරු', child: Text('ගුරු')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _respondentRole = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _respondentNameController,
              decoration: const InputDecoration(
                labelText: 'පුරවන්නාගේ නම',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'නම ඇතුළත් කරන්න.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _studentNameController,
              decoration: const InputDecoration(
                labelText: 'ශිෂ්යයාගේ නම',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'ශිෂ්යයාගේ නම ඇතුළත් කරන්න.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _studentAgeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ශිෂ්යයාගේ වයස',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'වයස ඇතුළත් කරන්න.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _studentGradeController,
              decoration: const InputDecoration(
                labelText: 'ශිෂ්යයාගේ ශ්රේණිය',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'ශ්රේණිය ඇතුළත් කරන්න.';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('කොටස 1: ඩිස්ලෙක්සියා මුල් පරීක්ෂාව'),
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: Text(
                'සෑම ප්රශ්නයකටම ඔව් හෝ නැහැ ලෙස පිළිතුරු දෙන්න. ලකුණු ස්වයංක්රීයව ගණනය වේ.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ),
            ...List.generate(_partOneQuestions.length, (index) {
              return _buildPartOneQuestion(index, _partOneQuestions[index]);
            }),
            const Divider(height: 32, thickness: 2),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'මුළු ලකුණු: $totalScore',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ඇඟවීම: $riskLevel',
                    style: const TextStyle(fontSize: 16, color: Colors.teal),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('කොටස 2: කියවීමේ හැසිරීම්'),
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: Text(
                'ශිෂ්යයාගේ කියවීමේ හැසිරීම් පිළිබඳ කථා කරන්න.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ),
            ...List.generate(_partTwoQuestions.length, (index) {
              return _buildPartTwoQuestion(index, _partTwoQuestions[index]);
            }),
            const SizedBox(height: 32),
            _buildSectionHeader('කොටස 3: පන්තිකාමර අධ්‍යයන නිරීක්ෂණ'),
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: Text(
                'පාසල් පරිසරයේ ශිෂ්යයාගේ පැවැත්ම නිරීක්ෂණ කරන්න.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ),
            ...List.generate(_partThreeQuestions.length, (index) {
              return _buildPartThreeQuestion(index, _partThreeQuestions[index]);
            }),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveSubmission,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('සුරකින්න සහ වාර්තා බලන්න', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/questionnaire_reports'),
              child: const Text('ප්රගති වාර්තා පමණක් බලන්න'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.teal,
        ),
      ),
    );
  }

  Widget _buildPartOneQuestion(int index, Map<String, dynamic> q) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Card(
        elevation: 1,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${index + 1}. ${q['q']} [${q['weight']}]',
                style: const TextStyle(fontSize: 16),
              ),
              Row(
                children: [
                  Radio<int>(
                    value: 1,
                    groupValue: _partOneScores[index],
                    onChanged: (val) => setState(() => _partOneScores[index] = val!),
                  ),
                  const Text('ඔව්'),
                  const SizedBox(width: 20),
                  Radio<int>(
                    value: 0,
                    groupValue: _partOneScores[index],
                    onChanged: (val) => setState(() => _partOneScores[index] = val!),
                  ),
                  const Text('නැහැ'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartTwoQuestion(int index, String q) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(q, style: const TextStyle(fontSize: 16)),
          ),
          Checkbox(
            value: _partTwoAnswers[index] ?? false,
            onChanged: (val) => setState(() => _partTwoAnswers[index] = val),
          ),
        ],
      ),
    );
  }

  Widget _buildPartThreeQuestion(int index, String q) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(q, style: const TextStyle(fontSize: 16)),
          ),
          Checkbox(
            value: _partThreeAnswers[index] ?? false,
            onChanged: (val) => setState(() => _partThreeAnswers[index] = val),
          ),
        ],
      ),
    );
  }
}
