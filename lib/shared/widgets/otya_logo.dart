/// Canonical Otya brand components.
///
/// Product branding keeps the folded O mark from [otya_logo_v2.dart]. Next,
/// Otya's assistant, uses the separate blue/red/yellow three-ball identity from
/// [otya_ai_mark.dart]. Existing thinking call sites keep working through the
/// compatibility export below.
export 'otya_logo_v2.dart' hide OtyaThinkingMark;
export 'otya_ai_mark.dart' show OtyaAiMark, OtyaThinkingMark;
