import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/letter_model.dart';
import '../services/progress_service.dart';
import '../widgets/common_widgets.dart';

enum LessonStage { learn, recognize, speak }

enum AnswerState { idle, correct, wrong, failedOut }

class _GroupStyle {
  const _GroupStyle(this.icon, this.color, this.bg);

  final IconData icon;
  final Color color;
  final Color bg;
}

_GroupStyle _styleFor(MakhrajGroup group) {
  switch (group) {
    case MakhrajGroup.cevf:
      return const _GroupStyle(Icons.air_rounded, AppColors.purple, Color(0xFFF3E5FF));
    case MakhrajGroup.halk:
      return const _GroupStyle(Icons.record_voice_over_rounded, AppColors.red, AppColors.redBg);
    case MakhrajGroup.lisan:
      return const _GroupStyle(Icons.graphic_eq_rounded, AppColors.blue, AppColors.blueBg);
    case MakhrajGroup.sefeteyn:
      return const _GroupStyle(Icons.sentiment_satisfied_alt_rounded, AppColors.orange, AppColors.orangeBg);
  }
}

TextStyle _t(double size, {FontWeight weight = FontWeight.w700, Color color = AppColors.text, double? height}) {
  return TextStyle(fontSize: size, fontWeight: weight, color: color, height: height);
}

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, this.startIndex = 0});

  final int startIndex;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  static const int _maxAttempts = 3;
  static const List<String> _praises = <String>['Harika!', 'Mükemmel!', 'Maşallah!', 'Çok güzel!', 'Aferin!'];

  final ProgressService _progress = ProgressService.instance;
  final AudioPlayer _player = AudioPlayer();
  final SpeechToText _speech = SpeechToText();
  final ConfettiController _confetti = ConfettiController(duration: const Duration(milliseconds: 900));
  final Stopwatch _clock = Stopwatch();
  final Random _random = Random();

  late int _index;
  LessonStage _stage = LessonStage.learn;
  AnswerState _answer = AnswerState.idle;
  int _attemptsLeft = _maxAttempts;
  List<String> _options = <String>[];
  final Set<String> _wrongOptions = <String>{};
  String _praise = 'Harika!';
  String _notice = '';
  String _heard = '';
  bool _hadFail = false;
  int _letterXp = 0;

  bool _speechChecked = false;
  bool _speechReady = false;
  bool _micDenied = false;
  bool _listening = false;
  bool _resolvedThisTry = false;
  String? _localeId;

  LetterModel get _letter => kLetters[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex.clamp(0, kLetters.length - 1);
    _clock.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _enterStage(LessonStage.learn);
    });
  }

  @override
  void dispose() {
    _clock.stop();
    _progress.addSeconds(_clock.elapsed.inSeconds);
    _player.dispose();
    _speech.cancel();
    _confetti.dispose();
    super.dispose();
  }

  void _enterStage(LessonStage stage) {
    setState(() {
      _stage = stage;
      _answer = AnswerState.idle;
      _attemptsLeft = _maxAttempts;
      _wrongOptions.clear();
      _heard = '';
      _notice = '';
      _listening = false;
      _resolvedThisTry = false;
      if (stage == LessonStage.recognize) {
        _options = _letter.buildOptions(_random);
      }
    });
    if (stage == LessonStage.learn) {
      _play();
    }
  }

  Future<void> _play() async {
    final String asset = _letter.audioAsset;
    try {
      await rootBundle.load('assets/$asset');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notice = 'Ses dosyası bulunamadı: assets/$asset. Diyanet/Husary kıraat kaydını bu isimle assets/audio klasörüne ekleyin.';
      });
      return;
    }
    try {
      if (_listening) {
        await _speech.stop();
        if (mounted) setState(() => _listening = false);
      }
      await _player.stop();
      await _player.play(AssetSource(asset));
    } catch (_) {
      if (!mounted) return;
      setState(() => _notice = 'Ses şu anda çalınamadı. Lütfen tekrar dene.');
    }
  }

  void _onOptionTap(String option) {
    if (_answer != AnswerState.idle || _wrongOptions.contains(option)) return;
    if (option == _letter.arabic) {
      _markCorrect();
    } else {
      _wrongOptions.add(option);
      _registerWrong();
    }
  }

  void _markCorrect() {
    HapticFeedback.lightImpact();
    _confetti.play();
    _progress.addXp(10);
    setState(() {
      _answer = AnswerState.correct;
      _praise = _praises[_random.nextInt(_praises.length)];
      _letterXp += 10;
      _notice = '';
    });
    _play();
  }

  void _registerWrong() {
    HapticFeedback.mediumImpact();
    final int left = _attemptsLeft - 1;
    if (left <= 0) {
      _hadFail = true;
      _progress.addReview(_letter.order);
      setState(() {
        _attemptsLeft = 0;
        _answer = AnswerState.failedOut;
        _notice = '';
      });
      _play();
    } else {
      setState(() {
        _attemptsLeft = left;
        _answer = AnswerState.wrong;
        _notice = '';
      });
    }
  }

  void _retry() {
    setState(() {
      _answer = AnswerState.idle;
      _heard = '';
      _notice = '';
    });
  }

  void _continue() {
    if (_stage == LessonStage.recognize) {
      _enterStage(LessonStage.speak);
    } else {
      _finishLetter();
    }
  }

  void _skipSpeak() {
    _hadFail = true;
    _progress.addReview(_letter.order);
    _finishLetter();
  }

  Future<void> _prepareSpeech() async {
    final PermissionStatus status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
      if (!mounted) return;
      setState(() {
        _micDenied = true;
        _notice = 'Mikrofon izni verilmedi. İzin verirsen telaffuzunu birlikte kontrol edebiliriz; istersen bu adımı atlayabilirsin.';
      });
      return;
    }
    bool ok = false;
    try {
      ok = await _speech.initialize(onError: _onSpeechError, onStatus: _onSpeechStatus);
      if (ok) {
        final List<LocaleName> locales = await _speech.locales();
        String? found;
        for (final LocaleName locale in locales) {
          if (locale.localeId.toLowerCase().replaceAll('-', '_') == 'ar_sa') {
            found = locale.localeId;
            break;
          }
        }
        if (found == null) {
          for (final LocaleName locale in locales) {
            if (locale.localeId.toLowerCase().startsWith('ar')) {
              found = locale.localeId;
              break;
            }
          }
        }
        _localeId = found ?? 'ar_SA';
      }
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _speechChecked = true;
      _micDenied = false;
      _speechReady = ok;
      if (!ok) {
        _notice = 'Bu cihazda ses tanıma kullanılamıyor. Google ses tanıma ve Arapça dil paketinin yüklü olduğundan emin ol; istersen bu adımı atlayabilirsin.';
      } else {
        _notice = '';
      }
    });
  }

  Future<void> _toggleListen() async {
    if (_answer != AnswerState.idle) return;
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!_speechReady) {
      await _prepareSpeech();
      if (!_speechReady || !mounted) return;
    }
    await _player.stop();
    _resolvedThisTry = false;
    setState(() {
      _listening = true;
      _heard = '';
      _notice = '';
    });
    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        localeId: _localeId ?? 'ar_SA',
        listenFor: const Duration(seconds: 7),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        cancelOnError: true,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _notice = 'Dinleme başlatılamadı. Lütfen tekrar dene.';
      });
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted || _resolvedThisTry || _answer != AnswerState.idle) return;
    final String heard = result.recognizedWords;
    setState(() => _heard = heard);
    if (_letter.matchesSpeech(heard)) {
      _resolvedThisTry = true;
      _speech.stop();
      setState(() => _listening = false);
      _markCorrect();
    } else if (result.finalResult) {
      _resolvedThisTry = true;
      setState(() => _listening = false);
      if (heard.trim().isEmpty) {
        setState(() => _notice = 'Ses algılanamadı. Mikrofona biraz daha yakın konuşup tekrar dene. Deneme hakkın harcanmadı.');
      } else {
        _registerWrong();
      }
    }
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    if ((status == 'done' || status == 'notListening') && _listening) {
      setState(() => _listening = false);
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;
    final String message = error.errorMsg;
    setState(() {
      _listening = false;
      if (message.contains('no_match') || message.contains('speech_timeout')) {
        _notice = 'Ses anlaşılamadı. Tekrar dene; deneme hakkın harcanmadı.';
      } else if (message.contains('permission')) {
        _micDenied = true;
        _notice = 'Mikrofon izni gerekiyor.';
      } else {
        _notice = 'Mikrofon hatası: $message. Tekrar deneyebilir veya adımı atlayabilirsin.';
      }
    });
  }

  Future<void> _finishLetter() async {
    final int levelBefore = _progress.level;
    _letterXp += 10;
    await _progress.addXp(10);
    await _progress.completeLetter(_letter.order);
    if (!mounted) return;
    final bool levelUp = _progress.level > levelBefore;
    final bool isLast = _index >= kLetters.length - 1;
    final String title;
    final String message;
    if (isLast) {
      title = 'Elif-Bâ tamamlandı!';
      message = 'Maşallah! 28 harfi bitirdin. Sırada harekeler (üstün, esre, ötre) var.';
    } else if (_hadFail) {
      title = 'Güzel çaba!';
      message = '${_letter.name} harfini tamamladın. Bu harfi daha sonra birlikte tekrar edeceğiz.';
    } else {
      title = 'Harika iş!';
      message = '${_letter.name} harfini öğrendin.';
    }
    final int gained = _letterXp;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => _CelebrationDialog(
        title: title,
        message: message,
        xp: gained,
        levelUp: levelUp ? _progress.level : null,
      ),
    );
    if (!mounted) return;
    if (isLast) {
      Navigator.of(context).pop();
      return;
    }
    _hadFail = false;
    _letterXp = 0;
    setState(() => _index += 1);
    _enterStage(LessonStage.learn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _topBar(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: SingleChildScrollView(
                      key: ValueKey<String>('$_index-${_stage.name}'),
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                      child: _body(),
                    ),
                  ),
                ),
                _bottomArea(),
              ],
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                numberOfParticles: 24,
                gravity: 0.3,
                colors: const <Color>[
                  AppColors.green,
                  AppColors.blue,
                  AppColors.gold,
                  AppColors.orange,
                  AppColors.purple,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    final double fraction = ((_index + _stage.index / 3) / kLetters.length).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.grayDark, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 14,
                    backgroundColor: AppColors.gray,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AnimatedBuilder(
                animation: _progress,
                builder: (BuildContext context, Widget? child) {
                  return Row(
                    children: [
                      StatChip(
                        icon: Icons.local_fire_department_rounded,
                        color: AppColors.orange,
                        value: '${_progress.currentStreak}',
                      ),
                      const SizedBox(width: 10),
                      StatChip(
                        icon: Icons.bolt_rounded,
                        color: AppColors.goldDark,
                        value: '${_progress.xp}',
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 0, 0),
            child: AnimatedBuilder(
              animation: _progress,
              builder: (BuildContext context, Widget? child) {
                return Row(
                  children: [
                    Text('Seviye ${_progress.level}', style: _t(13, color: AppColors.blueDark, weight: FontWeight.w800)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _progress.levelFraction,
                          minHeight: 8,
                          backgroundColor: AppColors.blueBg,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.blue),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${_progress.xpInLevel}/${ProgressService.xpPerLevel} XP', style: _t(12, color: AppColors.textLight)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_stage) {
      case LessonStage.learn:
        return _learnBody();
      case LessonStage.recognize:
        return _recognizeBody();
      case LessonStage.speak:
        return _speakBody();
    }
  }

  Widget _noticeBox() {
    if (_notice.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.orangeBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.orange, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: AppColors.orangeDark, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(_notice, style: _t(13.5, weight: FontWeight.w600, color: AppColors.text, height: 1.35))),
        ],
      ),
    );
  }

  Widget _listenButton() {
    return Center(
      child: Button3D(
        label: 'DİNLE',
        icon: Icons.volume_up_rounded,
        color: AppColors.blue,
        shadowColor: AppColors.blueDark,
        expand: false,
        height: 46,
        fontSize: 15,
        onTap: _play,
      ),
    );
  }

  Widget _learnBody() {
    final LetterModel l = _letter;
    final _GroupStyle style = _styleFor(l.group);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Yeni harf: ${l.order} / ${kLetters.length}', textAlign: TextAlign.center, style: _t(14, color: AppColors.blueDark, weight: FontWeight.w800)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.gray, width: 2),
          ),
          child: Column(
            children: [
              Text(l.arabic, style: _t(120, height: 1.25)),
              Text(l.name, style: _t(30, color: AppColors.green, weight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _listenButton(),
        _noticeBox(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: style.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: style.color, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
                    child: Icon(style.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mahreç', style: _t(12, color: AppColors.textLight, weight: FontWeight.w700)),
                        Text(l.group.title, style: _t(17, weight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(l.makhraj, style: _t(15, weight: FontWeight.w600, height: 1.4)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.greenBg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_rounded, color: AppColors.greenDark, size: 24),
              const SizedBox(width: 10),
              Expanded(child: Text(l.tip, style: _t(14.5, weight: FontWeight.w600, height: 1.4, color: AppColors.greenDark))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _attemptsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Deneme hakkı', style: _t(13, color: AppColors.textLight, weight: FontWeight.w700)),
        const SizedBox(width: 10),
        for (int i = 0; i < _maxAttempts; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Icon(
              Icons.circle,
              size: 16,
              color: i < _attemptsLeft ? AppColors.blue : AppColors.gray,
            ),
          ),
        const SizedBox(width: 8),
        Text('Kalan: $_attemptsLeft', style: _t(13, color: AppColors.blueDark, weight: FontWeight.w800)),
      ],
    );
  }

  Widget _recognizeBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tanıma', textAlign: TextAlign.center, style: _t(14, color: AppColors.blueDark, weight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Hangisi “${_letter.name}” harfi?', textAlign: TextAlign.center, style: _t(26, weight: FontWeight.w900)),
        const SizedBox(height: 12),
        _listenButton(),
        const SizedBox(height: 14),
        _attemptsRow(),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.2,
          children: [for (final String option in _options) _optionCard(option)],
        ),
        _noticeBox(),
      ],
    );
  }

  Widget _optionCard(String option) {
    final bool isWrong = _wrongOptions.contains(option);
    final bool isRight = option == _letter.arabic &&
        (_answer == AnswerState.correct || _answer == AnswerState.failedOut);
    Color face = Colors.white;
    Color edge = AppColors.gray;
    Color fg = AppColors.text;
    if (isWrong) {
      face = AppColors.redBg;
      edge = AppColors.red;
      fg = AppColors.red;
    }
    if (isRight) {
      face = AppColors.greenBg;
      edge = AppColors.green;
      fg = AppColors.greenDark;
    }
    return Card3D(
      face: face,
      edge: edge,
      onTap: (_answer == AnswerState.idle && !isWrong) ? () => _onOptionTap(option) : null,
      child: Center(child: Text(option, style: _t(60, color: fg, height: 1.3))),
    );
  }

  Widget _speakBody() {
    final LetterModel l = _letter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Telaffuz', textAlign: TextAlign.center, style: _t(14, color: AppColors.blueDark, weight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Mikrofona dokun ve “${l.name}” harfini oku', textAlign: TextAlign.center, style: _t(24, weight: FontWeight.w900, height: 1.25)),
        const SizedBox(height: 10),
        Center(child: Text(l.arabic, style: _t(90, height: 1.2))),
        _listenButton(),
        const SizedBox(height: 14),
        _attemptsRow(),
        const SizedBox(height: 18),
        Center(
          child: AnimatedScale(
            scale: _listening ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 250),
            child: Card3D(
              width: 104,
              height: 104,
              radius: 52,
              face: _listening ? AppColors.red : AppColors.blue,
              edge: _listening ? AppColors.redDark : AppColors.blueDark,
              onTap: _answer == AnswerState.idle ? _toggleListen : null,
              child: Center(
                child: Icon(
                  _listening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _listening ? 'Dinliyorum… şimdi oku' : 'Basıp harfi oku',
          textAlign: TextAlign.center,
          style: _t(15, color: _listening ? AppColors.red : AppColors.textLight, weight: FontWeight.w800),
        ),
        if (_heard.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Duyduğum: $_heard', textAlign: TextAlign.center, style: _t(16, color: AppColors.textLight, weight: FontWeight.w700)),
        ],
        if (_micDenied) ...[
          const SizedBox(height: 12),
          Center(
            child: Button3D(
              label: 'MİKROFON İZNİ VER',
              icon: Icons.mic_rounded,
              color: AppColors.orange,
              shadowColor: AppColors.orangeDark,
              expand: false,
              height: 46,
              fontSize: 14,
              onTap: _prepareSpeech,
            ),
          ),
        ],
        _noticeBox(),
        const SizedBox(height: 10),
        Text('Mahreç ipucu: ${l.group.title}', textAlign: TextAlign.center, style: _t(13, color: AppColors.textLight, weight: FontWeight.w600)),
      ],
    );
  }

  Widget _bottomArea() {
    Widget child;
    if (_stage == LessonStage.learn) {
      child = Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
        child: Button3D(label: 'DEVAM', onTap: () => _enterStage(LessonStage.recognize)),
      );
    } else {
      switch (_answer) {
        case AnswerState.idle:
          child = _stage == LessonStage.speak
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                  child: Button3D(
                    label: 'ŞİMDİLİK ATLA',
                    color: Colors.white,
                    shadowColor: AppColors.gray,
                    textColor: AppColors.grayDark,
                    onTap: _skipSpeak,
                  ),
                )
              : const SizedBox(height: 18);
        case AnswerState.correct:
          child = _feedbackPanel(
            bg: AppColors.greenBg,
            accent: AppColors.greenDark,
            icon: Icons.check_circle_rounded,
            title: _praise,
            message: 'Doğru! Devam edelim.',
            xpPop: true,
            button: Button3D(label: 'DEVAM', onTap: _continue),
          );
        case AnswerState.wrong:
          child = _feedbackPanel(
            bg: AppColors.redBg,
            accent: AppColors.redDark,
            icon: Icons.refresh_rounded,
            title: 'Neredeyse! Bir daha deneyelim',
            message: 'Kalan deneme hakkın: $_attemptsLeft',
            xpPop: false,
            button: Button3D(
              label: 'TEKRAR DENE',
              color: AppColors.red,
              shadowColor: AppColors.redDark,
              onTap: _retry,
            ),
          );
        case AnswerState.failedOut:
          child = _feedbackPanel(
            bg: AppColors.blueBg,
            accent: AppColors.blueDark,
            icon: Icons.lightbulb_rounded,
            title: 'Sorun değil, birlikte öğrenelim',
            message: '${_letter.tip} Bu harfi daha sonra tekrar edeceğiz.',
            xpPop: false,
            button: Button3D(
              label: 'DEVAM',
              color: AppColors.blue,
              shadowColor: AppColors.blueDark,
              onTap: _continue,
            ),
            extra: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Button3D(
                label: 'DOĞRUSUNU DİNLE',
                icon: Icons.volume_up_rounded,
                color: Colors.white,
                shadowColor: AppColors.blue,
                textColor: AppColors.blueDark,
                height: 46,
                fontSize: 15,
                onTap: _play,
              ),
            ),
          );
      }
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (Widget widget, Animation<double> animation) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(animation),
          child: widget,
        );
      },
      child: KeyedSubtree(
        key: ValueKey<String>('${_stage.name}-${_answer.name}'),
        child: child,
      ),
    );
  }

  Widget _feedbackPanel({
    required Color bg,
    required Color accent,
    required IconData icon,
    required String title,
    required String message,
    required bool xpPop,
    required Widget button,
    Widget? extra,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _t(20, color: accent, weight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(message, style: _t(14.5, color: accent, weight: FontWeight.w600, height: 1.35)),
                  ],
                ),
              ),
              if (xpPop)
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (BuildContext context, double value, Widget? child) {
                    return Transform.scale(scale: value, child: child);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                        Text('+10 XP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (extra != null) extra,
          button,
        ],
      ),
    );
  }
}

