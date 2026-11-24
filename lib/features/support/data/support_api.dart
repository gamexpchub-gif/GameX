import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api.dart';
import '../../auth/providers/auth_provider.dart';

DateTime _at(Object? v) =>
    DateTime.tryParse(v as String? ?? '')?.toLocal() ?? DateTime.now();

class HelpArticle {
  HelpArticle(Map<String, dynamic> j)
    : id = j['id'] as String,
      topic = j['topic'] as String? ?? 'other',
      title = j['title'] as String? ?? '',
      body = j['body'] as String? ?? '';
  final String id;
  final String topic;
  final String title;
  final String body;
}

class HelpTopic {
  HelpTopic(Map<String, dynamic> j)
    : id = j['id'] as String,
      title = j['title'] as String? ?? '';
  final String id;
  final String title;
}

class SupportHome {
  SupportHome(Map<String, dynamic> j)
    : topics = [
        for (final t in (j['topics'] as List? ?? const []))
          HelpTopic(t as Map<String, dynamic>),
      ],
      articles = [
        for (final a in (j['articles'] as List? ?? const []))
          HelpArticle(a as Map<String, dynamic>),
      ],
      categories = (j['categories'] as List? ?? const []).cast<String>(),
      phone = (j['contact'] as Map?)?['phone'] as String? ?? '',
      email = (j['contact'] as Map?)?['email'] as String? ?? '',
      hours = (j['contact'] as Map?)?['hours'] as String? ?? '',
      agentsOnline = (j['contact'] as Map?)?['agentsOnline'] as bool? ?? false,
      ai = j['ai'] as bool? ?? false,
      openTickets = (j['openTickets'] as num?)?.toInt() ?? 0,
      unread = (j['unread'] as num?)?.toInt() ?? 0;
  final List<HelpTopic> topics;
  final List<HelpArticle> articles;
  final List<String> categories;
  final String phone;
  final String email;
  final String hours;
  final bool agentsOnline;
  final bool ai;
  final int openTickets;
  final int unread;
}

class SupportMessage {
  SupportMessage(Map<String, dynamic> j)
    : id = j['id'] as String? ?? '',
      from = j['from'] as String? ?? 'system',
      text = j['text'] as String? ?? '',
      author = j['author'] as String?,
      at = _at(j['at']),
      photos = (j['photos'] as List? ?? const []).cast<String>(),
      suggestions = (j['suggestions'] as List? ?? const []).cast<String>();
  final String id;

  /// customer, ai, agent, system.
  final String from;
  final String text;
  final String? author;
  final DateTime at;
  final List<String> photos;
  final List<String> suggestions;

  bool get mine => from == 'customer';
}

class Ticket {
  Ticket(Map<String, dynamic> j)
    : id = j['id'] as String,
      subject = j['subject'] as String? ?? '',
      category = j['category'] as String? ?? 'Other',
      orderId = j['orderId'] as String?,
      orderItem = j['orderItem'] as String?,
      priority = j['priority'] as String? ?? 'normal',
      status = j['status'] as String? ?? 'open',
      source = j['source'] as String? ?? 'app',
      assignee = j['assignee'] as String?,
      createdAt = _at(j['createdAt']),
      updatedAt = _at(j['updatedAt']),
      slaDueAt = _at(j['slaDueAt']),
      unread = j['unreadCustomer'] as bool? ?? false,
      rating = ((j['rating'] as Map?)?['stars'] as num?)?.toInt(),
      messages = [
        for (final m in (j['messages'] as List? ?? const []))
          SupportMessage(m as Map<String, dynamic>),
      ];
  final String id;
  final String subject;
  final String category;
  final String? orderId;
  final String? orderItem;
  final String priority;

  /// open, awaiting_customer, resolved, closed.
  final String status;
  final String source;
  final String? assignee;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime slaDueAt;
  final bool unread;
  final int? rating;
  final List<SupportMessage> messages;

