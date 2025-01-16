import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/protobuf.dart';
import 'package:easy_localization/easy_localization.dart';

import '../ai_writer_block_component.dart';

const kdefaultReplacementType = AskAIReplacementType.markdown;

enum AskAIReplacementType {
  markdown,
  plainText,
}

enum SuggestionAction {
  accept,
  discard,
  close,
  tryAgain,
  rewrite,
  keep,
  insertBelow;

  String get i18n => "Accept";
}

enum AiWriterCommand {
  userQuestion,
  explain,
  // summarize,
  continueWriting,
  fixSpellingAndGrammar,
  improveWriting,
  makeShorter,
  makeLonger;

  String defaultPrompt(String input) => switch (this) {
        userQuestion => input,
        explain => "Explain this phrase in a concise manner:\n\n$input",
        // summarize => '$input\n\nTl;dr',
        continueWriting =>
          'Continue writing based on this existing text:\n\n$input',
        fixSpellingAndGrammar => 'Correct this to standard English:\n\n$input',
        improveWriting => 'Rewrite this in your own words:\n\n$input',
        makeShorter => 'Make this text shorter:\n\n$input',
        makeLonger => 'Make this text longer:\n\n$input',
      };

  String get i18n => switch (this) {
        userQuestion => LocaleKeys.document_plugins_smartEditSummarize.tr(),
        explain => LocaleKeys.document_plugins_smartEditFixSpelling.tr(),
        // summarize => LocaleKeys.document_plugins_smartEditSummarize.tr(),
        continueWriting => LocaleKeys.document_plugins_smartEditSummarize.tr(),
        fixSpellingAndGrammar =>
          LocaleKeys.document_plugins_smartEditFixSpelling.tr(),
        improveWriting =>
          LocaleKeys.document_plugins_smartEditImproveWriting.tr(),
        makeShorter => LocaleKeys.document_plugins_smartEditMakeLonger.tr(),
        makeLonger => LocaleKeys.document_plugins_smartEditMakeLonger.tr(),
      };

  CompletionTypePB toCompletionType() => switch (this) {
        userQuestion => CompletionTypePB.UserQuestion,
        explain => CompletionTypePB.ExplainSelected,
        // summarize => CompletionTypePB.Summarize,
        continueWriting => CompletionTypePB.ContinueWriting,
        fixSpellingAndGrammar => CompletionTypePB.SpellingAndGrammar,
        improveWriting => CompletionTypePB.ImproveWriting,
        makeShorter => CompletionTypePB.MakeShorter,
        makeLonger => CompletionTypePB.MakeLonger,
      };
}

enum ApplySuggestionFormatType {
  original({
    AiWriterBlockKeys.suggestion: AiWriterBlockKeys.suggestionOriginal,
  }),
  replace({
    AiWriterBlockKeys.suggestion: AiWriterBlockKeys.suggestionReplacement,
  }),
  clear({
    AiWriterBlockKeys.suggestion: null,
  });

  const ApplySuggestionFormatType(this.attributes);
  final Map<String, dynamic> attributes;
}
