// SAVE AS: lib/features/messaging/messaging.dart
// Single import for the entire messaging feature.
// Usage: import 'package:schooltrack_app/features/messaging/messaging.dart';

export 'domain/entities/message_entities.dart';
export 'domain/repositories/i_messaging_repository.dart';
export 'data/models/message_models.dart';
export 'data/datasources/messaging_remote_datasource.dart';
export 'data/repositories/messaging_repository.dart';
export 'presentation/providers/messaging_providers.dart';
export 'presentation/screens/inbox_screen.dart';
export 'presentation/screens/chat_screen.dart';
export 'presentation/screens/notifications_screen.dart';
export 'presentation/widgets/messaging_widgets.dart';
export 'presentation/widgets/messaging_overlay.dart';