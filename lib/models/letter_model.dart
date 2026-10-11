import 'dart:math';

enum MakhrajGroup { cevf, halk, lisan, sefeteyn }

extension MakhrajGroupInfo on MakhrajGroup {
  String get title {
    return switch (this) {
      MakhrajGroup.cevf => 'Ağız boşluğu (Cevf)',
      MakhrajGroup.halk => 'Boğaz (Halk)',
      MakhrajGroup.lisan => 'Dil (Lisan)',
      MakhrajGroup.sefeteyn => 'Dudaklar (Şefeteyn)',
    };
  }
}

class LetterModel {
  const LetterModel({
    required this.order,
    required this.arabic,
    required this.name,
    required this.group,
    required this.makhraj,
    required this.tip,
    required this.audioAsset,
    required this.accepts,
    required this.similar,
  });

  final int order;
  final String arabic;
  final String name;
  final MakhrajGroup group;
  final String makhraj;
  final String tip;
  final String audioAsset;
  final List<String> accepts;
  final List<String> similar;

  List<String> buildOptions(Random random) {
    final List<String> options = <String>[arabic, ...similar.take(3)];
    options.shuffle(random);
    return options;
  }

  static String normalizeArabic(String input) {
    final StringBuffer buffer = StringBuffer();
    for (final int rune in input.runes) {
      if ((rune >= 0x064B && rune <= 0x065F) || rune == 0x0670 || rune == 0x0640) {
        continue;
      }
      switch (rune) {
        case 0x0623:
        case 0x0625:
        case 0x0622:
        case 0x0671:
          buffer.writeCharCode(0x0627);
        case 0x0649:
        case 0x06CC:
          buffer.writeCharCode(0x064A);
        case 0x0629:
          buffer.writeCharCode(0x0647);
        case 0x06A9:
          buffer.writeCharCode(0x0643);
        default:
          buffer.writeCharCode(rune);
      }
    }
    return buffer.toString().trim();
  }

  static int _distance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    List<int> previous = List<int>.generate(b.length + 1, (int i) => i);
    for (int i = 1; i <= a.length; i++) {
      final List<int> current = List<int>.filled(b.length + 1, 0);
      current[0] = i;
      for (int j = 1; j <= b.length; j++) {
        final int cost = a[i - 1] == b[j - 1] ? 0 : 1;
        current[j] = min(min(current[j - 1] + 1, previous[j] + 1), previous[j - 1] + cost);
      }
      previous = current;
    }
    return previous[b.length];
  }

  bool matchesSpeech(String heard) {
    final String cleaned = normalizeArabic(heard);
    if (cleaned.isEmpty) return false;
    final Set<String> targets = <String>{
      normalizeArabic(arabic),
      ...accepts.map(normalizeArabic),
    };
    final List<String> words = cleaned.split(RegExp(r'\s+'));
    for (final String word in words) {
      if (targets.contains(word)) return true;
      if (word.length >= 3) {
        for (final String target in targets) {
          if (target.length >= 3 && _distance(word, target) <= 1) return true;
        }
      }
    }
    return false;
  }
}

