
class QuranVerse {
  final String arabicText;
  final String surahName;
  final int ayahNumber;
  final int surahNumber;

  QuranVerse({
    required this.arabicText,
    required this.surahName,
    required this.ayahNumber,
    required this.surahNumber,
  });
}
class SurahModel {
  final String index;
  final String name;
  final Map<String, String> verses;
  final int count;
  final List<JuzModel> juz;

  SurahModel({
    required this.index,
    required this.name,
    required this.verses,
    required this.count,
    required this.juz,
  });

  factory SurahModel.fromJson(Map<String, dynamic> json) {
    return SurahModel(
      index: json['index'] ?? '',
      name: json['name'] ?? '',
      verses: Map<String, String>.from(json['verse'] ?? {}),
      count: json['count'] ?? 0,
      juz: (json['juz'] as List?)
          ?.map((e) => JuzModel.fromJson(e))
          .toList() ?? [],
    );
  }
}

class JuzModel {
  final String index;
  final Map<String, String> verse;

  JuzModel({
    required this.index,
    required this.verse,
  });

  factory JuzModel.fromJson(Map<String, dynamic> json) {
    return JuzModel(
      index: json['index'] ?? '',
      verse: Map<String, String>.from(json['verse'] ?? {}),
    );
  }
}