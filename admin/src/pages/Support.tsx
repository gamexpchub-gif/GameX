import { useEffect, useMemo, useRef, useState } from 'react';
import { Bot, BookOpen, Clock, Headphones, MessageSquare, Plus, Send, Star, Ticket as TicketIcon, Trash2, User } from 'lucide-react';
import { HelpArticle, SupportChat, SupportMsg, SupportTicket, act, ago, media, update, useDB } from '../store';
import { Badge, Button, Card, Drawer, Empty, Field, PageHeader, SearchInput, Tabs, cx, inputCls, toast } from '../ui';

const AGENT_KEY = 'gamex_agent_name';
const agentName = () => {
  try {
    return localStorage.getItem(AGENT_KEY) || 'GAMEX Support';
  } catch {
    return 'GAMEX Support';
  }
};

const ticketTone = { open: 'blue', awaiting_customer: 'amber', resolved: 'green', closed: 'slate' } as const;
const ticketLabel = { open: 'Open', awaiting_customer: 'Waiting on customer', resolved: 'Resolved', closed: 'Closed' } as const;
const chatTone = { ai: 'blue', waiting: 'red', agent: 'green', closed: 'slate' } as const;
const chatLabel = { ai: 'AI handling', waiting: 'Needs agent', agent: 'With agent', closed: 'Ended' } as const;
const prioTone = { normal: 'slate', high: 'amber', urgent: 'red' } as const;

const QUICK = [
  'Thanks for reaching out! Let me check this for you.',
  'I have escalated this to our logistics team. You will get an update within 24 hours.',
  'Your refund has been initiated. It reaches UPI in 1–3 days and cards in 5–7 business days.',
  'Could you share a photo or screenshot of the issue?',
  'This is resolved now. Is there anything else I can help with?',
];

export default function Support() {
  const [tab, setTab] = useState<'chats' | 'tickets' | 'articles'>('chats');
  const chats = useDB((d) => d.chats);
  const tickets = useDB((d) => d.tickets);
  const needAgent = chats.filter((c) => c.mode === 'waiting' || (c.mode === 'agent' && c.unreadAdmin)).length;
  const openTickets = tickets.filter((t) => t.status === 'open').length;
  const [agent, setAgent] = useState(agentName);
  const saveAgent = (v: string) => {
    setAgent(v);
    try {
      localStorage.setItem(AGENT_KEY, v);
    } catch {
      /* private mode */
    }
  };
  const today = new Date().toISOString().slice(0, 10);
  const rated = [...tickets, ...chats].filter((x) => x.rating);
  const csat = rated.length ? (rated.reduce((s, x) => s + (x.rating?.stars || 0), 0) / rated.length).toFixed(1) : '—';
  const aiSolved = chats.filter((c) => c.mode === 'closed' && !c.ticketId).length;

  return (
    <>
      <PageHeader
        title="Support"
        subtitle="Live chats with the GAMEX Assistant, tickets and Help Center articles."
        actions={
          <label className="flex items-center gap-2 text-sm text-muted">
            <User size={16} /> Reply as
            <input className={cx(inputCls, 'w-40 py-1.5')} value={agent} onChange={(e) => saveAgent(e.target.value)} />
          </label>
        }
      />
      <div className="mb-5 grid grid-cols-2 gap-3 md:grid-cols-4">
        {[
          { icon: Headphones, label: 'Chats needing agent', value: needAgent, tone: needAgent ? 'text-rose-600' : 'text-ink' },
          { icon: TicketIcon, label: 'Open tickets', value: openTickets, tone: 'text-ink' },
          { icon: Bot, label: 'Chats solved by AI', value: aiSolved, tone: 'text-ink' },
          { icon: Star, label: `CSAT (${rated.length} ratings)`, value: csat, tone: 'text-ink' },
        ].map((s) => (
          <Card key={s.label} className="flex items-center gap-3">
            <s.icon className="text-brand" size={22} />
            <div>
              <p className={cx('text-xl font-extrabold', s.tone)}>{s.value}</p>
              <p className="text-xs text-muted">{s.label}</p>
            </div>
          </Card>
        ))}
      </div>
      <div className="mb-4">
        <Tabs
          value={tab}
          onChange={setTab}
          items={[
            { id: 'chats', label: 'Live chats', count: needAgent },
            { id: 'tickets', label: 'Tickets', count: openTickets },
            { id: 'articles', label: 'Help articles' },
          ]}
        />
      </div>
      {tab === 'chats' && <Chats chats={chats} agent={agent} />}
      {tab === 'tickets' && <Tickets tickets={tickets} agent={agent} today={today} />}
      {tab === 'articles' && <Articles />}
    </>
  );
}