const List<LetterModel> kLetters = <LetterModel>[
  LetterModel(
    order: 1,
    arabic: 'ا',
    name: 'Elif',
    group: MakhrajGroup.cevf,
    makhraj: 'Elif, med harfidir; sesi ağız boşluğundan (cevf) çıkar. Hemze olarak okunduğunda ise boğazın en dibinden (aksâ-yı halk) çıkar.',
    tip: 'Ağzını rahatça aç ve sesi uzat: “aaa”. Hemze için sesi boğazının dibinden hafifçe başlat.',
    audioAsset: 'audio/harf_01.mp3',
    accepts: <String>['الف', 'ا', 'ء', 'ال'],
    similar: <String>['ل', 'ك', 'د'],
  ),
  LetterModel(
    order: 2,
    arabic: 'ب',
    name: 'Be',
    group: MakhrajGroup.sefeteyn,
    makhraj: 'İki dudağın nemli kısımları birbirine değerek çıkar.',
    tip: 'Dudaklarını kapat, sonra hızla aç: “be”. Sesi dudaklarında patlat.',
    audioAsset: 'audio/harf_02.mp3',
    accepts: <String>['باء', 'با', 'به', 'بي'],
    similar: <String>['ت', 'ث', 'ن'],
  ),
  LetterModel(
    order: 3,
    arabic: 'ت',
    name: 'Te',
    group: MakhrajGroup.lisan,
    makhraj: 'Dil ucu, üst ön iki dişin diş etine yakın köküne değerek çıkar. İnce okunur.',
    tip: 'Dilinin ucunu üst dişlerinin hemen arkasına hafifçe dokundur ve “te” de.',
    audioAsset: 'audio/harf_03.mp3',
    accepts: <String>['تاء', 'تا', 'ته', 'تي'],
    similar: <String>['ب', 'ث', 'ن'],
  ),
  LetterModel(
    order: 4,
    arabic: 'ث',
    name: 'Se',
    group: MakhrajGroup.lisan,
    makhraj: 'Dil ucu, üst ön dişlerin uçlarına değerek çıkar. Hava dişlerin arasından sızar.',
    tip: 'Dilini dişlerinin arasına hafifçe koy ve üfler gibi “se” de.',
    audioAsset: 'audio/harf_04.mp3',
    accepts: <String>['ثاء', 'ثا', 'ثه', 'ثي'],
    similar: <String>['ت', 'ب', 'ن'],
  ),
  LetterModel(
    order: 5,
    arabic: 'ج',
    name: 'Cim',
    group: MakhrajGroup.lisan,
    makhraj: 'Dilin orta kısmı, damağın tam karşısındaki bölgeye değerek çıkar.',
    tip: 'Dilinin ortasını damağına yaklaştır ve “ce” de.',
    audioAsset: 'audio/harf_05.mp3',
    accepts: <String>['جيم', 'جا', 'جي', 'جه'],
    similar: <String>['ح', 'خ', 'ع'],
  ),
  LetterModel(
    order: 6,
    arabic: 'ح',
    name: 'Ha',
    group: MakhrajGroup.halk,
    makhraj: 'Boğazın orta kısmından çıkar.',
    tip: 'Aynaya buğu yapar gibi, boğazından sürtünmeli ve ince bir “ha” çıkar.',
    audioAsset: 'audio/harf_06.mp3',
    accepts: <String>['حاء', 'حا', 'حي', 'حه'],
    similar: <String>['ج', 'خ', 'ع'],
  ),
  LetterModel(
    order: 7,
    arabic: 'خ',
    name: 'Hı',
    group: MakhrajGroup.halk,
    makhraj: 'Boğazın ağıza yakın kısmından (ednâ-yı halk) çıkar. Kalın okunur.',
    tip: 'Boğazının üst tarafında hafif bir gargara gibi “hı” sesi çıkar.',
    audioAsset: 'audio/harf_07.mp3',
    accepts: <String>['خاء', 'خا', 'خي', 'خه'],
    similar: <String>['ح', 'ج', 'غ'],
  ),
  LetterModel(
    order: 8,
    arabic: 'د',
    name: 'Dal',
    group: MakhrajGroup.lisan,
    makhraj: 'Dil ucu, üst ön dişlerin diş etine yakın köküne değerek çıkar. Te ile aynı mahreçtendir.',
    tip: 'Dilini Te’deki gibi yerleştir, ama sesi titreşimle çıkar: “de”.',
    audioAsset: 'audio/harf_08.mp3',
    accepts: <String>['دال', 'دا', 'دي', 'ده'],
    similar: <String>['ذ', 'ر', 'ز'],
  ),
  LetterModel(
    order: 9,
    arabic: 'ذ',
    name: 'Zel',
    group: MakhrajGroup.lisan,
    makhraj: 'Dil ucu, üst ön dişlerin uçlarına değerek çıkar. Se ile aynı mahreçtendir.',
    tip: 'Dil ucun dişlerinin arasında dururken sesi titreşimle çıkar: “zel”.',
    audioAsset: 'audio/harf_09.mp3',
    accepts: <String>['ذال', 'ذا', 'ذي', 'ذه'],
    similar: <String>['د', 'ز', 'ر'],
  ),
  LetterModel(
    order: 10,
    arabic: 'ر',
    name: 'Ra',
    group: MakhrajGroup.lisan,
    makhraj: 'Dil ucu ve sırtı, Nun’un çıktığı yerden biraz içeride damağa yaklaşarak çıkar.',
    tip: 'Dilini hafifçe titreterek “ra” de. Dil ucunu damağa yaklaştır.',
    audioAsset: 'audio/harf_10.mp3',
    accepts: <String>['راء', 'را', 'ري', 'ره'],
    similar: <String>['ز', 'د', 'و'],
  ),
  LetterModel(
    order: 11,
    arabic: 'ز',
    name: 'Ze',
    group: MakhrajGroup.lisan,
    makhraj: 'Dil ucu, alt ve üst ön dişlerin arasına yaklaşarak çıkar. Islık gibi bir sesi vardır.',
    tip: 'Arı vızıltısı gibi “zzz” sesini ince bir şekilde çıkar.',
    audioAsset: 'audio/harf_11.mp3',
    accepts: <String>['زاي', 'زا', 'زي', 'زه'],
    similar: <String>['ر', 'ذ', 'و'],
  ),
  LetterModel(
    order: 12,
    arabic: 'س',
    name: 'Sin',
    group: MakhrajGroup.lisan,
    makhraj: 'Ze ile aynı mahreçten, dil ucu ile alt ve üst ön dişlerin arasından çıkar. Islık gibi bir sesi vardır.',
    tip: 'Yılan sesi gibi “sss” de. Dil ucun alt dişlerinin arkasında kalsın.',
    audioAsset: 'audio/harf_12.mp3',
    accepts: <String>['سين', 'سا', 'سي', 'سه'],
    similar: <String>['ش', 'ص', 'ض'],
  ),
  LetterModel(
    order: 13,
    arabic: 'ش',
    name: 'Şın',
    group: MakhrajGroup.lisan,
    makhraj: 'Dilin orta kısmı, damağın ortasına yaklaşarak çıkar. Cim ile aynı mahreçtendir.',
    tip: 'Birini susturur gibi “şşş” de; ses dilin ortasından yayılsın.',
    audioAsset: 'audio/harf_13.mp3',
    accepts: <String>['شين', 'شا', 'شي', 'شه'],
    similar: <String>['س', 'ص', 'ض'],
  ),
  LetterModel(
    order: 14,
    arabic: 'ص',
    name: 'Sad',
    group: MakhrajGroup.lisan,
    makhraj: 'Sin ve Ze ile aynı mahreçten çıkar; ama kalın okunur.',
    tip: 'Sin’i söylemeye başla, sonra dilinin arkasını kaldırıp ağzını doldur: kalın “sa”.',
    audioAsset: 'audio/harf_14.mp3',
    accepts: <String>['صاد', 'صا', 'صي', 'صه'],
    similar: <String>['ض', 'س', 'ط'],
  ),
  LetterModel(
    order: 15,
    arabic: 'ض',
    name: 'Dad',
    group: MakhrajGroup.lisan,
    makhraj: 'Dilin yan kenarı, üst azı dişlerinin köküne değerek çıkar. Kalın okunur.',
    tip: 'Dilinin yanını üst azı dişlerine bastır ve dolgun, kalın bir “dad” de.',
    audioAsset: 'audio/harf_15.mp3',
    accepts: <String>['ضاد', 'ضا', 'ضي', 'ضه'],
    similar: <String>['ص', 'ظ', 'ط'],
  ),
  LetterModel(
    order: 16,
    arabic: 'ط',
    name: 'Tı',
    group: MakhrajGroup.lisan,
    makhraj: 'Dil ucu, üst ön dişlerin diş etine yakın köküne değerek çıkar. Te ile aynı mahreçtendir; kalın okunur.',
    tip: 'Te’yi söylerken dilinin arkasını yukarı kaldır ve sesi doldur: kalın “tı”.',
    audioAsset: 'audio/harf_16.mp3',
    accepts: <String>['طاء', 'طا', 'طي', 'طه'],
    similar: <String>['ظ', 'ص', 'ض'],
  ),
  LetterModel(
    order: 17,
    arabic: 'ظ',
    name: 'Zı',
    group: MakhrajGroup.lisan,
    makhraj: 'Dil ucu, üst ön dişlerin uçlarına değerek çıkar. Zel ile aynı mahreçtendir; kalın okunur.',
    tip: 'Zel gibi dil ucunu dişlerinin arasına koy, dilinin arkasını kaldırarak kalın “zı” de.',
    audioAsset: 'audio/harf_17.mp3',
    accepts: <String>['ظاء', 'ظا', 'ظي', 'ظه'],
    similar: <String>['ط', 'ض', 'ع'],
  ),
  LetterModel(
    order: 18,
    arabic: 'ع',
    name: 'Ayn',
    group: MakhrajGroup.halk,
    makhraj: 'Boğazın orta kısmından çıkar. Ha ile aynı mahreçtendir.',
    tip: 'Boğazını hafifçe daralt ve derinden titreşimli bir “ayn” sesi çıkar.',
    audioAsset: 'audio/harf_18.mp3',
    accepts: <String>['عين', 'عا', 'عي', 'عه'],
    similar: <String>['غ', 'ح', 'ف'],
  ),
  LetterModel(
    order: 19,
    arabic: 'غ',
    name: 'Gayn',
    group: MakhrajGroup.halk,
    makhraj: 'Boğazın ağıza yakın kısmından çıkar. Hı ile aynı mahreçtendir.',
    tip: 'Hı’daki gibi boğazından, ama titreşimli: gargara yaparken çıkan yumuşak “ğ”.',
    audioAsset: 'audio/harf_19.mp3',
    accepts: <String>['غين', 'غا', 'غي', 'غه'],
    similar: <String>['ع', 'خ', 'ف'],
  ),
  LetterModel(
    order: 20,
    arabic: 'ف',
    name: 'Fe',
    group: MakhrajGroup.sefeteyn,
    makhraj: 'Üst ön dişlerin uçları ile alt dudağın ıslak kısmının iç yüzü buluşarak çıkar.',
    tip: 'Üst dişlerini alt dudağına hafifçe değdir ve üfle: “fe”.',
    audioAsset: 'audio/harf_20.mp3',
    accepts: <String>['فاء', 'فا', 'في', 'فه'],
    similar: <String>['ق', 'غ', 'و'],
  ),
  LetterModel(
    order: 21,
    arabic: 'ق',
    name: 'Kaf',
    group: MakhrajGroup.lisan,
    makhraj: 'Dilin en arka kısmı (dil kökü), yumuşak damağa değerek çıkar. Kalın okunur.',
    tip: 'Dilini en arkadan damağa dokundur; derin ve kalın bir “ka” çıkar.',
    audioAsset: 'audio/harf_21.mp3',
    accepts: <String>['قاف', 'قا', 'قي', 'قه'],
    similar: <String>['ف', 'ن', 'ك'],
  ),
  LetterModel(
    order: 22,
    arabic: 'ك',
    name: 'Kef',
    group: MakhrajGroup.lisan,
    makhraj: 'Dilin arka kısmı, Kaf’ın mahrecinin biraz önünden damağa değerek çıkar. İnce okunur.',
    tip: 'Türkçedeki ince “k” gibi, ama net ve açık: “ke”.',
    audioAsset: 'audio/harf_22.mp3',
    accepts: <String>['كاف', 'كا', 'كي', 'كه'],
    similar: <String>['ل', 'ق', 'ه'],
  ),
  LetterModel(
    order: 23,
    arabic: 'ل',
    name: 'Lam',
    group: MakhrajGroup.lisan,
    makhraj: 'Dil ucunun yan kenarları, üst ön dişlerin köküne yakın bölgeye değerek çıkar.',
    tip: 'Dil ucunu üst dişlerinin arkasına koy ve “le” de.',
    audioAsset: 'audio/harf_23.mp3',
    accepts: <String>['لام', 'لا', 'لي', 'له'],
    similar: <String>['ك', 'ا', 'د'],
  ),
  LetterModel(
    order: 24,
    arabic: 'م',
    name: 'Mim',
    group: MakhrajGroup.sefeteyn,
    makhraj: 'İki dudağın birleşmesiyle çıkar. Ses genizden de destek alır.',
    tip: 'Dudaklarını kapat ve “mmm” diye vızılda.',
    audioAsset: 'audio/harf_24.mp3',
    accepts: <String>['ميم', 'ما', 'مي', 'مه'],
    similar: <String>['و', 'ه', 'ن'],
  ),
  LetterModel(
    order: 25,
    arabic: 'ن',
    name: 'Nun',
    group: MakhrajGroup.lisan,
    makhraj: 'Dil ucu, üst ön dişlerin diş etine değerek çıkar. Ses genizden de destek alır.',
    tip: 'Dilini üst dişlerinin arkasına yasla ve burnundan “nnn” diye ses ver.',
    audioAsset: 'audio/harf_25.mp3',
    accepts: <String>['نون', 'نا', 'ني', 'نه'],
    similar: <String>['ب', 'ت', 'ق'],
  ),
  LetterModel(
    order: 26,
    arabic: 'و',
    name: 'Vav',
    group: MakhrajGroup.sefeteyn,
    makhraj: 'İki dudak yuvarlak şekilde büzülerek çıkar. Med harfi olarak ağız boşluğundan da beslenir.',
    tip: 'Dudaklarını “u” der gibi büz ve “vav” de.',
    audioAsset: 'audio/harf_26.mp3',
    accepts: <String>['واو', 'وا', 'وي', 'وه'],
    similar: <String>['ر', 'م', 'ز'],
  ),
  LetterModel(
    order: 27,
    arabic: 'ه',
    name: 'He',
    group: MakhrajGroup.halk,
    makhraj: 'Boğazın en dibinden (aksâ-yı halk) çıkar. Hemze ile aynı mahreçtendir.',
    tip: 'Elini ağzının önüne tut ve sıcak nefes verir gibi “he” de.',
    audioAsset: 'audio/harf_27.mp3',
    accepts: <String>['هاء', 'ها', 'هي', 'هه'],
    similar: <String>['م', 'ح', 'و'],
  ),
  LetterModel(
    order: 28,
    arabic: 'ي',
    name: 'Ye',
    group: MakhrajGroup.lisan,
    makhraj: 'Dilin orta kısmı, damağın ortasına yaklaşarak çıkar. Cim ve Şın ile aynı mahreçtendir.',
    tip: 'Dilinin ortasını damağa kaldır ve akıcı bir “ye” de.',
    audioAsset: 'audio/harf_28.mp3',
    accepts: <String>['ياء', 'يا', 'يي', 'يه'],
    similar: <String>['ب', 'ن', 'ت'],
  ),
];
