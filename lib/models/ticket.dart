/// オンライン整理券モデル。
///
/// - スタッフ視点 (staffView): code を含む全情報 + position/eta
/// - 来場者視点 (userView): code なし、自分の券の状態 + 待ち行列情報
class TicketChatMsg {
  final String id;
  final String from; // 'user' | 'staff'
  final String kind; // 'chat' | 'notice'
  final String text;
  final int at; // epoch sec

  const TicketChatMsg({
    required this.id,
    required this.from,
    required this.kind,
    required this.text,
    required this.at,
  });

  factory TicketChatMsg.fromJson(Map<String, dynamic> json) => TicketChatMsg(
        id: (json['id'] as String?) ?? '',
        from: (json['from'] as String?) ?? 'staff',
        kind: (json['kind'] as String?) ?? 'chat',
        text: (json['text'] as String?) ?? '',
        at: (json['at'] as num?)?.toInt() ?? 0,
      );
}

class Ticket {
  final String id;
  final String code; // staff view only ('' for user view / paper)
  final String number; // 連番（1, 2, 3, ...）
  final String kind; // 'online' | 'paper'
  final String label;
  final String status; // waiting/called/playing/done/cancelled
  final int createdAt;
  final int calledAt;
  final int startedAt;
  final int finishedAt;
  final int cancelledAt;
  final String cancelReason; // 'user' | 'late' | 'staff' | ''
  final List<TicketChatMsg> chat;
  final int userUnread;
  final int staffUnread;
  final bool reviewPosted;
  final int reservedSlot; // 予約スロット開始（epoch sec、0=当日券）
  final int position; // 0-based queue position (-1 = not queued)
  final int etaSec;
  // user view extras
  final int gameSec;
  final int intervalSec;
  final int lateCancelSec;
  final bool reviewsEnabled;