// ------------------------------------------------------------------ chats --
function Chats({ chats, agent }: { chats: SupportChat[]; agent: string }) {
  const [filter, setFilter] = useState<'active' | 'all'>('active');
  const list = useMemo(
    () =>
      chats
        .filter((c) => filter === 'all' || c.mode !== 'closed')
        .sort((a, b) => (a.mode === 'waiting' ? -1 : 0) - (b.mode === 'waiting' ? -1 : 0) || b.updatedAt.localeCompare(a.updatedAt)),
    [chats, filter],
  );
  const [sel, setSel] = useState<string | null>(null);
  const cur = chats.find((c) => c.id === sel) || null;
  useEffect(() => {
    if (cur?.unreadAdmin && cur.mode !== 'waiting') act('POST', `/support/chats/${cur.id}/read`).catch(() => {});
  }, [cur?.id, cur?.unreadAdmin, cur?.mode]);

  return (
    <div className="grid gap-4 lg:grid-cols-[360px_1fr]">
      <Card pad={false} className="max-h-[70vh] overflow-y-auto">
        <div className="flex gap-2 border-b border-slate-100 p-3">
          {(['active', 'all'] as const).map((f) => (
            <button key={f} onClick={() => setFilter(f)} className={cx('rounded-full px-3 py-1 text-xs font-semibold', filter === f ? 'bg-brand text-white' : 'bg-slate-100 text-muted')}>
              {f === 'active' ? 'Active' : 'All'}
            </button>
          ))}
        </div>
        {list.length === 0 && <Empty icon={MessageSquare} title="No chats" text="Customer chats with the GAMEX Assistant appear here." />}
        {list.map((c) => {
          const last = [...c.messages].reverse().find((m) => m.from !== 'system');
          return (
            <button key={c.id} onClick={() => setSel(c.id)} className={cx('block w-full border-b border-slate-100 p-3 text-left hover:bg-slate-50', sel === c.id && 'bg-brand/5')}>
              <div className="flex items-center gap-2">
                <p className="flex-1 truncate font-semibold text-ink">{c.name}</p>
                {c.unreadAdmin && <span className="h-2 w-2 rounded-full bg-rose-500" />}
                <Badge tone={chatTone[c.mode]} dot>
                  {chatLabel[c.mode]}
                </Badge>
              </div>
              <p className="mt-1 truncate text-xs text-muted">{last ? `${last.from === 'customer' ? '' : last.from === 'ai' ? 'AI: ' : 'Agent: '}${last.text}` : '—'}</p>
              <p className="mt-1 text-[11px] text-slate-400">{ago(c.updatedAt)}</p>
            </button>
          );
        })}
      </Card>
      {cur ? (
        <Conversation
          title={cur.name}
          subtitle={`${cur.phone} • ${cur.id}${cur.ticketId ? ` • ticket ${cur.ticketId}` : ''}`}
          badge={
            <Badge tone={chatTone[cur.mode]} dot>
              {chatLabel[cur.mode]}
            </Badge>
          }
          messages={cur.messages}
          disabled={cur.mode === 'closed'}
          actions={
            cur.mode !== 'closed' && (
              <Button size="sm" variant="secondary" onClick={() => act('POST', `/support/chats/${cur.id}/close`).then(() => toast('Chat closed'))}>
                End chat
              </Button>
            )
          }
          onSend={(text) => act('POST', `/support/chats/${cur.id}/reply`, { text, agent }).then(() => undefined)}
          hint={cur.mode === 'ai' ? 'Replying takes the chat over from the AI assistant' : 'Reply to the customer…'}
        />
      ) : (
        <Card>
          <Empty icon={Headphones} title="Select a chat" text="Chats that need an agent are listed first. Your reply is sent instantly with a notification." />
        </Card>
      )}
    </div>
  );
}