  bool get isOpen => status == 'open' || status == 'awaiting_customer';
  String get statusLabel => switch (status) {
    'open' => 'Open',
    'awaiting_customer' => 'Replied',
    'resolved' => 'Resolved',
    _ => 'Closed',
  };
  SupportMessage? get lastMessage => messages.isEmpty
      ? null
      : messages.lastWhere(
          (m) => m.from != 'system',
          orElse: () => messages.last,
        );
}

class SupportChat {
  SupportChat(Map<String, dynamic> j)
    : id = j['id'] as String,
      mode = j['mode'] as String? ?? 'ai',
      ticketId = j['ticketId'] as String?,
      agent = j['agent'] as String?,
      agentsOnline = j['agentsOnline'] as bool? ?? false,
      ai = j['ai'] as bool? ?? false,
      messages = [
        for (final m in (j['messages'] as List? ?? const []))
          SupportMessage(m as Map<String, dynamic>),
      ];
  final String id;

  /// ai, waiting (for an agent), agent, closed.
  final String mode;
  final String? ticketId;
  final String? agent;
  final bool agentsOnline;
  final bool ai;
  final List<SupportMessage> messages;
}

class SupportApi {
  SupportApi(this._api);
  final Api _api;

  Future<SupportHome> home() async =>
      SupportHome(await _api.get('/support/home') as Map<String, dynamic>);

  Future<List<Ticket>> tickets() async => [
    for (final t in await _api.get('/support/tickets') as List)
      Ticket(t as Map<String, dynamic>),
  ];

  Future<Ticket> ticket(String id) async =>
      Ticket(await _api.get('/support/tickets/$id') as Map<String, dynamic>);

  Future<Ticket> createTicket({
    required String category,
    required String subject,
    required String text,
    String? orderId,
    List<String> photos = const [],
  }) async {
    final uploaded = [for (final p in photos) await _api.upload(p)];
    return Ticket(
      await _api.post('/support/tickets', {
        'category': category,
        'subject': subject,
        'text': text,
        'orderId': ?orderId,
        'photos': uploaded,
      })
          as Map<String, dynamic>,
    );
  }

  Future<Ticket> reply(String id, String text, {List<String> photos = const []}) async {
    final uploaded = [for (final p in photos) await _api.upload(p)];
    return Ticket(
      await _api.post('/support/tickets/$id/messages', {
        'text': text,
        'photos': uploaded,
      })
          as Map<String, dynamic>,
    );
  }

  Future<Ticket> close(String id, {int? rating}) async => Ticket(
    await _api.post('/support/tickets/$id/close', {'rating': ?rating})
        as Map<String, dynamic>,
  );

  SupportChat? _chat(Object? j) =>
      j == null ? null : SupportChat(j as Map<String, dynamic>);

  Future<SupportChat?> chat() async => _chat(await _api.get('/support/chat'));
  Future<SupportChat> startChat() async =>
      _chat(await _api.post('/support/chat/start'))!;
  Future<SupportChat> send(String text) async =>
      _chat(await _api.post('/support/chat/messages', {'text': text}))!;
  Future<SupportChat> askAgent() async =>
      _chat(await _api.post('/support/chat/agent'))!;
  Future<SupportChat?> endChat({int? rating}) async =>
      _chat(await _api.post('/support/chat/end', {'rating': ?rating}));
}

final supportApiProvider = Provider<SupportApi>(
  (ref) => SupportApi(ref.watch(apiProvider)),
);

final supportHomeProvider = FutureProvider.autoDispose<SupportHome>((ref) {
  ref.watch(authProvider);
  return ref.watch(supportApiProvider).home();
});

final myTicketsProvider = FutureProvider.autoDispose<List<Ticket>>((ref) {
  if (ref.watch(authProvider) == null) return const [];
  return ref.watch(supportApiProvider).tickets();
});