class _CelebrationDialog extends StatefulWidget {
  const _CelebrationDialog({
    required this.title,
    required this.message,
    required this.xp,
    this.levelUp,
  });

  final String title;
  final String message;
  final int xp;
  final int? levelUp;

  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog> {
  final ConfettiController _controller = ConfettiController(duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (BuildContext context, double value, Widget? child) {
                    return Transform.scale(scale: value, child: child);
                  },
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                    child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 56),
                  ),
                ),
                const SizedBox(height: 16),
                Text(widget.title, textAlign: TextAlign.center, style: _t(26, weight: FontWeight.w900, color: AppColors.greenDark)),
                const SizedBox(height: 8),
                Text(widget.message, textAlign: TextAlign.center, style: _t(16, weight: FontWeight.w600, color: AppColors.textLight, height: 1.4)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.orangeBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded, color: AppColors.goldDark, size: 26),
                      const SizedBox(width: 4),
                      Text('+${widget.xp} XP', style: _t(22, weight: FontWeight.w900, color: AppColors.orangeDark)),
                    ],
                  ),
                ),
                if (widget.levelUp != null) ...[
                  const SizedBox(height: 12),
                  Text('Seviye atladın! Yeni seviye: ${widget.levelUp}', textAlign: TextAlign.center, style: _t(16, weight: FontWeight.w800, color: AppColors.blueDark)),
                ],
                const SizedBox(height: 20),
                Button3D(label: 'DEVAM', onTap: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          ConfettiWidget(
            confettiController: _controller,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 30,
            gravity: 0.25,
            colors: const <Color>[
              AppColors.green,
              AppColors.blue,
              AppColors.gold,
              AppColors.orange,
              AppColors.purple,
            ],
          ),
        ],
      ),
    );
  }
}