// ---------------------------------------------------------------- tickets --
function Tickets({ tickets, agent, today }: { tickets: SupportTicket[]; agent: string; today: string }) {
  const [status, setStatus] = useState<'active' | 'resolved' | 'all'>('active');
  const [q, setQ] = useState('');
  const [sel, setSel] = useState<string | null>(null);
  const list = useMemo(() => {
    const s = q.trim().toLowerCase();
    const prio = { urgent: 0, high: 1, normal: 2 } as const;
    return tickets
      .filter((t) => (status === 'all' ? true : status === 'active' ? ['open', 'awaiting_customer'].includes(t.status) : ['resolved', 'closed'].includes(t.status)))
      .filter((t) => !s || `${t.id} ${t.name} ${t.phone} ${t.subject} ${t.orderId || ''}`.toLowerCase().includes(s))
      .sort((a, b) => Number(b.status === 'open') - Number(a.status === 'open') || prio[a.priority] - prio[b.priority] || a.slaDueAt.localeCompare(b.slaDueAt));
  }, [tickets, status, q]);
  const cur = tickets.find((t) => t.id === sel) || null;
  useEffect(() => {
    if (cur?.unreadAdmin) act('PATCH', `/support/tickets/${cur.id}`, { read: true }).catch(() => {});
  }, [cur?.id, cur?.unreadAdmin]);
  const patch = (body: object) => cur && act('PATCH', `/support/tickets/${cur.id}`, body).then(() => toast('Ticket updated'));

  return (
    <div className="grid gap-4 lg:grid-cols-[400px_1fr]">
      <Card pad={false} className="max-h-[70vh] overflow-y-auto">
        <div className="space-y-2 border-b border-slate-100 p-3">
          <SearchInput value={q} onChange={setQ} placeholder="Search ticket, name, phone, order" />
          <div className="flex gap-2">
            {(['active', 'resolved', 'all'] as const).map((f) => (
              <button key={f} onClick={() => setStatus(f)} className={cx('rounded-full px-3 py-1 text-xs font-semibold capitalize', status === f ? 'bg-brand text-white' : 'bg-slate-100 text-muted')}>
                {f}
              </button>
            ))}
          </div>
        </div>
        {list.length === 0 && <Empty icon={TicketIcon} title="No tickets" text="Tickets raised from the app and escalated chats appear here." />}
        {list.map((t) => {
          const late = ['open'].includes(t.status) && t.slaDueAt < new Date().toISOString();
          return (
            <button key={t.id} onClick={() => setSel(t.id)} className={cx('block w-full border-b border-slate-100 p-3 text-left hover:bg-slate-50', sel === t.id && 'bg-brand/5')}>
              <div className="flex items-center gap-2">
                <p className="flex-1 truncate font-semibold text-ink">{t.subject}</p>
                {t.unreadAdmin && <span className="h-2 w-2 rounded-full bg-rose-500" />}
              </div>
              <p className="mt-1 text-xs text-muted">
                {t.id} • {t.name} • {t.category}
              </p>
              <div className="mt-2 flex flex-wrap items-center gap-1.5">
                <Badge tone={ticketTone[t.status]}>{ticketLabel[t.status]}</Badge>
                {t.priority !== 'normal' && <Badge tone={prioTone[t.priority]}>{t.priority}</Badge>}
                {t.source === 'chat' && <Badge tone="blue">from chat</Badge>}
                {late && (
                  <span className="flex items-center gap-1 text-[11px] font-semibold text-rose-600">
                    <Clock size={11} /> SLA missed
                  </span>
                )}
                <span className="ml-auto text-[11px] text-slate-400">{t.createdAt.slice(0, 10) === today ? ago(t.updatedAt) : t.updatedAt.slice(0, 10)}</span>
              </div>
            </button>
          );
        })}
      </Card>
      {cur ? (
        <Conversation
          title={cur.subject}
          subtitle={`${cur.id} • ${cur.name} • ${cur.phone}${cur.orderId ? ` • order ${cur.orderId}${cur.orderItem ? ` (${cur.orderItem})` : ''}` : ''}`}
          badge={<Badge tone={ticketTone[cur.status]}>{ticketLabel[cur.status]}</Badge>}
          messages={cur.messages}
          disabled={cur.status === 'closed'}
          actions={
            <div className="flex flex-wrap items-center gap-2">
              <select className={cx(inputCls, 'w-auto py-1.5 text-xs')} value={cur.priority} onChange={(e) => patch({ priority: e.target.value })}>
                {['normal', 'high', 'urgent'].map((p) => (
                  <option key={p}>{p}</option>
                ))}
              </select>
              <select className={cx(inputCls, 'w-auto py-1.5 text-xs')} value={cur.status} onChange={(e) => patch({ status: e.target.value })}>
                {Object.entries(ticketLabel).map(([k, v]) => (
                  <option key={k} value={k}>
                    {v}
                  </option>
                ))}
              </select>
              {cur.rating && (
                <Badge tone="amber">
                  {cur.rating.stars}★ {cur.rating.comment}
                </Badge>
              )}
            </div>
          }
          withStatus
          onSend={(text, resolve) => act('POST', `/support/tickets/${cur.id}/reply`, { text, agent, status: resolve ? 'resolved' : undefined }).then(() => undefined)}
          hint="Reply to the customer (they get a notification)…"
        />
      ) : (
        <Card>
          <Empty icon={TicketIcon} title="Select a ticket" text="Open, urgent and overdue tickets are listed first." />
        </Card>
      )}
    </div>
  );
}