  const Ticket({
    required this.id,
    required this.code,
    required this.number,
    required this.kind,
    required this.label,
    required this.status,
    required this.createdAt,
    required this.calledAt,
    required this.startedAt,
    required this.finishedAt,
    required this.cancelledAt,
    required this.cancelReason,
    required this.chat,
    required this.userUnread,
    required this.staffUnread,
    required this.reviewPosted,
    this.reservedSlot = 0,
    required this.position,
    required this.etaSec,
    required this.gameSec,
    required this.intervalSec,
    required this.lateCancelSec,
    required this.reviewsEnabled,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
        id: (json['id'] as String?) ?? '',
        code: (json['code'] as String?) ?? '',
        number: (json['number'] as String?) ?? '',
        kind: (json['kind'] as String?) ?? 'online',
        label: (json['label'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'waiting',
        createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
        calledAt: (json['called_at'] as num?)?.toInt() ?? 0,
        startedAt: (json['started_at'] as num?)?.toInt() ?? 0,
        finishedAt: (json['finished_at'] as num?)?.toInt() ?? 0,
        cancelledAt: (json['cancelled_at'] as num?)?.toInt() ?? 0,
        cancelReason: (json['cancel_reason'] as String?) ?? '',
        chat: ((json['chat'] as List?) ?? const [])
            .map((e) => TicketChatMsg.fromJson(e as Map<String, dynamic>))
            .toList(),
        userUnread: (json['user_unread'] as num?)?.toInt() ?? 0,
        staffUnread: (json['staff_unread'] as num?)?.toInt() ?? 0,
        reviewPosted: (json['review_posted'] as bool?) ?? false,
        reservedSlot: (json['reserved_slot'] as num?)?.toInt() ?? 0,
        position: (json['position'] as num?)?.toInt() ?? -1,
        etaSec: (json['eta_sec'] as num?)?.toInt() ?? 0,
        gameSec: (json['game_sec'] as num?)?.toInt() ?? 180,
        intervalSec: (json['interval_sec'] as num?)?.toInt() ?? 90,
        lateCancelSec: (json['late_cancel_sec'] as num?)?.toInt() ?? 900,
        reviewsEnabled: (json['reviews_enabled'] as bool?) ?? true,
      );

  bool get isActive =>
      status == 'waiting' || status == 'called' || status == 'playing';

  static const statusLabels = <String, String>{
    'waiting': '待機中',
    'called': '呼出中',
    'playing': 'プレイ中',
    'done': '終了',
    'cancelled': 'キャンセル',
  };

  String get statusLabel => statusLabels[status] ?? status;
}

/// 予約可能な日時ウィンドウ（スタッフがダッシュボードで設定）。
class ReserveWindow {
  final String date; // "YYYY-MM-DD"
  final String start; // "HH:MM"
  final String end; // "HH:MM"

  const ReserveWindow({
    required this.date,
    required this.start,
    required this.end,
  });

  factory ReserveWindow.fromJson(Map<String, dynamic> json) => ReserveWindow(
        date: (json['date'] as String?) ?? '',
        start: (json['start'] as String?) ?? '',
        end: (json['end'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {'date': date, 'start': start, 'end': end};
}

/// 予約スロット（空き照会の戻り）。
class ReserveSlot {
  final int start; // epoch sec
  final int end;
  final int capacity;
  final int reserved;
  final int available;

  const ReserveSlot({
    required this.start,
    required this.end,
    required this.capacity,
    required this.reserved,
    required this.available,
  });

  factory ReserveSlot.fromJson(Map<String, dynamic> json) => ReserveSlot(
        start: (json['start'] as num?)?.toInt() ?? 0,
        end: (json['end'] as num?)?.toInt() ?? 0,
        capacity: (json['capacity'] as num?)?.toInt() ?? 0,
        reserved: (json['reserved'] as num?)?.toInt() ?? 0,
        available: (json['available'] as num?)?.toInt() ?? 0,
      );
}

class TicketSettings {
  final int gameSec;
  final int intervalSec;
  final int capacity;
  final int lateCancelSec;
  final bool reviewsEnabled;
  final bool reserveEnabled;
  final int reserveSlotSec;
  final int reserveSlotCapacity;
  final List<ReserveWindow> reserveWindows;
  final List<String> reserveAllowedEmails; // ドメイン外で予約を許可するメール

  const TicketSettings({
    this.gameSec = 180,
    this.intervalSec = 90,
    this.capacity = 200,
    this.lateCancelSec = 900,
    this.reviewsEnabled = true,
    this.reserveEnabled = true,
    this.reserveSlotSec = 1800,
    this.reserveSlotCapacity = 5,
    this.reserveWindows = const [],
    this.reserveAllowedEmails = const [],
  });

  factory TicketSettings.fromJson(Map<String, dynamic> json) => TicketSettings(
        gameSec: (json['game_sec'] as num?)?.toInt() ?? 180,
        intervalSec: (json['interval_sec'] as num?)?.toInt() ?? 90,
        capacity: (json['capacity'] as num?)?.toInt() ?? 200,
        lateCancelSec: (json['late_cancel_sec'] as num?)?.toInt() ?? 900,
        reviewsEnabled: (json['reviews_enabled'] as bool?) ?? true,
        reserveEnabled: (json['reserve_enabled'] as bool?) ?? true,
        reserveSlotSec: (json['reserve_slot_sec'] as num?)?.toInt() ?? 1800,
        reserveSlotCapacity:
            (json['reserve_slot_capacity'] as num?)?.toInt() ?? 5,
        reserveWindows: ((json['reserve_windows'] as List?) ?? const [])
            .map((e) => ReserveWindow.fromJson(e as Map<String, dynamic>))
            .toList(),
        reserveAllowedEmails: ((json['reserve_allowed_emails'] as List?) ??
                const [])
            .map((e) => e.toString())
            .toList(),
      );
}

class Review {
  final String id;
  final String ticketNumber;
  final int stars;
  final String text;
  final int at;

  const Review({
    required this.id,
    required this.ticketNumber,
    required this.stars,
    required this.text,
    required this.at,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: (json['id'] as String?) ?? '',
        ticketNumber: (json['ticket_number'] as String?) ?? '',
        stars: (json['stars'] as num?)?.toInt() ?? 5,
        text: (json['text'] as String?) ?? '',
        at: (json['at'] as num?)?.toInt() ?? 0,
      );
}