// ----------------------------------------------------------- conversation --
function Conversation({
  title,
  subtitle,
  badge,
  messages,
  actions,
  disabled,
  onSend,
  hint,
  withStatus,
}: {
  title: string;
  subtitle: string;
  badge: React.ReactNode;
  messages: SupportMsg[];
  actions?: React.ReactNode;
  disabled?: boolean;
  onSend: (text: string, resolve?: boolean) => Promise<void>;
  hint: string;
  withStatus?: boolean;
}) {
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const end = useRef<HTMLDivElement>(null);
  useEffect(() => end.current?.scrollIntoView({ block: 'end' }), [messages.length]);
  const send = (resolve = false) => {
    if (!text.trim()) return toast('Type a reply');
    setBusy(true);
    onSend(text.trim(), resolve)
      .then(() => {
        setText('');
        toast(resolve ? 'Replied and resolved' : 'Reply sent');
      })
      .catch((e: Error) => toast(e.message))
      .finally(() => setBusy(false));
  };
  return (
    <Card pad={false} className="flex max-h-[70vh] flex-col">
      <div className="flex flex-wrap items-start gap-3 border-b border-slate-100 p-4">
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <p className="truncate font-bold text-ink">{title}</p>
            {badge}
          </div>
          <p className="mt-0.5 truncate text-xs text-muted">{subtitle}</p>
        </div>
        {actions}
      </div>
      <div className="flex-1 space-y-2 overflow-y-auto bg-slate-50 p-4">
        {messages.map((m) =>
          m.from === 'system' ? (
            <p key={m.id} className="text-center text-[11px] text-slate-400">
              {m.text} • {ago(m.at)}
            </p>
          ) : (
            <div key={m.id} className={cx('flex', m.from === 'customer' ? 'justify-start' : 'justify-end')}>
              <div className={cx('max-w-[75%] rounded-2xl px-3 py-2 text-sm', m.from === 'customer' ? 'bg-white text-ink shadow-sm' : m.from === 'ai' ? 'bg-sky-100 text-ink' : 'bg-brand text-white')}>
                <p className={cx('mb-0.5 text-[11px] font-bold', m.from === 'agent' ? 'text-white/80' : 'text-muted')}>
                  {m.from === 'customer' ? 'Customer' : m.from === 'ai' ? 'GAMEX Assistant (AI)' : m.author || 'Agent'}
                </p>
                {m.photos?.map((p) => (
                  <a key={p} href={media(p)} target="_blank" rel="noreferrer">
                    <img src={media(p)} alt="" className="mb-1 max-h-40 rounded-lg" />
                  </a>
                ))}
                <p className="whitespace-pre-wrap">{m.text}</p>
                <p className={cx('mt-1 text-[10px]', m.from === 'agent' ? 'text-white/70' : 'text-slate-400')}>{ago(m.at)}</p>
              </div>
            </div>
          ),
        )}
        <div ref={end} />
      </div>
      {!disabled && (
        <div className="border-t border-slate-100 p-3">
          <div className="mb-2 flex gap-1.5 overflow-x-auto">
            {QUICK.map((q) => (
              <button key={q} onClick={() => setText(q)} className="shrink-0 rounded-full bg-slate-100 px-2.5 py-1 text-[11px] text-muted hover:bg-slate-200">
                {q.slice(0, 38)}…
              </button>
            ))}
          </div>
          <div className="flex items-end gap-2">
            <textarea
              className={cx(inputCls, 'min-h-[44px] flex-1 resize-y')}
              rows={2}
              placeholder={hint}
              value={text}
              onChange={(e) => setText(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) send();
              }}
            />
            <div className="flex flex-col gap-1">
              <Button icon={Send} disabled={busy} onClick={() => send()}>
                Send
              </Button>
              {withStatus && (
                <Button size="sm" variant="success" disabled={busy} onClick={() => send(true)}>
                  Send & resolve
                </Button>
              )}
            </div>
          </div>
          <p className="mt-1 text-[11px] text-slate-400">Ctrl + Enter to send</p>
        </div>
      )}
    </Card>
  );
}

// --------------------------------------------------------------- articles --
const TOPICS = ['orders', 'returns', 'refunds', 'payments', 'warranty', 'quality', 'sell', 'repairs', 'account'];

function Articles() {
  const articles = useDB((d) => d.helpArticles);
  const [edit, setEdit] = useState<HelpArticle | null>(null);
  const save = () => {
    if (!edit) return;
    if (!edit.title.trim() || edit.body.trim().length < 20) return toast('Add a title and a helpful answer');
    const isNew = !edit.id;
    const a = isNew ? { ...edit, id: `h${Date.now().toString(36)}` } : edit;
    update((d) => ({ ...d, helpArticles: isNew ? [...d.helpArticles, a] : d.helpArticles.map((x) => (x.id === a.id ? a : x)) }));
    toast('Article saved — live in the app and used by the AI assistant');
    setEdit(null);
  };
  return (
    <>
      <div className="mb-3 flex items-center justify-between">
        <p className="text-sm text-muted">These answers appear in the app's Help Center and are the policy the AI assistant follows.</p>
        <Button icon={Plus} onClick={() => setEdit({ id: '', topic: 'orders', title: '', body: '' })}>
          New article
        </Button>
      </div>
      <div className="grid gap-3 md:grid-cols-2">
        {articles.map((a) => (
          <Card key={a.id}>
            <div className="flex items-start gap-2">
              <BookOpen size={18} className="mt-0.5 text-brand" />
              <div className="min-w-0 flex-1">
                <p className="font-bold text-ink">{a.title}</p>
                <Badge tone="blue">{a.topic}</Badge>
                <p className="mt-2 line-clamp-3 text-sm text-muted">{a.body}</p>
              </div>
              <div className="flex flex-col gap-1">
                <Button size="sm" variant="secondary" onClick={() => setEdit({ ...a })}>
                  Edit
                </Button>
                <button
                  onClick={() => confirm('Delete this article?') && update((d) => ({ ...d, helpArticles: d.helpArticles.filter((x) => x.id !== a.id) }))}
                  className="rounded-lg p-2 text-muted hover:bg-rose-50 hover:text-rose-600"
                >
                  <Trash2 size={15} />
                </button>
              </div>
            </div>
          </Card>
        ))}
      </div>
      <Drawer
        open={!!edit}
        onClose={() => setEdit(null)}
        title={edit?.id ? 'Edit article' : 'New article'}
        footer={
          <>
            <Button variant="secondary" onClick={() => setEdit(null)}>
              Cancel
            </Button>
            <Button onClick={save}>Save</Button>
          </>
        }
      >
        {edit && (
          <div className="space-y-4">
            <Field label="Topic">
              <select className={inputCls} value={edit.topic} onChange={(e) => setEdit({ ...edit, topic: e.target.value })}>
                {TOPICS.map((t) => (
                  <option key={t}>{t}</option>
                ))}
              </select>
            </Field>
            <Field label="Question">
              <input className={inputCls} value={edit.title} onChange={(e) => setEdit({ ...edit, title: e.target.value })} />
            </Field>
            <Field label="Answer">
              <textarea className={cx(inputCls, 'min-h-[180px]')} value={edit.body} onChange={(e) => setEdit({ ...edit, body: e.target.value })} />
            </Field>
          </div>
        )}
      </Drawer>
    </>
  );
}
